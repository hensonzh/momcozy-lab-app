import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_conversation_panel.dart';

void main() {
  testWidgets('current conversation closes while switching is locked', (
    tester,
  ) async {
    final repository = _FakeConversationRepository();
    await tester.pumpWidget(
      _host(
        repository,
        state: const AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          threadId: 'thread-new',
          runId: 'running',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-thread-new')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('agent-conversation-panel')),
      findsNothing,
    );
    expect(repository.loadedThreadIds, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dismissal invalidates a pending switch exactly once', (
    tester,
  ) async {
    var dismissals = 0;
    final canSwitch = ValueNotifier(true);
    addTearDown(canSwitch.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAgentConversationPanel(
                context: context,
                repository: _FakeConversationRepository(),
                activeThreadId: null,
                canSwitchListenable: canSwitch,
                onSelected: (_) async => false,
                onDismissed: () => dismissals++,
              ),
              child: const Text('Open history'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open history'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-close-button')),
    );
    await tester.pumpAndSettle();
    expect(dismissals, 1);
  });
  testWidgets('opens a flat partial-width conversation panel', (tester) async {
    final repository = _FakeConversationRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-conversation-panel')), findsOne);
    expect(find.text('会话历史'), findsOne);
    expect(find.text('最近的会话'), findsOne);
    expect(find.text('较早的会话'), findsOne);
    expect(find.text('今天'), findsNothing);
    expect(find.text('昨天'), findsNothing);
    expect(find.text('更早'), findsNothing);
    expect(find.text('新建会话'), findsNothing);
    final panelSize = tester.getSize(
      find.byKey(const ValueKey('agent-conversation-panel')),
    );
    final screenSize = MediaQuery.sizeOf(
      tester.element(find.byKey(const ValueKey('agent-conversation-panel'))),
    );
    expect(panelSize.width, closeTo(360, 0.1));
    expect(panelSize.width, lessThan(screenSize.width));
    expect(panelSize.height, screenSize.height);
  });

  testWidgets('selecting a conversation restores it and closes the panel', (
    tester,
  ) async {
    final repository = _FakeConversationRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-thread-old')),
    );
    await tester.pumpAndSettle();

    expect(repository.loadedThreadIds, ['thread-old']);
    expect(
      find.byKey(const ValueKey('agent-conversation-panel')),
      findsNothing,
    );
    expect(find.text('历史问题'), findsOne);
    expect(find.text('历史回答'), findsOne);
  });

  testWidgets('conversation switching is disabled while a reply is running', (
    tester,
  ) async {
    final repository = _FakeConversationRepository();
    await tester.pumpWidget(
      _host(
        repository,
        state: const AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          threadId: 'thread-new',
          runId: 'run-live',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-thread-old')),
    );
    await tester.pump();

    expect(repository.loadedThreadIds, isEmpty);
    expect(find.text('回复完成后可切换会话'), findsOne);
  });

  testWidgets('open panel unlocks when the active reply finishes', (
    tester,
  ) async {
    final repository = _FakeConversationRepository();
    await tester.pumpWidget(
      _host(
        repository,
        state: const AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          threadId: 'thread-new',
          runId: 'run-live',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('回复完成后可切换会话'), findsOne);

    await tester.pumpWidget(
      _host(
        repository,
        state: const AgentStreamRunState(
          phase: AgentStreamRunPhase.finished,
          threadId: 'thread-new',
          runId: 'run-live',
          textContent: '已完成',
          completedAssistantMessageReceived: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('回复完成后可切换会话'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-thread-old')),
    );
    await tester.pumpAndSettle();
    expect(repository.loadedThreadIds, ['thread-old']);
  });

  testWidgets('dismissed conversation load cannot overwrite a new session', (
    tester,
  ) async {
    final repository = _FakeConversationRepository();
    final deferredHistory = Completer<AgentConversationHistory>();
    repository.loadCompleter = deferredHistory;
    await tester.pumpWidget(_host(repository));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-thread-old')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-close-button')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('agent-new-session-button')));
    await tester.pump();

    deferredHistory.complete(repository.history());
    await tester.pumpAndSettle();
    expect(find.text('历史问题'), findsNothing);
    expect(find.text('历史回答'), findsNothing);
  });

  testWidgets('older conversation history loads only after user requests it', (
    tester,
  ) async {
    final repository = _FakeConversationRepository()
      ..firstPageNextBeforeSequence = 7;
    await tester.pumpWidget(_host(repository));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-thread-old')),
    );
    await tester.pumpAndSettle();

    expect(repository.loadBeforeSequences, [null]);
    expect(find.text('更早问题'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-older-load')),
    );
    await tester.pumpAndSettle();

    expect(repository.loadBeforeSequences, [null, 7]);
    expect(find.text('更早问题'), findsOne);
    expect(find.text('更早回答'), findsOne);
  });

  testWidgets('conversation list failure exposes a working retry', (
    tester,
  ) async {
    final repository = _FakeConversationRepository()..listFailuresRemaining = 1;
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('agent-conversation-history-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂时无法加载会话'), findsOne);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('最近的会话'), findsOne);
  });
}

Widget _host(
  AgentConversationRepository repository, {
  AgentStreamRunState state = const AgentStreamRunState(),
}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: const SizedBox(height: 60, child: Text('底部导航')),
      body: AgentHubPage(state: state, conversationRepository: repository),
    ),
  );
}

class _FakeConversationRepository implements AgentConversationRepository {
  final List<String> loadedThreadIds = <String>[];
  final List<int?> loadBeforeSequences = <int?>[];
  int listFailuresRemaining = 0;
  int? firstPageNextBeforeSequence;
  Completer<AgentConversationHistory>? loadCompleter;

  @override
  Future<List<AgentConversationSummary>> listConversations({
    int limit = 50,
  }) async {
    if (listFailuresRemaining > 0) {
      listFailuresRemaining -= 1;
      throw StateError('offline');
    }
    return [
      AgentConversationSummary(
        id: 'thread-new',
        title: '最近的会话',
        status: 'active',
        createdAt: DateTime.utc(2026, 7, 19),
        updatedAt: DateTime.utc(2026, 7, 20),
      ),
      AgentConversationSummary(
        id: 'thread-old',
        title: '较早的会话',
        status: 'active',
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 19),
      ),
    ];
  }

  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) async {
    loadedThreadIds.add(threadId);
    loadBeforeSequences.add(beforeSequence);
    final pending = loadCompleter;
    if (pending != null && beforeSequence == null) return pending.future;
    if (beforeSequence != null) {
      return history(question: '更早问题', answer: '更早回答', runId: 'run-older');
    }
    return history(nextBeforeSequence: firstPageNextBeforeSequence);
  }

  AgentConversationHistory history({
    String question = '历史问题',
    String answer = '历史回答',
    String runId = 'run-old',
    int? nextBeforeSequence,
  }) {
    final thread = AgentConversationSummary(
      id: 'thread-old',
      title: '较早的会话',
      status: 'active',
      createdAt: DateTime.utc(2026, 7, 18),
      updatedAt: DateTime.utc(2026, 7, 19),
    );
    return AgentConversationHistory(
      thread: thread,
      messages: [
        AgentConversationMessage(
          role: AgentConversationMessageRole.user,
          content: question,
        ),
      ],
      currentState: AgentStreamRunState(
        phase: AgentStreamRunPhase.finished,
        threadId: 'thread-old',
        runId: runId,
        textContent: answer,
        completedAssistantMessageReceived: true,
      ),
      nextBeforeSequence: nextBeforeSequence,
    );
  }
}
