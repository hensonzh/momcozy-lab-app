@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Agent home and keyboard at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_host(const AgentHubPage(), scale: scale));
        await tester.pumpAndSettle();
        await _loadImages(tester);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/agent-home-${width.toInt()}.png',
            ),
          );
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('agent-composer-input')),
          '想聊聊今天的喂养情况',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final input = tester.getRect(
          find.byKey(const ValueKey('agent-composer-input')),
        );
        expect(input.bottom, lessThanOrEqualTo(544));
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets('Agent transcript at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          const AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent:
                  'We can review today’s records together.\n\n**Next steps**\n\n- Review your baby’s feeding and sleep\n- Note how much rest you had today',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _loadImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-chat-${width.toInt()}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

Future<void> _loadImages(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in [MomCozyAssets.agentAvatar])
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pumpAndSettle();
}
