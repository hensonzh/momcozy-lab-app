import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('More primary tab is disabled', (tester) async {
    await _pumpApp(tester, initialLocation: '/me');

    final moreTab = find.byKey(const ValueKey('bottom-nav-more'));
    expect(tester.widget<Semantics>(moreTab).properties.enabled, isFalse);

    await tester.tap(moreTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/me')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-page-/more')), findsNothing);
  });

  testWidgets('More direct route links to the recovery profile overview', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more');

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
    expect(find.text('No body profile data yet'), findsOneWidget);
    expect(find.text('Nothing is inferred'), findsOneWidget);
    expect(find.text('Pelvic floor & bladder'), findsNothing);
    expect(find.text('Core & abdomen'), findsNothing);
    expect(find.text('74'), findsNothing);
    expect(find.byKey(const ValueKey('more-add-health-record')), findsNothing);

    expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);
  });

  testWidgets('direct editor route is guarded until persistence exists', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more/body-profile/edit');

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile/edit')),
      findsOneWidget,
    );
    expect(find.text('Body profile editing unavailable'), findsOneWidget);
    expect(find.text('Save Profile'), findsNothing);
    expect(find.text('Sometimes'), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('more-body-profile-back')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile')),
      findsOneWidget,
    );
    expect(find.text('No body profile data yet'), findsOneWidget);
  });

  testWidgets('More remains usable on a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpApp(tester, initialLocation: '/more/body-profile');

    expect(find.text('No body profile data yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('more-add-health-record')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Body Profile supports 200 percent text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpApp(tester, initialLocation: '/more/body-profile');

    expect(find.text('No body profile data yet'), findsOneWidget);
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
    MomCozyFlutterApp(
      router: createMomCozyRouter(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}
