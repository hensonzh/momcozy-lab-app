import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('RecordsApiRepository', () {
    test('maps production feeding records and request contract', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'feeding-001',
            'feed_type': 'bottle',
            'volume_ml': 80.0,
            'feed_time': '2026-06-29T08:00:00Z',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchFeedingRecords(
        userId: 'ignored-user-authority',
        date: DateTime.utc(2026, 6, 29),
      );

      expect(transport.lastPath, feedingRecordsEndpoint);
      expect(transport.lastQuery, {
        'start_at': '2026-06-29T00:00:00.000Z',
        'end_at': '2026-06-30T00:00:00.000Z',
        'limit': 50,
      });
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(records.single.id, 'feeding-001');
      expect(records.single.type, 'bottle');
      expect(records.single.amountMl, 80);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:00:00Z'));
    });

    test('maps production pumping records and request contract', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'pump-001',
            'title': 'Morning pump',
            'pump_type': 'electric',
            'source': 'manual',
            'milk_volume_ml': 120.0,
            'pump_start_time': '2026-06-29T08:40:00Z',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchPumpMilkRecords(
        userId: 'ignored-user-authority',
        date: DateTime.utc(2026, 6, 29),
      );

      expect(transport.lastPath, pumpMilkRecordsEndpoint);
      expect(transport.lastQuery, {
        'start_at': '2026-06-29T00:00:00.000Z',
        'end_at': '2026-06-30T00:00:00.000Z',
        'limit': 50,
      });
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(records.single.id, 'pump-001');
      expect(records.single.title, 'Morning pump');
      expect(records.single.pumpType, isNull);
      expect(records.single.pumpSource, isNull);
      expect(records.single.amountMl, 120);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:40:00Z'));
    });

    test('maps production growth records and owner-scoped query', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'growth-001',
            'weight_kg': 4.2,
            'height_cm': 54.5,
            'measured_at': '2026-06-29T00:00:00Z',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchGrowthRecords(
        userId: 'ignored-user-authority',
        babyId: 'infant-fixture',
      );

      expect(transport.lastPath, growthRecordsEndpoint);
      expect(transport.lastQuery, {'infant_id': 'infant-fixture', 'limit': 50});
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(records.single.id, 'growth-001');
      expect(records.single.weightGram, 4200);
      expect(records.single.heightCm, 54.5);
      expect(records.single.measuredAt, DateTime.parse('2026-06-29T00:00:00Z'));
    });

    test('maps empty production lists', () async {
      final repository = RecordsApiRepository(
        transport: FixtureApiJsonTransport({'items': []}),
      );

      final feeding = await repository.fetchFeedingRecords(
        userId: 'ignored-user-authority',
        date: DateTime.utc(2026, 6, 29),
      );
      final pumping = await repository.fetchPumpMilkRecords(
        userId: 'ignored-user-authority',
        date: DateTime.utc(2026, 6, 29),
      );
      final growth = await repository.fetchGrowthRecords(
        userId: 'ignored-user-authority',
        babyId: 'infant-fixture',
      );

      expect(feeding, isEmpty);
      expect(pumping, isEmpty);
      expect(growth, isEmpty);
    });

    test('preserves production HTTP failures', () async {
      final repository = RecordsApiRepository(
        transport: FixtureApiJsonTransport({
          'http_status': 503,
          'status_text': 'Service Unavailable',
          'body': {
            'error': {
              'code': 'dependency_failed',
              'message': 'Records temporarily unavailable',
              'request_id': 'req-records-001',
            },
          },
        }),
      );

      await expectLater(
        repository.fetchFeedingRecords(
          userId: 'ignored-user-authority',
          date: DateTime.utc(2026, 6, 29),
        ),
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
