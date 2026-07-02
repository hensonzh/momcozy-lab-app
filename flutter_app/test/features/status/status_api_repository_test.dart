import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('StatusApiRepository', () {
    test('maps production profile and infant overview', () async {
      final transport = FixtureApiJsonTransportByPath({
        statusProfileEndpoint: {
          'user_id': 'user-001',
          'display_name': 'Mom',
          'delivery_date': '2026-05-20',
        },
        statusInfantsEndpoint: {
          'items': [
            {
              'id': 'infant-001',
              'owner_user_id': 'user-001',
              'infant_name': 'Baby',
              'birth_date': '2026-05-20',
              'sex': 'female',
              'status': 'active',
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
      expect(overview.baby?.nickname, 'Baby');
      expect(overview.baby?.ageDays, 42);
    });

    test('maps empty profile and infants list', () async {
      final repository = StatusApiRepository(
        transport: FixtureApiJsonTransportByPath({
          statusProfileEndpoint: const {'user_id': 'user-001'},
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
  });
}
