import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('More opens the recovery profile overview directly', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/me');

    await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);
    expect(find.text('Body Profile'), findsOneWidget);
    expect(find.text('Your recovery profile'), findsOneWidget);
    expect(find.text('Confirmed profile'), findsOneWidget);
    expect(find.text('Pelvic floor & bladder'), findsOneWidget);
    expect(find.text('Core & abdomen'), findsOneWidget);
    expect(find.text('设备与服务'), findsNothing);
    expect(find.text('账户与偏好'), findsNothing);

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

  testWidgets('profile overview back returns to Me', (tester) async {
    await _pumpApp(tester, initialLocation: '/more');

    final backButton = find.byKey(const ValueKey('more-profile-back'));
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/me')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-more')), findsOneWidget);
  });

  testWidgets('profile actions open the editor and save returns to More', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more');

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

    expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);
    expect(find.text('Your recovery profile'), findsOneWidget);
  });

  testWidgets('pain quick selector updates the selected pain zones', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more/body-profile/edit');

    final upperBack = find.text('Upper Back');
    await tester.scrollUntilVisible(
      upperBack,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(upperBack, findsOneWidget);

    await tester.tap(upperBack);
    await tester.pump();

    expect(find.text('Upper Back'), findsNWidgets(2));
  });

  testWidgets('More remains usable on a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpApp(tester, initialLocation: '/more');

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
    await _pumpApp(
      tester,
      initialLocation: '/more',
      viewport: const Size(430, 1636),
    );

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../../goldens/more/profile_overview.png'),
    );
  });

  testWidgets('More editor matches the approved visual baseline', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: '/more/body-profile/edit',
      viewport: const Size(438, 1498),
    );

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../../goldens/more/profile_editor.png'),
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  Size viewport = const Size(430, 932),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    const MaterialApp(
      home: SizedBox(key: ValueKey('more-asset-precache-host')),
    ),
  );
  final assetContext = tester.element(
    find.byKey(const ValueKey('more-asset-precache-host')),
  );
  await tester.runAsync(
    () => Future.wait([
      precacheImage(
        const AssetImage('assets/images/more/recovery_score.png'),
        assetContext,
      ),
      precacheImage(
        const AssetImage('assets/images/more/pain_map_preview.png'),
        assetContext,
      ),
    ]),
  );
  final runtimeController = MomCozyRuntimeController(
    MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport(const {'status': 200, 'data': {}}),
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'more-golden-user',
        babyId: 'more-golden-baby',
        locale: 'zh-CN',
        accessToken: 'more-golden-access-token',
      ),
    ),
  );
  final router = createMomCozyRouter(
    initialLocation: initialLocation,
    runtimeController: runtimeController,
  );
  addTearDown(runtimeController.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MomCozyFlutterApp(router: router, runtimeController: runtimeController),
  );
  await tester.pumpAndSettle();
}
