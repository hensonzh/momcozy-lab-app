import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Bottom navigation component parity goldens', () {
    testWidgets('Me tab selected matches compact baseline', (tester) async {
      await _bottomNavigationComponentApp(tester, location: '/me');

      final bottomNav = find.byType(MomCozyBottomNavigation);
      expect(bottomNav, findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
      expect(
        find.descendant(of: bottomNav, matching: find.text('Cozymate')),
        findsNothing,
      );

      await expectLater(
        bottomNav,
        matchesGoldenFile(
          '../../../goldens/component_parity/bottom_nav_me_selected.png',
        ),
      );
    });

    testWidgets('agent tab selected matches compact baseline', (tester) async {
      await _bottomNavigationComponentApp(tester, location: '/');

      final bottomNav = find.byType(MomCozyBottomNavigation);
      expect(bottomNav, findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
      expect(
        find.descendant(of: bottomNav, matching: find.text('Cozymate')),
        findsNothing,
      );

      await expectLater(
        bottomNav,
        matchesGoldenFile(
          '../../../goldens/component_parity/bottom_nav_agent_selected.png',
        ),
      );
    });

    testWidgets('Plan tab selected matches 0806 baseline', (tester) async {
      await _bottomNavigationComponentApp(tester, location: '/plan');

      final bottomNav = find.byType(MomCozyBottomNavigation);
      expect(bottomNav, findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-plan')), findsOneWidget);

      await expectLater(
        bottomNav,
        matchesGoldenFile(
          '../../../goldens/component_parity/bottom_nav_plan_selected.png',
        ),
      );
    });
  });
}

Future<void> _bottomNavigationComponentApp(
  WidgetTester tester, {
  required String location,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: MomCozyColors.background,
          bottomNavigationBar: MomCozyBottomNavigation(location: location),
        ),
      ),
    ),
  );
  await tester.pump();

  final appContext = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(MomCozyAssets.agentAvatar),
      appContext,
    ).timeout(const Duration(seconds: 5));
  });
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}
