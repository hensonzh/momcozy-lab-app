import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('W1 component parity goldens', () {
    testWidgets('promo hero matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/w1'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hero = find.byKey(const ValueKey('w1-promo-hero'));
      expect(hero, findsOneWidget);
      expect(find.text('MOMCOZY · NEW'), findsOneWidget);
      expect(find.text('W1'), findsWidgets);
      expect(find.text('Wellness & Well-being'), findsOneWidget);

      await expectLater(
        hero,
        matchesGoldenFile(
          '../../../goldens/component_parity/w1_promo_hero.png',
        ),
      );
    });
  });
}
