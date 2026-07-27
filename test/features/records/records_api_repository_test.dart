import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/records/data/records_api_repository.dart';

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

    test('uses local calendar boundaries for a feeding day', () async {
      final transport = FixtureApiJsonTransport({'items': []});
      final repository = RecordsApiRepository(transport: transport);
      final localDay = DateTime(2026, 7, 11);

      await repository.fetchFeedingRecords(date: localDay);

      expect(transport.lastQuery, {
        'start_at': DateTime(2026, 7, 11).toUtc().toIso8601String(),
        'end_at': DateTime(2026, 7, 12).toUtc().toIso8601String(),
        'limit': 50,
      });
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

    test('queries pumping records across a bounded trend range', () async {
      final transport = FixtureApiJsonTransport({'items': []});
      final repository = RecordsApiRepository(transport: transport);

      await repository.fetchPumpMilkRecordsRange(
        start: DateTime.utc(2026, 6, 1),
        end: DateTime.utc(2026, 7, 1),
      );

      expect(transport.lastQuery, {
        'start_at': '2026-06-01T00:00:00.000Z',
        'end_at': '2026-07-01T00:00:00.000Z',
        'limit': 100,
      });
    });

    test('maps measured milk trends and optional legacy analytics', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'date': '2026-07-01',
            'pumped_milk_volume_ml': 180.5,
            'pumping_count': 2,
            'measured_only': true,
          },
          {
            'delivery_date': '2026-07-02',
            'total_milk': '210',
            'pump_count': '3',
            'total_milk_estimate': '260',
            'reference_lower': '200',
            'reference_upper': 320,
            'measured_only': false,
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final trends = await repository.fetchMilkTrends(
        startDate: DateTime(2026, 6, 2),
        days: 31,
      );

      expect(transport.lastPath, milkTrendsEndpoint);
      expect(transport.lastQuery, {
        'start_date': '2026-06-02',
        'days': 31,
        'include_today': true,
      });
      expect(trends.first.pumpedMilkVolumeMl, 180.5);
      expect(trends.first.pumpingCount, 2);
      expect(trends.first.measuredOnly, isTrue);
      expect(trends.last.pumpedMilkVolumeMl, 210);
      expect(trends.last.pumpingCount, 3);
      expect(trends.last.estimatedMilkVolumeMl, 260);
      expect(trends.last.referenceLowerMl, 200);
      expect(trends.last.referenceUpperMl, 320);
      expect(trends.last.measuredOnly, isFalse);
    });

    test('maps production growth records and owner-scoped query', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'growth-001',
            'weight_kg': 4.2,
            'height_cm': 54.5,
            'head_cm': 36.2,
            'measured_at': '2026-06-29T00:00:00Z',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchGrowthRecords(
        babyId: 'infant-fixture',
      );

      expect(transport.lastPath, growthRecordsEndpoint);
      expect(transport.lastQuery, {'infant_id': 'infant-fixture', 'limit': 50});
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(records.single.id, 'growth-001');
      expect(records.single.weightGram, 4200);
      expect(records.single.heightCm, 54.5);
      expect(records.single.headCm, 36.2);
      expect(records.single.measuredAt, DateTime.parse('2026-06-29T00:00:00Z'));
    });

    test('creates and updates production growth records', () async {
      final transport = FixtureApiJsonTransport({
        'id': 'growth-001',
        'infant_id': 'infant-fixture',
        'weight_kg': 4.3,
        'height_cm': 55.0,
        'head_cm': 36.5,
        'measured_at': '2026-07-11T08:00:00Z',
        'status': 'active',
      });
      final repository = RecordsApiRepository(transport: transport);

      final created = await repository.createGrowthRecord(
        babyId: 'infant-fixture',
        measuredAt: DateTime.parse('2026-07-11T08:00:00Z'),
        weightKg: 4.3,
        heightCm: 55,
        headCm: 36.5,
        idempotencyKey: 'growth-create-001',
      );

      expect(transport.lastMethod, 'POST');
      expect(transport.lastPath, growthRecordsEndpoint);
      expect(transport.lastHeaders, {'Idempotency-Key': 'growth-create-001'});
      expect(transport.lastBody, {
        'infant_id': 'infant-fixture',
        'measured_at': '2026-07-11T08:00:00.000Z',
        'weight_kg': 4.3,
        'height_cm': 55.0,
        'head_cm': 36.5,
      });
      expect(created.headCm, 36.5);

      final updated = await repository.updateGrowthRecord(
        recordId: 'growth-001',
        weightKg: 4.3,
        heightCm: 55,
        headCm: 36.5,
      );

      expect(transport.lastMethod, 'PATCH');
      expect(transport.lastPath, '$growthRecordsEndpoint/growth-001');
      expect(transport.lastBody, {
        'weight_kg': 4.3,
        'height_cm': 55.0,
        'head_cm': 36.5,
      });
      expect(updated.weightKg, 4.3);
    });

    test('maps empty production lists', () async {
      final repository = RecordsApiRepository(
        transport: FixtureApiJsonTransport({'items': []}),
      );

      final feeding = await repository.fetchFeedingRecords(
        date: DateTime.utc(2026, 6, 29),
      );
      final pumping = await repository.fetchPumpMilkRecords(
        date: DateTime.utc(2026, 6, 29),
      );
      final growth = await repository.fetchGrowthRecords(
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
        repository.fetchFeedingRecords(date: DateTime.utc(2026, 6, 29)),
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
