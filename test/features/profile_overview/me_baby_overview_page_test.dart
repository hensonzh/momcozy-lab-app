import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Me and Baby profile overview pages', () {
    testWidgets(
      'navigation exposes all five destinations with active Plan and More',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/me');

        for (final entry in const [
          ('bottom-nav-me', 'Me'),
          ('bottom-nav-baby', 'Baby'),
          ('bottom-nav-agent', 'Cozymate'),
          ('bottom-nav-plan', 'Plan'),
          ('bottom-nav-more', 'More'),
        ]) {
          expect(find.byKey(ValueKey(entry.$1)), findsOneWidget);
          expect(find.text(entry.$2), findsWidgets);
        }
        expect(find.text('社区'), findsNothing);
        expect(find.text('设备'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-plan')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('route-page-/schedule')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);
        expect(find.text('设备与服务'), findsOneWidget);
        expect(find.text('账户与偏好'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('route-page-/baby')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
      },
    );

    testWidgets('Me uses authoritative milk data and avoids a fake score', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      expect(find.text('Postpartum Recovery'), findsOneWidget);
      expect(tester.getRect(find.text('momcozy')).top, greaterThanOrEqualTo(0));
      expect(
        tester
            .getRect(
              find.byKey(
                const ValueKey('me-baby-overview-notification-disabled'),
              ),
            )
            .top,
        greaterThanOrEqualTo(0),
      );
      expect(find.text('Good morning,'), findsOneWidget);
      expect(find.text('Me'), findsWidgets);
      expect(find.text('Lactation'), findsWidgets);
      expect(find.text('Recovery'), findsWidgets);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('mL measured today'), findsOneWidget);
      expect(find.text('3 pumping sessions'), findsOneWidget);
      expect(find.text('473'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('me-section-recovery')));
      await tester.pumpAndSettle();

      expect(find.text('Recovery data unavailable'), findsOneWidget);
      expect(find.text('78'), findsNothing);
      expect(find.text('Body Assessment'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
    });

    testWidgets('Me saves a stage before switching to its workspace', (
      tester,
    ) async {
      final transport = _profileOverviewTransport(
        writeResponse: const {
          'user_id': 'profile-overview-user',
          'current_care_stage': 'pregnancy',
        },
      );
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(find.byKey(const ValueKey('me-current-stage-selector')));
      await tester.pumpAndSettle();

      expect(find.text('Select Current Stage'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('me-stage-option-postpartum')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('../../goldens/me_baby_overview/stage_selector.png'),
      );

      await tester.tap(find.byKey(const ValueKey('me-stage-option-pregnancy')));
      await tester.pumpAndSettle();

      expect(find.text('Select Current Stage'), findsNothing);
      expect(find.text('Pregnancy'), findsWidgets);
      expect(
        find.byKey(const ValueKey('me-stage-workspace-pregnancy')),
        findsOneWidget,
      );
      expect(find.text('Prenatal care & milestones'), findsOneWidget);
      expect(find.text('78'), findsNothing);
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastBody, {'current_care_stage': 'pregnancy'});
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/pregnancy_first_screen.png',
        ),
      );
    });

    testWidgets('Me keeps the old workspace when a stage save fails', (
      tester,
    ) async {
      final transport = _profileOverviewTransport(
        writeResponse: const {
          'http_status': 503,
          'status_text': 'Unavailable',
          'body': {
            'error': {
              'code': 'dependency_failed',
              'message': 'Profile unavailable',
            },
          },
        },
      );
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(find.byKey(const ValueKey('me-current-stage-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('me-stage-option-fertility')));
      await tester.pumpAndSettle();

      expect(find.text('Select Current Stage'), findsOneWidget);
      expect(find.text('Couldn’t change stage. Try again.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('me-current-stage-selector')),
          matching: find.text('Postpartum Recovery'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('me-stage-workspace-fertility')),
        findsNothing,
      );
    });

    testWidgets('Baby header does not expose the maternal stage selector', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      expect(
        find.byKey(const ValueKey('me-current-stage-selector')),
        findsNothing,
      );
      expect(find.text('Infant'), findsOneWidget);
    });

    testWidgets(
      'stage selector fits a compact screen and closes without saving',
      (tester) async {
        final transport = _profileOverviewTransport();
        await _pumpApp(
          tester,
          initialLocation: '/me',
          viewportSize: const Size(360, 640),
          runtime: _runtime(transport: transport),
        );

        await tester.tap(
          find.byKey(const ValueKey('me-current-stage-selector')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Select Current Stage'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('me-stage-option-fertility')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('me-stage-option-postpartum')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('me-stage-selector-close')));
        await tester.pumpAndSettle();

        expect(find.text('Select Current Stage'), findsNothing);
        expect(transport.postedBodies, isEmpty);
      },
    );

    testWidgets(
      'Baby uses authoritative feeding and growth data with honest empty states',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/baby');

        expect(find.text('Infant'), findsOneWidget);
        expect(find.text('Mia'), findsOneWidget);
        expect(find.text('Camera not connected'), findsOneWidget);
        expect(find.text('24°C'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
        await tester.pumpAndSettle();
        expect(find.text('No sleep data yet'), findsOneWidget);
        expect(find.text('14.2 h'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
        await tester.pumpAndSettle();
        expect(find.text('2 feeds recorded'), findsOneWidget);
        expect(find.text('120 mL measured'), findsOneWidget);
        expect(find.text('Today’s Feeds'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
        await tester.pumpAndSettle();
        expect(find.text('No diaper data yet'), findsOneWidget);
        expect(find.text('7 changes'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-section-growth')));
        await tester.pumpAndSettle();
        expect(find.text('6.2 kg'), findsOneWidget);
        expect(find.text('64.5 cm'), findsOneWidget);
        expect(find.text('42 cm'), findsOneWidget);
        expect(find.text('P55 (Normal)'), findsNothing);
        expect(find.text('Recorded data'), findsNWidgets(3));
      },
    );

    testWidgets(
      'Me pulls down into the avatar state and swipes up to details',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/me');

        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsNothing,
        );

        await tester.drag(
          find.byKey(const ValueKey('route-page-/me')),
          const Offset(0, 260),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsOneWidget,
        );
        expect(
          tester.getRect(find.text('momcozy')).top,
          greaterThanOrEqualTo(0),
        );
        expect(
          tester
              .getRect(
                find.byKey(
                  const ValueKey('me-baby-overview-notification-disabled'),
                ),
              )
              .top,
          greaterThanOrEqualTo(0),
        );
        expect(
          find.text('Your avatar is looking strong today!'),
          findsOneWidget,
        );
        expect(find.text('Swipe up to see detailed stats'), findsOneWidget);

        await tester.drag(
          find.byKey(const ValueKey('me-baby-overview-avatar-gesture-area')),
          const Offset(0, -260),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsNothing,
        );
        expect(find.text('Today’s Milk'), findsOneWidget);
      },
    );

    testWidgets(
      'avatar actions work without exposing the retired record entry',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/me');

        await tester.tap(
          find.byKey(const ValueKey('me-baby-overview-open-avatar')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('me-baby-overview-close-avatar')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsNothing,
        );

        expect(
          find.byKey(const ValueKey('me-baby-overview-add-record')),
          findsNothing,
        );
      },
    );

    testWidgets('Me device entry opens the real device flow', (tester) async {
      await _pumpApp(tester, initialLocation: '/me');

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-connect-device')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/device')), findsOneWidget);
    });

    testWidgets('Baby avatar state uses recorded feeding summary', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.drag(
        find.byKey(const ValueKey('route-page-/baby')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
        findsOneWidget,
      );
      expect(find.text('Mia'), findsWidgets);
      expect(find.text('2 feeds recorded today'), findsWidgets);
    });

    testWidgets('Me and Baby avatar gestures stay stable on a narrow screen', (
      tester,
    ) async {
      for (final route in const ['/me', '/baby']) {
        await _pumpApp(
          tester,
          initialLocation: route,
          viewportSize: const Size(360, 800),
        );

        await tester.drag(
          find.byKey(ValueKey('route-page-$route')),
          const Offset(0, 240),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byKey(const ValueKey('me-baby-overview-avatar-gesture-area')),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Me matches the approved first-screen visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('../../goldens/me_baby_overview/me_first_screen.png'),
      );
    });

    testWidgets('Baby matches the approved first-screen visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/baby_first_screen.png',
        ),
      );
    });

    testWidgets('Me avatar state matches the approved visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');
      await tester.drag(
        find.byKey(const ValueKey('route-page-/me')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('../../goldens/me_baby_overview/me_avatar_state.png'),
      );
    });

    testWidgets('Baby avatar state matches the approved visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');
      await tester.drag(
        find.byKey(const ValueKey('route-page-/baby')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/baby_avatar_state.png',
        ),
      );
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  Size viewportSize = const Size(430, 932),
  MomCozyApiRuntime? runtime,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final routes = FakeRouteIntentPlatform();
  addTearDown(routes.dispose);

  await tester.pumpWidget(
    MomCozyFlutterApp(
      router: createMomCozyRouter(initialLocation: initialLocation),
      routeIntentPlatform: routes,
      apiRuntime: runtime ?? _runtime(),
    ),
  );
  await tester.pumpAndSettle();
  final imageContext = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/mom_avatar.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/baby_avatar.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/baby_avatar_full.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/nursery_camera.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/momcozy-agent.png'),
        imageContext,
      ),
    ]);
  });
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _runtime({FixtureApiJsonTransportByPath? transport}) {
  return MomCozyApiRuntime(
    jsonTransport: transport ?? _profileOverviewTransport(),
    userId: 'profile-overview-user',
    babyId: 'profile-overview-baby',
    locale: 'en-US',
    now: () => DateTime.utc(2026, 7, 3),
  );
}

FixtureApiJsonTransportByPath _profileOverviewTransport({
  Map<String, Object?>? writeResponse,
}) {
  return FixtureApiJsonTransportByPath(
    {
      profileMeEndpoint: const {
        'user_id': 'profile-overview-user',
        'delivery_date': '2026-06-12',
      },
      profileInfantsEndpoint: const {
        'items': [
          {
            'id': 'profile-overview-baby',
            'infant_name': 'Mia',
            'birth_date': '2026-04-06',
          },
        ],
      },
      milkTrendsEndpoint: const {
        'items': [
          {
            'date': '2026-07-03',
            'pumped_milk_volume_ml': 210,
            'pumping_count': 3,
            'measured_only': true,
          },
        ],
      },
      feedingRecordsEndpoint: const {
        'items': [
          {
            'id': 'feed-1',
            'feed_type': 'bottle',
            'volume_ml': 80,
            'feed_time': '2026-07-03T06:00:00Z',
          },
          {
            'id': 'feed-2',
            'feed_type': 'bottle',
            'volume_ml': 40,
            'feed_time': '2026-07-03T10:00:00Z',
          },
        ],
      },
      growthRecordsEndpoint: const {
        'items': [
          {
            'id': 'growth-1',
            'weight_kg': 6.2,
            'height_cm': 64.5,
            'head_cm': 42,
            'measured_at': '2026-07-03T12:00:00Z',
          },
        ],
      },
    },
    writeResponsesByPath: {profileMeEndpoint: ?writeResponse},
  );
}
