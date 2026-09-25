import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';
import '../../support/momcozy_test_fonts.dart';

final _epoch = DateTime(2026, 9, 23, 8);
final _input = find.byKey(const ValueKey('agent-composer-input'));

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());

  testWidgets(
    'every return refreshes the current conversation and lands at latest',
    (tester) async {
      _mobile(tester);
      final store = _MemoryStore(_snapshot(40, composerText: '未发送的补充'));
      final repository = _Repository(_history(21, 40, cursor: 21));
      Widget page(bool visible) => _host(
        AgentHubPage(
          isVisible: visible,
          interactionStateStore: store,
          conversationRepository: repository,
        ),
      );

      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(repository.conversationCalls, 1);
      _scroll(tester).jumpTo(700);
      await tester.pumpAndSettle();

      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      repository.value = _history(23, 42, cursor: 23);
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();

      expect(repository.conversationCalls, 2);
      expect(find.text(_text(42)), findsOneWidget);
      expect(_scroll(tester).position.extentAfter, lessThan(1));
      expect(tester.widget<TextField>(_input).controller!.text, '未发送的补充');
      expect(
        find.byKey(const ValueKey('agent-continuation-hint')),
        findsNothing,
      );
      expect(find.text('有新回复 · 回到最新'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-first-unread-marker')),
        findsNothing,
      );
      await _dispose(tester);
    },
  );

  testWidgets('cold restart restores draft and opens at latest', (
    tester,
  ) async {
    _mobile(tester);
    final store = _MemoryStore(_snapshot(60, composerText: '未发送的补充'));

    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_input).controller!.text, '未发送的补充');
    expect(_scroll(tester).position.extentAfter, lessThan(1));
    expect(find.byKey(const ValueKey('agent-continuation-hint')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-first-unread-marker')),
      findsNothing,
    );
    await _dispose(tester);
  });

  testWidgets('draft-only restart remains a first conversation', (
    tester,
  ) async {
    final store = _MemoryStore(
      const AgentHubInteractionSnapshot(composerText: '还没有发送'),
    );
    await tester.pumpWidget(_host(AgentHubPage(interactionStateStore: store)));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_input).controller!.text, '还没有发送');
    expect(find.byType(AgentHubHistorySliver), findsNothing);
    expect(find.byKey(const ValueKey('agent-continuation-hint')), findsNothing);
    await _dispose(tester);
  });

  testWidgets(
    'default entry loads latest history and prepending preserves viewport and IDs',
    (tester) async {
      _mobile(tester);
      final repository = _Repository(_history(21, 40, cursor: 21));
      final older = Completer<AgentConversationHistory>();
      repository.older = () => older.future;
      await tester.pumpWidget(
        _host(AgentHubPage(conversationRepository: repository)),
      );
      await tester.pumpAndSettle();
      expect(repository.latestCalls, 1);
      expect(_scroll(tester).position.extentAfter, lessThan(1));

      _scroll(tester).jumpTo(0);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-conversation-older-loading')),
        findsOneWidget,
      );
      final before = tester
          .getTopLeft(find.byKey(const ValueKey('agent-history-0')))
          .dy;
      final page = _history(1, 20);
      older.complete(
        AgentConversationHistory(
          thread: page.thread,
          messages: [
            ...page.messages,
            const AgentConversationMessage(
              id: 'message-21',
              sequence: 21,
              role: AgentConversationMessageRole.user,
              content: '重复边界',
            ),
          ],
          currentState: page.currentState,
          latestMessageCreatedAt: page.latestMessageCreatedAt,
        ),
      );
      await tester.pumpAndSettle();

      final messages = tester
          .widget<AgentHubHistorySliver>(find.byType(AgentHubHistorySliver))
          .messages;
      expect(
        messages.map((message) => message.id).toSet().length,
        messages.length,
      );
      expect(messages.length, 39);
      final index = messages.indexWhere(
        (message) => message.id == 'message-21',
      );
      expect(
        tester.getTopLeft(find.byKey(ValueKey('agent-history-$index'))).dy,
        closeTo(before, 1),
      );
      expect(messages.first.id, 'message-1');
      expect(messages.last.id, 'message-39');
      expect(repository.cursors, [21]);
      await _dispose(tester);
    },
  );

  testWidgets(
    'older history failure retries inline without changing draft or transcript',
    (tester) async {
      final repository = _Repository(_history(21, 40, cursor: 21));
      repository.older = () async => throw StateError('offline');
      await tester.pumpWidget(
        _host(AgentHubPage(conversationRepository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_input, '保留这段草稿');
      _scroll(tester).jumpTo(0);
      await tester.pumpAndSettle();

      final retry = find.byKey(
        const ValueKey('agent-conversation-older-retry'),
      );
      expect(retry, findsOneWidget);
      expect(tester.widget<TextField>(_input).controller!.text, '保留这段草稿');
      repository.older = () async => _history(1, 20);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retry, findsNothing);
      expect(
        tester
            .widget<AgentHubHistorySliver>(find.byType(AgentHubHistorySliver))
            .messages
            .length,
        39,
      );
      await _dispose(tester);
    },
  );

  testWidgets(
    'a new reply while browsing history uses only the ordinary latest control',
    (tester) async {
      _mobile(tester);
      final client = _Client();
      addTearDown(client.close);
      final store = _MemoryStore(_snapshot(40));
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            interactionStateStore: store,
            runner: AgentStreamRunner(client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_input, '我还有一个问题');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pumpAndSettle();
      _scroll(tester).jumpTo(800);
      await tester.pumpAndSettle();
      final offset = _scroll(tester).offset;

      client.emit('run.started', 1, {});
      client.emit('message.completed', 2, {
        'role': 'assistant',
        'text': '可以，我们接着看上次记录的情况。',
      });
      client.emit('run.completed', 3, {});
      await tester.pumpAndSettle();

      expect(_scroll(tester).offset, closeTo(offset, 1));
      expect(find.text('Jump to latest message'), findsOneWidget);
      expect(find.text('有新回复 · 回到最新'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-first-unread-marker')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
      );
      await tester.pumpAndSettle();
      expect(_scroll(tester).position.extentAfter, lessThan(1));
      await _dispose(tester);
    },
  );

  testWidgets(
    'external reply keeps cached older history without an unread state',
    (tester) async {
      _mobile(tester);
      final store = _MemoryStore(_snapshot(40));
      final repository = _Repository(_history(21, 40, cursor: 21));
      Widget page(String? refreshKey) => _host(
        AgentHubPage(
          interactionStateStore: store,
          conversationRepository: repository,
          externalConversationRefreshKey: refreshKey,
          externalConversationRefreshInterval: Duration.zero,
        ),
      );
      await tester.pumpWidget(page(null));
      await tester.pumpAndSettle();
      _scroll(tester).jumpTo(800);
      await tester.pumpAndSettle();
      final offset = _scroll(tester).offset;

      repository.value = _history(23, 42, cursor: 23);
      await tester.pumpWidget(page('external-reply'));
      await tester.pumpAndSettle();

      final messages = tester
          .widget<AgentHubHistorySliver>(find.byType(AgentHubHistorySliver))
          .messages;
      expect(messages.first.id, 'message-1');
      expect(messages.map((message) => message.id).toSet().length, 41);
      expect(_scroll(tester).offset, closeTo(offset, 1));
      expect(find.text('Jump to latest message'), findsOneWidget);
      expect(find.text('有新回复 · 回到最新'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-first-unread-marker')),
        findsNothing,
      );
      await _dispose(tester);
    },
  );

  testWidgets(
    'a late history response cannot overwrite a new local turn or its draft',
    (tester) async {
      final repository = _Repository(_history(1, 4));
      final pending = Completer<AgentConversationHistory>();
      repository.latest = () => pending.future;
      final client = _Client();
      addTearDown(client.close);
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            conversationRepository: repository,
            runner: AgentStreamRunner(client),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(_input, '新的本地消息');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pumpAndSettle();
      pending.complete(_history(1, 4));
      await tester.pumpAndSettle();

      final messages = tester
          .widget<AgentHubHistorySliver>(find.byType(AgentHubHistorySliver))
          .messages;
      expect(messages.last.content, '新的本地消息');
      expect(messages.any((message) => message.id == 'message-1'), isFalse);
      expect(client.requests, hasLength(1));
      await _dispose(tester);
    },
  );
}

void _mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget page) => TickerMode(
  enabled: false,
  child: MaterialApp(
    theme: momCozyTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: const MomCozyBottomNavigation(location: '/'),
    ),
  ),
);

ScrollController _scroll(WidgetTester tester) => tester
    .widget<CustomScrollView>(
      find.byKey(const ValueKey('agent-chat-scroll-view')),
    )
    .controller!;

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

AgentStreamRunState _state(int index) => AgentStreamRunState(
  phase: AgentStreamRunPhase.finished,
  threadId: 'thread-1',
  runId: 'run-$index',
  messageId: 'message-$index',
  completedAssistantMessageReceived: true,
  textContent: _text(index),
);

String _text(int index) => switch (index) {
  1 => 'I saved yesterday’s notes and would like to add more today.',
  2 => 'Your earlier notes are saved. We can continue here.',
  3 => 'I want to track feeding again today. What should I note?',
  4 =>
    'Start with the feeding time, method, and what you noticed today. We can compare it with your earlier notes.',
  _ =>
    index.isOdd
        ? 'Entry $index: Today feels similar to last time. I have another note to add.'
        : 'Entry $index received. ${List.filled(index % 3 + 1, 'We can review the time, feeding method, and what changed.').join()}',
};

AgentConversationHistory _history(int first, int last, {int? cursor}) =>
    AgentConversationHistory(
      thread: AgentConversationSummary(
        id: 'thread-1',
        title: '继续记录',
        status: 'active',
        createdAt: _epoch,
        updatedAt: _epoch,
      ),
      messages: [
        for (var i = first; i < last; i++)
          AgentConversationMessage(
            id: 'message-$i',
            sequence: i,
            createdAt: _epoch.add(Duration(seconds: i)),
            role: i.isOdd
                ? AgentConversationMessageRole.user
                : AgentConversationMessageRole.assistant,
            content: _text(i),
          ),
      ],
      currentState: _state(last),
      nextBeforeSequence: cursor,
      latestMessageCreatedAt: _epoch.add(Duration(seconds: last)),
    );

AgentHubInteractionSnapshot _snapshot(int count, {String composerText = ''}) =>
    AgentHubInteractionSnapshot(
      runState: _state(count),
      composerText: composerText,
      historyMessages: [
        for (var i = 1; i < count; i++)
          AgentHubHistorySnapshot(
            id: 'message-$i',
            sequence: i,
            createdAt: _epoch.add(Duration(seconds: i)),
            role: i.isOdd ? 'user' : 'assistant',
            content: _text(i),
          ),
      ],
    );

class _MemoryStore implements AgentHubInteractionStateStore {
  _MemoryStore(this.value);

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

class _Repository implements AgentConversationRepository {
  _Repository(this.value);

  AgentConversationHistory value;
  int latestCalls = 0;
  int conversationCalls = 0;
  final cursors = <int?>[];
  Future<AgentConversationHistory?> Function()? latest;
  Future<AgentConversationHistory> Function()? older;

  @override
  Future<AgentConversationHistory?> loadLatestConversation() async {
    latestCalls++;
    return latest == null ? value : latest!();
  }

  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) async {
    if (beforeSequence == null) {
      conversationCalls++;
      return value;
    }
    cursors.add(beforeSequence);
    return older == null ? value : older!();
  }
}

class _Client implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final controller = StreamController<AgentStreamEvent>.broadcast();

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    return controller.stream;
  }

  void emit(String type, int sequence, Map<String, Object?> payload) =>
      controller.add(
        AgentStreamEvent({
          'event_id': 'event-$sequence',
          'type': type,
          'sequence': sequence,
          'thread_id': 'thread-1',
          'run_id': 'run-new',
          'message_id': 'message-new',
          'payload': payload,
        }),
      );

  Future<void> close() => controller.close();
}
