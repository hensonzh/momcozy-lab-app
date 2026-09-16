import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_conversation_panel.dart';
import '../../support/agent_history_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets(
    'short large history scrolls past long titles and closes a pending switch once',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = HistoryFixtureRepository()
        ..loadList = () async => [
          historySummary('current', '讨论宝宝的喂养情况，继续上次的话题。' * 12),
          historySummary('next', '继续较早的会话'),
        ];
      final canSwitch = ValueNotifier(true);
      addTearDown(canSwitch.dispose);
      final pending = Completer<bool>();
      var dismissals = 0;
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAgentConversationPanel(
                  context: context,
                  repository: repository,
                  activeThreadId: 'current',
                  canSwitchListenable: canSwitch,
                  onSelected: (id) {
                    selected.add(id);
                    return pending.future;
                  },
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
      final next = find.byKey(const ValueKey('agent-conversation-next'));
      await tester.scrollUntilVisible(
        next,
        250,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('agent-conversation-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(next);
      await tester.pump();
      await tester.tap(next);
      await tester.pump();
      expect(selected, ['next']);
      await tester.tap(
        find.byKey(const ValueKey('agent-conversation-close-button')),
      );
      await tester.pumpAndSettle();
      expect(dismissals, 1);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(dismissals, 1);
      expect(
        find.byKey(const ValueKey('agent-conversation-panel')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('history states $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyAgentHistory(
          tester,
          scale: scale,
          capture: (state) async {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/agent-history-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          },
        );
      });
    }
  }
}
