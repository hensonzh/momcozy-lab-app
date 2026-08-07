import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('redesigned first-level status pages', () {
    testWidgets(
      'navigation exposes Me, Baby, and More while Plan stays inert',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/me');

        for (final label in const ['Me', 'Baby', 'Cozymate', 'Plan', 'More']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('宝宝和我'), findsNothing);
        expect(find.text('社区'), findsNothing);
        expect(find.text('设备'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-plan')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('route-page-/me')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('route-page-/baby')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
      },
    );

    testWidgets('Me uses the fixed design data for lactation and recovery', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      expect(find.text('Postpartum Recovery'), findsOneWidget);
      expect(tester.getRect(find.text('momcozy')).top, greaterThanOrEqualTo(0));
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('status-v2-notification-disabled')),
            )
            .top,
        greaterThanOrEqualTo(0),
      );
      expect(find.text('Good morning,'), findsOneWidget);
      expect(find.text('Sophia'), findsOneWidget);
      expect(find.text('Lactation'), findsWidgets);
      expect(find.text('Recovery'), findsWidgets);
      expect(find.text('Weekly milk goal reached'), findsOneWidget);
      expect(find.text('473'), findsOneWidget);
      expect(find.text('ml / 600 ml'), findsOneWidget);
      expect(find.text('79% of daily goal · Keep going!'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('me-section-recovery')));
      await tester.pumpAndSettle();

      expect(find.text('Recovery Score'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('↑ 4 vs last week'), findsOneWidget);
      expect(find.text('Body Assessment'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
      expect(find.textContaining('No recovery'), findsNothing);
    });

    testWidgets(
      'Baby landing follows the four-section design without empty states',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/baby');

        expect(find.text('Infant'), findsOneWidget);
        expect(find.text('Baby Emma'), findsOneWidget);
        expect(find.text('3 months 2 weeks'), findsOneWidget);
        expect(find.text('I had enough milk today ✓'), findsOneWidget);
        expect(find.text('Nursery Camera'), findsOneWidget);
        expect(find.text('24°C'), findsOneWidget);
        expect(find.text('58%'), findsOneWidget);
        expect(find.text('Rolled over'), findsOneWidget);
        expect(find.textContaining('No camera'), findsNothing);
        expect(find.byKey(const ValueKey('baby-section-growth')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
        await tester.pumpAndSettle();
        expect(find.text('14.2 h'), findsOneWidget);
        expect(find.text('Currently Sleeping'), findsOneWidget);
        expect(find.text('3 naps'), findsOneWidget);
        expect(find.text('Optimal'), findsOneWidget);
        expect(find.textContaining('No sleep'), findsNothing);
      },
    );

    testWidgets('Baby feeding and diaper tabs open designed detail pages', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('baby-detail-feeding')), findsOneWidget);
      expect(find.text('Feeding & Care'), findsOneWidget);
      expect(find.text('Logs & Summaries'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(
        find.text('6 feeds completed · 730 ml out of 800 ml'),
        findsOneWidget,
      );
      expect(find.text('Today’s Feeds'), findsOneWidget);
      expect(find.text('6:30 AM'), findsOneWidget);
      expect(find.text('9:30 PM'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('baby-detail-back-feeding')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('baby-profile-hero')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('baby-detail-diaper')), findsOneWidget);
      expect(find.text('Diaper Tracker'), findsOneWidget);
      expect(find.text('Logs & Summaries'), findsOneWidget);
      expect(find.text('7 changes'), findsOneWidget);
      expect(find.text('5 Wet'), findsOneWidget);
      expect(find.text('2 Dirty'), findsOneWidget);
      expect(find.text('Diaper Timeline'), findsOneWidget);
      expect(find.textContaining('No diaper'), findsNothing);
    });

    testWidgets('Baby sleep summary opens the deeper sleep report', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');
      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-sleep-summary-card')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('baby-detail-sleep')), findsOneWidget);
      expect(find.text('Baby Sleep'), findsOneWidget);
      expect(find.text('Rest & Recovery'), findsOneWidget);
      expect(find.text('10.2 hours'), findsOneWidget);
      expect(find.text('Weekly Pattern'), findsOneWidget);
    });

    testWidgets('Baby add action shows records and opens growth details', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');
      await tester.tap(find.byKey(const ValueKey('status-v2-add')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('baby-add-record-sheet')),
        findsOneWidget,
      );
      for (final label in const [
        'Sleep',
        'Feeding',
        'Diaper',
        'Weight',
        'Height',
        'Head Circ.',
      ]) {
        expect(find.text(label), findsWidgets);
      }

      await tester.tap(find.byKey(const ValueKey('baby-add-record-weight')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('baby-detail-weight')), findsOneWidget);
      expect(find.text('Baby Weight'), findsOneWidget);
      expect(find.text('6.2 kg'), findsWidgets);
      expect(find.text('P55 (Normal)'), findsOneWidget);
      expect(find.text('Recent History'), findsOneWidget);
    });

    testWidgets(
      'Me pulls down into the avatar state and swipes up to details',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/me');

        expect(
          find.byKey(const ValueKey('status-v2-avatar-expanded')),
          findsNothing,
        );

        await tester.drag(
          find.byKey(const ValueKey('route-page-/me')),
          const Offset(0, 260),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('status-v2-avatar-expanded')),
          findsOneWidget,
        );
        expect(
          tester.getRect(find.text('momcozy')).top,
          greaterThanOrEqualTo(0),
        );
        expect(
          tester
              .getRect(
                find.byKey(const ValueKey('status-v2-notification-disabled')),
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
          find.byKey(const ValueKey('status-v2-avatar-gesture-area')),
          const Offset(0, -260),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('status-v2-avatar-expanded')),
          findsNothing,
        );
        expect(find.text('Today’s Milk'), findsOneWidget);
      },
    );

    testWidgets('Baby avatar state keeps the fixed sleep summary', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.drag(
        find.byKey(const ValueKey('route-page-/baby')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('status-v2-avatar-expanded')),
        findsOneWidget,
      );
      expect(find.text('Baby Emma'), findsWidgets);
      expect(find.text('I slept 14.2h today ✓'), findsOneWidget);
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
          find.byKey(const ValueKey('status-v2-avatar-expanded')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byKey(const ValueKey('status-v2-avatar-gesture-area')),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('status-v2-avatar-expanded')),
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
        matchesGoldenFile('../../goldens/status_v2/me_first_screen.png'),
      );
    });

    testWidgets('Baby matches the approved first-screen visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('../../goldens/status_v2/baby_first_screen.png'),
      );
    });

    testWidgets('Baby sleep landing matches the supplied visual', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');
      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('../../goldens/status_v2/baby_sleep_screen.png'),
      );
    });

    testWidgets('Baby feeding detail matches the supplied visual', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 1074),
      );
      await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/status_v2/baby_feeding_detail_390x1074.png',
        ),
      );
    });

    testWidgets('Baby add record sheet matches the supplied visual', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 844),
      );
      await tester.tap(find.byKey(const ValueKey('status-v2-add')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/status_v2/baby_add_record_sheet_390x844.png',
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
        matchesGoldenFile('../../goldens/status_v2/me_avatar_state.png'),
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
        matchesGoldenFile('../../goldens/status_v2/baby_avatar_state.png'),
      );
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  Size viewportSize = const Size(430, 932),
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
      apiRuntime: _runtime(),
    ),
  );
  await tester.pumpAndSettle();
  final imageContext = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(
        const AssetImage('assets/images/status_v2/mom_avatar.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/status_v2/baby_avatar.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/status_v2/baby_avatar_full.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/status_v2/nursery_camera.png'),
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

MomCozyApiRuntime _runtime() {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      statusProfileEndpoint: const {
        'user_id': 'status-v2-user',
        'delivery_date': '2026-06-12',
      },
      statusInfantsEndpoint: const {
        'items': [
          {
            'id': 'status-v2-baby',
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
    }),
    userId: 'status-v2-user',
    babyId: 'status-v2-baby',
    locale: 'en-US',
    now: () => DateTime.utc(2026, 7, 3),
  );
}
