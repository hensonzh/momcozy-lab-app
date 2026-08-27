@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Device user component parity goldens', () {
    testWidgets('form card matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          child: MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/device/user'),
            routeIntentPlatform: routeIntentPlatform,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final formCard = find.byKey(const ValueKey('device-user-form-card'));
      expect(formCard, findsOneWidget);
      expect(find.text('用户名'), findsOneWidget);
      expect(find.text('用户类型'), findsNothing);
      expect(find.text('删除用户'), findsOneWidget);
      expect(find.text('切换用户'), findsOneWidget);

      await expectLater(
        formCard,
        matchesGoldenFile(
          '../../../goldens/component_parity/device_user_form_card.png',
        ),
      );
    });
  });
}
