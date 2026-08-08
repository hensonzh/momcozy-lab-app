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
            'infant_id': 'infant-fixture',
            'feed_type': 'bottle',
            'volume_ml': 80.0,
            'feed_time': '2026-06-29T08:00:00Z',
          },
          {
            'id': 'feeding-other',
            'infant_id': 'infant-other',
            'feed_type': 'formula',
            'volume_ml': 120.0,
            'feed_time': '2026-06-29T09:00:00Z',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchFeedingRecords(
        date: DateTime.utc(2026, 6, 29),
        babyId: 'infant-fixture',
      );

      expect(transport.lastPath, feedingRecordsEndpoint);
      expect(transport.lastQuery, {
        'start_at': '2026-06-29T00:00:00.000Z',
        'end_at': '2026-06-30T00:00:00.000Z',
        'infant_id': 'infant-fixture',
        'limit': 50,
      });
      expect(transport.lastQuery, isNot(containsPair('user_id', anything)));
      expect(records.single.id, 'feeding-001');
      expect(records.single.infantId, 'infant-fixture');
      expect(records.single.type, 'bottle');
      expect(records.single.amountMl, 80);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:00:00Z'));
    });

    test('uses local calendar boundaries for a feeding day', () async {
      final transport = FixtureApiJsonTransport({'items': []});
      final repository = RecordsApiRepository(transport: transport);
      final localDay = DateTime(2026, 7, 11);

      await repository.fetchFeedingRecords(
        date: localDay,
        babyId: 'infant-fixture',
      );

      expect(transport.lastQuery, {
        'start_at': DateTime(2026, 7, 11).toUtc().toIso8601String(),
        'end_at': DateTime(2026, 7, 12).toUtc().toIso8601String(),
        'infant_id': 'infant-fixture',
        'limit': 50,
      });
    });

    test('loads an infant-scoped feeding range for weekly views', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'feeding-001',
            'infant_id': 'infant-fixture',
            'feed_type': 'bottle',
            'volume_ml': 80,
            'feed_time': '2026-06-25T08:00:00Z',
          },
          {
            'id': 'feeding-other',
            'infant_id': 'infant-other',
            'feed_type': 'formula',
            'volume_ml': 120,
            'feed_time': '2026-06-26T09:00:00Z',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchFeedingRecordsRange(
        start: DateTime.utc(2026, 6, 23),
        end: DateTime.utc(2026, 6, 30),
        babyId: 'infant-fixture',
      );

      expect(transport.lastQuery, {
        'start_at': '2026-06-23T00:00:00.000Z',
        'end_at': '2026-06-30T00:00:00.000Z',
        'infant_id': 'infant-fixture',
        'limit': 100,
      });
      expect(records.map((record) => record.id), ['feeding-001']);
    });

    test('maps infant-scoped sleep and diaper ranges', () async {
      final sleepTransport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'sleep-001',
            'infant_id': 'infant-fixture',
            'started_at': '2026-06-29T01:00:00Z',
            'ended_at': '2026-06-29T03:00:00Z',
            'sleep_type': 'nap',
            'duration_seconds': 7200,
            'notes': '',
          },
        ],
      });
      final diaperTransport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'diaper-001',
            'infant_id': 'infant-fixture',
            'changed_at': '2026-06-29T04:00:00Z',
            'diaper_type': 'mixed',
            'notes': '',
          },
        ],
      });

      final sleeps = await RecordsApiRepository(transport: sleepTransport)
          .fetchSleepRecordsRange(
            start: DateTime.utc(2026, 6, 23),
            end: DateTime.utc(2026, 6, 30),
            babyId: 'infant-fixture',
          );
      final diapers = await RecordsApiRepository(transport: diaperTransport)
          .fetchDiaperRecordsRange(
            start: DateTime.utc(2026, 6, 23),
            end: DateTime.utc(2026, 6, 30),
            babyId: 'infant-fixture',
          );

      expect(sleepTransport.lastPath, sleepRecordsEndpoint);
      expect(sleepTransport.lastQuery, {
        'start_at': '2026-06-23T00:00:00.000Z',
        'end_at': '2026-06-30T00:00:00.000Z',
        'infant_id': 'infant-fixture',
        'limit': 100,
      });
      expect(sleeps.single.durationSeconds, 7200);
      expect(diaperTransport.lastPath, diaperRecordsEndpoint);
      expect(diapers.single.type, 'mixed');
    });

    test('creates sleep and diaper records for the selected infant', () async {
      final sleepTransport = FixtureApiJsonTransport({
        'id': 'sleep-created',
        'infant_id': 'infant-fixture',
        'started_at': '2026-06-29T01:00:00Z',
        'ended_at': '2026-06-29T03:00:00Z',
        'sleep_type': 'nap',
        'duration_seconds': 7200,
        'notes': '',
      });
      final diaperTransport = FixtureApiJsonTransport({
        'id': 'diaper-created',
        'infant_id': 'infant-fixture',
        'changed_at': '2026-06-29T04:00:00Z',
        'diaper_type': 'wet',
        'notes': '',
      });

      await RecordsApiRepository(transport: sleepTransport).createSleepRecord(
        babyId: 'infant-fixture',
        startedAt: DateTime.utc(2026, 6, 29, 1),
        endedAt: DateTime.utc(2026, 6, 29, 3),
        type: 'nap',
        idempotencyKey: 'sleep-key',
      );
      await RecordsApiRepository(transport: diaperTransport).createDiaperRecord(
        babyId: 'infant-fixture',
        changedAt: DateTime.utc(2026, 6, 29, 4),
        type: 'wet',
        idempotencyKey: 'diaper-key',
      );

      expect(sleepTransport.lastBody, {
        'infant_id': 'infant-fixture',
        'started_at': '2026-06-29T01:00:00.000Z',
        'ended_at': '2026-06-29T03:00:00.000Z',
        'sleep_type': 'nap',
      });
      expect(sleepTransport.lastHeaders, {'Idempotency-Key': 'sleep-key'});
      expect(diaperTransport.lastBody, {
        'infant_id': 'infant-fixture',
        'changed_at': '2026-06-29T04:00:00.000Z',
        'diaper_type': 'wet',
      });
      expect(diaperTransport.lastHeaders, {'Idempotency-Key': 'diaper-key'});
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

    test('creates scoped feeding and pumping records', () async {
      final feedingTransport = FixtureApiJsonTransport({
        'id': 'feeding-new',
        'infant_id': 'infant-fixture',
        'feed_type': 'bottle',
        'volume_ml': 95.0,
        'feed_time': '2026-07-11T08:00:00Z',
      });
      final feedingRepository = RecordsApiRepository(
        transport: feedingTransport,
      );

      final feeding = await feedingRepository.createFeedingRecord(
        babyId: 'infant-fixture',
        occurredAt: DateTime.parse('2026-07-11T08:00:00Z'),
        type: 'bottle',
        amountMl: 95,
        idempotencyKey: 'feeding-create-001',
      );

      expect(feedingTransport.lastPath, feedingRecordsEndpoint);
      expect(feedingTransport.lastHeaders, {
        'Idempotency-Key': 'feeding-create-001',
      });
      expect(feedingTransport.lastBody, {
        'infant_id': 'infant-fixture',
        'feed_time': '2026-07-11T08:00:00.000Z',
        'feed_type': 'bottle',
        'volume_ml': 95.0,
      });
      expect(feeding.amountMl, 95);

      final pumpingTransport = FixtureApiJsonTransport({
        'id': 'pumping-new',
        'pump_start_time': '2026-07-11T09:00:00Z',
        'milk_volume_ml': 110.0,
        'pump_type': 'manual',
        'source': 'manual',
        'title': '',
      });
      final pumpingRepository = RecordsApiRepository(
        transport: pumpingTransport,
      );

      final pumping = await pumpingRepository.createPumpMilkRecord(
        occurredAt: DateTime.parse('2026-07-11T09:00:00Z'),
        amountMl: 110,
        idempotencyKey: 'pumping-create-001',
      );

      expect(pumpingTransport.lastPath, pumpMilkRecordsEndpoint);
      expect(pumpingTransport.lastHeaders, {
        'Idempotency-Key': 'pumping-create-001',
      });
      expect(pumpingTransport.lastBody, {
        'pump_start_time': '2026-07-11T09:00:00.000Z',
        'milk_volume_ml': 110.0,
        'pump_type': 'manual',
        'source': 'manual',
      });
      expect(pumping.amountMl, 110);
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
        babyId: 'infant-fixture',
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
        repository.fetchFeedingRecords(
          date: DateTime.utc(2026, 6, 29),
          babyId: 'infant-fixture',
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
