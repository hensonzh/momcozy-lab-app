import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('StatusApiRepository', () {
    test('maps production profile and infant overview', () async {
      final transport = FixtureApiJsonTransportByPath({
        statusProfileEndpoint: {
          'preferred_name': 'Mom',
          'age': 30,
          'estimated_due_date': '2026-05-20',
        },
        statusInfantsEndpoint: {
          'items': [
            {
              'id': 'infant-001',
              'name': 'Baby',
              'birth_date': '2026-05-20',
              'sex_at_birth': 'female',
            },
          ],
        },
      });
      final repository = StatusApiRepository(
        transport: transport,
        now: () => DateTime.utc(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(transport.postedBodies, isEmpty);
      expect(transport.lastPath, statusInfantsEndpoint);
      expect(transport.lastQuery, isEmpty);
      expect(overview.mom?.stage, '哺乳期');
      expect(overview.mom?.postpartumDay, 42);
      expect(overview.mom?.estimatedDueDate, DateTime.parse('2026-05-20'));
      expect(overview.baby?.id, 'infant-001');
      expect(overview.baby?.nickname, 'Baby');
      expect(overview.baby?.ageDays, 42);
      expect(overview.baby?.birthDate, DateTime.parse('2026-05-20'));
    });

    test('maps empty profile and infants list', () async {
      final repository = StatusApiRepository(
        transport: FixtureApiJsonTransportByPath({
          statusProfileEndpoint: const {
            'preferred_name': null,
            'age': null,
            'estimated_due_date': null,
          },
          statusInfantsEndpoint: const {'items': []},
        }),
        now: () => DateTime.utc(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom, isNull);
      expect(overview.baby, isNull);
    });

    test('preserves production HTTP failures', () async {
      final repository = StatusApiRepository(
        transport: FixtureApiJsonTransportByPath({
          statusProfileEndpoint: const {
            'http_status': 500,
            'status_text': 'Server Error',
            'body': {
              'error': {
                'code': 'dependency_failed',
                'message': 'Profile unavailable',
                'request_id': 'req-profile-001',
              },
            },
          },
        }),
      );

      await expectLater(
        repository.fetchOverview(),
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.errorCode,
            'errorCode',
            'dependency_failed',
          ),
        ),
      );
    });

    test(
      'uses the device calendar day instead of a UTC date boundary',
      () async {
        final repository = StatusApiRepository(
          transport: FixtureApiJsonTransportByPath({
            statusProfileEndpoint: const {
              'user_id': 'user-local-day',
              'estimated_due_date': '2026-06-30',
            },
            statusInfantsEndpoint: const {
              'items': [
                {'id': 'baby-local-day', 'birth_date': '2026-06-30'},
              ],
            },
          }),
          now: () => DateTime(2026, 7, 1, 0, 15),
        );

        final overview = await repository.fetchOverview();

        expect(overview.mom?.postpartumDay, 1);
        expect(overview.baby?.ageDays, 1);
      },
    );
  });
}
