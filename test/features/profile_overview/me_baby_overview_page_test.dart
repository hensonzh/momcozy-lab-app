import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/notifications/data/notifications_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/maternal_care_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Me and Baby profile overview pages', () {
    testWidgets('navigation exposes all five destinations with disabled More', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      for (final entry in const [
        ('bottom-nav-me', 'Me'),
        ('bottom-nav-baby', 'Baby'),
        ('bottom-nav-plan', 'Plan'),
        ('bottom-nav-more', 'More'),
      ]) {
        expect(find.byKey(ValueKey(entry.$1)), findsOneWidget);
        expect(find.text(entry.$2), findsWidgets);
      }
      expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MomCozyBottomNavigation),
          matching: find.text('Cozymate'),
        ),
        findsNothing,
      );
      expect(find.text('社区'), findsNothing);
      expect(find.text('设备'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-plan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/plan')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/plan')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-page-/more')), findsNothing);
      expect(find.byKey(const ValueKey('bottom-nav-more')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/baby')), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
    });

    testWidgets('Me uses authoritative milk data and avoids a fake score', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      expect(find.text('Postpartum Recovery'), findsWidgets);
      expect(
        find.byKey(const ValueKey('me-baby-overview-stage-dot')),
        findsNothing,
      );
      expect(tester.getRect(find.text('momcozy')).top, greaterThanOrEqualTo(0));
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('me-baby-overview-notification')),
            )
            .top,
        greaterThanOrEqualTo(0),
      );
      expect(find.text('Postpartum Recovery'), findsWidgets);
      expect(find.text('No active program yet'), findsOneWidget);
      expect(find.text('Body Profile'), findsOneWidget);
      expect(find.text('Me'), findsWidgets);
      expect(find.text('Lactation'), findsWidgets);
      expect(find.text('Recovery'), findsWidgets);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('mL measured today'), findsOneWidget);
      expect(find.text('3 pumping sessions'), findsOneWidget);
      expect(find.text('Add another day to see a trend'), findsOneWidget);
      expect(find.text('473'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('me-section-recovery')));
      await tester.pumpAndSettle();

      expect(find.text('Recovery data unavailable'), findsOneWidget);
      expect(find.text('78'), findsNothing);
      expect(find.text('Body Assessment'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
    });

    testWidgets('Pregnancy uses authoritative gestation and program totals', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'pregnancy',
              'expected_due_date': '2026-12-20',
            },
            careOverviewResponse: const {
              'stage': 'pregnancy',
              'pregnancy': {
                'state': 'ready',
                'expected_due_date': '2026-09-25',
                'gestational_week': 28,
                'gestational_day': 0,
                'days_remaining': 84,
                'trimester': 'third',
              },
              'program': {
                'state': 'ready',
                'plan_id': 'plan-prenatal',
                'plan_type': 'prenatal_yoga',
                'title': 'Prenatal Yoga Program',
                'completed_sessions': 6,
                'total_sessions': 12,
              },
            },
          ),
        ),
      );

      expect(find.text('Week 28'), findsWidgets);
      expect(find.text('6 of 12 sessions completed'), findsOneWidget);
      expect(find.text('84 days to go'), findsOneWidget);
    });

    testWidgets('Me never labels an earlier milk trend as today', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            milkTrendItems: const [
              {
                'date': '2026-07-02',
                'measured_volume_ml': 190,
                'pumping_count': 2,
                'measured_pumping_count': 2,
              },
            ],
          ),
        ),
      );

      expect(find.text('No milk recorded today'), findsOneWidget);
      expect(find.text('190'), findsNothing);
      expect(find.text('mL measured today'), findsNothing);
    });

    testWidgets('Me removes hero chrome while preserving avatar entry', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      final hero = find.byKey(const ValueKey('me-profile-hero'));
      expect(
        find.descendant(of: hero, matching: find.byIcon(Icons.refresh_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: hero,
          matching: find.byIcon(Icons.fullscreen_rounded),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-open-avatar')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    });

    testWidgets('Me keeps saved data visible when refresh fails', (
      tester,
    ) async {
      final transport = _FailingRefreshTransport(_profileOverviewTransport());
      transport.failMilkReads = true;
      final cache = ProfileOverviewCache(
        ownerUserId: 'profile-overview-user',
        babyId: 'profile-overview-baby',
      );
      cache.milkTrends = OverviewCacheEntry(
        value: [
          MilkTrendDay(
            date: DateTime.utc(2026, 7, 3),
            measuredVolumeMl: 210,
            pumpingCount: 3,
            measuredPumpingCount: 3,
          ),
        ],
        fetchedAt: DateTime.utc(2026, 7, 1),
      );
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport, profileOverviewCache: cache),
      );

      expect(
        find.text('Couldn’t refresh. Showing saved data.'),
        findsOneWidget,
      );
      expect(find.text('210'), findsOneWidget);

      transport.failMilkReads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t refresh. Showing saved data.'), findsNothing);
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
      expect(find.text('Prenatal'), findsWidgets);
      expect(find.text('Today’s Milestones'), findsOneWidget);
      expect(find.text('78'), findsNothing);
      expect(transport.lastBody, {'current_care_stage': 'pregnancy'});
      expect(transport.postedBodies.single, {
        'current_care_stage': 'pregnancy',
      });
      expect(transport.getPaths, contains(maternalCareOverviewEndpoint));
    });

    testWidgets('Fertility matches the cycle design without invented data', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'fertility',
            },
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('me-stage-hero-fertility')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('me-stage-tabs-fertility')),
        findsOneWidget,
      );
      expect(find.text('Cycle Tracking'), findsOneWidget);
      expect(find.text('Cycle'), findsWidgets);
      expect(find.text('Wellness'), findsWidgets);
      expect(find.text('Ovulation Prediction'), findsOneWidget);
      expect(find.text('Cycle records needed'), findsOneWidget);
      expect(find.textContaining('98%'), findsNothing);
      expect(find.textContaining('fertile window is open'), findsNothing);

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/fertility_first_screen.png',
        ),
      );
    });

    testWidgets('Pregnancy uses confirmed week and plan sessions', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'pregnancy',
              'expected_due_date': '2026-10-09',
            },
            planItems: const [
              {
                'id': 'prenatal-yoga',
                'plan_type': 'yoga',
                'title': 'Prenatal Yoga Program',
                'summary': 'A confirmed prenatal movement plan',
                'status': 'active',
                'payload': <String, Object?>{},
              },
            ],
            planSessionItems: const [
              {
                'id': 'session-1',
                'plan_id': 'prenatal-yoga',
                'task_date': '2026-07-03',
                'task_time': '08:00',
                'title': 'Prenatal breathing',
                'status': 'completed',
                'payload': <String, Object?>{},
              },
              {
                'id': 'session-2',
                'plan_id': 'prenatal-yoga',
                'task_date': '2026-07-03',
                'task_time': '17:00',
                'title': 'Gentle mobility',
                'status': 'pending',
                'payload': <String, Object?>{},
              },
            ],
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('me-stage-hero-pregnancy')),
        findsOneWidget,
      );
      expect(find.text('Prenatal Yoga Program'), findsOneWidget);
      expect(find.text('1 of 2 sessions completed'), findsOneWidget);
      expect(find.text('Prenatal'), findsWidgets);
      expect(find.text('Wellness'), findsWidgets);
      expect(find.text("Today’s Milestones"), findsOneWidget);
      expect(find.text('Week 26 of 40'), findsOneWidget);
      expect(find.text('98 days to go'), findsOneWidget);
      expect(find.text('Prenatal breathing'), findsOneWidget);
      expect(find.text('Gentle mobility'), findsOneWidget);
      expect(find.textContaining('Eggplant'), findsNothing);
      expect(find.textContaining('14.8'), findsNothing);

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/pregnancy_first_screen.png',
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-open-avatar')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
        findsOneWidget,
      );
      expect(find.text('Week 26 · Second Trimester'), findsOneWidget);
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/pregnancy_avatar_state.png',
        ),
      );
    });

    testWidgets('Pregnancy accepts a confirmed gestational week fallback', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'pregnancy',
              'birth_prep_due_date_or_week': 'Week 32',
            },
          ),
        ),
      );

      expect(find.text('Week 32 of 40'), findsOneWidget);
      expect(find.text('About 56 days to go'), findsOneWidget);
    });

    testWidgets('Me asks for a stage when the profile has no stage evidence', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
            },
          ),
        ),
      );

      expect(find.text('Select Stage'), findsOneWidget);
      expect(find.text('Choose your current stage'), findsOneWidget);
      expect(find.text('Postpartum Recovery'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('me-stage-choose')));
      await tester.pumpAndSettle();
      expect(find.text('Select Current Stage'), findsOneWidget);
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

      expect(find.text('momcozy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('me-current-stage-selector')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('me-baby-overview-notification')),
        findsOneWidget,
      );
      expect(find.text('Infant'), findsOneWidget);
    });

    testWidgets('Notification bell opens the real owner inbox', (tester) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-notification')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('route-page-/notifications')),
        findsOneWidget,
      );
      expect(find.text('Feeding reminder'), findsOneWidget);
      expect(transport.lastPath, notificationsEndpoint);
      expect(transport.lastQuery, {'limit': 100});

      await tester.tap(find.byKey(const ValueKey('notifications-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-page-/baby')), findsOneWidget);
    });

    testWidgets('Infant selector switches the visible baby and record scope', (
      tester,
    ) async {
      final transport = _profileOverviewTransport(
        infantItems: const [
          {
            'id': 'profile-overview-baby',
            'infant_name': 'Mia',
            'birth_date': '2026-04-06',
          },
          {
            'id': 'profile-overview-baby-2',
            'infant_name': 'Noah',
            'birth_date': '2026-06-20',
          },
        ],
      );
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );

      expect(find.text('Mia'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('baby-profile-selector')));
      await tester.pumpAndSettle();

      expect(find.text('Select Infant'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('baby-profile-option-profile-overview-baby')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('baby-profile-option-profile-overview-baby-2'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('baby-profile-option-profile-overview-baby-2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Noah'), findsOneWidget);
      expect(find.text('Mia'), findsNothing);
      expect(transport.getPaths, contains(growthRecordsEndpoint));
      expect(transport.lastPath, feedingSummaryEndpoint);
      expect(transport.lastQuery?['infant_id'], 'profile-overview-baby-2');
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

    testWidgets('stage selector is edge-to-edge and exposes a drag handle', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      await tester.tap(find.byKey(const ValueKey('me-current-stage-selector')));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(
        find.byKey(const ValueKey('me-stage-selector-card')),
      );
      expect(sheet.left, 0);
      expect(sheet.right, 430);
      expect(
        find.byKey(const ValueKey('me-stage-selector-drag-handle')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Baby uses the four-section design with authoritative and honest data',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/baby');

        expect(find.text('Infant'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('me-baby-overview-stage-dot')),
          findsNothing,
        );
        expect(find.text('Mia'), findsOneWidget);
        expect(find.text('Nursery Camera'), findsOneWidget);
        expect(find.text('OFFLINE'), findsOneWidget);
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('24°C'), findsNothing);
        expect(find.byKey(const ValueKey('baby-section-growth')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
        await tester.pumpAndSettle();
        expect(find.text('Total Sleep Today'), findsOneWidget);
        expect(find.text('3 h'), findsOneWidget);
        expect(find.text('2 confirmed sleep records today'), findsOneWidget);
        expect(find.text('Sleep Pattern Today'), findsOneWidget);
        expect(find.text('1 nap'), findsOneWidget);
        expect(find.text('Sleep Training'), findsOneWidget);
        expect(find.text('14.2 h'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('baby-detail-feeding')),
          findsOneWidget,
        );
        expect(find.text('Today’s Feeding Summary'), findsOneWidget);
        expect(
          find.text('2 confirmed feeds · 120 mL measured'),
          findsOneWidget,
        );
        expect(find.text('Today’s Feeds'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('baby-feeding-period-week')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Last 7 Days Feeding Summary'), findsOneWidget);
        expect(
          find.text('3 confirmed feeds · 200 mL measured'),
          findsOneWidget,
        );
        expect(find.text('Completed-day intake'), findsOneWidget);
        expect(find.text('Today’s Feeds'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('baby-feeding-period-day')));
        await tester.pumpAndSettle();
        expect(find.text('Today’s Feeds'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('baby-detail-back-feeding')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('baby-detail-diaper')),
          findsOneWidget,
        );
        expect(find.text('2 changes'), findsOneWidget);
        expect(find.text('2 Wet'), findsOneWidget);
        expect(find.text('1 Dirty'), findsOneWidget);
        expect(find.text('No diaper data yet'), findsNothing);
        expect(find.text('7 changes'), findsNothing);
      },
    );

    testWidgets('Baby feeding uses linked seven-day and diaper records', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            feedingItems: const [
              {
                'id': 'feed-today',
                'infant_id': 'profile-overview-baby',
                'feeding_method': 'bottle',
                'milk_components': [
                  {'milk_source': 'breast_milk', 'volume_ml': 80},
                ],
                'feed_time': '2026-07-03T06:00:00Z',
              },
              {
                'id': 'feed-yesterday',
                'infant_id': 'profile-overview-baby',
                'feeding_method': 'bottle',
                'milk_components': [
                  {'milk_source': 'formula', 'volume_ml': 60},
                ],
                'feed_time': '2026-07-02T06:00:00Z',
              },
            ],
            feedingSummaryResponse: _feedingSummaryFixture(
              feedingCount: 2,
              measuredVolumeMl: 140,
            ),
            diaperItems: const [
              {
                'id': 'diaper-both',
                'infant_id': 'profile-overview-baby',
                'changed_at': '2026-07-03T07:00:00Z',
                'diaper_kind': 'both',
                'wetness': 'medium',
                'stool_color': 'yellow',
              },
              {
                'id': 'diaper-wet',
                'infant_id': 'profile-overview-baby',
                'changed_at': '2026-07-03T09:00:00Z',
                'diaper_kind': 'wet',
                'wetness': 'light',
              },
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
      await tester.pumpAndSettle();

      expect(find.text('1 confirmed feed · 80 mL measured'), findsOneWidget);
      expect(find.text('2 wet · 1 dirty'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('baby-feeding-period-week')));
      await tester.pumpAndSettle();

      expect(find.text('2 confirmed feeds · 140 mL measured'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('baby-feeding-week-daily-card')),
        findsOneWidget,
      );
    });

    testWidgets('Baby hero paints the avatar above the feeding summary', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _emptyRuntime(),
      );

      expect(find.text('Baby'), findsWidgets);
      expect(find.text('Age not recorded'), findsOneWidget);
      expect(find.text('No feeding data recorded today'), findsOneWidget);

      const copyKey = ValueKey('me-baby-overview-baby-hero-copy');
      const avatarKey = ValueKey('me-baby-overview-baby-hero-avatar');
      final hero = find.byKey(const ValueKey('baby-profile-hero'));
      final stack = tester.widget<Stack>(
        find.descendant(of: hero, matching: find.byType(Stack)).first,
      );
      final copyIndex = stack.children.indexWhere(
        (child) => child.key == copyKey,
      );
      final avatarIndex = stack.children.indexWhere(
        (child) => child.key == avatarKey,
      );

      expect(copyIndex, greaterThanOrEqualTo(0));
      expect(avatarIndex, greaterThan(copyIndex));
      expect(tester.getSize(hero).height, 175);
      expect(find.text('No feeding data recorded today'), findsOneWidget);
    });

    testWidgets('Baby expanded avatar clips the baked-in name', (tester) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.drag(
        find.byKey(const ValueKey('route-page-/baby')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.contains(
                'baby_avatar_full',
              ),
        ),
      );
      expect(
        (avatar.image as AssetImage).assetName,
        'assets/images/me_baby_overview/baby_avatar_full.png',
      );
      expect(
        find.byKey(const ValueKey('baby-avatar-name-free-clip')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Baby Development uses a confirmed gestational week without inventing clinical data',
      (tester) async {
        await _pumpApp(
          tester,
          initialLocation: '/baby/development',
          runtime: _runtime(
            transport: _profileOverviewTransport(
              profileResponse: const {
                'user_id': 'profile-overview-user',
                'display_name': 'Avery',
                'current_care_stage': 'pregnancy',
              },
              pregnancyFactValue: 'Week 28',
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('baby-development-page')),
          findsOneWidget,
        );
        expect(find.text('Baby Development'), findsOneWidget);
        expect(find.text('Week 28 Visualization'), findsOneWidget);
        expect(find.text('Week 28 Milestones'), findsOneWidget);
        expect(find.text('Milestone guidance unavailable'), findsOneWidget);
        expect(find.text('Estimated Length'), findsOneWidget);
        expect(find.text('Estimated Weight'), findsOneWidget);
        expect(find.text('Not available'), findsNWidgets(2));
        expect(find.text('37.6 cm'), findsNothing);
        expect(find.text('1,005 g'), findsNothing);
        expect(find.textContaining('55th percentile'), findsNothing);
        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile(
            '../../goldens/me_baby_overview/baby_development_first_screen.png',
          ),
        );
      },
    );

    testWidgets('Baby Development is reachable from pregnancy workspace', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'pregnancy',
            },
            pregnancyFactValue: 'Week 28',
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('me-stage-pregnancy-development')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('me-stage-pregnancy-development')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('baby-development-page')),
        findsOneWidget,
      );
      expect(find.text('Week 28 Visualization'), findsOneWidget);
    });

    testWidgets('Baby Development derives a week from a confirmed due date', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby/development',
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'pregnancy',
            },
            pregnancyFactValue: '2026-10-10',
          ),
        ),
      );

      expect(find.text('Week 25 Visualization'), findsOneWidget);
      expect(find.textContaining('55th percentile'), findsNothing);
    });

    testWidgets('Baby Development supports narrow screens and large text', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby/development',
        viewportSize: const Size(360, 640),
        textScaleFactor: 2,
        runtime: _runtime(
          transport: _profileOverviewTransport(
            profileResponse: const {
              'user_id': 'profile-overview-user',
              'display_name': 'Avery',
              'current_care_stage': 'pregnancy',
            },
            pregnancyFactValue: 'Week 28',
          ),
        ),
      );

      expect(find.text('Baby Development'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('baby-development-start-education')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('baby-development-start-education')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Baby monitor renders status separately from its clean image', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      final camera = find.byKey(const ValueKey('baby-monitor-camera-card'));
      final preview = tester.widget<Image>(
        find.descendant(of: camera, matching: find.byType(Image)).first,
      );
      expect(
        (preview.image as AssetImage).assetName,
        'assets/images/me_baby_overview/nursery_camera_clean.png',
      );
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('Baby main layout preserves the approved reference anchors', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      final heroBackground = tester.getRect(
        find.byKey(const ValueKey('baby-profile-hero-background')),
      );
      final cameraCard = tester.getRect(
        find.byKey(const ValueKey('baby-monitor-camera-card')),
      );
      final recentCard = tester.getRect(
        find.byKey(const ValueKey('baby-monitor-recent-card')),
      );
      final addRecord = tester.getRect(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );

      expect(heroBackground, const Rect.fromLTWH(22, 77, 386, 156));
      expect(cameraCard, const Rect.fromLTWH(16, 311, 398, 241));
      expect(recentCard.left, 16);
      expect(recentCard.top, 562);
      expect(recentCard.width, 398);
      expect(addRecord, const Rect.fromLTWH(350, 772, 56, 56));
    });

    testWidgets('Baby matches source anchors with iPhone safe areas', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewPadding: const FakeViewPadding(top: 24, bottom: 34),
      );

      expect(
        tester.getRect(
          find.byKey(const ValueKey('baby-profile-hero-background')),
        ),
        const Rect.fromLTWH(22, 101, 386, 156),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-monitor-camera-card'))),
        const Rect.fromLTWH(16, 335, 398, 241),
      );
      expect(tester.getRect(find.text('momcozy')).top, closeTo(55, 1));
      expect(
        tester.getRect(find.byKey(const ValueKey('bottom-nav-agent'))).top,
        closeTo(829, 4),
      );
    });

    testWidgets('Baby sleep summary opens the honest detailed report', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-sleep-summary-card')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('baby-detail-sleep')), findsOneWidget);
      expect(find.text('Baby Sleep'), findsOneWidget);
      expect(find.text('2 h'), findsWidgets);
      expect(find.text('Nap'), findsWidgets);
      expect(find.text('No naps recorded'), findsNothing);
      expect(find.text('Weekly Pattern'), findsOneWidget);
      expect(find.text('10.2 hours'), findsNothing);
    });

    testWidgets('Baby sleep landing preserves the approved source geometry', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');
      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(const ValueKey('baby-sleep-summary-card'))),
        const Rect.fromLTWH(16, 273, 398, 168),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-sleep-pattern-card'))),
        const Rect.fromLTWH(16, 451, 398, 116),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-sleep-trend-card'))),
        const Rect.fromLTWH(16, 577, 398, 143),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-sleep-training-card'))),
        const Rect.fromLTWH(16, 730, 398, 114),
      );
    });

    testWidgets('Baby growth detail presents recorded trend and deltas', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await _openGrowthDetail(tester, 'weight');

      expect(find.byKey(const ValueKey('baby-detail-weight')), findsOneWidget);
      expect(find.text('Baby Weight'), findsOneWidget);
      expect(find.text('Weight Trend'), findsOneWidget);
      expect(find.text('Reference band unavailable'), findsOneWidget);
      expect(find.text('+0.4 kg'), findsOneWidget);
      expect(find.text('Baseline'), findsOneWidget);
      expect(find.text('P55 (Normal)'), findsNothing);
    });

    testWidgets('Baby growth layout preserves the approved card geometry', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 844),
      );
      await _openGrowthDetail(tester, 'weight');

      expect(
        tester.getRect(find.byKey(const ValueKey('baby-growth-current-card'))),
        const Rect.fromLTWH(16, 95, 358, 100),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-growth-trend-card'))),
        const Rect.fromLTWH(16, 211, 358, 195),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-growth-history-card'))),
        const Rect.fromLTWH(16, 422, 358, 251),
      );
    });

    testWidgets('Baby detail chrome preserves the approved source geometry', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 1074),
      );
      await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(const ValueKey('baby-detail-back-feeding'))),
        const Rect.fromLTWH(16, 26, 44, 44),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-detail-more-disabled'))),
        const Rect.fromLTWH(330, 26, 44, 44),
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('baby-feeding-period-background')),
        ),
        const Rect.fromLTWH(16, 78, 358, 38),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-feeding-summary-card'))),
        const Rect.fromLTWH(16, 139, 358, 76),
      );
      expect(find.text('Weekly Intake Trend'), findsOneWidget);

      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 875),
      );
      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-sleep-summary-card')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(
          find.byKey(const ValueKey('baby-sleep-last-night-card')),
        ),
        const Rect.fromLTWH(16, 95, 358, 125),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-sleep-timeline-card'))),
        const Rect.fromLTWH(16, 236, 358, 132),
      );

      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 963),
      );
      await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
      await tester.pumpAndSettle();
      final diaperSummary = tester.getRect(
        find.byKey(const ValueKey('baby-diaper-summary-card')),
      );
      expect(diaperSummary.left, 16);
      expect(diaperSummary.top, 95);
      expect(diaperSummary.width, 358);
      expect(diaperSummary.height, closeTo(105, 0.3));
      final wetCard = tester.getRect(
        find.byKey(const ValueKey('baby-diaper-wet-card')),
      );
      expect(wetCard.left, 16);
      expect(wetCard.top, closeTo(216, 0.3));
      expect(wetCard.width, 174);
      expect(wetCard.height, closeTo(90, 0.01));
      final dirtyCard = tester.getRect(
        find.byKey(const ValueKey('baby-diaper-dirty-card')),
      );
      expect(dirtyCard.left, 200);
      expect(dirtyCard.top, closeTo(216, 0.3));
      expect(dirtyCard.width, 174);
      expect(dirtyCard.height, closeTo(90, 0.01));
      final diaperTimeline = tester.getRect(
        find.byKey(const ValueKey('baby-diaper-timeline-card')),
      );
      expect(diaperTimeline.left, 16);
      expect(diaperTimeline.top, closeTo(322, 0.3));
      expect(diaperTimeline.width, 358);
    });

    testWidgets('Baby primary controls expose minimum 44px tap targets', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      for (final key in const [
        'baby-section-monitor',
        'baby-section-sleep',
        'baby-section-feeding',
        'baby-section-diaper',
        'me-baby-overview-notification',
        'me-baby-overview-connect-camera',
        'me-baby-overview-add-record',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }
    });

    testWidgets('Baby uses the approved typography and vector iconography', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      expect(tester.widget<Text>(find.text('Mia')).style?.fontFamily, 'Rubik');
      expect(
        tester.widget<Text>(find.text('12 weeks 4 days')).style?.fontFamily,
        'Figtree',
      );
      for (final key in const [
        'me-baby-overview-notification',
        'baby-section-monitor',
        'baby-section-sleep',
        'baby-section-feeding',
        'baby-section-diaper',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(SvgPicture),
          ),
          findsOneWidget,
          reason: key,
        );
      }

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      for (final detail in const [
        'sleep',
        'feeding',
        'diaper',
        'weight',
        'height',
        'head-circumference',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('baby-add-record-$detail')),
            matching: find.byType(SvgPicture),
          ),
          findsOneWidget,
          reason: detail,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('baby-add-record-close')),
          matching: find.byType(SvgPicture),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('baby-add-record-feeding')));
      await tester.pumpAndSettle();
      for (final key in const [
        'baby-detail-back-feeding',
        'baby-detail-more-disabled',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(SvgPicture),
          ),
          findsOneWidget,
          reason: key,
        );
      }
    });

    testWidgets('Baby core flows remain usable at 200 percent text scale', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(360, 800),
        textScaleFactor: 2,
      );

      expect(tester.takeException(), isNull);
      final heroRect = tester.getRect(
        find.byKey(const ValueKey('baby-profile-hero')),
      );
      final summaryRect = tester.getRect(find.text('2 feeds recorded today'));
      expect(summaryRect.bottom, lessThanOrEqualTo(heroRect.bottom));
      await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('baby-detail-diaper')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('baby-detail-back-diaper')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('baby-add-record-sheet')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Every Baby detail remains stable at 360px and 200% text', (
      tester,
    ) async {
      for (final detail in const ['feeding', 'diaper', 'sleep']) {
        await _pumpApp(
          tester,
          initialLocation: '/baby',
          viewportSize: const Size(360, 800),
          textScaleFactor: 2,
        );
        await tester.tap(find.byKey(ValueKey('baby-section-$detail')));
        await tester.pumpAndSettle();
        if (detail == 'sleep') {
          final summary = find.byKey(const ValueKey('baby-sleep-summary-card'));
          await tester.ensureVisible(summary);
          await tester.tap(summary);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(ValueKey('baby-detail-$detail')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: detail);
      }

      for (final detail in const ['weight', 'height', 'head-circumference']) {
        await _pumpApp(
          tester,
          initialLocation: '/baby',
          viewportSize: const Size(360, 800),
          textScaleFactor: 2,
        );
        await _openGrowthDetail(tester, detail);
        expect(find.byKey(ValueKey('baby-detail-$detail')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: detail);
      }
    });

    testWidgets('Baby add sheet exposes six records and real growth details', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('baby-add-record-sheet')),
        findsOneWidget,
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
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
      for (final detail in const ['sleep', 'diaper']) {
        final tile = find.byKey(ValueKey('baby-add-record-$detail'));
        final inkWell = tester.widget<InkWell>(
          find.descendant(of: tile, matching: find.byType(InkWell)),
        );
        expect(inkWell.onTap, isNotNull, reason: detail);
        expect(
          find.descendant(of: tile, matching: find.text('Coming soon')),
          findsNothing,
          reason: detail,
        );
      }

      await tester.tap(find.byKey(const ValueKey('baby-add-record-weight')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('baby-growth-editor-weight')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('baby-detail-weight')), findsOneWidget);
      expect(find.text('Baby Weight'), findsOneWidget);
      expect(find.text('6.2 kg'), findsWidgets);
      expect(find.text('Weight Trend'), findsOneWidget);
      expect(find.text('Recent History'), findsOneWidget);
      expect(find.text('P55 (Normal)'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('baby-growth-value-input')),
        '6.4',
      );
      await tester.tap(find.byKey(const ValueKey('baby-growth-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('baby-growth-editor-weight')),
        findsNothing,
      );
      expect(find.text('6.4 kg'), findsWidgets);
      expect(find.text('Growth measurement saved.'), findsOneWidget);
    });

    testWidgets('Baby saves a manual sleep record from the add sheet', (
      tester,
    ) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-add-record-sleep')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('record-sleep-duration')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('record-sleep-duration')),
        '60',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();

      expect(transport.lastMethod, 'GET');
      expect(transport.getPaths.last, sleepRecordsEndpoint);
      final sleepWrite = transport.postedBodies.last;
      expect(sleepWrite['infant_id'], 'profile-overview-baby');
      expect(sleepWrite['sleep_kind'], 'nap');
      expect(
        DateTime.parse(
          sleepWrite['ended_at']! as String,
        ).difference(DateTime.parse(sleepWrite['started_at']! as String)),
        const Duration(minutes: 60),
      );
    });

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
                find.byKey(const ValueKey('me-baby-overview-notification')),
              )
              .top,
          greaterThanOrEqualTo(0),
        );
        expect(find.text('No active program yet'), findsWidgets);
        expect(find.text('Body Profile'), findsWidgets);
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

    testWidgets('Postpartum avatar mode keeps the stage pill understated', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      await tester.drag(
        find.byKey(const ValueKey('route-page-/me')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();

      final stagePill = tester.widget<Material>(
        find.byKey(const ValueKey('me-current-stage-selector')),
      );
      expect(stagePill.color, const Color(0xfff2e9e6));
    });

    testWidgets('maternal stage tabs separate visual height from tap target', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      final tabs = find.byKey(const ValueKey('me-stage-tabs-postpartum'));
      final lactation = find.byKey(const ValueKey('me-section-lactation'));
      final surface = find.byKey(
        const ValueKey('me-stage-tab-surface-lactation'),
      );

      expect(tester.getSize(tabs).height, 48);
      expect(tester.getSize(lactation).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(surface).height, 36);
      expect(tester.getTopLeft(surface).dy, 287);
    });

    testWidgets(
      'maternal hero keeps compact visuals inside accessible tap targets',
      (tester) async {
        await _pumpApp(tester, initialLocation: '/me');

        final title = tester.widget<Text>(
          find.byKey(const ValueKey('me-stage-program-title')),
        );
        final action = find.byKey(const ValueKey('me-stage-body-profile'));
        final surface = find.byKey(
          const ValueKey('me-stage-body-profile-surface'),
        );

        expect(title.style?.fontSize, 14);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(action).width, lessThan(160));
        expect(tester.getSize(surface).height, 32);
        expect(tester.getTopLeft(surface).dx, 38);
      },
    );

    testWidgets('avatar and supported record actions stay available', (
      tester,
    ) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport),
      );

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

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mom-add-record-sheet')),
        findsOneWidget,
      );
      for (final label in const [
        'Pumping (Left)',
        'Pumping (Right)',
        'Sleep',
        'Weight',
        'Water Intake',
        'Vitals',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(
        find.byKey(const ValueKey('mom-add-record-pumping-left')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log pumping session'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('record-pumping-left-amount')),
        '95',
      );
      await tester.tap(find.byKey(const ValueKey('record-pumping-side-right')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-pumping-right-amount')),
        '42.5',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();

      expect(find.text('Record saved'), findsOneWidget);
      expect(transport.postedBodies.last, {
        'pump_start_time': '2026-07-03T00:00:00.000Z',
        'outputs': [
          {'breast_side': 'left', 'volume_ml': 95.0},
          {'breast_side': 'right', 'volume_ml': 42.5},
        ],
        'pump_type': 'manual',
        'source': 'manual',
      });
    });

    testWidgets('Me saves water, weight, and vital records from real forms', (
      tester,
    ) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('mom-add-record-water-intake')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-water-amount')),
        '300',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies.last, containsPair('amount_ml', 300.0));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mom-add-record-weight')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-maternal-weight')),
        '62.5',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies.last, containsPair('weight_kg', 62.5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mom-add-record-vitals')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-vital-systolic')),
        '118',
      );
      await tester.enterText(
        find.byKey(const ValueKey('record-vital-diastolic')),
        '76',
      );
      await tester.enterText(
        find.byKey(const ValueKey('record-vital-heart-rate')),
        '72',
      );
      await tester.enterText(
        find.byKey(const ValueKey('record-vital-temperature')),
        '36.7',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies.last, containsPair('systolic_mmhg', 118));
      expect(transport.postedBodies.last, containsPair('diastolic_mmhg', 76));
      expect(transport.postedBodies.last, containsPair('heart_rate_bpm', 72));
      expect(transport.postedBodies.last, containsPair('temperature_c', 36.7));
    });

    testWidgets('Me exposes maternal sleep as a disabled future capability', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();

      final sleep = find.byKey(const ValueKey('mom-add-record-sleep'));
      expect(tester.widget<Semantics>(sleep).properties.enabled, isFalse);
      expect(
        find.descendant(of: sleep, matching: find.text('Coming soon')),
        findsOneWidget,
      );

      await tester.tap(sleep);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mom-add-record-sheet')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('record-sleep-duration')), findsNothing);
    });

    testWidgets('Baby saves feeding records in the current infant scope', (
      tester,
    ) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-add-record-feeding')));
      await tester.pumpAndSettle();
      expect(find.text('Add baby record'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('record-feeding-breast_milk-amount')),
        '75',
      );
      await tester.tap(
        find.byKey(const ValueKey('record-feeding-source-formula')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-feeding-formula-amount')),
        '25.5',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();

      expect(transport.postedBodies.last, {
        'infant_id': 'profile-overview-baby',
        'feed_time': '2026-07-03T00:00:00.000Z',
        'feeding_method': 'bottle',
        'milk_components': [
          {'milk_source': 'breast_milk', 'volume_ml': 75.0},
          {'milk_source': 'formula', 'volume_ml': 25.5},
        ],
      });
    });

    testWidgets('Baby saves duration-only direct breastfeeding honestly', (
      tester,
    ) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-add-record-feeding')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record-feeding-method')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Direct breastfeeding').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-feeding-duration')),
        '15',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();

      expect(transport.postedBodies.last, {
        'infant_id': 'profile-overview-baby',
        'feed_time': '2026-07-03T00:00:00.000Z',
        'feeding_method': 'direct_breastfeeding',
        'milk_components': [
          {'milk_source': 'breast_milk', 'volume_ml': null},
        ],
        'duration_seconds': 900,
      });
    });

    testWidgets('Baby renders and saves confirmed sleep and diaper records', (
      tester,
    ) async {
      final transport = _profileOverviewTransport(
        sleepItems: const [
          {
            'id': 'sleep-1',
            'infant_id': 'profile-overview-baby',
            'started_at': '2026-07-03T01:00:00Z',
            'ended_at': '2026-07-03T02:30:00Z',
            'sleep_kind': 'nap',
          },
        ],
        diaperItems: const [
          {
            'id': 'diaper-1',
            'infant_id': 'profile-overview-baby',
            'changed_at': '2026-07-03T03:00:00Z',
            'diaper_kind': 'both',
            'wetness': 'medium',
            'stool_color': 'gold',
            'stool_consistency': 'soft',
            'notes': '',
          },
        ],
      );
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );

      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();
      expect(find.text('1 h 30 min'), findsOneWidget);
      expect(find.text('1 nap'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
      await tester.pumpAndSettle();
      expect(find.text('1 change'), findsOneWidget);
      expect(find.text('1 Wet'), findsOneWidget);
      expect(find.text('1 Dirty'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('baby-detail-back-diaper')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-add-record-sleep')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record-sleep-duration')),
        '45',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies.last, {
        'infant_id': 'profile-overview-baby',
        'started_at': '2026-07-02T23:15:00.000Z',
        'ended_at': '2026-07-03T00:00:00.000Z',
        'sleep_kind': 'nap',
        'source': 'manual',
      });

      await _pumpApp(
        tester,
        initialLocation: '/baby',
        runtime: _runtime(transport: transport),
      );
      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-add-record-diaper')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies.last, {
        'infant_id': 'profile-overview-baby',
        'changed_at': '2026-07-03T00:00:00.000Z',
        'diaper_kind': 'wet',
        'wetness': 'medium',
        'notes': '',
        'source': 'manual',
      });
    });

    testWidgets('Me device entry opens the real device flow', (tester) async {
      await _pumpApp(tester, initialLocation: '/me');

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-connect-device')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/device')), findsOneWidget);
    });

    testWidgets('Baby monitor opens the real device flow', (tester) async {
      await _pumpApp(tester, initialLocation: '/baby');

      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-connect-camera')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-page-/device')), findsOneWidget);
    });

    testWidgets('Recovery opens the honest Body Profile state', (tester) async {
      await _pumpApp(tester, initialLocation: '/me');
      await tester.tap(find.byKey(const ValueKey('me-section-recovery')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Profile'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('route-page-/more/body-profile')),
        findsOneWidget,
      );
      expect(find.text('No body profile data yet'), findsOneWidget);
    });

    testWidgets('Stage hero Body Profile does not trigger avatar mode', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      await tester.tap(find.byKey(const ValueKey('me-stage-body-profile')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('route-page-/more/body-profile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('me-baby-overview-avatar-expanded')),
        findsNothing,
      );
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
      final expandedImage = tester.widget<Image>(
        find.byKey(const ValueKey('baby-avatar-expanded-image')),
      );
      expect(
        (expandedImage.image as AssetImage).assetName,
        endsWith('baby_avatar_full.png'),
      );
      expect(
        find.byKey(const ValueKey('baby-avatar-without-baked-name')),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('baby-avatar-handle'))),
        const Rect.fromLTWH(195, 701, 40, 4),
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('baby-avatar-monitor-preview')),
        ),
        const Rect.fromLTWH(16, 762, 398, 210),
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('me-baby-overview-add-record')),
        ),
        const Rect.fromLTWH(350, 772, 56, 56),
      );
    });

    testWidgets('Baby avatar mode has explicit enter and exit controls', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

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

    testWidgets('Me and Baby remain stable at 360, 390, and 430 widths', (
      tester,
    ) async {
      for (final width in const [360.0, 390.0, 430.0]) {
        for (final route in const ['/me', '/baby']) {
          await _pumpApp(
            tester,
            initialLocation: route,
            viewportSize: Size(width, 860),
          );
          expect(
            find.byKey(const ValueKey('me-baby-overview-add-record')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets(
      'profile controls preserve 200 percent text without scaling it down',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpApp(
          tester,
          initialLocation: '/me',
          viewportSize: const Size(360, 860),
        );

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('me-current-stage-selector')),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('me-section-lactation')),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        await _pumpApp(
          tester,
          initialLocation: '/baby',
          viewportSize: const Size(360, 860),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('baby-section-feeding')),
        );
        await tester.tap(find.byKey(const ValueKey('baby-section-feeding')));
        await tester.pumpAndSettle();
        expect(find.text('Today’s Feeds'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Me matches the approved first-screen visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('../../goldens/me_baby_overview/me_first_screen.png'),
      );
    });

    testWidgets('Me recovery matches the honest visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/me');
      await tester.tap(find.byKey(const ValueKey('me-section-recovery')));
      await tester.pumpAndSettle();

      expect(find.text('Recovery Score'), findsOneWidget);
      expect(find.text('Not scored'), findsOneWidget);
      expect(find.text('Recovery data unavailable'), findsOneWidget);
      expect(find.text('78'), findsNothing);
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/me_recovery_screen.png',
        ),
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

    testWidgets('Baby first screen matches its narrow visual baseline', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(360, 800),
      );

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/narrow_360x800/baby_first_screen.png',
        ),
      );
    });

    testWidgets('Baby sleep landing matches its visual baseline', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');
      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/baby_sleep_screen.png',
        ),
      );
    });

    testWidgets('Baby feeding detail matches its visual baseline', (
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
          '../../goldens/me_baby_overview/baby_feeding_detail.png',
        ),
      );
    });

    testWidgets('Baby diaper detail matches its visual baseline', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 963),
      );
      await tester.tap(find.byKey(const ValueKey('baby-section-diaper')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/baby_diaper_detail.png',
        ),
      );
    });

    testWidgets('Baby sleep detail matches its visual baseline', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 875),
      );
      await tester.tap(find.byKey(const ValueKey('baby-section-sleep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('baby-sleep-summary-card')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/baby_sleep_detail.png',
        ),
      );
    });

    for (final detail in const [
      ('weight', 'baby_weight_detail.png'),
      ('height', 'baby_height_detail.png'),
      ('head-circumference', 'baby_head_circ_detail.png'),
    ]) {
      testWidgets('Baby ${detail.$1} detail matches its visual baseline', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          initialLocation: '/baby',
          viewportSize: const Size(390, 844),
        );
        await _openGrowthDetail(tester, detail.$1);

        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile('../../goldens/me_baby_overview/${detail.$2}'),
        );
      });
    }

    testWidgets('Baby add record sheet matches its visual baseline', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/baby',
        viewportSize: const Size(390, 844),
      );
      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/baby_add_record_sheet.png',
        ),
      );
    });

    testWidgets('Me add record sheet matches its visual baseline', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/me',
        viewportSize: const Size(390, 844),
      );
      await tester.tap(
        find.byKey(const ValueKey('me-baby-overview-add-record')),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile(
          '../../goldens/me_baby_overview/me_add_record_sheet.png',
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
        find.byType(Overlay).first,
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
  double textScaleFactor = 1,
  FakeViewPadding viewPadding = FakeViewPadding.zero,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = viewPadding;
  tester.view.viewPadding = viewPadding;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
        const AssetImage('assets/images/me_baby_overview/pregnancy_avatar.png'),
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
      for (final asset in const [
        'assets/images/me_baby_overview/milk_bottle.png',
        'assets/images/me_baby_overview/breast.png',
        'assets/images/me_baby_overview/lactation.png',
        'assets/images/me_baby_overview/body_assessment.png',
        'assets/images/me_baby_overview/yoga.png',
      ])
        precacheImage(AssetImage(asset), imageContext),
      precacheImage(
        const AssetImage(
          'assets/images/me_baby_overview/nursery_camera_clean.png',
        ),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/baby_development.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage(
          'assets/images/me_baby_overview/prenatal_education.png',
        ),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/sleep_training.png'),
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

MomCozyApiRuntime _runtime({
  ApiJsonTransport? transport,
  ProfileOverviewCache? profileOverviewCache,
}) {
  return MomCozyApiRuntime(
    jsonTransport: transport ?? _profileOverviewTransport(),
    userId: 'profile-overview-user',
    babyId: 'profile-overview-baby',
    locale: 'en-US',
    now: () => DateTime.utc(2026, 7, 3),
    timezoneProvider: () async => 'UTC',
    profileOverviewCache: profileOverviewCache,
  );
}

class _FailingRefreshTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  _FailingRefreshTransport(this.delegate);

  final FixtureApiJsonTransportByPath delegate;
  bool failMilkReads = false;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    if (failMilkReads && path == milkTrendsEndpoint) {
      throw const ApiRequestTimeoutException();
    }
    return delegate.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => delegate.postJson(path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => delegate.putJson(path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => delegate.patchJson(path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => delegate.deleteJson(path, headers: headers);
}

Map<String, Object?> _feedingSummaryFixture({
  required int feedingCount,
  required double measuredVolumeMl,
}) => {
  'days': 7,
  'timezone': 'UTC',
  'feeding_count': feedingCount,
  'measured_volume_count': measuredVolumeMl > 0 ? feedingCount : 0,
  'measured_volume_ml': measuredVolumeMl,
  'average_measured_volume_ml': feedingCount == 0
      ? null
      : measuredVolumeMl / feedingCount,
  'feeding_method_counts': {if (feedingCount > 0) 'bottle': feedingCount},
  'milk_source_volumes_ml': {
    if (measuredVolumeMl > 0) 'breast_milk': measuredVolumeMl,
  },
  'latest_feeding_at': feedingCount == 0 ? null : '2026-07-03T10:00:00Z',
  'completed_days': {
    'window_days': 6,
    'recorded_days': feedingCount > 0 ? 1 : 0,
    'measured_days': measuredVolumeMl > 0 ? 1 : 0,
    'average_volume_per_measured_day_ml': measuredVolumeMl > 0
        ? measuredVolumeMl
        : null,
    'average_feedings_per_recorded_day': feedingCount > 0
        ? feedingCount.toDouble()
        : null,
    'daily_series': [
      {
        'date': '2026-06-27',
        'measured_volume_ml': null,
        'feeding_count': 0,
        'measured_feeding_count': 0,
      },
      {
        'date': '2026-06-28',
        'measured_volume_ml': null,
        'feeding_count': 0,
        'measured_feeding_count': 0,
      },
      {
        'date': '2026-06-29',
        'measured_volume_ml': null,
        'feeding_count': 0,
        'measured_feeding_count': 0,
      },
      {
        'date': '2026-06-30',
        'measured_volume_ml': null,
        'feeding_count': 0,
        'measured_feeding_count': 0,
      },
      {
        'date': '2026-07-01',
        'measured_volume_ml': measuredVolumeMl > 0 ? measuredVolumeMl : null,
        'feeding_count': feedingCount,
        'measured_feeding_count': measuredVolumeMl > 0 ? feedingCount : 0,
      },
      {
        'date': '2026-07-02',
        'measured_volume_ml': null,
        'feeding_count': 0,
        'measured_feeding_count': 0,
      },
    ],
  },
  'comparison': {
    'status': 'insufficient_data',
    'current_average_volume_per_measured_day_ml': measuredVolumeMl > 0
        ? measuredVolumeMl
        : null,
    'previous_average_volume_per_measured_day_ml': null,
    'change_percent': null,
    'current_measured_days': measuredVolumeMl > 0 ? 1 : 0,
    'previous_measured_days': 0,
    'minimum_measured_days': 5,
  },
  'intake_evaluation_context': {
    'status': 'insufficient_data',
    'reason_code': 'growth_record_missing',
    'growth_measurement_date': null,
    'chronological_age_days': null,
  },
};

FixtureApiJsonTransportByPath _profileOverviewTransport({
  Map<String, Object?>? writeResponse,
  Map<String, Object?>? profileResponse,
  List<Map<String, Object?>>? milkTrendItems,
  List<Map<String, Object?>>? infantItems,
  String? pregnancyFactValue,
  List<Map<String, Object?>>? planItems,
  List<Map<String, Object?>>? planSessionItems,
  Map<String, Object?>? careOverviewResponse,
  List<Map<String, Object?>>? feedingItems,
  Map<String, Object?>? feedingSummaryResponse,
  List<Map<String, Object?>>? sleepItems,
  List<Map<String, Object?>>? diaperItems,
}) {
  return FixtureApiJsonTransportByPath(
    {
      profileMeEndpoint:
          profileResponse ??
          const {
            'user_id': 'profile-overview-user',
            'display_name': 'Avery',
            'current_care_stage': 'postpartum',
            'actual_delivery_date': '2026-06-12',
          },
      profileInfantsEndpoint: {
        'items':
            infantItems ??
            const [
              {
                'id': 'profile-overview-baby',
                'infant_name': 'Mia',
                'birth_date': '2026-04-06',
              },
            ],
      },
      profilePregnancyFactEndpoint: {
        'items': [
          if (pregnancyFactValue != null)
            {
              'fact_key': pregnancyDueDateOrWeekFactKey,
              'fact_kind': 'verified',
              'status': 'active',
              'value': pregnancyFactValue,
            },
        ],
      },
      milkTrendsEndpoint: {
        'items':
            milkTrendItems ??
            const [
              {
                'date': '2026-07-03',
                'measured_volume_ml': 210,
                'pumping_count': 3,
                'measured_pumping_count': 3,
              },
            ],
      },
      feedingRecordsEndpoint: {
        'items':
            feedingItems ??
            const [
              {
                'id': 'feed-1',
                'infant_id': 'profile-overview-baby',
                'feeding_method': 'bottle',
                'milk_components': [
                  {'milk_source': 'breast_milk', 'volume_ml': 80},
                ],
                'feed_time': '2026-07-03T06:00:00Z',
              },
              {
                'id': 'feed-2',
                'infant_id': 'profile-overview-baby',
                'feeding_method': 'bottle',
                'milk_components': [
                  {'milk_source': 'formula', 'volume_ml': 40},
                ],
                'feed_time': '2026-07-03T10:00:00Z',
              },
              {
                'id': 'feed-previous',
                'infant_id': 'profile-overview-baby',
                'feeding_method': 'bottle',
                'milk_components': [
                  {'milk_source': 'breast_milk', 'volume_ml': 80},
                ],
                'feed_time': '2026-07-01T10:00:00Z',
              },
            ],
      },
      feedingSummaryEndpoint:
          feedingSummaryResponse ??
          _feedingSummaryFixture(feedingCount: 3, measuredVolumeMl: 200),
      sleepRecordsEndpoint: {
        'items':
            sleepItems ??
            const [
              {
                'id': 'sleep-night',
                'infant_id': 'profile-overview-baby',
                'started_at': '2026-07-03T00:00:00Z',
                'ended_at': '2026-07-03T02:00:00Z',
                'sleep_kind': 'night',
                'notes': '',
              },
              {
                'id': 'sleep-nap',
                'infant_id': 'profile-overview-baby',
                'started_at': '2026-07-03T13:00:00Z',
                'ended_at': '2026-07-03T14:00:00Z',
                'sleep_kind': 'nap',
                'notes': '',
              },
            ],
      },
      diaperRecordsEndpoint: {
        'items':
            diaperItems ??
            const [
              {
                'id': 'diaper-wet',
                'infant_id': 'profile-overview-baby',
                'changed_at': '2026-07-03T09:00:00Z',
                'diaper_kind': 'wet',
                'notes': '',
              },
              {
                'id': 'diaper-mixed',
                'infant_id': 'profile-overview-baby',
                'changed_at': '2026-07-03T12:00:00Z',
                'diaper_kind': 'both',
                'notes': '',
              },
              {
                'id': 'diaper-previous',
                'infant_id': 'profile-overview-baby',
                'changed_at': '2026-07-01T12:00:00Z',
                'diaper_kind': 'dirty',
                'notes': '',
              },
            ],
      },
      notificationsEndpoint: const {
        'items': [
          {
            'id': 'notification-1',
            'notification_type': 'feeding_due',
            'title': 'Feeding reminder',
            'body': 'Bottle is due',
            'status': 'unread',
            'source': 'system',
            'payload': <String, Object?>{},
            'created_at': '2026-07-03T08:00:00Z',
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
            'measurement_position': 'recumbent',
            'measurement_context': 'routine',
          },
          {
            'id': 'growth-2',
            'weight_kg': 5.8,
            'height_cm': 62.5,
            'head_cm': 41,
            'measured_at': '2026-06-03T12:00:00Z',
            'measurement_position': 'recumbent',
            'measurement_context': 'routine',
          },
          {
            'id': 'growth-3',
            'weight_kg': 5.2,
            'height_cm': 59.5,
            'head_cm': 39.5,
            'measured_at': '2026-05-03T12:00:00Z',
            'measurement_position': 'recumbent',
            'measurement_context': 'routine',
          },
          {
            'id': 'growth-4',
            'weight_kg': 4.4,
            'height_cm': 53,
            'head_cm': 36,
            'measured_at': '2026-04-06T12:00:00Z',
            'measurement_position': 'recumbent',
            'measurement_context': 'birth',
          },
        ],
      },
      planListEndpoint: {'items': planItems ?? const <Object?>[]},
      planSessionListEndpoint: {'items': planSessionItems ?? const <Object?>[]},
      maternalCareOverviewEndpoint:
          careOverviewResponse ?? const <String, Object?>{},
    },
    writeResponsesByPath: {
      profileMeEndpoint: ?writeResponse,
      '$growthRecordsEndpoint/growth-1': const {
        'id': 'growth-1',
        'weight_kg': 6.4,
        'height_cm': 64.5,
        'head_cm': 42,
        'measured_at': '2026-07-03T12:00:00Z',
        'measurement_position': 'recumbent',
        'measurement_context': 'routine',
      },
      feedingRecordsEndpoint: const {
        'id': 'feeding-created',
        'infant_id': 'profile-overview-baby',
        'feed_time': '2026-07-03T00:00:00Z',
        'feeding_method': 'bottle',
        'milk_components': [
          {'milk_source': 'breast_milk', 'volume_ml': 75},
        ],
        'duration_seconds': null,
      },
      pumpMilkRecordsEndpoint: const {
        'id': 'pumping-created',
        'pump_start_time': '2026-07-03T00:00:00Z',
        'outputs': [
          {'breast_side': 'left', 'volume_ml': 95},
        ],
        'pump_type': 'manual',
        'duration_seconds': null,
      },
      growthRecordsEndpoint: const {
        'id': 'growth-created',
        'infant_id': 'profile-overview-baby',
        'weight_kg': 6.4,
        'height_cm': null,
        'head_cm': null,
        'measured_at': '2026-07-03T00:00:00Z',
        'measurement_position': 'recumbent',
        'measurement_context': 'routine',
      },
      sleepRecordsEndpoint: const {
        'id': 'sleep-created',
        'infant_id': 'profile-overview-baby',
        'started_at': '2026-07-02T23:15:00Z',
        'ended_at': '2026-07-03T00:00:00Z',
        'sleep_kind': 'nap',
      },
      diaperRecordsEndpoint: const {
        'id': 'diaper-created',
        'infant_id': 'profile-overview-baby',
        'changed_at': '2026-07-03T00:00:00Z',
        'diaper_kind': 'wet',
        'wetness': 'medium',
        'notes': '',
      },
    },
  );
}

Future<void> _openGrowthDetail(WidgetTester tester, String detailId) async {
  await tester.tap(find.byKey(const ValueKey('me-baby-overview-add-record')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('baby-add-record-$detailId')));
  await tester.pumpAndSettle();
  expect(find.byKey(ValueKey('baby-growth-editor-$detailId')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('baby-growth-editor-close')));
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _emptyRuntime() {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      profileMeEndpoint: const {'user_id': 'profile-overview-user'},
      profileInfantsEndpoint: const {'items': <Object>[]},
      milkTrendsEndpoint: const {'items': <Object>[]},
      feedingRecordsEndpoint: const {'items': <Object>[]},
      feedingSummaryEndpoint: _feedingSummaryFixture(
        feedingCount: 0,
        measuredVolumeMl: 0,
      ),
      growthRecordsEndpoint: const {'items': <Object>[]},
      sleepRecordsEndpoint: const {'items': <Object>[]},
      diaperRecordsEndpoint: const {'items': <Object>[]},
      planListEndpoint: const {'items': <Object>[]},
      planSessionListEndpoint: const {'items': <Object>[]},
    }),
    userId: 'profile-overview-user',
    babyId: 'profile-overview-baby',
    locale: 'en-US',
    now: () => DateTime.utc(2026, 7, 3),
    timezoneProvider: () async => 'UTC',
  );
}
