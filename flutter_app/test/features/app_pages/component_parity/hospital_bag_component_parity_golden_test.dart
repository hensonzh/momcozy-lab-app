import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Hospital bag component parity goldens', () {
    testWidgets('footer matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/hospital-bag-cart'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pump();

      final appContext = tester.element(find.byType(MomCozyFlutterApp));
      await tester.runAsync(() async {
        await Future.wait([
          for (final asset in _hospitalBagAssets)
            precacheImage(AssetImage(asset), appContext),
        ]).timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();

      final footer = find.byKey(const ValueKey('hospital-bag-footer'));
      expect(footer, findsOneWidget);
      expect(find.text('预计合计'), findsWidgets);
      expect(find.text('去结算'), findsOneWidget);

      await expectLater(
        footer,
        matchesGoldenFile(
          '../../../goldens/component_parity/hospital_bag_footer.png',
        ),
      );
    });
  });
}

const _hospitalBagAssets = [
  'assets/images/hospital_bag_mom_pad.jpg',
  'assets/images/hospital_bag_mom_sanitary.jpg',
  'assets/images/hospital_bag_mom_underwear.png',
  'assets/images/hospital_bag_mom_wipes.jpg',
  'assets/images/hospital_bag_mom_bottle.jpg',
  'assets/images/hospital_bag_mom_briefs.png',
  'assets/images/hospital_bag_baby_diaper.jpg',
  'assets/images/hospital_bag_baby_wipes.jpg',
  'assets/images/hospital_bag_baby_towel.jpg',
  'assets/images/hospital_bag_baby_blanket.jpg',
  'assets/images/hospital_bag_baby_clothes.jpg',
  'assets/images/hospital_bag_baby_bath_towel.jpg',
  'assets/images/hospital_bag_milk_pad.jpg',
  'assets/images/hospital_bag_milk_cream.jpg',
  'assets/images/hospital_bag_milk_storage.jpg',
  'assets/images/hospital_bag_pump_m9.jpg',
  'assets/images/hospital_bag_milk_bra.jpg',
  'assets/images/hospital_bag_milk_bottle.jpg',
];
