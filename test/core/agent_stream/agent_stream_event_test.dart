import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Agent stream fixtures', () {
    test('parse the same logical text stream from JSONL and SSE frames', () {
      final jsonl = parseAgentJsonl(
        readMigrationFixture('agent_events/text_stream_basic.jsonl'),
      );
      final sse = parseAgentEventStream(
        readMigrationFixture('agent_events/text_stream_basic.eventstream'),
      );

      expect(sse.map((event) => event.raw), jsonl.map((event) => event.raw));
      expect(
        jsonl
            .where((event) => event.type == 'message.delta')
            .map((event) => event.textDelta)
            .whereType<String>()
            .join(),
        'I can help you review today\'s pumping pattern.',
      );
    });

    test('cover the required domain event types and stable merge keys', () {
      final events = <AgentStreamEvent>[
        AgentStreamEvent(readFixtureMap('agent_events/run_started.json')),
        ...parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        ),
        ...parseAgentJsonl(
          readMigrationFixture('agent_events/tool_call_lifecycle.jsonl'),
        ),
        AgentStreamEvent(
          readFixtureMap('agent_events/rich_text_artifact.json'),
        ),
        AgentStreamEvent(readFixtureMap('agent_events/run_failed.json')),
      ];
      final types = events.map((event) => event.type).toSet();

      expect(
        types,
        containsAll(<String>[
          'run.started',
          'message.delta',
          'message.completed',
          'run.completed',
          'run.failed',
          'tool.started',
          'tool.completed',
          'artifact.created',
          'action.confirmation_required',
        ]),
      );
      expect(events.every((event) => event.mergeKey.isNotEmpty), isTrue);
      expect(
        events.where((event) => event.isTerminal).map((event) => event.type),
        containsAll(['run.completed', 'run.failed']),
      );
    });

    test(
      'treats waiting for confirmation as a stable terminal stream event',
      () {
        final event = AgentStreamEvent(const {
          'type': 'run.waiting_for_confirmation',
          'thread_id': 'thread-action-001',
          'run_id': 'run-action-001',
          'sequence': 5,
        });

        expect(event.isTerminal, isTrue);
        expect(event.replayKey, 'sequence:run-action-001:5');
      },
    );

    test('uses payload action ids as stable reducer keys', () {
      final event = AgentStreamEvent(const {
        'type': 'action.queued',
        'thread_id': 'thread-action-001',
        'run_id': 'run-action-001',
        'payload': {'action_id': 'action-support-001'},
      });

      expect(event.mergeKey, 'action:action-support-001');
    });

    test('exposes production reducer ids from raw or payload fields', () {
      final event = AgentStreamEvent(const {
        'event_id': 'evt-action-001',
        'type': 'action.applied',
        'thread_id': 'thread-action-001',
        'run_id': 'run-action-001',
        'sequence': '8',
        'payload': {
          'action_id': 'action-support-001',
          'tool_call_id': 'tool-support-001',
          'artifact_id': 'artifact-support-001',
          'cursor': '1720000000-0',
        },
      });

      expect(event.sequence, 8);
      expect(event.actionId, 'action-support-001');
      expect(event.toolCallId, 'tool-support-001');
      expect(event.artifactId, 'artifact-support-001');
      expect(event.cursor, '1720000000-0');
      expect(event.isTransient, isFalse);
    });

    test('recognizes transient message delta events', () {
      final event = AgentStreamEvent(const {
        'event_id': 'delta:1720000000-0',
        'type': 'message.delta',
        'thread_id': 'thread-stream-001',
        'run_id': 'run-stream-001',
        'transient': true,
        'cursor': '1720000000-0',
        'payload': {
          'delta': '正在生成',
          'message_stream_id': 'assistant',
          'stream_schema_version': 'append-only.v1',
          'segment_index': 2,
          'prefix_utf8_bytes': 12,
          'prefix_sha256': 'prefix-hash',
        },
      });

      expect(event.isTransient, isTrue);
      expect(event.sequence, isNull);
      expect(event.textDelta, '正在生成');
      expect(event.messageStreamId, 'assistant');
      expect(event.streamSchemaVersion, 'append-only.v1');
      expect(event.segmentIndex, 2);
      expect(event.prefixUtf8Bytes, 12);
      expect(event.prefixSha256, 'prefix-hash');
      expect(event.replayKey, 'event:delta:1720000000-0');
    });

    test('exposes backend semantic metadata from payload or raw fields', () {
      final payloadSemantic = AgentStreamEvent(const {
        'type': 'run.progress',
        'created_at': '2026-07-27T10:00:00Z',
        'payload': {
          'semantic': {
            'label': '我在组织回复～',
            'surface': 'status_bar',
            'lifecycle': 'running',
            'merge_key': 'progress:response_finalizing',
            'priority': 80,
          },
        },
      });
      final rawSemantic = AgentStreamEvent(const {
        'type': 'run.progress',
        'semantic': {'label': '我想一下', 'surface': 'thinking_note'},
      });

      expect(payloadSemantic.semanticLabel, '我在组织回复～');
      expect(payloadSemantic.semanticSurface, 'status_bar');
      expect(payloadSemantic.semanticLifecycle, 'running');
      expect(payloadSemantic.semanticMergeKey, 'progress:response_finalizing');
      expect(payloadSemantic.semanticPriority, 80);
      expect(payloadSemantic.createdAt, DateTime.utc(2026, 7, 27, 10));
      expect(rawSemantic.semanticLabel, '我想一下');
      expect(rawSemantic.semanticSurface, 'thinking_note');
    });

    test('uses payload tool call ids as stable reducer keys', () {
      final started = AgentStreamEvent(const {
        'type': 'tool.started',
        'thread_id': 'thread-tool-001',
        'run_id': 'run-tool-001',
        'payload': {
          'tool_call_id': 'call-pump-001',
          'tool_name': 'pump_session_summary_query',
        },
      });
      final completed = AgentStreamEvent(const {
        'type': 'tool.completed',
        'thread_id': 'thread-tool-001',
        'run_id': 'run-tool-001',
        'payload': {
          'tool_call_id': 'call-pump-001',
          'tool_name': 'pump_session_summary_query',
        },
      });

      expect(started.mergeKey, 'tool:call-pump-001');
      expect(completed.mergeKey, started.mergeKey);
    });

    test('does not expose canonical tool payloads as assistant text', () {
      final args = AgentStreamEvent(const {
        'type': 'tool.progress',
        'payload': {
          'tool_call_id': 'call-profile',
          'safe_args': {'display_name': 'henson'},
        },
      });
      final result = AgentStreamEvent(const {
        'type': 'tool.completed',
        'payload': {
          'tool_call_id': 'call-skill',
          'safe_output': {'service_skill_id': 'birth-prep'},
        },
      });

      expect(args.type, 'tool.progress');
      expect(args.textDelta, isNull);
      expect(args.completedText, isNull);
      expect(result.type, 'tool.completed');
      expect(result.textDelta, isNull);
      expect(result.completedText, isNull);
    });

    test('strips structured tool JSON from assistant completed text', () {
      final event = AgentStreamEvent(const {
        'type': 'message.completed',
        'payload': {
          'role': 'assistant',
          'text':
              '我先帮你看一下。\n{"service_skill_id":"milk-management","status":"service_skill_loaded"}',
        },
      });

      expect(event.completedText, '我先帮你看一下。');
      expect(event.completedText, isNot(contains('service_skill_id')));
    });

    test('does not extract quick replies from assistant text JSON fallback', () {
      final event = AgentStreamEvent(const {
        'type': 'message.completed',
        'payload': {
          'role': 'assistant',
          'text':
              '已经整理好了。\n{"quick_replies":[{"text":"继续聊这个"},{"text":"给我更多细节"},{"text":"换个方向"}]}',
        },
      });

      expect(event.completedText, '已经整理好了。');
      expect(event.quickReplies, isEmpty);
    });

    test(
      'extracts exactly three quick replies from completed message payload',
      () {
        final event = AgentStreamEvent(const {
          'type': 'message.completed',
          'payload': {
            'role': 'assistant',
            'message_id': 'msg-quick-001',
            'text': '已经整理好了。',
            'quick_replies': [
              {'id': 'qr_1', 'text': '继续聊这个'},
              {'id': 'qr_2', 'text': '给我更多细节'},
              {'id': 'qr_3', 'text': '换个方向'},
            ],
          },
        });

        expect(event.messageId, 'msg-quick-001');
        expect(event.quickReplies, ['继续聊这个', '给我更多细节', '换个方向']);
      },
    );

    test(
      'extracts an opaque workflow reply cursor from completed messages',
      () {
        final event = AgentStreamEvent(const {
          'type': 'message.completed',
          'payload': {
            'role': 'assistant',
            'text': '目前双胎类型确认了吗？',
            'workflow_reply': {
              'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
              'workflow_type': 'pregnancy_plan',
              'revision': 4,
              'step_token': 'opaque-step-token',
            },
          },
        });

        expect(event.workflowReply, {
          'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
          'workflow_type': 'pregnancy_plan',
          'revision': 4,
          'step_token': 'opaque-step-token',
        });
      },
    );

    test('ignores incomplete quick reply sets', () {
      final event = AgentStreamEvent(const {
        'type': 'message.completed',
        'payload': {
          'role': 'assistant',
          'text': '我整理好了。',
          'quick_replies': [
            {'text': '继续聊这个'},
            {'text': '给我更多细节'},
          ],
        },
      });

      expect(event.quickReplies, isEmpty);
    });

    test('extracts completed text from durable message payloads', () {
      final event = AgentStreamEvent(const {
        'type': 'message.completed',
        'thread_id': 'thread-message-001',
        'run_id': 'run-message-001',
        'message_id': 'msg-message-001',
        'payload': {
          'message': {
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'Durable '},
              {
                'type': 'text',
                'text': {'value': 'reply'},
              },
            ],
          },
        },
      });

      expect(event.completedText, 'Durable reply');
    });
  });
}
