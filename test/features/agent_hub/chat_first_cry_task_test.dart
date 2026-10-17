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
      expect(find.textContaining('暂不可用'), findsWidgets);
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
      runner: AgentStreamRunner(client),
      interactionStateStore: store,
      conversationRepository: repository,
    ),
  ),
);

class _CaptureClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    return const Stream<AgentStreamEvent>.empty();
  }
}

class _FakeCryAudio implements ChatFirstCryAudioSession {
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

class _CryRepository implements AgentConversationRepository {
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
