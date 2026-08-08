import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/body_profile/data/body_profile_api_repository.dart';

import '../../support/momcozy_test_fonts.dart';
import '../../support/fixture_api_transport.dart';

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
    expect(find.text('Body Profile'), findsOneWidget);
    expect(find.text('No body profile data yet'), findsOneWidget);
    expect(find.text('Nothing is inferred'), findsOneWidget);
    expect(find.text('设备与服务'), findsNothing);
    expect(find.text('账户与偏好'), findsNothing);
    expect(find.byKey(const ValueKey('more-body-profile')), findsNothing);
    expect(find.text('Pelvic floor & bladder'), findsNothing);
    expect(find.text('Core & abdomen'), findsNothing);
    expect(find.text('74'), findsNothing);
    expect(
      find.byKey(const ValueKey('more-add-health-record')),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);
  });

  testWidgets('direct editor route loads the confirmed profile form', (
    tester,
  ) async {
    await _pumpApp(tester, initialLocation: '/more/body-profile/edit');

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile/edit')),
      findsOneWidget,
    );
    expect(find.text('Body profile editing unavailable'), findsNothing);
    expect(find.text('Save Profile'), findsOneWidget);
    expect(find.text('Sometimes'), findsWidgets);
    expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('more-body-profile-back')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('route-page-/more/body-profile')),
      findsOneWidget,
    );
    expect(find.text('No body profile data yet'), findsOneWidget);
  });

  testWidgets('confirmed body profile renders only stored recovery details', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: '/more/body-profile',
      bodyProfileResponse: _confirmedBodyProfile,
    );

    expect(find.text('Pelvic floor & bladder'), findsOneWidget);
    expect(find.text('Sometimes'), findsOneWidget);
    expect(find.text('Core & abdomen'), findsOneWidget);
    expect(find.text('Lower Abdomen'), findsOneWidget);
    expect(find.text('Vaginal birth'), findsWidgets);
    expect(find.text('74'), findsNothing);
  });

  testWidgets('body profile editor saves an explicitly selected value', (
    tester,
  ) async {
    final transport = await _pumpApp(
      tester,
      initialLocation: '/more/body-profile/edit',
      bodyProfileWriteResponse: const {
        'owner_user_id': 'profile-user',
        'urine_leakage': 'sometimes',
        'pain_areas': <Object>[],
        'has_confirmed_data': true,
        'recovery_score': null,
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('body-profile-urine-leakage-sometimes')),
    );
    await tester.tap(find.byKey(const ValueKey('body-profile-save')));
    await tester.pumpAndSettle();

    expect(transport.postedBodies, hasLength(1));
    expect(transport.postedBodies.single['urine_leakage'], 'sometimes');
    expect(
      transport.postedBodies.single.containsKey('recovery_score'),
      isFalse,
    );
  });

  testWidgets('More remains usable on a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpApp(tester, initialLocation: '/more/body-profile');

    expect(find.text('No body profile data yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('more-add-health-record')),
      findsOneWidget,
    );
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

  testWidgets('Body Profile editor supports 200 percent text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpApp(tester, initialLocation: '/more/body-profile/edit');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('body-profile-pain-lower_body')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('More matches the approved overview visual baseline', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: '/more/body-profile',
      bodyProfileResponse: _confirmedBodyProfile,
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
      bodyProfileResponse: _confirmedBodyProfile,
    );

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../../goldens/more/profile_editor.png'),
    );
  });
}

Future<FixtureApiJsonTransportByPath> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  Map<String, Object?> bodyProfileResponse = const {
    'owner_user_id': 'profile-user',
    'pain_areas': <Object>[],
    'has_confirmed_data': false,
    'recovery_score': null,
  },
  Map<String, Object?>? bodyProfileWriteResponse,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final transport = FixtureApiJsonTransportByPath(
    {bodyProfileMeEndpoint: bodyProfileResponse},
    writeResponsesByPath: {bodyProfileMeEndpoint: ?bodyProfileWriteResponse},
  );
  await tester.pumpWidget(
    MomCozyFlutterApp(
      router: createMomCozyRouter(initialLocation: initialLocation),
      apiRuntime: MomCozyApiRuntime(
        jsonTransport: transport,
        userId: 'profile-user',
        babyId: 'profile-baby',
      ),
    ),
  );
  await tester.pumpAndSettle();
  return transport;
}

const _confirmedBodyProfile = <String, Object?>{
  'owner_user_id': 'profile-user',
  'urine_leakage': 'sometimes',
  'lower_abdominal_pain': 'rare',
  'pelvic_floor_strength': 3,
  'diastasis_severity': 'mild',
  'daily_impact_description': 'Tightness while lifting the baby',
  'delivery_type': 'vaginal',
  'wound_status': 'No current discomfort',
  'bleeding_status': 'Decreasing and lighter',
  'bowel_status': 'Occasional constipation',
  'pain_areas': <Object>[
    <String, Object?>{
      'id': 'pain-1',
      'zone': 'lower_abdomen',
      'intensity': 4,
      'sensation': 'Aching',
      'pattern': 'Recurring',
    },
  ],
  'updated_at': '2026-08-08T08:00:00Z',
  'has_confirmed_data': true,
  'recovery_score': null,
};
