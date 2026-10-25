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
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_welcome_coordinator.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_welcome_gate.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';
import '../../support/fixture_api_transport.dart';
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

  testWidgets(
    'new maternal welcome hides the old cached and server welcome, preserving real turns',
    (tester) async {
      _mobile(tester);
      const oldKey = 'chat-first-welcome:aaaaaaaaaaaaaaaaaaaaaaaa';
      const newKey = 'chat-first-welcome:bbbbbbbbbbbbbbbbbbbbbbbb';
      final stored = _MemoryStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-1',
            runId: 'welcome-old',
            messageId: 'welcome-old-reply',
            textContent: '旧资料的欢迎回复',
            completedAssistantMessageReceived: true,
          ),
          currentRunIsChatFirstWelcome: true,
          currentWelcomeKey: oldKey,
          composerText: '我的草稿',
          historyMessages: [
            AgentHubHistorySnapshot(
              id: 'older-welcome',
              role: 'assistant',
              content: '更早的欢迎回复',
              isChatFirstWelcome: true,
              chatFirstWelcomeKey: oldKey,
            ),
            AgentHubHistorySnapshot(
              id: 'real-user',
              role: 'user',
              content: '真实提问',
            ),
          ],
        ),
      );
      final repository = _Repository(
        AgentConversationHistory(
          thread: AgentConversationSummary(
            id: 'thread-1',
            title: 'Momcozy AI',
            status: 'active',
            createdAt: _epoch,
            updatedAt: _epoch,
          ),
          messages: const [
            AgentConversationMessage(
              id: 'welcome-old-reply',
              role: AgentConversationMessageRole.assistant,
              content: '旧资料的欢迎回复',
              isChatFirstWelcome: true,
              chatFirstWelcomeKey: oldKey,
            ),
            AgentConversationMessage(
              id: 'real-user',
              role: AgentConversationMessageRole.user,
              content: '真实提问',
            ),
          ],
          currentState: const AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-1',
            runId: 'welcome-new',
            messageId: 'welcome-new-reply',
            textContent: '新资料的欢迎回复',
            completedAssistantMessageReceived: true,
          ),
          currentRunIsChatFirstWelcome: true,
          currentWelcomeKey: newKey,
        ),
      );
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            chatFirstExperience: true,
            currentWelcomeKey: newKey,
            interactionStateStore: stored,
            conversationRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.conversationCalls, 1);
      expect(find.text('新资料的欢迎回复', findRichText: true), findsOneWidget);
      expect(find.text('旧资料的欢迎回复', findRichText: true), findsNothing);
      expect(find.text('更早的欢迎回复', findRichText: true), findsNothing);
      expect(find.text('真实提问'), findsOneWidget);
      expect(tester.widget<TextField>(_input).controller!.text, '我的草稿');
      await tester.pump(const Duration(milliseconds: 300));
      expect(stored.value?.currentWelcomeKey, newKey);
      expect(
        stored.value?.historyMessages.any(
          (message) => message.id == 'older-welcome',
        ),
        isTrue,
      );
      expect(
        stored.value?.historyMessages.any(
          (message) => message.id == 'welcome-old-reply',
        ),
        isTrue,
      );
      await _dispose(tester);
    },
  );

  testWidgets(
    'old welcome does not flash while a changed profile prepares a new one',
    (tester) async {
      _mobile(tester);
      const oldKey = 'chat-first-welcome:aaaaaaaaaaaaaaaaaaaaaaaa';
      const newKey = 'chat-first-welcome:bbbbbbbbbbbbbbbbbbbbbbbb';
      final repository = _Repository(_history(1, 2));
      final waiting = Completer<AgentConversationHistory?>();
      repository.latest = () => waiting.future;
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            chatFirstExperience: true,
            currentWelcomeKey: newKey,
            conversationRepository: repository,
            state: const AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '旧资料的欢迎回复',
            ),
            historyMessages: const [
              AgentHubHistoryMessage(
                id: 'old-welcome',
                role: AgentHubHistoryRole.assistant,
                content: '另一条旧欢迎回复',
                isChatFirstWelcome: true,
                chatFirstWelcomeKey: oldKey,
              ),
              AgentHubHistoryMessage(
                id: 'ordinary',
                role: AgentHubHistoryRole.user,
                content: '普通对话保留',
              ),
            ],
            currentRunIsChatFirstWelcome: true,
            currentRunWelcomeKey: oldKey,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('旧资料的欢迎回复', findRichText: true), findsNothing);
      expect(find.text('另一条旧欢迎回复', findRichText: true), findsNothing);
      expect(find.text('普通对话保留'), findsOneWidget);
      waiting.complete(null);
      await tester.pumpAndSettle();
      await _dispose(tester);
    },
  );

  testWidgets(
    'profile key refresh reuses cached welcome without dropping real turns',
    (tester) async {
      _mobile(tester);
      const oldKey = 'chat-first-welcome:aaaaaaaaaaaaaaaaaaaaaaaa';
      const newKey = 'chat-first-welcome:bbbbbbbbbbbbbbbbbbbbbbbb';
      const history = [
        AgentHubHistoryMessage(
          id: 'welcome-old',
          role: AgentHubHistoryRole.assistant,
          content: '旧资料欢迎',
          isChatFirstWelcome: true,
          chatFirstWelcomeKey: oldKey,
        ),
        AgentHubHistoryMessage(
          id: 'ordinary-user',
          role: AgentHubHistoryRole.user,
          content: '真实问题',
        ),
        AgentHubHistoryMessage(
          id: 'ordinary-answer',
          role: AgentHubHistoryRole.assistant,
          content: '真实回答',
        ),
        AgentHubHistoryMessage(
          id: 'welcome-new',
          role: AgentHubHistoryRole.assistant,
          content: '新资料欢迎',
          isChatFirstWelcome: true,
          chatFirstWelcomeKey: newKey,
        ),
      ];
      Widget page(String currentKey) => _host(
        AgentHubPage(
          chatFirstExperience: true,
          currentWelcomeKey: currentKey,
          historyMessages: history,
        ),
      );

      await tester.pumpWidget(page(''));
      await tester.pumpAndSettle();
      expect(find.text('旧资料欢迎'), findsNothing);
      expect(find.text('新资料欢迎'), findsNothing);
      expect(find.text('真实问题'), findsOneWidget);
      expect(find.text('真实回答', findRichText: true), findsOneWidget);

      await tester.pumpWidget(page(oldKey));
      await tester.pumpAndSettle();
      expect(find.text('旧资料欢迎', findRichText: true), findsOneWidget);
      expect(find.text('新资料欢迎'), findsNothing);

      await tester.pumpWidget(page(newKey));
      await tester.pumpAndSettle();
      expect(find.text('旧资料欢迎'), findsNothing);
      expect(find.text('新资料欢迎', findRichText: true), findsOneWidget);
      expect(find.text('真实问题'), findsOneWidget);
      expect(find.text('真实回答', findRichText: true), findsOneWidget);
      await _dispose(tester);
    },
  );

  testWidgets(
    'an older welcome page cannot duplicate the current saved welcome',
    (tester) async {
      _mobile(tester);
      const key = 'chat-first-welcome:bbbbbbbbbbbbbbbbbbbbbbbb';
      final recent = _history(21, 40, cursor: 21);
      final repository = _Repository(
        AgentConversationHistory(
          thread: recent.thread,
          messages: recent.messages,
          currentState: const AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-1',
            runId: 'welcome-latest',
            messageId: 'welcome-latest-reply',
            textContent: '当前欢迎回复',
            completedAssistantMessageReceived: true,
          ),
          currentRunIsChatFirstWelcome: true,
          currentWelcomeKey: key,
          nextBeforeSequence: 21,
        ),
      );
      final older = _history(1, 20);
      repository.older = () async => AgentConversationHistory(
        thread: older.thread,
        messages: [
          ...older.messages,
          const AgentConversationMessage(
            id: 'older-same-key-welcome',
            sequence: 20,
            role: AgentConversationMessageRole.assistant,
            content: '旧的同键欢迎回复',
            isChatFirstWelcome: true,
            chatFirstWelcomeKey: key,
          ),
        ],
        currentState: older.currentState,
      );
      await tester.pumpWidget(
        _host(
          AgentHubPage(
            chatFirstExperience: true,
            currentWelcomeKey: key,
            conversationRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      _scroll(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(repository.cursors, [21]);
      final messages = tester
          .widget<AgentHubHistorySliver>(find.byType(AgentHubHistorySliver))
          .messages;
      expect(messages.any((item) => item.content == '旧的同键欢迎回复'), isFalse);
      expect(messages.any((item) => item.id == 'message-1'), isTrue);
      _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      // The sliver can gain extent when the final reply is laid out.
      _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('当前欢迎回复', findRichText: true), findsOneWidget);
      await _dispose(tester);
    },
  );

  testWidgets('starting a new welcome does not reinsert an obsolete welcome', (
    tester,
  ) async {
    _mobile(tester);
    const oldKey = 'chat-first-welcome:aaaaaaaaaaaaaaaaaaaaaaaa';
    const newKey = 'chat-first-welcome:bbbbbbbbbbbbbbbbbbbbbbbb';
    final client = _Client();
    addTearDown(client.close);
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          chatFirstExperience: true,
          currentWelcomeKey: newKey,
          currentRunIsChatFirstWelcome: true,
          currentRunWelcomeKey: oldKey,
          state: const AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-1',
            runId: 'welcome-old',
            messageId: 'welcome-old-reply',
            textContent: '旧资料欢迎',
            completedAssistantMessageReceived: true,
          ),
          historyMessages: const [
            AgentHubHistoryMessage(
              id: 'ordinary',
              role: AgentHubHistoryRole.user,
              content: '真实问题保留',
            ),
          ],
          runner: AgentStreamRunner(client),
          initialAutoRunRequest: const AgentHubAutoRunRequest(
            requestMessage:
                '[Momcozy Chat 欢迎引导][bbbbbbbbbbbbbbbbbbbbbbbb] 更新欢迎',
            idempotencyKey: newKey,
            metadata: {'source': 'chat_first_welcome'},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(client.requests, hasLength(1));
    expect(find.text('旧资料欢迎', findRichText: true), findsNothing);
    expect(find.text('真实问题保留'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets(
    'cold persisted welcome does not restart after a profile change',
    (tester) async {
      _mobile(tester);
      const oldKey = 'chat-first-welcome:aaaaaaaaaaaaaaaaaaaaaaaa';
      final saved = MemoryChatFirstWelcomeStore();
      await saved.save('owner-1', oldKey);
      final coordinator = ChatFirstWelcomeCoordinator(
        product: FixtureApiJsonTransportByPath({
          '/v1/profile/me-experience': {
            'profile': {
              'age': 31,
              'delivery_count': 1,
              'actual_delivery_date': '2026-10-12',
              'gestation_weeks': 38,
              'gestation_days': 0,
              'baby_count': 1,
            },
            'concerns': <Object>[],
          },
        }),
        agent: FixtureApiJsonTransportByPath(const {
          '/v1/agent/threads': {'items': <Object>[]},
        }),
        store: saved,
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 16),
      );
      final persisted = _MemoryStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-1',
            runId: 'welcome-old',
            messageId: 'welcome-old-reply',
            textContent: '旧资料的欢迎回复',
            completedAssistantMessageReceived: true,
          ),
          currentRunIsChatFirstWelcome: true,
          currentWelcomeKey: oldKey,
        ),
      );
      final repository = _Repository(
        AgentConversationHistory(
          thread: AgentConversationSummary(
            id: 'thread-1',
            title: 'Momcozy AI',
            status: 'active',
            createdAt: _epoch,
            updatedAt: _epoch,
          ),
          messages: const [],
          currentState: const AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: 'thread-1',
            runId: 'welcome-old',
            messageId: 'welcome-old-reply',
            textContent: '旧资料的欢迎回复',
            completedAssistantMessageReceived: true,
          ),
          currentRunIsChatFirstWelcome: true,
          currentWelcomeKey: oldKey,
        ),
      );
      final client = _Client();
      addTearDown(client.close);
      await tester.pumpWidget(
        _host(
          ChatFirstWelcomeGate(
            activationKey: 'owner-1',
            visible: true,
            coordinator: coordinator,
            builder:
                (
                  context,
                  request,
                  currentKey,
                  onAccepted,
                  onRejected,
                  retryToken,
                ) => AgentHubPage(
                  chatFirstExperience: true,
                  currentWelcomeKey: currentKey,
                  interactionStateStore: persisted,
                  conversationRepository: repository,
                  runner: AgentStreamRunner(client),
                  initialAutoRunRequest: request,
                  onInitialAutoRunAccepted: onAccepted,
                  onInitialAutoRunRejected: onRejected,
                  initialAutoRunRetryToken: retryToken,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.requests, isEmpty);
      expect(find.text('旧资料的欢迎回复', findRichText: true), findsOneWidget);
      await _dispose(tester);
    },
  );

  testWidgets(
    'cold interrupted run reconciles the completed server reply without resending',
    (tester) async {
      _mobile(tester);
      final store = _MemoryStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            threadId: 'thread-1',
            runId: 'run-4',
            lastSequence: 3,
          ),
          activeRequest: AgentStreamRequest(
            threadId: 'thread-1',
            message: 'Internal welcome request',
            idempotencyKey: 'welcome-once',
          ),
        ),
      );
      final repository = _Repository(_history(1, 4));
      final client = _Client();
      addTearDown(client.close);

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            chatFirstExperience: true,
            interactionStateStore: store,
            conversationRepository: repository,
            runner: AgentStreamRunner(client),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.conversationCalls, 1);
      expect(find.text(_text(4), findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsNothing);
      expect(client.requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.value?.runState.phase, AgentStreamRunPhase.finished);
      await _dispose(tester);
    },
  );

  testWidgets('cold interrupted run resumes the same still-active server run', (
    tester,
  ) async {
    _mobile(tester);
    final store = _MemoryStore(
      const AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          threadId: 'thread-1',
          runId: 'run-4',
          lastSequence: 3,
        ),
        activeRequest: AgentStreamRequest(
          threadId: 'thread-1',
          message: 'Internal welcome request',
          idempotencyKey: 'welcome-once',
        ),
      ),
    );
    final complete = _history(1, 4);
    final repository = _Repository(
      AgentConversationHistory(
        thread: complete.thread,
        messages: complete.messages,
        currentState: const AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          threadId: 'thread-1',
          runId: 'run-4',
          lastSequence: 3,
        ),
      ),
    );
    final client = _Client();
    addTearDown(client.close);

    await tester.pumpWidget(
      _host(
        AgentHubPage(
          chatFirstExperience: true,
          interactionStateStore: store,
          conversationRepository: repository,
          runner: AgentStreamRunner(client),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.conversationCalls, 1);
    expect(client.requests, hasLength(1));
    expect(client.requests.single.runId, 'run-4');
    expect(client.requests.single.threadId, 'thread-1');
    expect(client.requests.single.message, 'Internal welcome request');
    expect(client.requests.single.idempotencyKey, 'welcome-once');
    await _dispose(tester);
  });

  testWidgets(
    'lagging history cannot replace an interrupted run with an older reply',
    (tester) async {
      _mobile(tester);
      final store = _MemoryStore(
        const AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(
            phase: AgentStreamRunPhase.streaming,
            threadId: 'thread-1',
            runId: 'run-4',
            lastSequence: 3,
          ),
          activeRequest: AgentStreamRequest(
            threadId: 'thread-1',
            message: 'Internal welcome request',
            idempotencyKey: 'welcome-once',
          ),
        ),
      );
      final repository = _Repository(_history(1, 3));
      final client = _Client();
      addTearDown(client.close);
      Widget page(bool visible) => _host(
        AgentHubPage(
          isVisible: visible,
          chatFirstExperience: true,
          interactionStateStore: store,
          conversationRepository: repository,
          runner: AgentStreamRunner(client),
        ),
      );

      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(repository.conversationCalls, 1);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsOneWidget);
      expect(client.requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.value?.runState.runId, 'run-4');
      expect(store.value?.activeRequest?.idempotencyKey, 'welcome-once');

      repository.value = _history(1, 4);
      await tester.pumpWidget(page(false));
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(repository.conversationCalls, 2);
      expect(find.text(_text(4), findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-retry-button')), findsNothing);
      expect(client.requests, isEmpty);
      await _dispose(tester);
    },
  );

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

  testWidgets('chat-first offline history retry preserves the unsent draft', (
    tester,
  ) async {
    final repository = _Repository(_history(1, 2));
    repository.latest = () async => throw StateError('offline');
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          chatFirstExperience: true,
          conversationRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('历史消息暂时无法加载，点击重试。'), findsOneWidget);
    expect(find.textContaining('Could not load earlier'), findsNothing);

    await tester.enterText(_input, '保留未发送的草稿');
    await tester.pump();
    expect(find.text('历史消息暂时无法同步，点击重试。'), findsOneWidget);
    repository.latest = () async => _history(1, 2);
    await tester.tap(find.text('历史消息暂时无法同步，点击重试。'));
    await tester.pumpAndSettle();

    expect(repository.latestCalls, 2);
    expect(find.text('历史消息暂时无法同步，点击重试。'), findsNothing);
    expect(tester.widget<TextField>(_input).controller!.text, '保留未发送的草稿');
    expect(find.text(_text(2), findRichText: true), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('chat-first history loading does not expose English status', (
    tester,
  ) async {
    final pending = Completer<AgentConversationHistory?>();
    final repository = _Repository(_history(1, 2));
    repository.latest = () => pending.future;
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          chatFirstExperience: true,
          conversationRepository: repository,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('正在恢复对话…'), findsOneWidget);
    expect(find.text('Restoring conversation…'), findsNothing);
    pending.complete(null);
    await tester.pumpAndSettle();
    await _dispose(tester);
  });

  testWidgets('chat-first conversation deep link retries a failed load', (
    tester,
  ) async {
    _mobile(tester);
    final repository = _FailingTargetRepository(_history(1, 2));
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          body: AgentHubPage(
            chatFirstExperience: true,
            conversationRepository: repository,
            initialConversationId: 'thread-1',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('无法打开此对话。'), findsOneWidget);
    expect(find.text('重试'), findsWidgets);
    expect(find.text('Could not open this conversation.'), findsNothing);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text(_text(2), findRichText: true), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('chat-first older history reports offline retry in Chinese', (
    tester,
  ) async {
    final repository = _Repository(_history(21, 40, cursor: 21));
    repository.older = () async => throw StateError('offline');
    await tester.pumpWidget(
      _host(
        AgentHubPage(
          chatFirstExperience: true,
          conversationRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_input, '更早消息之外的草稿');
    _scroll(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('更早消息加载失败，点击重试。'), findsOneWidget);

    repository.older = () async => _history(1, 20);
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-older-retry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('更早消息加载失败，点击重试。'), findsNothing);
    expect(tester.widget<TextField>(_input).controller!.text, '更早消息之外的草稿');
    await _dispose(tester);
  });

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

class _FailingTargetRepository implements AgentConversationRepository {
  _FailingTargetRepository(this.history);

  final AgentConversationHistory history;
  int calls = 0;

  @override
  Future<AgentConversationHistory?> loadLatestConversation() async => null;

  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) async {
    calls++;
    if (calls == 1) throw StateError('offline');
    return history;
  }
}
