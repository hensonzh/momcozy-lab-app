import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('W1 component parity goldens', () {
    testWidgets('promo hero matches compact baseline', (tester) async {
      await _pumpW1ComponentApp(tester);

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

    testWidgets('product summary card matches compact baseline', (
      tester,
    ) async {
      await _pumpW1ComponentApp(tester);

      final card = find.byKey(const ValueKey('w1-product-summary-card'));
      expect(card, findsOneWidget);
      expect(find.text('Momcozy W1 穿戴式吸奶器'), findsOneWidget);
      expect(find.text('重量'), findsOneWidget);
      expect(find.text('≤35dB'), findsOneWidget);

      await expectLater(
        card,
        matchesGoldenFile(
          '../../../goldens/component_parity/w1_product_summary_card.png',
        ),
      );
    });

    testWidgets('core highlights label matches compact baseline', (
      tester,
    ) async {
      await _pumpW1ComponentApp(tester);

      final label = find.byKey(const ValueKey('w1-core-highlights-label'));
      expect(label, findsOneWidget);
      expect(find.text('核心亮点'), findsOneWidget);

      await expectLater(
        label,
        matchesGoldenFile(
          '../../../goldens/component_parity/w1_core_highlights_label.png',
        ),
      );
    });

    testWidgets('skin fit selling point matches compact baseline', (
      tester,
    ) async {
      await _pumpW1ComponentApp(tester);

      final point = find.byKey(const ValueKey('w1-selling-point-skin-fit'));
      expect(point, findsOneWidget);
      expect(find.text('亲肤零压穿戴'), findsOneWidget);

      await expectLater(
        point,
        matchesGoldenFile(
          '../../../goldens/component_parity/w1_skin_fit_selling_point.png',
        ),
      );
    });

    testWidgets('mom care selling point matches compact baseline', (
      tester,
    ) async {
      await _pumpW1ComponentApp(tester);

      final point = find.byKey(const ValueKey('w1-selling-point-mom-care'));
      expect(point, findsOneWidget);
      expect(find.text('妈妈身心关怀模式'), findsOneWidget);

      await expectLater(
        point,
        matchesGoldenFile(
          '../../../goldens/component_parity/w1_mom_care_selling_point.png',
        ),
      );
    });
  });
}

Future<void> _pumpW1ComponentApp(WidgetTester tester) async {
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
}
