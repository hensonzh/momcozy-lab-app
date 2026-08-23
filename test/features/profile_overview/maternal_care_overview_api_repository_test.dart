import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/maternal_care_overview_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('MaternalCareOverviewApiRepository', () {
    test('maps postpartum program progress and query date', () async {
      final transport = FixtureApiJsonTransportByPath({
        maternalCareOverviewEndpoint: const {
          // Retired server fields may still arrive, but are ignored.
          'stage': 'pregnancy',
          'pregnancy': {'state': 'ready', 'gestational_week': 28},
          'program': {
            'plan_id': 'plan-recovery',
            'title': 'Postpartum Recovery',
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
      expect(overview.program?.planId, 'plan-recovery');
      expect(overview.program?.title, 'Postpartum Recovery');
      expect(overview.program?.completedSessions, 6);
      expect(overview.program?.totalSessions, 12);
    });

    test('maps an absent program to null', () async {
      final repository = MaternalCareOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          maternalCareOverviewEndpoint: const {},
        }),
      );

      final overview = await repository.fetchOverview(
        onDate: DateTime(2026, 8, 8),
      );

      expect(overview.program, isNull);
    });

    test('rejects invalid program progress', () async {
      final repository = MaternalCareOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          maternalCareOverviewEndpoint: const {
            'program': {
              'plan_id': 'plan-recovery',
              'title': 'Postpartum Recovery',
              'completed_sessions': 13,
              'total_sessions': 12,
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
