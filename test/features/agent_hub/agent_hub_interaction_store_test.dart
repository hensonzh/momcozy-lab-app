import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_cry_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_poop_task.dart';

void main() {
  test(
    'poop marker and remote trigger survive without private photo bytes',
    () {
      final snapshot = AgentHubInteractionSnapshot(
        runState: const AgentStreamRunState(threadId: 'thread-poop'),
        poopTasks: [
          ChatFirstPoopTask(
            id: 'local:poop:1',
            createdAt: DateTime.utc(2026, 10, 17),
            threadId: 'thread-poop',
            runId: 'run-poop',
            status: ChatFirstPoopTaskStatus.completed,
          ),
        ],
        historyMessages: const [
          AgentHubHistorySnapshot(
            id: 'server-poop-user',
            role: 'user',
            runId: 'run-poop',
            content: '',
            isChatFirstPoopTrigger: true,
          ),
        ],
      );
      final encoded = jsonEncode(snapshot.toMap(includeImageData: false));
      expect(encoded, isNot(contains('base64')));
      expect(encoded, isNot(contains('capture.wav')));
      expect(encoded, isNot(contains('photoBytes')));
      final restored = AgentHubInteractionSnapshot.fromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(
        restored.poopTasks.single.status,
        ChatFirstPoopTaskStatus.completed,
      );
      expect(restored.poopTasks.single.runId, 'run-poop');
      expect(restored.historyMessages.single.isChatFirstPoopTrigger, isTrue);
      expect(restored.historyMessages.single.runId, 'run-poop');
      expect(AgentHubInteractionSnapshot.fromMap({}).poopTasks, isEmpty);
    },
  );

  test('cry card marker round-trips without audio bytes or path', () {
    final snapshot = AgentHubInteractionSnapshot(
      runState: const AgentStreamRunState(threadId: 'thread-a'),
      cryTasks: [
        ChatFirstCryTask(
          id: 'local:cry:test',
          threadId: 'thread-a',
          createdAt: DateTime.utc(2026, 10, 17),
          precedingAssistantMessageId: 'reply-1',
        ),
      ],
    );
    final encoded = jsonEncode(snapshot.toMap(includeImageData: false));
    expect(encoded, contains('local:cry:test'));
    expect(encoded, isNot(contains('capture.wav')));
    expect(encoded, isNot(contains('audio')));
    expect(encoded, isNot(contains('filePath')));
    final decoded = AgentHubInteractionSnapshot.fromMap(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(decoded.cryTasks.single.threadId, 'thread-a');
    expect(decoded.cryTasks.single.precedingAssistantMessageId, 'reply-1');
    expect(decoded.cryTasks.single.status, ChatFirstCryTaskStatus.pending);
    expect(decoded.historyMessages, isEmpty);
    expect(decoded.hasConversationHistory, isTrue);
  });

  test(
    'persisted cry result is a reference, never a trusted displayed category',
    () {
      final task = ChatFirstCryTask(
        id: 'local:cry:verified',
        createdAt: DateTime.utc(2026, 10, 22),
        status: ChatFirstCryTaskStatus.completed,
        analysisId: 'a0a10a10-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
        answer: 'sleep',
        analyzedAt: DateTime.utc(2026, 10, 22),
      );
      final restored = ChatFirstCryTask.fromMap({
        ...task.toMap(),
        'answer': 'injected-false-result',
      })!;
      expect(restored.status, ChatFirstCryTaskStatus.verifying);
      expect(restored.answer, isNull);
      expect(restored.analysisId, task.analysisId);
    },
  );

  test('legacy snapshots and untrusted cry entries are safely ignored', () {
    expect(AgentHubInteractionSnapshot.fromMap({}).cryTasks, isEmpty);
    final decoded = AgentHubInteractionSnapshot.fromMap({
      'cryTasks': [
        {'id': 'server-message', 'createdAt': '2026-10-17T00:00:00Z'},
        {'id': 'local:cry:invalid', 'createdAt': 'not-a-date'},
        {
          'id': 'local:cry:valid',
          'createdAt': '2026-10-17T00:00:00Z',
          'status': 'future-status',
          'audioPath': '/tmp/capture.wav',
        },
      ],
    });
    expect(decoded.cryTasks, hasLength(1));
    expect(decoded.cryTasks.single.status, ChatFirstCryTaskStatus.pending);
    expect(decoded.toMap().toString(), isNot(contains('audioPath')));
    expect(decoded.toMap().toString(), isNot(contains('capture.wav')));
  });

  test('phase one drops retired settings and form drafts from old caches', () {
    final restored = AgentHubInteractionSnapshot.fromMap({
      'composerText': '保留当前草稿',
      'autoVoiceEnabled': true,
      'localActionStatuses': {'old-action': 'confirmed'},
      'formSubmissions': {
        'old-form': {'state': 'submitted'},
      },
      'viewState': {
        'lastReadMessageId': 'old-message',
        'position': {'scrollOffset': 640, 'atLatest': false},
      },
      'pendingAttachmentCleanupIds': ['remove-me'],
    });
    final saved = restored.toMap();
    expect(restored.composerText, '保留当前草稿');
    expect(restored.pendingAttachmentCleanupIds, ['remove-me']);
    for (final key in [
      'autoVoiceEnabled',
      'localActionStatuses',
      'formSubmissions',
      'viewState',
    ]) {
      expect(saved.containsKey(key), isFalse);
    }
  });

  test('restored retry requests preserve their selected locale', () {
    final snapshot = AgentHubInteractionSnapshot.fromMap({
      'activeRequest': {
        'message': 'Help me',
        'threadId': 'existing-thread',
        'locale': 'zh-CN',
      },
    });

    expect(snapshot.activeRequest?.locale, 'zh-CN');
    expect(snapshot.activeRequest?.threadId, 'existing-thread');
    expect(snapshot.activeRequest?.message, 'Help me');
  });

  test('active stool follow-up authorization survives secure persistence', () {
    const snapshot = AgentHubInteractionSnapshot(
      activeRequest: AgentStreamRequest(
        message: '继续解释',
        threadId: '11111111-1111-4111-8111-111111111111',
        locale: 'zh-CN',
        idempotencyKey: 'followup-once',
        stoolFollowup: StoolFollowupInput(
          analysisId: '22222222-2222-4222-8222-222222222222',
          babyId: '33333333-3333-4333-8333-333333333333',
        ),
      ),
    );
    final restored = AgentHubInteractionSnapshot.fromMap(
      jsonDecode(jsonEncode(snapshot.toMap(includeImageData: false)))
          as Map<String, dynamic>,
    );
    expect(
      restored.activeRequest?.stoolFollowup?.analysisId,
      '22222222-2222-4222-8222-222222222222',
    );
    expect(
      restored.activeRequest?.stoolFollowup?.babyId,
      '33333333-3333-4333-8333-333333333333',
    );
    expect(restored.activeRequest?.idempotencyKey, 'followup-once');
  });

  test('cleanup intent persists without conversation or image bytes', () {
    const snapshot = AgentHubInteractionSnapshot(
      pendingAttachmentCleanupIds: ['abandoned-file'],
    );
    final restored = AgentHubInteractionSnapshot.fromMap(
      jsonDecode(jsonEncode(snapshot.toMap(includeImageData: false)))
          as Map<String, dynamic>,
    );
    expect(restored.hasContent, isTrue);
    expect(restored.hasConversationHistory, isFalse);
    expect(restored.pendingAttachmentCleanupIds, ['abandoned-file']);
    expect(
      AgentHubInteractionSnapshot.fromMap({}).pendingAttachmentCleanupIds,
      isEmpty,
    );
  });

  test('welcome identifiers survive the secure snapshot JSON round trip', () {
    const oldKey = 'chat-first-welcome:aaaaaaaaaaaaaaaaaaaaaaaa';
    const newKey = 'chat-first-welcome:bbbbbbbbbbbbbbbbbbbbbbbb';
    const snapshot = AgentHubInteractionSnapshot(
      currentRunIsChatFirstWelcome: true,
      currentWelcomeKey: newKey,
      historyMessages: [
        AgentHubHistorySnapshot(
          id: 'older-welcome',
          role: 'assistant',
          content: '旧资料欢迎',
          isChatFirstWelcome: true,
          chatFirstWelcomeKey: oldKey,
        ),
        AgentHubHistorySnapshot(
          id: 'ordinary',
          role: 'assistant',
          content: '普通回答保留',
        ),
      ],
    );
    final restored = AgentHubInteractionSnapshot.fromMap(
      jsonDecode(jsonEncode(snapshot.toMap(includeImageData: false)))
          as Map<String, dynamic>,
    );
    expect(restored.currentRunIsChatFirstWelcome, isTrue);
    expect(restored.currentWelcomeKey, newKey);
    expect(restored.historyMessages.first.isChatFirstWelcome, isTrue);
    expect(restored.historyMessages.first.chatFirstWelcomeKey, oldKey);
    expect(restored.historyMessages.last.isChatFirstWelcome, isFalse);
    expect(restored.historyMessages.last.content, '普通回答保留');

    final legacy = AgentHubInteractionSnapshot.fromMap({
      'historyMessages': [
        {'role': 'assistant', 'content': '旧格式普通回答'},
      ],
    });
    expect(legacy.currentRunIsChatFirstWelcome, isFalse);
    expect(legacy.currentWelcomeKey, isNull);
    expect(legacy.historyMessages.single.isChatFirstWelcome, isFalse);
  });

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
        'artifact_type': 'rich_text',
        'schema_version': 'v1',
        'artifact': {
          'id': 'history-artifact',
          'artifact_type': 'rich_text',
          'schema_version': 'v1',
          'payload': {'title': '历史说明', 'content': '历史结构化内容'},
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

  test(
    'uploaded image references survive secure persistence without bytes',
    () {
      const image = AgentStreamImageInput(
        dataUrl: 'data:image/png;base64,large-sensitive-payload',
        fileId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
        mimeType: 'image/png',
        name: 'sent.png',
        size: 24,
        detail: 'low',
      );
      const snapshot = AgentHubInteractionSnapshot(
        attachedImages: [image],
        historyMessages: [
          AgentHubHistorySnapshot(role: 'user', content: '', images: [image]),
        ],
        activeRequest: AgentStreamRequest(
          message: 'Please look at this image',
          images: [image],
        ),
      );

      final encoded = jsonEncode(snapshot.toMap(includeImageData: false));
      final restored = AgentHubInteractionSnapshot.fromMap(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );

      expect(encoded, isNot(contains('large-sensitive-payload')));
      expect(encoded, contains(image.fileId));
      expect(restored.attachedImages.single.fileId, image.fileId);
      expect(restored.attachedImages.single.dataUrl, isEmpty);
      expect(
        restored.historyMessages.single.images.single.fileId,
        image.fileId,
      );
      expect(restored.historyMessages.single.images.single.dataUrl, isEmpty);
      expect(restored.activeRequest?.images.single.fileId, image.fileId);
      expect(restored.activeRequest?.images.single.dataUrl, isEmpty);
    },
  );

  test('proprietary runtime asset ids survive secure persistence', () {
    const image = AgentStreamImageInput(
      dataUrl: 'data:image/png;base64,large-sensitive-payload',
      assetId: '7b8aa8c8-2c49-48c4-9cad-80f438a6c979',
    );
    const snapshot = AgentHubInteractionSnapshot(attachedImages: [image]);

    final encoded = jsonEncode(snapshot.toMap(includeImageData: false));
    final restored = AgentHubInteractionSnapshot.fromMap(
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
    );

    expect(encoded, isNot(contains('large-sensitive-payload')));
    expect(restored.attachedImages.single.assetId, image.assetId);
    expect(restored.attachedImages.single.fileId, image.assetId);
  });

  test('PDF draft and request metadata survive secure persistence', () {
    const file = AgentStreamFileInput(
      fileId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
      mimeType: 'application/pdf',
      name: 'checkup-report.pdf',
      size: 2048,
    );
    const snapshot = AgentHubInteractionSnapshot(
      attachedFiles: [file],
      historyMessages: [
        AgentHubHistorySnapshot(role: 'user', content: '', files: [file]),
      ],
      activeRequest: AgentStreamRequest(
        message: 'Please review this file',
        files: [file],
      ),
    );

    final encoded = jsonEncode(snapshot.toMap(includeImageData: false));
    final restored = AgentHubInteractionSnapshot.fromMap(
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
    );

    expect(encoded, contains('checkup-report.pdf'));
    expect(restored.attachedFiles, [file]);
    expect(restored.historyMessages.single.files, [file]);
    expect(restored.activeRequest?.files, [file]);
  });
}
