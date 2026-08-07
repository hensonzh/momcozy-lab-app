import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
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
        expect(find.byKey(const ValueKey('route-page-/more')), findsOneWidget);
        expect(find.text('Body Profile'), findsOneWidget);
        expect(find.text('设备与服务'), findsOneWidget);
        expect(find.text('账户与偏好'), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-more')), findsOneWidget);

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
      expect(
        find.byKey(const ValueKey('me-baby-overview-stage-dot')),
        findsNothing,
      );
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
      expect(find.text('Avery'), findsOneWidget);
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
                'pumped_milk_volume_ml': 190,
                'pumping_count': 2,
                'measured_only': true,
              },
            ],
          ),
        ),
      );

      expect(find.text('No milk recorded today'), findsOneWidget);
      expect(find.text('190'), findsNothing);
      expect(find.text('mL measured today'), findsNothing);
    });

    testWidgets('Me exposes an explicit refresh action', (tester) async {
      final transport = _profileOverviewTransport();
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport),
      );
      expect(
        transport.getPaths.where((path) => path == profileMeEndpoint).length,
        1,
      );

      await tester.tap(find.byKey(const ValueKey('me-baby-overview-refresh')));
      await tester.pumpAndSettle();

      expect(
        transport.getPaths.where((path) => path == profileMeEndpoint).length,
        2,
      );
    });

    testWidgets('Me keeps saved data visible when refresh fails', (
      tester,
    ) async {
      final transport = _FailingRefreshTransport(_profileOverviewTransport());
      await _pumpApp(
        tester,
        initialLocation: '/me',
        runtime: _runtime(transport: transport),
      );
      transport.failMilkReads = true;

      await tester.tap(find.byKey(const ValueKey('me-baby-overview-refresh')));
      await tester.pumpAndSettle();

      expect(
        find.text('Couldn’t refresh. Showing saved data.'),
        findsOneWidget,
      );
      expect(find.text('210'), findsOneWidget);
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
        find.byKey(const ValueKey('me-baby-overview-notification-disabled')),
        findsOneWidget,
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
        expect(find.text('No sleep data recorded today'), findsOneWidget);
        expect(find.text('Sleep Pattern Today'), findsOneWidget);
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
        expect(find.text('Weekly feeding data unavailable'), findsOneWidget);
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
        expect(find.text('No diaper data yet'), findsOneWidget);
        expect(find.text('0 changes'), findsOneWidget);
        expect(find.text('7 changes'), findsNothing);
      },
    );

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
      expect(find.text('— hours'), findsOneWidget);
      expect(find.text('No naps recorded'), findsOneWidget);
      expect(find.text('Weekly Pattern'), findsOneWidget);
      expect(find.text('10.2 hours'), findsNothing);
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

    testWidgets('Baby primary controls expose minimum 44px tap targets', (
      tester,
    ) async {
      await _pumpApp(tester, initialLocation: '/baby');

      for (final key in const [
        'baby-section-monitor',
        'baby-section-sleep',
        'baby-section-feeding',
        'baby-section-diaper',
        'me-baby-overview-notification-disabled',
        'me-baby-overview-connect-camera',
        'me-baby-overview-add-record',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
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

    testWidgets('avatar and record actions expose genuine capabilities', (
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
      expect(find.text('Add pumping record'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('record-pumping-amount')),
        '95',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();

      expect(find.text('Record saved'), findsOneWidget);
      expect(transport.postedBodies.last, containsPair('milk_volume_ml', 95.0));
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
        find.byKey(const ValueKey('record-feeding-amount')),
        '75',
      );
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pumpAndSettle();

      expect(transport.postedBodies.last, {
        'infant_id': 'profile-overview-baby',
        'feed_time': '2026-07-03T00:00:00.000Z',
        'feed_type': 'bottle',
        'volume_ml': 75.0,
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
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.endsWith(
                'baby_avatar_full.png',
              ),
        ),
        findsOneWidget,
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
  double textScaleFactor = 1,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        const AssetImage('assets/images/me_baby_overview/baby_avatar.png'),
        imageContext,
      ),
      precacheImage(
        const AssetImage('assets/images/me_baby_overview/nursery_camera.png'),
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

MomCozyApiRuntime _runtime({ApiJsonTransport? transport}) {
  return MomCozyApiRuntime(
    jsonTransport: transport ?? _profileOverviewTransport(),
    userId: 'profile-overview-user',
    babyId: 'profile-overview-baby',
    locale: 'en-US',
    now: () => DateTime.utc(2026, 7, 3),
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

FixtureApiJsonTransportByPath _profileOverviewTransport({
  Map<String, Object?>? writeResponse,
  Map<String, Object?>? profileResponse,
  List<Map<String, Object?>>? milkTrendItems,
}) {
  return FixtureApiJsonTransportByPath(
    {
      profileMeEndpoint:
          profileResponse ??
          const {
            'user_id': 'profile-overview-user',
            'display_name': 'Avery',
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
      milkTrendsEndpoint: {
        'items':
            milkTrendItems ??
            const [
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
          {
            'id': 'growth-2',
            'weight_kg': 5.8,
            'height_cm': 62.5,
            'head_cm': 41,
            'measured_at': '2026-06-03T12:00:00Z',
          },
          {
            'id': 'growth-3',
            'weight_kg': 5.2,
            'height_cm': 59.5,
            'head_cm': 39.5,
            'measured_at': '2026-05-03T12:00:00Z',
          },
          {
            'id': 'growth-4',
            'weight_kg': 4.4,
            'height_cm': 53,
            'head_cm': 36,
            'measured_at': '2026-04-06T12:00:00Z',
          },
        ],
      },
    },
    writeResponsesByPath: {
      profileMeEndpoint: ?writeResponse,
      '$growthRecordsEndpoint/growth-1': const {
        'id': 'growth-1',
        'weight_kg': 6.4,
        'height_cm': 64.5,
        'head_cm': 42,
        'measured_at': '2026-07-03T12:00:00Z',
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
      growthRecordsEndpoint: const {'items': <Object>[]},
    }),
    userId: 'profile-overview-user',
    babyId: 'profile-overview-baby',
    locale: 'en-US',
    now: () => DateTime.utc(2026, 7, 3),
  );
}
