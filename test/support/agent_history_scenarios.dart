import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_conversation_panel.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentHistory(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final list = Completer<List<AgentConversationSummary>>();
  final repository = HistoryFixtureRepository()..loadList = (() => list.future);
  final canSwitch = ValueNotifier(false);
  var dismissals = 0;
  var selection = Completer<bool>();
  final selections = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Cozymate')),
          body: Center(
            child: TextButton(
              onPressed: () => showAgentConversationPanel(
                context: context,
                repository: repository,
                activeThreadId: 'current',
                canSwitchListenable: canSwitch,
                onSelected: (id) {
                  selections.add(id);
                  return selection.future;
                },
                onDismissed: () => dismissals++,
              ),
              child: const Text('Open history'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open history'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    find.byKey(const ValueKey('agent-conversation-loading')),
    findsOneWidget,
  );
  await capture('loading');
  list.completeError(StateError('offline'));
  await tester.pumpAndSettle();
  expect(find.text('暂时无法加载会话'), findsOneWidget);
  await capture('load-error');
  repository.loadList = () async => [
    historySummary('current', 'Reviewing today’s feeding notes together'),
    historySummary('earlier', 'Recovery and a little support'),
    for (var i = 0; i < 20; i++)
      historySummary('older-$i', 'Earlier conversation ${i + 1}'),
  ];
  await tester.tap(find.text('重试'));
  await tester.pumpAndSettle();
  await capture('locked');
  final earlier = find.byKey(const ValueKey('agent-conversation-earlier'));
  await tester.tap(earlier);
  await tester.pump();
  expect(selections, isEmpty);
  canSwitch.value = true;
  await tester.pumpAndSettle();
  await capture('list');
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('agent-conversation-list')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('agent-conversation-older-19')),
    220,
    scrollable: scrollable,
  );
  expect(find.text('Earlier conversation 20'), findsOneWidget);
  await capture('list-end');
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('agent-conversation-current')),
    -220,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  expect(
    tester
        .getSize(find.byKey(const ValueKey('agent-conversation-current')))
        .height,
    greaterThanOrEqualTo(62),
  );
  await tester.tap(earlier);
  await tester.pump();
  await capture('switching');
  await tester.tap(find.byKey(const ValueKey('agent-conversation-current')));
  await tester.pump();
  expect(selections, ['earlier']);
  expect(dismissals, 0);
  selection.complete(false);
  await tester.pumpAndSettle();
  expect(find.text('无法打开该会话，请重试'), findsOneWidget);
  await capture('switch-error');
  selection = Completer<bool>()..complete(true);
  await tester.tap(earlier);
  await tester.pumpAndSettle();
  expect(selections, ['earlier', 'earlier']);
  expect(dismissals, 1);
  expect(find.byKey(const ValueKey('agent-conversation-panel')), findsNothing);
  repository.loadList = () async => [];
  await tester.tap(find.text('Open history'));
  await tester.pumpAndSettle();
  expect(find.text('还没有历史会话'), findsOneWidget);
  await capture('empty');
  expect(await tester.binding.handlePopRoute(), isTrue);
  await tester.pumpAndSettle();
  expect(dismissals, 2);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  canSwitch.dispose();
}

AgentConversationSummary historySummary(String id, String title) =>
    AgentConversationSummary(
      id: id,
      title: title,
      status: 'active',
      createdAt: DateTime(2026, 9, 12, 9, 30),
      updatedAt: DateTime(2026, 9, 12, 9, 30),
    );

class HistoryFixtureRepository implements AgentConversationRepository {
  late Future<List<AgentConversationSummary>> Function() loadList;
  @override
  Future<List<AgentConversationSummary>> listConversations({int limit = 50}) =>
      loadList();
  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) => throw UnimplementedError();
}
