import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('AgentStreamRunState', () {
    test('accumulates streamed text and finishes on terminal events', () {
      var state = const AgentStreamRunState().start();

      for (final event in parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      )) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.threadId, 'thread-fixture-001');
      expect(state.runId, 'run-fixture-text-001');
      expect(state.messageId, 'msg-reply-text-001');
      expect(state.lastSequence, 5);
      expect(
        state.textContent,
        'I can help you review today\'s pumping pattern.',
      );
      expect(state.canRetry, isFalse);
      expect(state.events.length, 3);

      final afterTerminal = state.applyEvent(
        AgentStreamEvent(readFixtureMap('agent_events/run_failed.json')),
      );

      expect(afterTerminal.phase, AgentStreamRunPhase.finished);
      expect(afterTerminal.events.length, 3);
    });

    test('preserves partial text and marks disconnect as retryable', () {
      var state = const AgentStreamRunState().start();
      final events = parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      );

      for (final event in events.take(2)) {
        state = state.applyEvent(event);
      }

      state = state.markDisconnected(StateError('socket closed'));

      expect(state.phase, AgentStreamRunPhase.disconnected);
      expect(state.canRetry, isTrue);
      expect(state.textContent, 'I can help ');
      expect(state.errorMessage, contains('socket closed'));
    });

    test(
      'releases received artifacts after text or a successful terminal signal',
      () {
        final artifact = AgentStreamEvent(const {
          'event_id': 'evt-artifact-pending',
          'type': 'artifact.created',
          'thread_id': 'thread-artifact-pending',
          'run_id': 'run-artifact-pending',
          'artifact_id': 'artifact-pending',
          'sequence': 1,
          'payload': {
            'artifact_type': 'card',
            'card': {'title': '待发布卡片'},
          },
        });
        final pending = const AgentStreamRunState().start().applyEvent(
          artifact,
        );

        expect(pending.artifactEvents, isNotEmpty);
        expect(pending.canPublishArtifactEvents, isFalse);

        final withText = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-text',
            'type': 'message.delta',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'message_id': 'message-artifact-pending',
            'sequence': 2,
            'payload': {'text': '我已经整理好了。'},
          }),
        );
        expect(withText.canPublishArtifactEvents, isTrue);

        final withWhitespace = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-whitespace',
            'type': 'message.delta',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'message_id': 'message-artifact-pending',
            'sequence': 2,
            'payload': {'text': ' \n'},
          }),
        );
        expect(withWhitespace.canPublishArtifactEvents, isFalse);

        final withCompletedMessage = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-message-completed',
            'type': 'message.completed',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'message_id': 'message-artifact-pending',
            'sequence': 2,
            'payload': {'role': 'assistant', 'text': ''},
          }),
        );
        expect(withCompletedMessage.canPublishArtifactEvents, isTrue);

        final withCompletedRun = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-run-completed',
            'type': 'run.completed',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'sequence': 2,
          }),
        );
        expect(withCompletedRun.canPublishArtifactEvents, isTrue);

        final waitingForConfirmation = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-waiting',
            'type': 'run.waiting_for_confirmation',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'sequence': 2,
          }),
        );
        expect(waitingForConfirmation.canPublishArtifactEvents, isTrue);

        final failed = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-run-failed',
            'type': 'run.failed',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'sequence': 2,
          }),
        );
        expect(failed.canPublishArtifactEvents, isFalse);
        expect(
          pending
              .markDisconnected(StateError('socket closed'))
              .canPublishArtifactEvents,
          isFalse,
        );
        final cancelled = pending.applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-artifact-cancelled',
            'type': 'run.cancelled',
            'thread_id': 'thread-artifact-pending',
            'run_id': 'run-artifact-pending',
            'sequence': 2,
          }),
        );
        expect(cancelled.canPublishArtifactEvents, isFalse);
      },
    );

    test('deduplicates replayed events by event id or sequence', () {
      var state = const AgentStreamRunState().start();
      final replayedEvents = [
        const {
          'type': 'run.started',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'sequence': 1,
        },
        const {
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'sequence': 2,
          'payload': {'text': 'Already streamed '},
        },
        const {
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'sequence': 2,
          'payload': {'text': 'Already streamed '},
        },
        const {
          'event_id': 'evt-replay-003',
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'payload': {'text': 'only once.'},
        },
        const {
          'event_id': 'evt-replay-003',
          'type': 'message.delta',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'payload': {'text': 'only once.'},
        },
        const {
          'type': 'run.completed',
          'thread_id': 'thread-fixture-001',
          'run_id': 'run-replay-001',
          'message_id': 'msg-replay-001',
          'sequence': 4,
        },
      ].map(AgentStreamEvent.new);

      for (final event in replayedEvents) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.textContent, 'Already streamed only once.');
      expect(state.events.length, 2);
    });

    test('keeps streamed text stable when assistant completed arrives', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'delta:1720000000-0',
          'type': 'message.delta',
          'thread_id': 'thread-transient-001',
          'run_id': 'run-transient-001',
          'transient': true,
          'cursor': '1720000000-0',
          'payload': {'delta': '正在'},
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'delta:1720000000-1',
          'type': 'message.delta',
          'thread_id': 'thread-transient-001',
          'run_id': 'run-transient-001',
          'transient': true,
          'cursor': '1720000000-1',
          'payload': {'delta': '生成'},
        }),
      );

      expect(state.textContent, '正在生成');
      expect(state.provisionalTextContent, '正在生成');
      expect(state.lastSequence, isNull);
      expect(state.events, isEmpty);

      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'evt-final-001',
          'type': 'message.completed',
          'thread_id': 'thread-transient-001',
          'run_id': 'run-transient-001',
          'message_id': 'msg-final-001',
          'sequence': 4,
          'payload': {'role': 'assistant', 'text': '这是最终回复。'},
        }),
      );

      expect(state.textContent, '正在生成');
      expect(state.provisionalTextContent, '');
      expect(state.lastSequence, 4);
      expect(state.phase, AgentStreamRunPhase.streaming);
      expect(state.hasCompletedAssistantMessage, isTrue);
      expect(state.isAwaitingVisibleReply, isFalse);
    });

    test('only appends missing completed suffix to streamed text', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.delta',
          'thread_id': 'thread-suffix-001',
          'run_id': 'run-suffix-001',
          'message_id': 'msg-suffix-001',
          'payload': {'delta': '这是最终'},
        }),
      );

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.completed',
          'thread_id': 'thread-suffix-001',
          'run_id': 'run-suffix-001',
          'message_id': 'msg-suffix-001',
          'payload': {'role': 'assistant', 'text': '这是最终回复。'},
        }),
      );

      expect(state.textContent, '这是最终回复。');
      expect(state.provisionalTextContent, '');
    });

    test('does not replace streamed text on completed mismatch', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'delta:mismatch-001',
          'type': 'message.delta',
          'thread_id': 'thread-mismatch-001',
          'run_id': 'run-mismatch-001',
          'message_id': 'msg-mismatch-001',
          'transient': true,
          'payload': {'delta': '用户已经看到的回复'},
        }),
      );

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.completed',
          'thread_id': 'thread-mismatch-001',
          'run_id': 'run-mismatch-001',
          'message_id': 'msg-mismatch-001',
          'payload': {
            'role': 'assistant',
            'text': '后端最终清洗后的不同回复',
            'quick_replies': [
              {'text': '继续聊这个'},
              {'text': '给我更多细节'},
              {'text': '换个方向'},
            ],
          },
        }),
      );

      expect(state.textContent, '用户已经看到的回复');
      expect(state.provisionalTextContent, '');
      expect(state.quickReplies, ['继续聊这个', '给我更多细节', '换个方向']);
    });

    test('updates quick replies from transient completed message payload', () {
      var state = const AgentStreamRunState().start();
      final events = parseAgentEventStream('''
id: 1
data: {"type":"message.completed","thread_id":"thread-quick-001","run_id":"run-quick-001","message_id":"msg-quick-001","payload":{"role":"assistant","text":"已经整理好了。","quick_replies":[{"id":"qr_1","text":"继续聊这个"},{"id":"qr_2","text":"给我更多细节"},{"id":"qr_3","text":"换个方向"}]}}

id: 3
data: {"type":"run.completed","thread_id":"thread-quick-001","run_id":"run-quick-001"}

''');

      for (final event in events) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.messageId, 'msg-quick-001');
      expect(state.textContent, '已经整理好了。');
      expect(state.quickReplies, ['继续聊这个', '给我更多细节', '换个方向']);
    });

    test(
      'persists the latest workflow reply cursor across app restoration',
      () {
        final state = const AgentStreamRunState().start().applyEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-workflow-reply-001',
            'type': 'message.completed',
            'thread_id': 'thread-workflow-reply-001',
            'run_id': 'run-workflow-reply-001',
            'payload': {
              'role': 'assistant',
              'text': '宝宝最近 24 小时大约有几片湿尿布？',
              'workflow_reply': {
                'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
                'workflow_type': 'milk_analysis',
                'revision': 6,
                'step_token': 'opaque-step-token',
              },
            },
          }),
        );

        final restored = AgentStreamRunState.fromMap(state.toMap());

        expect(restored.workflowReply, {
          'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
          'workflow_type': 'milk_analysis',
          'revision': 6,
          'step_token': 'opaque-step-token',
        });
      },
    );

    test('does not replace indexed streamed text on completed mismatch', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.delta',
          'thread_id': 'thread-stale-001',
          'run_id': 'run-stale-001',
          'message_id': 'msg-stale-001',
          'sequence': 2,
          'payload': {'delta': '旧的 partial'},
        }),
      );

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.completed',
          'thread_id': 'thread-stale-001',
          'run_id': 'run-stale-001',
          'message_id': 'msg-stale-001',
          'sequence': 3,
          'payload': {'role': 'assistant', 'text': '重试后的完整回复'},
        }),
      );

      expect(state.textContent, '旧的 partial');
      expect(state.provisionalTextContent, '');
    });

    test('buffers indexed segment gaps and drains them in order', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        _indexedDelta(index: 0, delta: 'A', prefixHash: _sha256A),
      );
      state = state.applyEvent(
        _indexedDelta(index: 2, delta: 'C', prefixHash: _sha256Abc),
      );

      expect(state.textContent, 'A');
      expect(state.nextTextSegmentIndex, 1);
      expect(state.hasTextSegmentGap, isTrue);

      state = state.applyEvent(
        _indexedDelta(index: 1, delta: 'B', prefixHash: _sha256Ab),
      );

      expect(state.textContent, 'ABC');
      expect(state.nextTextSegmentIndex, 3);
      expect(state.hasTextSegmentGap, isFalse);
      expect(state.textIntegrityErrorCode, isNull);
    });

    test('rejects an indexed segment with invalid prefix integrity', () {
      final state = const AgentStreamRunState().start().applyEvent(
        _indexedDelta(index: 0, delta: 'A', prefixHash: 'invalid'),
      );

      expect(state.textContent, isEmpty);
      expect(state.nextTextSegmentIndex, 0);
      expect(state.textIntegrityErrorCode, 'prefix_hash_mismatch');
    });

    test('completed text only appends a missing indexed suffix', () {
      var state = const AgentStreamRunState().start().applyEvent(
        _indexedDelta(index: 0, delta: 'A', prefixHash: _sha256A),
      );

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'message.completed',
          'run_id': 'run-indexed-001',
          'message_id': 'msg-indexed-001',
          'payload': {
            'role': 'assistant',
            'text': 'ABC',
            'stream_schema_version': 'append-only.v1',
            'segment_count': 3,
            'content_utf8_bytes': 3,
            'content_sha256': _sha256Abc,
          },
        }),
      );

      expect(state.textContent, 'ABC');
      expect(state.nextTextSegmentIndex, 3);
      expect(state.hasTextSegmentGap, isFalse);
      expect(state.textIntegrityErrorCode, isNull);
    });

    test('keeps repeated text deltas when no replay key is present', () {
      var state = const AgentStreamRunState().start();

      for (final event in [
        const {
          'type': 'message.delta',
          'run_id': 'run-repeat-001',
          'message_id': 'msg-repeat-001',
          'payload': {'text': 'ha '},
        },
        const {
          'type': 'message.delta',
          'run_id': 'run-repeat-001',
          'message_id': 'msg-repeat-001',
          'payload': {'text': 'ha '},
        },
      ].map(AgentStreamEvent.new)) {
        state = state.applyEvent(event);
      }

      expect(state.textContent, 'ha ha ');
      expect(state.events, isEmpty);
    });

    test('keeps transient delta replay keys without growing event history', () {
      var state = const AgentStreamRunState().start();

      for (var index = 0; index < 120; index++) {
        state = state.applyEvent(
          AgentStreamEvent({
            'event_id': 'delta:stream-$index',
            'type': 'message.delta',
            'thread_id': 'thread-heavy-delta',
            'run_id': 'run-heavy-delta',
            'transient': true,
            'payload': {'delta': '字'},
          }),
        );
      }

      state = state.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'delta:stream-42',
          'type': 'message.delta',
          'thread_id': 'thread-heavy-delta',
          'run_id': 'run-heavy-delta',
          'transient': true,
          'payload': {'delta': '重复'},
        }),
      );

      expect(state.textContent.length, 120);
      expect(state.events, isEmpty);
      expect(state.seenReplayKeys.length, 120);
    });

    test('uses durable completed message text when deltas are absent', () {
      var state = const AgentStreamRunState().start();

      for (final event in [
        const {
          'type': 'run.started',
          'thread_id': 'thread-durable-001',
          'run_id': 'run-durable-001',
          'message_id': 'msg-durable-001',
        },
        const {
          'type': 'message.completed',
          'thread_id': 'thread-durable-001',
          'run_id': 'run-durable-001',
          'message_id': 'msg-durable-001',
          'payload': {
            'message': {
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'Durable assistant reply.'},
              ],
            },
          },
        },
        const {
          'type': 'run.completed',
          'thread_id': 'thread-durable-001',
          'run_id': 'run-durable-001',
          'message_id': 'msg-durable-001',
        },
      ].map(AgentStreamEvent.new)) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.textContent, 'Durable assistant reply.');
    });

    test('applies canonical text and terminal events from SSE', () {
      var state = const AgentStreamRunState().start();
      final events = parseAgentEventStream('''
id: 3
data: {"type":"run.started","thread_id":"thread-canonical-001","run_id":"run-canonical-001"}

id: 4
data: {"type":"message.delta","thread_id":"thread-canonical-001","run_id":"run-canonical-001","payload":{"message_stream_id":"msg-canonical-001","delta":"你好呀～"}}

id: 5
data: {"type":"message.completed","thread_id":"thread-canonical-001","run_id":"run-canonical-001","message_id":"msg-canonical-001","payload":{"role":"assistant","text":"你好呀～"}}

id: 6
data: {"type":"run.completed","thread_id":"thread-canonical-001","run_id":"run-canonical-001"}

''');

      for (final event in events) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.textContent, '你好呀～');
      expect(state.threadId, 'thread-canonical-001');
      expect(state.runId, 'run-canonical-001');
      expect(state.messageId, 'msg-canonical-001');
      expect(state.lastSequence, 6);
      expect(events.map((event) => event.type), [
        'run.started',
        'message.delta',
        'message.completed',
        'run.completed',
      ]);
    });

    test('keeps canonical tool JSON out of text and stores quick replies', () {
      var state = const AgentStreamRunState().start();
      final events = parseAgentEventStream('''
id: 1
data: {"type":"run.started","thread_id":"thread-canonical-tools","run_id":"run-canonical-tools"}

id: 2
data: {"type":"tool.progress","thread_id":"thread-canonical-tools","run_id":"run-canonical-tools","payload":{"tool_call_id":"call-profile","safe_args":{"preferred_name":"henson"}}}

id: 3
data: {"type":"tool.completed","thread_id":"thread-canonical-tools","run_id":"run-canonical-tools","payload":{"tool_call_id":"call-profile","safe_output":{"preferred_name":"Mai"}}}

id: 4
data: {"type":"message.delta","thread_id":"thread-canonical-tools","run_id":"run-canonical-tools","payload":{"message_stream_id":"msg-canonical-tools","delta":"你好 henson"}}

id: 5
data: {"type":"message.completed","thread_id":"thread-canonical-tools","run_id":"run-canonical-tools","message_id":"msg-canonical-tools","payload":{"role":"assistant","text":"你好 henson","quick_replies":[{"id":"qr_1","text":"继续聊这个"},{"id":"qr_2","text":"给我更多细节"},{"id":"qr_3","text":"换个方向"}]}}

id: 7
data: {"type":"run.completed","thread_id":"thread-canonical-tools","run_id":"run-canonical-tools"}

''');

      for (final event in events) {
        state = state.applyEvent(event);
      }

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.textContent, '你好 henson');
      expect(state.textContent, isNot(contains('preferred_name')));
      expect(state.quickReplies, ['继续聊这个', '给我更多细节', '换个方向']);
    });

    test('maps run error events to non-retryable error state', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(readFixtureMap('agent_events/run_failed.json')),
      );

      expect(state.phase, AgentStreamRunPhase.error);
      expect(state.canRetry, isFalse);
      expect(
        state.errorMessage,
        'The agent stream timed out before a final response.',
      );
    });

    test(
      'preserves waiting-for-confirmation state without retry affordance',
      () {
        var state = const AgentStreamRunState().start();

        state = state.applyEvent(
          AgentStreamEvent(const {
            'type': 'message.completed',
            'thread_id': 'thread-action-001',
            'run_id': 'run-action-001',
            'message_id': 'msg-action-001',
            'payload': {'text': '请确认是否创建支持工单。'},
          }),
        );
        state = state.applyEvent(
          AgentStreamEvent(const {
            'type': 'run.waiting_for_confirmation',
            'thread_id': 'thread-action-001',
            'run_id': 'run-action-001',
            'message_id': 'msg-action-001',
            'payload': {'pending_action_id': 'action-support-001'},
          }),
        );

        expect(state.phase, AgentStreamRunPhase.waitingForConfirmation);
        expect(state.isActive, isFalse);
        expect(state.blocksComposer, isTrue);
        expect(state.canRetry, isFalse);
        expect(state.textContent, '请确认是否创建支持工单。');
        expect(state.runId, 'run-action-001');
      },
    );

    test('does not index or serialize hidden and implicit action cards', () {
      var hidden = const AgentStreamRunState().start();
      hidden = hidden.applyEvent(
        AgentStreamEvent(const {
          'event_id': 'evt-direct-applied',
          'type': 'action.applied',
          'thread_id': 'thread-direct',
          'run_id': 'run-direct',
          'action_id': 'action-direct',
          'sequence': 1,
          'payload': {
            'action_id': 'action-direct',
            'action_status': 'applied',
            'user_visible': false,
            'requires_confirmation': false,
            'execution_mode': 'explicit_intent',
          },
        }),
      );

      expect(hidden.actionEvents, isEmpty);
      expect(hidden.lastSequence, 1);
      expect(hidden.seenReplayKeys, contains('event:evt-direct-applied'));
      expect(hidden.toMap(), isNot(contains('events')));

      final implicit = const AgentStreamRunState().start().applyEvent(
        AgentStreamEvent(const {
          'event_id': 'evt-implicit-applied',
          'type': 'action.applied',
          'action_id': 'action-implicit',
          'sequence': 2,
          'payload': {
            'action_id': 'action-implicit',
            'action_status': 'applied',
          },
        }),
      );

      expect(implicit.actionEvents, isEmpty);
      expect(implicit.toMap(), isNot(contains('events')));
    });

    test('keeps one visible action through confirmation lifecycle events', () {
      var state = const AgentStreamRunState().start();
      for (final event in [
        AgentStreamEvent(const {
          'event_id': 'evt-visible-confirmation',
          'type': 'action.confirmation_required',
          'action_id': 'action-visible',
          'sequence': 1,
          'payload': {
            'action_id': 'action-visible',
            'action_status': 'confirmation_required',
            'user_visible': true,
            'requires_confirmation': true,
          },
        }),
        AgentStreamEvent(const {
          'event_id': 'evt-visible-applied',
          'type': 'action.applied',
          'action_id': 'action-visible',
          'sequence': 2,
          'payload': {
            'action_id': 'action-visible',
            'action_status': 'applied',
          },
        }),
      ]) {
        state = state.applyEvent(event);
      }

      expect(state.actionEvents, hasLength(1));
      expect(state.actionEvents['action-visible']?.type, 'action.applied');
      final restored = AgentStreamRunState.fromMap(state.toMap());
      expect(restored.actionEvents, hasLength(1));
      expect(restored.actionEvents['action-visible']?.type, 'action.applied');

      final legacy = const AgentStreamRunState().start().applyEvent(
        AgentStreamEvent(const {
          'event_id': 'evt-legacy-confirmation',
          'type': 'action.confirmation_required',
          'action_id': 'action-legacy',
          'sequence': 1,
          'payload': {'action_id': 'action-legacy'},
        }),
      );
      expect(legacy.actionEvents, contains('action-legacy'));
    });

    test('merges action events after waiting for confirmation', () {
      var state = const AgentStreamRunState().start();

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'action.confirmation_required',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 3,
          'payload': {
            'action_id': 'action-support-001',
            'action_status': 'confirmation_required',
            'action_type': 'support.ticket.create',
            'target_type': 'support_ticket',
            'preview_payload': {'title': '创建售后工单'},
          },
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 4,
          'payload': {'action_id': 'action-support-001'},
        }),
      );

      expect(state.phase, AgentStreamRunPhase.waitingForConfirmation);
      expect(
        state.actionEvents['action-support-001']?.type,
        'action.confirmation_required',
      );

      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'action.queued',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 5,
          'payload': {
            'action_id': 'action-support-001',
            'action_status': 'confirmed',
            'action_type': 'support.ticket.create',
            'target_type': 'support_ticket',
          },
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'action.applied',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 6,
          'payload': {
            'action_id': 'action-support-001',
            'action_status': 'applied',
            'action_type': 'support.ticket.create',
            'target_type': 'support_ticket',
          },
        }),
      );
      state = state.applyEvent(
        AgentStreamEvent(const {
          'type': 'run.completed',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 7,
          'payload': {'action_id': 'action-support-001'},
        }),
      );

      expect(state.phase, AgentStreamRunPhase.finished);
      expect(state.lastSequence, 7);
      expect(state.actionEvents['action-support-001']?.type, 'action.applied');
      expect(state.events.map((event) => event.type), [
        'action.confirmation_required',
        'run.waiting_for_confirmation',
        'action.queued',
        'action.applied',
        'run.completed',
      ]);
    });

    test('indexes tool and artifact lifecycle by stable ids', () {
      var state = const AgentStreamRunState().start();

      for (final event in [
        const {
          'type': 'tool.started',
          'thread_id': 'thread-tool-001',
          'run_id': 'run-tool-001',
          'sequence': 2,
          'payload': {'tool_call_id': 'tool-read-001'},
        },
        const {
          'type': 'tool.completed',
          'thread_id': 'thread-tool-001',
          'run_id': 'run-tool-001',
          'sequence': 3,
          'payload': {'tool_call_id': 'tool-read-001'},
        },
        const {
          'type': 'artifact.created',
          'thread_id': 'thread-tool-001',
          'run_id': 'run-tool-001',
          'sequence': 4,
          'payload': {'artifact_id': 'artifact-plan-001', 'title': '今日计划'},
        },
      ].map(AgentStreamEvent.new)) {
        state = state.applyEvent(event);
      }

      expect(state.toolEvents['tool-read-001']?.type, 'tool.completed');
      expect(
        state.artifactEvents['artifact-plan-001']?.type,
        'artifact.created',
      );
      expect(state.lastSequence, 4);
    });

    test('keeps local cancel state even when backend cancel fails', () {
      var state = const AgentStreamRunState().start().requestCancel();

      state = state.applyCancelResult(
        acknowledged: false,
        statusCode: 503,
        error: 'cancel failed',
      );

      expect(state.phase, AgentStreamRunPhase.cancelled);
      expect(state.cancelAcknowledged, isFalse);
      expect(state.cancelStatusCode, 503);
      expect(state.errorMessage, 'cancel failed');
      expect(state.canRetry, isFalse);
    });

    test('records acknowledged cancel responses', () {
      var state = const AgentStreamRunState().start().requestCancel();

      state = state.applyCancelResult(acknowledged: true, statusCode: 404);

      expect(state.phase, AgentStreamRunPhase.cancelled);
      expect(state.cancelAcknowledged, isTrue);
      expect(state.cancelStatusCode, 404);
      expect(state.errorMessage, isNull);
    });

    test('serializes and restores stable replay state', () {
      var state = const AgentStreamRunState().start();
      final events = [
        const {
          'event_id': 'evt-action-1',
          'type': 'action.confirmation_required',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'action_id': 'action-1',
          'sequence': 2,
          'payload': {
            'summary': '创建支持工单',
            'preview_payload': {'title': '提交人工支持'},
          },
        },
        const {
          'event_id': 'evt-wait-1',
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-action',
          'run_id': 'run-action',
          'sequence': 3,
        },
      ].map(AgentStreamEvent.new);

      for (final event in events) {
        state = state.applyEvent(event);
      }

      final restored = AgentStreamRunState.fromMap(state.toMap());

      expect(restored.phase, AgentStreamRunPhase.waitingForConfirmation);
      expect(restored.threadId, 'thread-action');
      expect(restored.runId, 'run-action');
      expect(restored.lastSequence, 3);
      expect(restored.events.length, 2);
      expect(restored.actionEvents, contains('action-1'));
      expect(restored.applyEvent(events.last).events.length, 2);
    });

    test('serializes transient delta replay keys without raw delta events', () {
      var state = const AgentStreamRunState().start();
      final delta = AgentStreamEvent(const {
        'event_id': 'delta:restore-1',
        'type': 'message.delta',
        'thread_id': 'thread-restore-delta',
        'run_id': 'run-restore-delta',
        'transient': true,
        'payload': {'delta': '恢复'},
      });

      state = state.applyEvent(delta);
      final restored = AgentStreamRunState.fromMap(state.toMap());
      final afterReplay = restored.applyEvent(delta);

      expect(restored.textContent, '恢复');
      expect(restored.events, isEmpty);
      expect(afterReplay.textContent, '恢复');
      expect(afterReplay.events, isEmpty);
    });

    test('restores pending indexed segments and drains a recovered gap', () {
      var state = const AgentStreamRunState().start();
      state = state.applyEvent(
        _indexedDelta(index: 0, delta: 'A', prefixHash: _sha256A),
      );
      state = state.applyEvent(
        _indexedDelta(index: 2, delta: 'C', prefixHash: _sha256Abc),
      );

      final restored = AgentStreamRunState.fromMap(state.toMap());
      final recovered = restored.applyEvent(
        _indexedDelta(index: 1, delta: 'B', prefixHash: _sha256Ab),
      );

      expect(restored.textContent, 'A');
      expect(restored.hasTextSegmentGap, isTrue);
      expect(recovered.textContent, 'ABC');
      expect(recovered.hasTextSegmentGap, isFalse);
      expect(recovered.nextTextSegmentIndex, 3);
    });
  });
}

const _sha256A =
    '559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd';
const _sha256Ab =
    '38164fbd17603d73f696b8b4d72664d735bb6a7c88577687fd2ae33fd6964153';
const _sha256Abc =
    'b5d4045c3f466fa91fe2cc6abe79232a1a57cdf104f7a26e716e0a1e2789df78';

AgentStreamEvent _indexedDelta({
  required int index,
  required String delta,
  required String prefixHash,
}) {
  return AgentStreamEvent({
    'event_id': 'delta:indexed-$index',
    'type': 'message.delta',
    'thread_id': 'thread-indexed-001',
    'run_id': 'run-indexed-001',
    'transient': true,
    'payload': {
      'delta': delta,
      'message_stream_id': 'msg-indexed-001',
      'stream_schema_version': 'append-only.v1',
      'segment_index': index,
      'prefix_utf8_bytes': index + 1,
      'prefix_sha256': prefixHash,
    },
  });
}
