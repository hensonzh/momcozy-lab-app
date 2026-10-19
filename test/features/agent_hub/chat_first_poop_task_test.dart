import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_poop_task.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';

void main() {
  testWidgets('one task sends up to three photos together and allows removal', (
    tester,
  ) async {
    _smallViewport(tester);
    final media = _Media();
    final client = _Client();
    final store = _Store();
    var picks = 0;
    await tester.pumpWidget(
      _page(
        media,
        client,
        store: store,
        pickImage: (_) async {
          picks++;
          return AgentStreamImageInput(
            dataUrl: '',
            mimeType: 'image/png',
            name: 'diaper-$picks.png',
            size: _photo.length,
            localBytes: _photo,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
    }
    expect(find.text('已选 3/3 张'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-poop-photo')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('已选 2/3 张'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
    await tester.pump();
    expect(media.uploads, 2);
    expect(client.requests, hasLength(1));
    expect(client.requests.single.images.map((image) => image.fileId), [
      'owned-photo',
      'owned-photo-2',
    ]);
    expect(
      client.requests.single.images.every((image) => image.localBytes == null),
      isTrue,
    );
    client.accept();
    await tester.pumpAndSettle();
    expect(find.text('已发送 2 张便便照片。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-first-poop-sent-0')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-sent-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-poop-zoom')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-zoom-close')));
    await tester.pumpAndSettle();
    // Persistent state may keep an owner-scoped asset reference and filename,
    // but not the local photo bytes or a data URL.
    final saved = store.value!.toMap(includeImageData: false).toString();
    expect(saved, isNot(contains('localBytes')));
    expect(saved, isNot(contains('dataUrl')));
    expect(saved, isNot(contains(base64Encode(_photo))));
    await tester.pumpWidget(_page(media, client, store: store, visible: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_page(media, client, store: store));
    await tester.pumpAndSettle();
    expect(find.text('已发送便便照片。'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-poop-sent-0')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'partial multi-photo upload retries without duplicating earlier assets',
    (tester) async {
      _smallViewport(tester);
      final media = _Media()..failOnUpload = 2;
      final client = _Client();
      await tester.pumpWidget(_page(media, client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('照片上传失败'), findsOneWidget);
      expect(media.uploads, 2);
      expect(client.requests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      expect(media.uploads, 3);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.images.map((image) => image.fileId), [
        'owned-photo',
        'owned-photo-3',
      ]);
      expect(media.uploadKeys[1], media.uploadKeys[2]);
      client.accept();
      await tester.pumpAndSettle();
      expect(find.text('已发送 2 张便便照片。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('accepted photo run shows responding state before reply', (
    tester,
  ) async {
    _smallViewport(tester);
    final media = _Media();
    final client = _Client();
    final store = _Store();
    await tester.pumpWidget(_page(media, client, store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
    await tester.pump();
    expect(find.text('响应中'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .enabled,
      isFalse,
    );
    client.queued();
    await tester.pump();
    expect(find.text('正在整理观察…'), findsOneWidget);
    expect(find.text('响应中'), findsOneWidget);
    client.complete();
    await tester.pumpAndSettle();
    expect(find.text('正在整理观察…'), findsNothing);
    expect(find.text('响应中'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'poop card reuses one draft and submits a typed image reference',
    (tester) async {
      _smallViewport(tester);
      final media = _Media();
      final client = _Client();
      final store = _Store();
      await tester.pumpWidget(_page(media, client, store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-topic-poop')),
        findsOneWidget,
      );
      expect(store.value?.poopTasks, hasLength(1));
      expect(store.value?.historyMessages, isEmpty);
      expect(media.uploads, 0);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-poop-preview')),
        findsOneWidget,
      );
      expect(media.uploads, 0);
      expect(store.value?.attachedImages, isEmpty);
      expect(store.value!.toMap().toString(), isNot(contains('diaper.png')));
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      expect(media.uploads, 1);
      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      expect(isChatFirstPoopPrompt(request.message), isTrue);
      expect(request.images.single.fileId, 'owned-photo');
      expect(request.images.single.localBytes, isNull);
      expect(request.images.single.dataUrl, isEmpty);
      expect(request.images.single.toProductionAttachment(), {
        'type': 'image',
        'asset_id': 'owned-photo',
        'detail': 'auto',
      });
      expect(
        store.value!.toMap(includeImageData: false).toString(),
        isNot(contains('diaper.png')),
      );
      expect(
        store.value!.toMap(includeImageData: false).toString(),
        isNot(contains('base64')),
      );
      client.accept();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('已发送便便照片。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-first-poop-preview')),
        findsNothing,
      );
      expect(
        store.value?.poopTasks.single.status,
        ChatFirstPoopTaskStatus.completed,
      );
      expect(store.value?.poopTasks.single.runId, 'run-poop');
      expect(media.deleted, isEmpty);
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-topic-poop')),
        findsNWidgets(2),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'upload failure keeps preview and retry; run failure reuses upload and request key',
    (tester) async {
      _smallViewport(tester);
      final media = _Media()..failOnce = true;
      final client = _Client();
      await tester.pumpWidget(_page(media, client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('照片上传失败'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-first-poop-preview')),
        findsOneWidget,
      );
      expect(client.requests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      expect(media.uploads, 2);
      expect(client.requests, hasLength(1));
      client.reject();
      await tester.pumpAndSettle();
      expect(find.textContaining('发送失败'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      expect(media.uploads, 2);
      expect(client.requests, hasLength(2));
      expect(
        client.requests[0].idempotencyKey,
        client.requests[1].idempotencyKey,
      );
      client.accept(1);
      await tester.pumpAndSettle();
      expect(find.text('已发送便便照片。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'abandon or navigate away drops local preview without uploading',
    (tester) async {
      _smallViewport(tester);
      final media = _Media();
      final client = _Client();
      final store = _Store();
      await tester.pumpWidget(_page(media, client, store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-abandon')));
      await tester.pumpAndSettle();
      expect(find.text('本次任务已取消。'), findsOneWidget);
      expect(client.requests, isEmpty);
      expect(media.uploads, 0);
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _page(media, client, store: store, visible: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-poop-preview')),
        findsNothing,
      );
      expect(
        store.value?.poopTasks.last.status,
        ChatFirstPoopTaskStatus.cancelled,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'replacing or abandoning after an unconfirmed Run never deletes its possible attachment',
    (tester) async {
      _smallViewport(tester);
      final media = _Media();
      final client = _Client();
      await tester.pumpWidget(_page(media, client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      client
          .reject(); // No server signal: createRun outcome is not authoritative.
      await tester.pumpAndSettle();
      expect(find.textContaining('发送失败'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pumpAndSettle();
      expect(media.deleted, isEmpty);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-abandon')));
      await tester.pumpAndSettle();
      expect(media.deleted, isEmpty);
      expect(client.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('server history replaces the completed local card once', (
    tester,
  ) async {
    _smallViewport(tester);
    final store = _Store()
      ..value = AgentHubInteractionSnapshot(
        runState: const AgentStreamRunState(threadId: 'thread-poop'),
        poopTasks: [
          ChatFirstPoopTask(
            id: 'local:poop:done',
            createdAt: DateTime.utc(2026, 10, 17, 12),
            threadId: 'thread-poop',
            runId: 'run-poop',
            status: ChatFirstPoopTaskStatus.completed,
          ),
        ],
        historyMessages: [
          AgentHubHistorySnapshot(
            id: 'server-user',
            runId: 'run-poop',
            role: 'user',
            content: '',
            createdAt: DateTime.utc(2026, 10, 17, 12),
            isChatFirstPoopTrigger: true,
          ),
          AgentHubHistorySnapshot(
            id: 'server-answer',
            role: 'assistant',
            content: '依据照片只能描述可见线索。',
            createdAt: DateTime.utc(2026, 10, 17, 12, 1),
          ),
        ],
      );
    await tester.pumpWidget(_page(_Media(), _Client(), store: store));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-poop')), findsOneWidget);
    expect(find.text('已发送便便照片。'), findsOneWidget);
    expect(find.text('依据照片只能描述可见线索。'), findsOneWidget);
    expect(find.textContaining('momcozy_internal_poop_v1'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another thread cannot display or reuse its pending card', (
    tester,
  ) async {
    _smallViewport(tester);
    final store = _Store()
      ..value = AgentHubInteractionSnapshot(
        runState: const AgentStreamRunState(threadId: 'thread-a'),
        poopTasks: [
          ChatFirstPoopTask(
            id: 'local:poop:thread-b',
            createdAt: DateTime.utc(2026, 10, 17),
            threadId: 'thread-b',
          ),
        ],
      );
    await tester.pumpWidget(_page(_Media(), _Client(), store: store));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-poop')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-poop')), findsOneWidget);
    expect(store.value?.poopTasks.last.threadId, 'thread-a');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late upload after leaving is deleted and never starts a Run', (
    tester,
  ) async {
    _smallViewport(tester);
    final media = _Media()..pending = Completer<void>();
    final client = _Client();
    await tester.pumpWidget(_page(media, client));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
    await tester.pump();
    expect(media.uploads, 1);
    await tester.pumpWidget(const SizedBox());
    media.pending!.complete();
    await tester.pump();
    expect(media.deleted, ['owned-photo']);
    expect(client.requests, isEmpty);
  });

  testWidgets('missing media contract never offers a false send action', (
    tester,
  ) async {
    _smallViewport(tester);
    final client = _Client();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentHubPage(
            chatFirstExperience: true,
            runner: AgentStreamRunner(client),
            pickImage: (_) async => AgentStreamImageInput(
              dataUrl: '',
              mimeType: 'image/png',
              name: 'local.png',
              localBytes: _photo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pumpAndSettle();
    expect(find.text('照片发送暂不可用，照片尚未上传。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('chat-first-poop-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('small screen large type keeps actions available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_page(_Media(), _Client()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-poop-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// One-pixel PNG; selection is private until the user confirms sending.
final _photo = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
  ),
);

Widget _page(
  _Media media,
  _Client client, {
  _Store? store,
  bool visible = true,
  AgentHubImagePicker? pickImage,
}) => MaterialApp(
  home: Scaffold(
    body: AgentHubPage(
      key: const ValueKey('poop-page'),
      chatFirstExperience: true,
      isVisible: visible,
      interactionStateStore: store,
      mediaRepository: media,
      runner: AgentStreamRunner(client),
      pickImage:
          pickImage ??
          (source) async => AgentStreamImageInput(
            dataUrl: '',
            mimeType: 'image/png',
            name: 'diaper.png',
            size: _photo.length,
            localBytes: _photo,
          ),
    ),
  ),
);

class _Media implements MediaRepository {
  int uploads = 0;
  bool failOnce = false;
  int? failOnUpload;
  final List<String?> uploadKeys = [];
  Completer<void>? pending;
  final deleted = <String>[];
  @override
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
  }) async {
    uploads++;
    uploadKeys.add(idempotencyKey);
    await pending?.future;
    if (failOnUpload == uploads) {
      failOnUpload = null;
      throw StateError('upload unavailable');
    }
    if (failOnce) {
      failOnce = false;
      throw StateError('upload unavailable');
    }
    return UploadedMediaFile(
      id: uploads == 1 ? 'owned-photo' : 'owned-photo-$uploads',
      name: 'diaper.png',
      sizeBytes: 68,
      extension: 'png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<void> deleteFile({
    required String fileId,
    String? idempotencyKey,
  }) async {
    deleted.add(fileId);
  }
}

class _Client implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final controllers = <StreamController<AgentStreamEvent>>[];
  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    final controller = StreamController<AgentStreamEvent>();
    controllers.add(controller);
    return controller.stream;
  }

  void accept([int index = 0]) {
    queued(index);
    complete(index);
  }

  void queued([int index = 0]) {
    controllers[index].add(
      AgentStreamEvent({
        'type': 'run.queued',
        'run_id': 'run-poop',
        'thread_id': 'thread-poop',
        'sequence': 1,
      }),
    );
  }

  void complete([int index = 0]) {
    controllers[index].add(
      AgentStreamEvent({
        'type': 'message.completed',
        'run_id': 'run-poop',
        'thread_id': 'thread-poop',
        'message_id': 'reply-poop',
        'sequence': 2,
        'payload': {'role': 'assistant', 'text': '只能根据照片描述观察线索。'},
      }),
    );
    controllers[index].add(
      AgentStreamEvent({
        'type': 'run.completed',
        'run_id': 'run-poop',
        'thread_id': 'thread-poop',
        'sequence': 3,
      }),
    );
    unawaited(controllers[index].close());
  }

  void reject([int index = 0]) => unawaited(controllers[index].close());
}

class _Store implements AgentHubInteractionStateStore {
  AgentHubInteractionSnapshot? value;
  @override
  Future<AgentHubInteractionSnapshot?> read() async => value;
  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {
    value = snapshot;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
