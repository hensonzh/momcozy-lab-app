import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/maternal_care_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('MaternalCareOverviewApiRepository', () {
    test('maps authoritative pregnancy and program progress', () async {
      final transport = FixtureApiJsonTransportByPath({
        maternalCareOverviewEndpoint: const {
          'stage': 'pregnancy',
          'pregnancy': {
            'state': 'ready',
            'expected_due_date': '2026-10-31',
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
          'capabilities': {
            'pregnancy_progress': 'available',
            'program_progress': 'available',
            'cycle_tracking': 'unavailable',
            'body_profile': 'unavailable',
            'water_records': 'unavailable',
            'vital_records': 'unavailable',
          },
          'generated_at': '2026-08-08T01:00:00Z',
        },
      });
      final repository = MaternalCareOverviewApiRepository(
        transport: transport,
      );

      final overview = await repository.fetchOverview(
        onDate: DateTime(2026, 8, 8),
      );

      expect(transport.lastPath, maternalCareOverviewEndpoint);
      expect(transport.lastQuery, {'date': '2026-08-08'});
      expect(overview.stage, MomLifeStage.pregnancy);
      expect(overview.pregnancy?.state, PregnancyProgressState.ready);
      expect(overview.pregnancy?.expectedDueDate, DateTime(2026, 10, 31));
      expect(overview.pregnancy?.gestationalWeek, 28);
      expect(overview.pregnancy?.gestationalDay, 0);
      expect(overview.pregnancy?.daysRemaining, 84);
      expect(overview.pregnancy?.trimester, PregnancyTrimester.third);
      expect(overview.program?.planId, 'plan-prenatal');
      expect(overview.program?.completedSessions, 6);
      expect(overview.program?.totalSessions, 12);
      expect(overview.capabilities.bodyProfile, CapabilityState.unavailable);
    });

    test(
      'keeps missing due date explicit instead of parsing legacy text',
      () async {
        final repository = MaternalCareOverviewApiRepository(
          transport: FixtureApiJsonTransportByPath({
            maternalCareOverviewEndpoint: const {
              'stage': 'pregnancy',
              'pregnancy': {'state': 'missing_due_date'},
            },
          }),
        );

        final overview = await repository.fetchOverview(
          onDate: DateTime(2026, 8, 8),
        );

        expect(
          overview.pregnancy?.state,
          PregnancyProgressState.missingDueDate,
        );
        expect(overview.pregnancy?.gestationalWeek, isNull);
      },
    );

    test('rejects an incomplete ready pregnancy response', () async {
      final repository = MaternalCareOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          maternalCareOverviewEndpoint: const {
            'stage': 'pregnancy',
            'pregnancy': {
              'state': 'ready',
              'expected_due_date': '2026-10-31',
              'gestational_week': 28,
            },
          },
        }),
      );

      await expectLater(
        repository.fetchOverview(onDate: DateTime(2026, 8, 8)),
        throwsFormatException,
      );
    });
  });
}
