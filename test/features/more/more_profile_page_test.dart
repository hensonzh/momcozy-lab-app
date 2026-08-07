import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('More links to the recovery profile overview', (tester) async {
    await _pumpApp(tester, initialLocation: '/me');

    await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);
    expect(find.text('设备与服务'), findsOneWidget);
    expect(find.text('账户与偏好'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('more-body-profile')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile')),
      findsOneWidget,
    );
    expect(find.text('Body Profile'), findsOneWidget);
    expect(find.text('Your recovery profile'), findsOneWidget);
    expect(find.text('Confirmed profile'), findsOneWidget);
    expect(find.text('Pelvic floor & bladder'), findsOneWidget);
    expect(find.text('Core & abdomen'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pain map'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pain map'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Postpartum recovery'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Postpartum recovery'), findsOneWidget);

    expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);
  });

  testWidgets('profile actions open the editor and save returns to More', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more/body-profile');

    await tester.tap(find.byKey(const ValueKey('more-edit-pelvic-floor')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile/edit')),
      findsOneWidget,
    );
    expect(find.text('Postpartum Recovery Tracker'), findsOneWidget);
    expect(find.text('Pelvic Floor Health'), findsOneWidget);
    expect(find.text('Diastasis Recti'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pain Map'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pain Map'), findsOneWidget);
    expect(find.text('Save Profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('more-save-profile')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile')),
      findsOneWidget,
    );
    expect(find.text('Your recovery profile'), findsOneWidget);
  });

  testWidgets('More remains usable on a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpApp(tester, initialLocation: '/more/body-profile');

    expect(find.text('Your recovery profile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('more-add-health-record')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('more-add-health-record')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('More matches the approved overview visual baseline', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more/body-profile');

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../../goldens/more/profile_overview.png'),
    );
  });

  testWidgets('More editor matches the approved visual baseline', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more/body-profile/edit');

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../../goldens/more/profile_editor.png'),
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    const MaterialApp(
      home: SizedBox(key: ValueKey('more-asset-precache-host')),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/more/recovery_score.png'),
      tester.element(find.byKey(const ValueKey('more-asset-precache-host'))),
    ),
  );
  await tester.pumpWidget(
    MomCozyFlutterApp(
      router: createMomCozyRouter(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}
