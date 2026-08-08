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
            'gestational_week': 28,
            'days_remaining': 84,
            'trimester': 'third',
          },
          'program': {
            'plan_id': 'plan-prenatal',
            'title': 'Prenatal Yoga Program',
            'completed_sessions': 6,
            'total_sessions': 12,
          },
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
      expect(overview.pregnancy?.gestationalWeek, 28);
      expect(overview.pregnancy?.daysRemaining, 84);
      expect(overview.pregnancy?.trimester, PregnancyTrimester.third);
      expect(overview.program?.planId, 'plan-prenatal');
      expect(overview.program?.completedSessions, 6);
      expect(overview.program?.totalSessions, 12);
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
            'pregnancy': {'state': 'ready', 'gestational_week': 28},
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
