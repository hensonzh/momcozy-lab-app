import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Bottom navigation component parity goldens', () {
    testWidgets('status tab selected matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const RepaintBoundary(
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: MomCozyColors.background,
              bottomNavigationBar: MomCozyBottomNavigation(location: '/status'),
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
      await tester.pumpAndSettle();

      final bottomNav = find.byType(MomCozyBottomNavigation);
      expect(bottomNav, findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);

      await expectLater(
        bottomNav,
        matchesGoldenFile(
          '../../../goldens/component_parity/bottom_nav_status_selected.png',
        ),
      );
    });
  });
}
