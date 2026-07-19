import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

void main() {
  group('restorable conversation detection', () {
    test('ignores settings and unsent local state without history', () {
      const snapshot = AgentHubInteractionSnapshot(
        composerText: '还没有发送的草稿',
        attachedImages: [
          AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,draft',
            mimeType: 'image/png',
            name: 'draft.png',
          ),
        ],
        autoVoiceEnabled: false,
        activeRequest: AgentStreamRequest(message: '尚未形成历史'),
        runState: AgentStreamRunState(threadId: 'empty-thread'),
      );

      expect(snapshot.hasContent, isTrue);
      expect(snapshot.hasConversationHistory, isFalse);
    });

    test('accepts persisted history and current streamed replies', () {
      const historical = AgentHubInteractionSnapshot(
        historyMessages: [
          AgentHubHistorySnapshot(role: 'user', content: '上一条问题'),
        ],
      );
      const streamed = AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(textContent: '上一条回复'),
      );
      final eventBacked = AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(
          events: [
            AgentStreamEvent(const {
              'type': 'run.started',
              'run_id': 'run-with-history',
            }),
          ],
        ),
      );

      expect(historical.hasConversationHistory, isTrue);
      expect(streamed.hasConversationHistory, isTrue);
      expect(eventBacked.hasConversationHistory, isTrue);
    });
  });

  test('history snapshot round-trips structured artifact state', () {
    final artifactEvent = AgentStreamEvent({
      'event_id': 'history-artifact-event',
      'type': 'artifact.created',
      'artifact_id': 'history-artifact',
      'payload': {
        'artifact_type': 'milk_plan_preview',
        'schema_version': 'v1',
        'artifact': {
          'id': 'history-artifact',
          'artifact_type': 'milk_plan_preview',
          'schema_version': 'v1',
          'payload': {
            'title': '历史奶量计划',
            'tasks': [
              {'title': '20:00 泵奶'},
            ],
          },
        },
      },
    });
    final runState =
        const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)
            .applyEvent(artifactEvent)
            .copyWith(phase: AgentStreamRunPhase.finished, textContent: '历史回复');
    final snapshot = AgentHubHistorySnapshot(
      role: 'assistant',
      content: '历史回复',
      runState: runState,
    );

    final restored = AgentHubHistorySnapshot.fromMap(snapshot.toMap());

    expect(restored, isNotNull);
    expect(restored!.runState, isNotNull);
    expect(restored.runState!.phase, AgentStreamRunPhase.finished);
    expect(restored.runState!.artifactEvents, hasLength(1));
    expect(
      restored.runState!.artifactEvents.values.single.artifactId,
      'history-artifact',
    );
  });

  test('legacy text-only history snapshots remain readable', () {
    final restored = AgentHubHistorySnapshot.fromMap({
      'role': 'assistant',
      'content': '旧历史消息',
    });

    expect(restored, isNotNull);
    expect(restored!.content, '旧历史消息');
    expect(restored.runState, isNull);
  });

  test(
    'replay filters applied-only action cards but keeps legacy confirmation',
    () {
      final restored = AgentHubHistorySnapshot.fromMap({
        'role': 'assistant',
        'content': '历史动作回复',
        'runState': {
          'phase': 'finished',
          'textContent': '历史动作回复',
          'events': [
            {
              'event_id': 'evt-old-applied',
              'type': 'action.applied',
              'action_id': 'action-old-applied',
              'payload': {
                'action_id': 'action-old-applied',
                'action_status': 'applied',
              },
            },
            {
              'event_id': 'evt-old-confirmation',
              'type': 'action.confirmation_required',
              'action_id': 'action-old-confirmation',
              'payload': {
                'action_id': 'action-old-confirmation',
                'action_status': 'confirmation_required',
              },
            },
          ],
        },
      });

      expect(restored, isNotNull);
      expect(restored!.runState!.actionEvents.keys, [
        'action-old-confirmation',
      ]);
      final replayEvents =
          restored.runState!.toMap()['events']! as List<Object?>;
      expect(
        replayEvents.whereType<Map>().map((event) => event['action_id']),
        isNot(contains('action-old-applied')),
      );
    },
  );

  test('user history snapshots preserve sent image previews', () {
    const snapshot = AgentHubHistorySnapshot(
      role: 'user',
      content: '',
      images: [
        AgentStreamImageInput(
          dataUrl: 'data:image/png;base64,preview',
          mimeType: 'image/png',
          name: 'sent.png',
          size: 7,
        ),
      ],
    );

    final restored = AgentHubHistorySnapshot.fromMap(snapshot.toMap());

    expect(restored, isNotNull);
    expect(restored!.content, isEmpty);
    expect(restored.images, hasLength(1));
    expect(restored.images.single.name, 'sent.png');
  });

  test(
    'active image request persists one payload and restores retry images',
    () {
      const image = AgentStreamImageInput(
        dataUrl: 'data:image/png;base64,one-copy-only',
        mimeType: 'image/png',
        name: 'sent.png',
        size: 13,
      );
      const snapshot = AgentHubInteractionSnapshot(
        historyMessages: [
          AgentHubHistorySnapshot(role: 'user', content: '看看', images: [image]),
        ],
        activeRequest: AgentStreamRequest(message: '看看', images: [image]),
      );

      final encoded = jsonEncode(snapshot.toMap());
      final restored = AgentHubInteractionSnapshot.fromMap(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );

      expect('one-copy-only'.allMatches(encoded), hasLength(1));
      expect(restored.activeRequest?.images, hasLength(1));
      expect(restored.activeRequest?.images.single.name, 'sent.png');
    },
  );

  test('secure persistence projection omits image bytes and image retries', () {
    const image = AgentStreamImageInput(
      dataUrl: 'data:image/png;base64,large-sensitive-payload',
      mimeType: 'image/png',
      name: 'sent.png',
      size: 24,
    );
    const snapshot = AgentHubInteractionSnapshot(
      attachedImages: [image],
      historyMessages: [
        AgentHubHistorySnapshot(role: 'user', content: '看看', images: [image]),
      ],
      activeRequest: AgentStreamRequest(message: '看看', images: [image]),
    );

    final encoded = jsonEncode(snapshot.toMap(includeImageData: false));
    final restored = AgentHubInteractionSnapshot.fromMap(
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
    );

    expect(encoded, isNot(contains('large-sensitive-payload')));
    expect(restored.attachedImages, isEmpty);
    expect(restored.historyMessages.single.images, isEmpty);
    expect(restored.activeRequest, isNull);
  });

  test('submitted artifact forms and request idempotency round-trip', () {
    final snapshot = AgentHubInteractionSnapshot(
      activeRequest: const AgentStreamRequest(
        message: '提交表单',
        idempotencyKey: 'agent-form-submit-stable',
      ),
      formSubmissions: {
        'form-artifact-1': AgentArtifactFormSubmission.submitted(
          values: const {
            'due_date_or_week': '38 周',
            'pregnancy_history': ['其它：第一胎剖宫产'],
          },
        ),
        'form-artifact-pending': AgentArtifactFormSubmission.submitting(
          values: const {'due_date_or_week': '39 周'},
        ),
      },
    );

    final restored = AgentHubInteractionSnapshot.fromMap(
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(snapshot.toMap())) as Map,
      ),
    );

    expect(restored.activeRequest?.idempotencyKey, 'agent-form-submit-stable');
    expect(restored.formSubmissions, hasLength(1));
    expect(restored.formSubmissions['form-artifact-1']?.isSubmitted, isTrue);
    expect(
      restored.formSubmissions['form-artifact-1']?.values['due_date_or_week'],
      '38 周',
    );
    expect(
      restored.formSubmissions.containsKey('form-artifact-pending'),
      isFalse,
    );
  });
}
