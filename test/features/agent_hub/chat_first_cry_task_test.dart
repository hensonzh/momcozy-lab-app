import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_cry_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_cry_audio.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/cry_analysis_repository.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

void main() {
  testWidgets(
    'one in-conversation cry task records, previews and never sends audio',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _FakeCryAudio();
      final client = _CaptureClient();
      await tester.pumpWidget(_page(audio: audio, client: client));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chat-first-topic-cry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-first-cry-start')),
        findsOneWidget,
      );
      expect(client.requests, isEmpty);

      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      expect(audio.starts, 1);
      expect(find.textContaining('正在录宝宝哭声'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('chat-first-voice-input')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '先记下的文字草稿',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .controller!
            .text,
        '先记下的文字草稿',
      );
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      expect(audio.stops, 1);
      expect(find.byKey(const ValueKey('chat-first-cry-seek')), findsOneWidget);
      expect(find.textContaining('不足 10 秒'), findsOneWidget);
      expect(find.textContaining('录音仅用于本机试听'), findsNothing);
      expect(find.text('上传并分析'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('上传并分析'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(client.requests, isEmpty);

      await tester.tap(find.byKey(const ValueKey('chat-first-cry-play')));
      await tester.pump();
      expect(audio.plays, 1);
      audio.emitPosition(const Duration(seconds: 3));
      await tester.pump();
      expect(find.textContaining('0:03 / 0:08'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-pause')));
      await tester.pump();
      expect(audio.pauses, 1);
      await tester.ensureVisible(
        find.byKey(const ValueKey('chat-first-cry-seek')),
      );
      await tester.drag(
        find.byKey(const ValueKey('chat-first-cry-seek')),
        const Offset(80, 0),
      );
      await tester.pump();
      expect(audio.seeks, isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('chat-first-cry-re-record')));
      await tester.pump();
      expect(audio.starts, 2);
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-abandon')));
      await tester.pump();
      expect(find.text('本次任务已取消。'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 10));
      expect(audio.clears, greaterThan(0));
      expect(client.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        for (var i = 0; i < 30 && audio.disposals == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      expect(audio.disposals, greaterThan(0));
    },
  );

  testWidgets(
    'opening and changing a cry card keeps its bottom actions in view',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _CryRepository()
        ..state = const AgentStreamRunState(threadId: 'thread-cry')
        ..messages.addAll(
          List.generate(
            20,
            (index) => AgentConversationMessage(
              id: 'history-$index',
              role: index.isEven
                  ? AgentConversationMessageRole.user
                  : AgentConversationMessageRole.assistant,
              content:
                  'Earlier conversation turn $index with enough content to scroll.',
            ),
          ),
        );
      await tester.pumpWidget(
        _page(
          audio: _FakeCryAudio(),
          client: _CaptureClient(),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('agent-chat-scroll-view')),
      );
      Rect card() =>
          tester.getRect(find.byKey(const ValueKey('chat-first-topic-cry')));
      expect(card().bottom, lessThanOrEqualTo(viewport.bottom + 1));
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pumpAndSettle();
      expect(card().bottom, lessThanOrEqualTo(viewport.bottom + 1));
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pumpAndSettle();
      expect(card().bottom, lessThanOrEqualTo(viewport.bottom + 1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'submit locks the capture card, waits, then shows a separate cause-only result',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport()..uploadGate = Completer<void>();
      final agent = _CaptureClient();
      await tester.pumpWidget(
        _page(
          audio: _FakeCryAudio(),
          client: agent,
          cry: CryAnalysisRepository(multipart: product, json: product),
          repository: _CryRepository(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chat-first-topic-cry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-first-cry-abandon')),
        findsNothing,
      );
      expect(find.text('上传并分析'), findsNothing);
      expect(find.byKey(const ValueKey('chat-first-cry-player')), findsNothing);
      expect(
        find.byKey(const ValueKey('chat-first-cry-result-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('chat-first-cry-waiting')),
        findsOneWidget,
      );
      expect(find.text('正在分析中'), findsOneWidget);
      expect(find.textContaining('正在分析哭声'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chat-first-cry-waiting')),
          matching: find.byKey(const ValueKey('agent-run-status-title-sweep')),
        ),
        findsOneWidget,
      );
      product.uploadGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-cry-waiting')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('chat-first-topic-cry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-first-cry-abandon')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('chat-first-cry-result-card')),
        findsOneWidget,
      );
      expect(find.text('哭声背后的原因'), findsOneWidget);
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      expect(find.text('这段哭声的线索'), findsNothing);
      expect(find.textContaining('分析于'), findsNothing);
      expect(find.textContaining('不能代替'), findsNothing);
      expect(
        find.byKey(const ValueKey('chat-first-cry-retry-advice')),
        findsNothing,
      );
      expect(agent.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('verified cause card precedes a separate Agent text reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final agent = _CaptureClient()..controlled = true;
    final product = _CryServiceTransport();
    await tester.pumpWidget(
      _page(
        audio: _FakeCryAudio(),
        client: agent,
        cry: CryAnalysisRepository(multipart: product, json: product),
        repository: _CryRepository(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
    await tester.pump();
    await tester.tap(find.text('上传并分析'));
    await tester.pump();
    await tester.pump();
    expect(agent.requests, hasLength(1));
    agent.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'cry-started',
        'type': 'run.started',
        'sequence': 1,
        'thread_id': 'thread-cry',
        'run_id': 'run-cry',
      }),
    );
    agent.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'cry-message',
        'type': 'message.completed',
        'sequence': 2,
        'thread_id': 'thread-cry',
        'run_id': 'run-cry',
        'message_id': 'reply-cry',
        'payload': {'role': 'assistant', 'text': '先抱抱宝宝，再结合饥饿信号看看。'},
      }),
    );
    agent.emit(
      0,
      AgentStreamEvent(const {
        'event_id': 'cry-done',
        'type': 'run.completed',
        'sequence': 3,
        'thread_id': 'thread-cry',
        'run_id': 'run-cry',
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-cry-result-card')),
      findsOneWidget,
    );
    expect(find.text('先抱抱宝宝，再结合饥饿信号看看。'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('chat-first-cry-result-card')))
          .dy,
      lessThan(tester.getTopLeft(find.text('先抱抱宝宝，再结合饥饿信号看看。')).dy),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'verified service result becomes a card and only its ID reaches Agent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _FakeCryAudio();
      final agent = _CaptureClient();
      final product = _CryServiceTransport();
      await tester.pumpWidget(
        _page(
          audio: audio,
          client: agent,
          cry: CryAnalysisRepository(multipart: product, json: product),
          repository: _CryRepository(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(product.recordings, [
        <int>[1, 2, 3],
      ]);
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      expect(find.textContaining('cry_translated'), findsNothing);
      expect(agent.requests, hasLength(1));
      final payload = buildProductionAgentRunPayload(agent.requests.single);
      expect(payload['attachments'], [
        {'type': 'cry_analysis', 'analysis_id': product.analysisId},
      ]);
      expect(payload.toString(), isNot(contains('input_audio')));
      expect(payload.toString(), isNot(contains('[1, 2, 3]')));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed result rerecord starts a fresh capture without reuploading',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _FakeCryAudio();
      final product = _CryServiceTransport()..uploadStatus = 'failed';
      final agent = _CaptureClient();
      await tester.pumpWidget(
        _page(
          audio: audio,
          client: agent,
          cry: CryAnalysisRepository(multipart: product, json: product),
          repository: _CryRepository(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(find.text('这次分析未完成，可以重新录一段。'), findsOneWidget);
      expect(audio.starts, 1);
      await tester.tap(find.text('重新录一段'));
      await tester.pump();
      expect(audio.starts, 2);
      expect(find.textContaining('正在录宝宝哭声'), findsOneWidget);
      expect(product.recordings, hasLength(1));
      expect(agent.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'rerecord from an old result preserves another pending upload key and preview',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _FakeCryAudio();
      final product = _CryServiceTransport()..uploadStatus = 'failed';
      final store = _CryStore();
      await tester.pumpWidget(
        _page(
          audio: audio,
          client: _CaptureClient(),
          store: store,
          cry: CryAnalysisRepository(multipart: product, json: product),
          repository: _CryRepository(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      product.uploadFailures = 1;
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      final key = store.value!.cryTasks.last.requestKey;
      expect(key, startsWith('cry:'));
      final starts = audio.starts;
      await tester.tap(find.text('重新录一段'));
      await tester.pump();
      expect(store.value!.cryTasks.last.requestKey, key);
      expect(audio.starts, starts);
      expect(
        find.byKey(const ValueKey('chat-first-cry-player')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'service unavailable keeps local recording and retries with the same key',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _FakeCryAudio();
      final product = _CryServiceTransport()..uploadFailures = 1;
      final store = _CryStore();
      final agent = _CaptureClient();
      await tester.pumpWidget(
        _page(
          audio: audio,
          client: agent,
          store: store,
          cry: CryAnalysisRepository(multipart: product, json: product),
          repository: _CryRepository(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-cry-submit-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-first-cry-player')),
        findsOneWidget,
      );
      expect(audio.disposals, 0);
      expect(store.value?.cryTasks.single.requestKey, startsWith('cry:'));
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(product.uploadKeys, hasLength(2));
      expect(product.uploadKeys[0], product.uploadKeys[1]);
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      expect(agent.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'restored result waits for server revalidation before showing a category',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport();
      final store = _CryStore();
      store.value = AgentHubInteractionSnapshot(
        runState: const AgentStreamRunState(threadId: 'thread-cry'),
        cryTasks: [
          ChatFirstCryTask.fromMap({
            'id': 'local:cry:persisted',
            'createdAt': '2026-10-22T00:00:00Z',
            'threadId': 'thread-cry',
            'status': 'completed',
            'answer': 'untrusted',
            'analysisId': product.analysisId,
          })!,
        ],
      );
      final agent = _CaptureClient();
      await tester.pumpWidget(
        _page(
          audio: _FakeCryAudio(),
          client: agent,
          store: store,
          cry: CryAnalysisRepository(multipart: product, json: product),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      expect(find.textContaining('untrusted'), findsNothing);
      expect(product.reads, 1);
      expect(agent.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'upload completed after leaving is recovered using the saved key',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport()
        ..uploadGate = Completer<void>()
        ..missingReads = 1;
      final store = _CryStore();
      final audio = _FakeCryAudio();
      final agent = _CaptureClient();
      final key = GlobalKey();
      Widget page(bool visible) => _page(
        audio: audio,
        client: agent,
        key: key,
        visible: visible,
        store: store,
        repository: _CryRepository(),
        cry: CryAnalysisRepository(multipart: product, json: product),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pump();
      expect(store.value?.cryTasks.single.requestKey, startsWith('cry:'));
      await tester.pumpWidget(page(false));
      await tester.pump();
      product.uploadGate!.complete();
      await tester.pump();
      await tester.pumpWidget(page(true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(product.lastReadPath, contains('/by-key/'));
      expect(product.reads, greaterThanOrEqualTo(2));
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      expect(agent.requests, hasLength(1));
      expect(
        buildProductionAgentRunPayload(agent.requests.single)['attachments'],
        [
          {'type': 'cry_analysis', 'analysis_id': product.analysisId},
        ],
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'another device reconstructs the result card from Product Backend',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport()
        ..listedResults.add({
          'id': 'a0a10a10-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
          'status': 'done',
          'answer': 'hungry',
          'created_at': '2026-10-22T00:00:00Z',
        });
      await tester.pumpWidget(
        _page(
          audio: _FakeCryAudio(),
          client: _CaptureClient(),
          repository: _CryRepository(),
          cry: CryAnalysisRepository(multipart: product, json: product),
          state: const AgentStreamRunState(threadId: 'thread-cry'),
        ),
      );
      await tester.pumpAndSettle();
      expect(product.lists, greaterThan(0));
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('history sync racing an upload does not duplicate its card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final product = _CryServiceTransport()
      ..uploadGate = Completer<void>()
      ..listGate = Completer<void>()
      ..listedResults.add({
        'id': 'a0a10a10-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
        'status': 'done',
        'answer': 'hungry',
        'created_at': '2026-10-22T00:00:00Z',
      });
    final agent = _CaptureClient();
    await tester.pumpWidget(
      _page(
        audio: _FakeCryAudio(),
        client: agent,
        repository: _CryRepository(),
        cry: CryAnalysisRepository(multipart: product, json: product),
        state: const AgentStreamRunState(threadId: 'thread-cry'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
    await tester.pump();
    await tester.tap(find.text('上传并分析'));
    await tester.pump();
    expect(product.recordings, hasLength(1));
    product.listGate!.complete();
    await tester.pump();
    product.uploadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('可能和饥饿有关'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-first-cry-result-card')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'retry cannot upload unless its recovery key reaches secure storage',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport();
      final store = _CryStore()..failCryKeyWrites = 100;
      final audio = _FakeCryAudio();
      final agent = _CaptureClient();
      await tester.pumpWidget(
        _page(
          audio: audio,
          client: agent,
          store: store,
          repository: _CryRepository(),
          cry: CryAnalysisRepository(multipart: product, json: product),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(product.recordings, isEmpty);
      expect(
        find.byKey(const ValueKey('chat-first-cry-submit-error')),
        findsOneWidget,
      );
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(product.recordings, isEmpty);
      store.failCryKeyWrites = 0;
      await tester.tap(find.text('上传并分析'));
      await tester.pumpAndSettle();
      expect(product.recordings, hasLength(1));
      expect(store.value?.cryTasks.single.requestKey, startsWith('cry:'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'advice state survives result verification and terminal failure advances key',
    () {
      final task = ChatFirstCryTask(
        id: 'local:cry:state',
        createdAt: DateTime.utc(2026, 10, 22),
        analysisId: 'analysis',
        status: ChatFirstCryTaskStatus.completed,
        adviceAccepted: true,
      );
      final restored = ChatFirstCryTask.fromMap(task.toMap())!;
      expect(restored.status, ChatFirstCryTaskStatus.verifying);
      expect(
        restored
            .withResult(
              id: 'analysis',
              resultStatus: 'done',
              resultAnswer: 'sleep',
              resultAt: DateTime.utc(2026, 10, 22),
            )
            .adviceAccepted,
        isTrue,
      );
      expect(task.failedAdvice().adviceAttempt, 1);
    },
  );

  testWidgets(
    'accepted but failed advice run keeps card retryable with a new key',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport();
      final agent = _CaptureClient()..controlled = true;
      await tester.pumpWidget(
        _page(
          audio: _FakeCryAudio(),
          client: agent,
          repository: _CryRepository(),
          cry: CryAnalysisRepository(multipart: product, json: product),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pump();
      await tester.pump();
      expect(agent.requests, hasLength(1));
      agent.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'cry-queued',
          'type': 'run.queued',
          'sequence': 1,
          'thread_id': 'thread-cry',
          'run_id': 'run-cry-1',
        }),
      );
      await tester.pump();
      agent.emit(
        0,
        AgentStreamEvent(const {
          'event_id': 'cry-failed',
          'type': 'run.failed',
          'sequence': 2,
          'thread_id': 'thread-cry',
          'run_id': 'run-cry-1',
          'payload': {'code': 'runtime_error'},
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-cry-retry-advice')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('chat-first-cry-retry-advice')),
      );
      await tester.pump();
      expect(agent.requests, hasLength(2));
      expect(agent.requests[0].idempotencyKey, endsWith(':0'));
      expect(agent.requests[1].idempotencyKey, endsWith(':1'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending classification polls and then sends only its result ID',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = _CryServiceTransport()..uploadStatus = 'pending';
      final agent = _CaptureClient();
      await tester.pumpWidget(
        _page(
          audio: _FakeCryAudio(),
          client: agent,
          repository: _CryRepository(),
          cry: CryAnalysisRepository(multipart: product, json: product),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
      await tester.pump();
      await tester.tap(find.text('上传并分析'));
      await tester.pump();
      await tester.pump();
      expect(agent.requests, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(product.reads, greaterThan(0));
      expect(find.text('可能和饥饿有关'), findsOneWidget);
      expect(agent.requests, hasLength(1));
      expect(
        buildProductionAgentRunPayload(agent.requests.single)['attachments'],
        [
          {'type': 'cry_analysis', 'analysis_id': product.analysisId},
        ],
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('permission and recording failures remain local and retryable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _FakeCryAudio()
      ..startError = const ChatFirstCryPermissionException();
    final client = _CaptureClient();
    await tester.pumpWidget(_page(audio: audio, client: client));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
    await tester.pump();
    expect(find.textContaining('麦克风权限'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-cry-retry')), findsOneWidget);
    expect(client.requests, isEmpty);
    audio.startError = StateError('private native recording detail');
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-retry')));
    await tester.pump();
    expect(find.textContaining('无法开始录音'), findsOneWidget);
    expect(find.textContaining('private native'), findsNothing);
    audio.startError = null;
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-first-cry-stop')), findsOneWidget);
    audio.stopError = StateError('private native stop detail');
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-stop')));
    await tester.pump();
    expect(find.textContaining('无法完成录音'), findsOneWidget);
    expect(find.textContaining('private native'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-abandon')));
    await tester.pump();
    expect(find.text('本次任务已取消。'), findsOneWidget);
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('local card survives remote recovery once, without audio bytes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _FakeCryAudio();
    final client = _CaptureClient();
    final store = _CryStore();
    final repository = _CryRepository();
    Widget page() => _page(
      audio: audio,
      client: client,
      store: store,
      repository: repository,
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pumpAndSettle();
    expect(store.value?.cryTasks, hasLength(1));
    expect(store.value?.historyMessages, isEmpty);
    expect(store.value?.cryTasks.single.status, ChatFirstCryTaskStatus.pending);
    expect(
      store.value!.toMap(includeImageData: false).toString(),
      isNot(contains('capture.wav')),
    );
    final snapshot = AgentHubInteractionSnapshot.fromMap(
      store.value!.toMap(includeImageData: false),
    );
    expect(snapshot.cryTasks, hasLength(1));
    expect(snapshot.cryTasks.single.id, store.value!.cryTasks.single.id);
    expect(snapshot.historyMessages, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    repository.messages.add(
      AgentConversationMessage(
        id: 'server-user-1',
        role: AgentConversationMessageRole.user,
        content: '真实历史消息',
        createdAt: DateTime(2026, 10, 16),
      ),
    );
    store.value = snapshot;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('真实历史消息'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-topic-cry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-cry')), findsOneWidget);
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'completed reply remains before the single local cry card after recovery',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _CryStore();
      final repository = _CryRepository();
      repository.state = const AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-cry',
        runId: 'run-before-cry',
        messageId: 'reply-before-cry',
        textContent: '之前的真实 AI 回复',
        completedAssistantMessageReceived: true,
      );
      final audio = _FakeCryAudio();
      final client = _CaptureClient();
      Widget page() => _page(
        audio: audio,
        client: client,
        store: store,
        repository: repository,
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('之前的真实 AI 回复'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pumpAndSettle();
      expect(find.text('之前的真实 AI 回复'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-first-topic-cry')),
        findsOneWidget,
      );
      expect(store.value?.historyMessages, isEmpty);
      expect(store.value?.cryTasks, hasLength(1));
      expect(
        store.value?.cryTasks.single.precedingAssistantMessageId,
        'reply-before-cry',
      );
      expect(
        tester.getTopLeft(find.text('之前的真实 AI 回复')).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('chat-first-topic-cry')))
              .dy,
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('之前的真实 AI 回复'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-first-topic-cry')),
        findsOneWidget,
      );
      expect(store.value?.historyMessages, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'using an old cry card moves it after the latest turn without duplication',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _CryStore()
        ..value = AgentHubInteractionSnapshot(
          runState: const AgentStreamRunState(threadId: 'thread-cry'),
          cryTasks: [
            ChatFirstCryTask(
              id: 'local:cry:old',
              createdAt: DateTime.utc(2026, 10, 1),
              threadId: 'thread-cry',
              placedAfterMessageId: 'old-reply',
            ),
          ],
          historyMessages: [
            AgentHubHistorySnapshot(
              id: 'old-reply',
              role: 'assistant',
              content: '旧回复',
              createdAt: DateTime.utc(2026, 10, 1),
            ),
            AgentHubHistorySnapshot(
              id: 'new-reply',
              role: 'assistant',
              content: '最新回复',
              createdAt: DateTime.utc(2026, 10, 2),
            ),
          ],
        );
      await tester.pumpWidget(
        _page(audio: _FakeCryAudio(), client: _CaptureClient(), store: store),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('chat-first-topic-cry'));
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('最新回复')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(tester.getTopLeft(find.text('最新回复')).dy),
      );
      expect(store.value?.cryTasks.single.placedAfterMessageId, 'new-reply');
    },
  );

  testWidgets('changing account disposes audio and never shows old card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firstAudio = _FakeCryAudio();
    final secondAudio = _FakeCryAudio();
    final client = _CaptureClient();
    final firstKey = Object();
    final secondKey = Object();
    await tester.pumpWidget(
      _page(
        audio: firstAudio,
        client: client,
        key: ObjectKey(firstKey),
        stateCacheKey: firstKey,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
    await tester.pump();
    await tester.pumpWidget(
      _page(
        audio: secondAudio,
        client: client,
        key: ObjectKey(secondKey),
        stateCacheKey: secondKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(firstAudio.clears, greaterThan(0));
    expect(find.byKey(const ValueKey('chat-first-topic-cry')), findsNothing);
    expect(secondAudio.starts, 0);
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permission arriving after navigation cannot reopen recording', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final permission = Completer<void>();
    final audio = _FakeCryAudio()..startWaiter = permission;
    final client = _CaptureClient();
    const key = ValueKey('pending-permission-page');
    await tester.pumpWidget(_page(audio: audio, client: client, key: key));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
    await tester.pump();
    expect(find.text('正在准备录音…'), findsOneWidget);
    await tester.pumpWidget(
      _page(audio: audio, client: client, key: key, visible: false),
    );
    permission.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-cry-stop')), findsNothing);
    expect(find.text('本次任务已取消。'), findsOneWidget);
    await tester.runAsync(() async {
      for (var i = 0; i < 30 && audio.disposals == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    expect(audio.clears, greaterThan(0));
    expect(audio.disposals, greaterThan(0));
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving the page discards capture and cannot reuse its audio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _FakeCryAudio();
    final client = _CaptureClient();
    const key = ValueKey('same-page');
    await tester.pumpWidget(_page(audio: audio, client: client, key: key));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-cry-start')));
    await tester.pump();
    await tester.pumpWidget(
      _page(audio: audio, client: client, key: key, visible: false),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));
    expect(audio.clears, greaterThan(0));
    expect(find.text('本次任务已取消。'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-cry-stop')), findsNothing);
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}

Widget _page({
  required _FakeCryAudio audio,
  required _CaptureClient client,
  Key? key,
  bool visible = true,
  AgentHubInteractionStateStore? store,
  AgentConversationRepository? repository,
  CryAnalysisRepository? cry,
  AgentStreamRunState state = const AgentStreamRunState(),
  Object? stateCacheKey,
}) => MaterialApp(
  home: Scaffold(
    body: AgentHubPage(
      key: key,
      chatFirstExperience: true,
      isVisible: visible,
      state: state,
      stateCacheKey: stateCacheKey,
      createCryAudio: () => audio,
      cryAnalysisRepository: cry,
      runner: AgentStreamRunner(client),
      interactionStateStore: store,
      conversationRepository: repository,
    ),
  ),
);

class _CaptureClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  bool controlled = false;
  final streams = <StreamController<AgentStreamEvent>>[];
  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    if (controlled) {
      final controller = StreamController<AgentStreamEvent>.broadcast();
      streams.add(controller);
      return controller.stream;
    }
    return const Stream<AgentStreamEvent>.empty();
  }

  void emit(int index, AgentStreamEvent event) => streams[index].add(event);
}

class _FakeCryAudio implements ChatFirstCryAudioSession {
  @override
  Future<List<int>> readRecording() async => <int>[1, 2, 3];

  final _positions = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  Object? startError;
  Object? stopError;
  Completer<void>? startWaiter;
  int starts = 0;
  int stops = 0;
  int clears = 0;
  int disposals = 0;
  int plays = 0;
  int pauses = 0;
  final seeks = <Duration>[];

  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  void emitPosition(Duration value) => _positions.add(value);
  @override
  Future<void> start() async {
    starts++;
    await startWaiter?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<Duration> stop() async {
    stops++;
    if (stopError != null) throw stopError!;
    return const Duration(seconds: 8);
  }

  @override
  Future<void> play() async {
    plays++;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _positions.add(position);
  }

  @override
  Future<void> clear() async {
    clears++;
    _playing.add(false);
    _positions.add(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _CryStore implements AgentHubInteractionStateStore {
  AgentHubInteractionSnapshot? value;
  int failCryKeyWrites = 0;
  @override
  Future<AgentHubInteractionSnapshot?> read() async => value;
  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {
    if (failCryKeyWrites > 0 &&
        snapshot.cryTasks.any((task) => task.requestKey != null)) {
      failCryKeyWrites--;
      throw StateError('Secure storage unavailable');
    }
    value = snapshot;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _CryRepository
    implements AgentConversationRepository, AgentConversationThreadCreator {
  @override
  Future<String> createConversation() async => 'thread-cry';
  final messages = <AgentConversationMessage>[];
  AgentStreamRunState state = const AgentStreamRunState(threadId: 'thread-cry');
  @override
  Future<AgentConversationHistory?> loadLatestConversation() async =>
      loadConversation('thread-cry');

  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) async => AgentConversationHistory(
    thread: AgentConversationSummary(
      id: threadId,
      title: '对话',
      status: 'active',
      createdAt: DateTime(2026, 10, 16),
      updatedAt: DateTime(2026, 10, 17),
    ),
    messages: [...messages],
    currentState: state,
  );
}

class _CryServiceTransport implements ApiMultipartTransport, ApiJsonTransport {
  final analysisId = 'a0a10a10-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
  final recordings = <List<int>>[];
  final uploadKeys = <String>[];
  int uploadFailures = 0;
  int reads = 0;
  Completer<void>? uploadGate;
  Completer<void>? listGate;
  String? lastReadPath;
  String uploadStatus = 'done';
  int missingReads = 0;
  int lists = 0;
  final listedResults = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    expect(path, '/v1/cry-analyses');
    expect(file.mimeType, 'audio/wav');
    expect(headers['Idempotency-Key'], isNotEmpty);
    uploadKeys.add(headers['Idempotency-Key']!);
    if (uploadFailures > 0) {
      uploadFailures--;
      throw ApiHttpException(
        statusCode: 503,
        statusText: 'Unavailable',
        body: null,
      );
    }
    expect(fields['thread_id'], 'thread-cry');
    recordings.add(file.bytes);
    await uploadGate?.future;
    return {
      'id': analysisId,
      'status': uploadStatus,
      'answer': uploadStatus == 'done' ? 'hungry' : null,
      'reason_code': uploadStatus == 'done' ? 'cry_translated' : null,
      'created_at': '2026-10-22T00:00:00Z',
    };
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/cry-analyses') {
      expect(query['thread_id'], 'thread-cry');
      await listGate?.future;
      lists++;
      return {'items': listedResults};
    }
    reads++;
    lastReadPath = path;
    if (missingReads > 0) {
      missingReads--;
      throw ApiHttpException(
        statusCode: 404,
        statusText: 'Not Found',
        body: null,
      );
    }
    return {
      'id': analysisId,
      'status': 'done',
      'answer': 'hungry',
      'created_at': '2026-10-22T00:00:00Z',
    };
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async => throw UnimplementedError();
}
