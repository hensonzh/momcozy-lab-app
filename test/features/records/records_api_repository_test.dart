import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';

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
            'volume_ml': 100.5,
            'duration_seconds': 900,
            'feed_time': '2026-06-29T08:00:00Z',
          },
          {
            'id': 'feeding-other',
            'infant_id': 'infant-other',
            'feed_type': 'bottle',
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
      expect(records.single.feedingMethod, FeedingMethod.bottle);
      expect(records.single.milkComponents, hasLength(1));
      expect(
        records.single.milkComponents.first.milkSource,
        MilkSource.unknown,
      );
      expect(records.single.measuredVolumeMl, 100.5);
      expect(records.single.durationSeconds, 900);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:00:00Z'));
    });

    test('rejects legacy feeding method and component fields', () async {
      final repository = RecordsApiRepository(
        transport: FixtureApiJsonTransport({
          'items': [
            {
              'id': 'legacy-feeding',
              'infant_id': 'infant-fixture',
              'feeding_method': 'bottle',
              'milk_components': [
                {'milk_source': 'formula', 'volume_ml': 80},
              ],
              'feed_time': '2026-07-11T08:00:00Z',
            },
          ],
        }),
      );

      await expectLater(
        repository.fetchFeedingRecords(
          date: DateTime.utc(2026, 7, 11),
          babyId: 'infant-fixture',
        ),
        throwsA(isA<FormatException>()),
      );
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
            'feed_type': 'bottle',
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

    test(
      'requests a seven-day feeding range when weekly data is needed',
      () async {
        final transport = FixtureApiJsonTransport({'items': []});
        final repository = RecordsApiRepository(transport: transport);

        await repository.fetchFeedingRecords(
          date: DateTime.utc(2026, 7, 11),
          babyId: 'infant-fixture',
          days: 7,
        );

        expect(transport.lastQuery, {
          'start_at': '2026-07-05T00:00:00.000Z',
          'end_at': '2026-07-12T00:00:00.000Z',
          'infant_id': 'infant-fixture',
          'limit': 100,
        });
      },
    );

    test('maps production pumping records and request contract', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'pump-001',
            'pump_type': 'electric',
            'milk_volume_ml': 120.25,
            'duration_seconds': 1200,
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
      expect(records.single.pumpType, 'electric');
      expect(records.single.outputs, hasLength(1));
      expect(records.single.outputs.first.breastSide, PumpingSide.unassigned);
      expect(records.single.measuredVolumeMl, 120.25);
      expect(records.single.durationSeconds, 1200);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:40:00Z'));
    });

    test('rejects legacy pumping output collections', () async {
      final repository = RecordsApiRepository(
        transport: FixtureApiJsonTransport({
          'items': [
            {
              'id': 'legacy-pumping',
              'pump_start_time': '2026-07-11T09:00:00Z',
              'outputs': [
                {'breast_side': 'left', 'volume_ml': 60},
              ],
            },
          ],
        }),
      );

      await expectLater(
        repository.fetchPumpMilkRecords(date: DateTime.utc(2026, 7, 11)),
        throwsA(isA<FormatException>()),
      );
    });

    test('creates scoped feeding and pumping records', () async {
      final feedingTransport = FixtureApiJsonTransport({
        'id': 'feeding-new',
        'infant_id': 'infant-fixture',
        'feed_type': 'bottle',
        'volume_ml': 95.5,
        'feed_time': '2026-07-11T08:00:00Z',
      });
      final feedingRepository = RecordsApiRepository(
        transport: feedingTransport,
      );

      final feeding = await feedingRepository.createFeedingRecord(
        babyId: 'infant-fixture',
        occurredAt: DateTime.parse('2026-07-11T08:00:00Z'),
        feedingMethod: FeedingMethod.bottle,
        volumeMl: 95.5,
        planTaskId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
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
        'volume_ml': 95.5,
        'plan_task_id': '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
      });
      expect(feeding.measuredVolumeMl, 95.5);

      final pumpingTransport = FixtureApiJsonTransport({
        'id': 'pumping-new',
        'pump_start_time': '2026-07-11T09:00:00Z',
        'pump_end_time': '2026-07-11T09:20:00Z',
        'pump_type': 'manual',
        'milk_volume_ml': 110.0,
      });
      final pumpingRepository = RecordsApiRepository(
        transport: pumpingTransport,
      );

      final pumping = await pumpingRepository.createPumpMilkRecord(
        occurredAt: DateTime.parse('2026-07-11T09:00:00Z'),
        endedAt: DateTime.parse('2026-07-11T09:20:00Z'),
        milkVolumeMl: 110,
        planTaskId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c519',
        idempotencyKey: 'pumping-create-001',
      );

      expect(pumpingTransport.lastPath, pumpMilkRecordsEndpoint);
      expect(pumpingTransport.lastHeaders, {
        'Idempotency-Key': 'pumping-create-001',
      });
      expect(pumpingTransport.lastBody, {
        'pump_start_time': '2026-07-11T09:00:00.000Z',
        'pump_end_time': '2026-07-11T09:20:00.000Z',
        'milk_volume_ml': 110.0,
        'plan_task_id': '0ea4b76d-2bc4-4ab8-91b7-3b24df53c519',
        'pump_type': 'manual',
        'source': 'manual',
      });
      expect(pumping.measuredVolumeMl, 110);
      expect(pumping.outputs.single.breastSide, PumpingSide.unassigned);
      expect(pumping.endedAt, DateTime.parse('2026-07-11T09:20:00Z'));
    });

    test(
      'encodes start-only direct breastfeeding without unsupported details',
      () async {
        final transport = FixtureApiJsonTransport({
          'id': 'feeding-direct',
          'infant_id': 'infant-fixture',
          'feed_type': 'direct_breastfeeding',
          'volume_ml': null,
          'feed_time': '2026-07-11T10:00:00Z',
        });

        final record = await RecordsApiRepository(transport: transport)
            .createFeedingRecord(
              babyId: 'infant-fixture',
              occurredAt: DateTime.parse('2026-07-11T10:00:00Z'),
              feedingMethod: FeedingMethod.directBreastfeeding,
            );

        expect(transport.lastBody, {
          'infant_id': 'infant-fixture',
          'feed_time': '2026-07-11T10:00:00.000Z',
          'feed_type': 'direct_breastfeeding',
        });
        expect(record.feedingMethod, FeedingMethod.directBreastfeeding);
        expect(record.breastSide, isNull);
        expect(record.measuredVolumeMl, isNull);
      },
    );

    test('maps and creates owner-scoped water records', () async {
      final listTransport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'water-001',
            'occurred_at': '2026-08-08T08:00:00Z',
            'amount_ml': 250.0,
          },
        ],
      });
      final repository = RecordsApiRepository(transport: listTransport);

      final records = await repository.fetchWaterRecords(
        date: DateTime.utc(2026, 8, 8),
      );

      expect(listTransport.lastPath, waterRecordsEndpoint);
      expect(listTransport.lastQuery, {
        'start_at': '2026-08-08T00:00:00.000Z',
        'end_at': '2026-08-09T00:00:00.000Z',
        'limit': 100,
      });
      expect(records.single.amountMl, 250);

      final createTransport = FixtureApiJsonTransport({
        'id': 'water-new',
        'occurred_at': '2026-08-08T09:00:00Z',
        'amount_ml': 300.0,
      });
      final created = await RecordsApiRepository(transport: createTransport)
          .createWaterRecord(
            occurredAt: DateTime.parse('2026-08-08T09:00:00Z'),
            amountMl: 300,
            idempotencyKey: 'water-create-001',
          );

      expect(createTransport.lastPath, waterRecordsEndpoint);
      expect(createTransport.lastHeaders, {
        'Idempotency-Key': 'water-create-001',
      });
      expect(createTransport.lastBody, {
        'occurred_at': '2026-08-08T09:00:00.000Z',
        'amount_ml': 300.0,
        'source': 'manual',
      });
      expect(created.amountMl, 300);
    });

    test('maps water trends using the device UTC offset', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {'date': '2026-08-08', 'total_water_ml': 1850.0, 'entry_count': 7},
        ],
        'days': 7,
        'timezone': 'UTC+08:00',
      });
      final repository = RecordsApiRepository(transport: transport);

      final trends = await repository.fetchWaterTrends(
        startDate: DateTime(2026, 8, 2),
        days: 7,
        utcOffsetMinutes: 480,
      );

      expect(transport.lastPath, waterTrendsEndpoint);
      expect(transport.lastQuery, {
        'start_date': '2026-08-02',
        'days': 7,
        'utc_offset_minutes': 480,
      });
      expect(trends.single.totalWaterMl, 1850);
      expect(trends.single.entryCount, 7);
    });

    test('maps and creates maternal vital records', () async {
      final transport = FixtureApiJsonTransport({
        'id': 'vital-001',
        'measured_at': '2026-08-08T08:00:00Z',
        'weight_kg': 62.5,
        'systolic_mmhg': 118,
        'diastolic_mmhg': 76,
        'heart_rate_bpm': 72,
        'temperature_c': 36.7,
      });
      final repository = RecordsApiRepository(transport: transport);

      final record = await repository.createVitalRecord(
        measuredAt: DateTime.parse('2026-08-08T08:00:00Z'),
        weightKg: 62.5,
        systolicMmhg: 118,
        diastolicMmhg: 76,
        heartRateBpm: 72,
        temperatureC: 36.7,
        idempotencyKey: 'vital-create-001',
      );

      expect(transport.lastPath, vitalRecordsEndpoint);
      expect(transport.lastHeaders, {'Idempotency-Key': 'vital-create-001'});
      expect(transport.lastBody, {
        'measured_at': '2026-08-08T08:00:00.000Z',
        'weight_kg': 62.5,
        'systolic_mmhg': 118,
        'diastolic_mmhg': 76,
        'heart_rate_bpm': 72,
        'temperature_c': 36.7,
        'source': 'manual',
      });
      expect(record.weightKg, 62.5);
      expect(record.heartRateBpm, 72);
    });

    test('maps and creates infant sleep records in a bounded range', () async {
      final listTransport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'sleep-001',
            'infant_id': 'infant-fixture',
            'started_at': '2026-08-08T05:00:00Z',
            'ended_at': '2026-08-08T05:45:00Z',
            'sleep_kind': 'nap',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: listTransport);

      final records = await repository.fetchSleepRecords(
        babyId: 'infant-fixture',
        start: DateTime.parse('2026-08-02T00:00:00Z'),
        end: DateTime.parse('2026-08-09T00:00:00Z'),
      );

      expect(listTransport.lastPath, sleepRecordsEndpoint);
      expect(listTransport.lastQuery, {
        'infant_id': 'infant-fixture',
        'start_at': '2026-08-02T00:00:00.000Z',
        'end_at': '2026-08-09T00:00:00.000Z',
        'limit': 100,
      });
      expect(records.single.kind, SleepKind.nap);
      expect(records.single.duration, const Duration(minutes: 45));

      final createTransport = FixtureApiJsonTransport({
        'id': 'sleep-new',
        'infant_id': 'infant-fixture',
        'started_at': '2026-08-08T05:00:00Z',
        'ended_at': '2026-08-08T05:45:00Z',
        'sleep_kind': 'nap',
      });
      await RecordsApiRepository(transport: createTransport).createSleepRecord(
        babyId: 'infant-fixture',
        startedAt: DateTime.parse('2026-08-08T05:00:00Z'),
        endedAt: DateTime.parse('2026-08-08T05:45:00Z'),
        kind: SleepKind.nap,
        idempotencyKey: 'sleep-create-001',
      );

      expect(createTransport.lastPath, sleepRecordsEndpoint);
      expect(createTransport.lastHeaders, {
        'Idempotency-Key': 'sleep-create-001',
      });
      expect(createTransport.lastBody, {
        'infant_id': 'infant-fixture',
        'started_at': '2026-08-08T05:00:00.000Z',
        'ended_at': '2026-08-08T05:45:00.000Z',
        'sleep_kind': 'nap',
        'source': 'manual',
      });
    });

    test('maps and creates infant diaper records', () async {
      final listTransport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'diaper-001',
            'infant_id': 'infant-fixture',
            'changed_at': '2026-08-08T06:00:00Z',
            'diaper_kind': 'both',
            'wetness': 'medium',
            'stool_color': 'gold',
            'stool_consistency': 'soft',
            'wet_diaper_count': 7,
            'bowel_movement_count': 3,
            'notes': '',
          },
        ],
      });
      final repository = RecordsApiRepository(transport: listTransport);

      final records = await repository.fetchDiaperRecords(
        babyId: 'infant-fixture',
        start: DateTime.parse('2026-08-02T00:00:00Z'),
        end: DateTime.parse('2026-08-09T00:00:00Z'),
      );

      expect(listTransport.lastPath, diaperRecordsEndpoint);
      expect(listTransport.lastQuery, {
        'infant_id': 'infant-fixture',
        'start_at': '2026-08-02T00:00:00.000Z',
        'end_at': '2026-08-09T00:00:00.000Z',
        'limit': 100,
      });
      expect(records.single.kind, DiaperKind.both);
      expect(records.single.wetness, DiaperWetness.medium);
      expect(records.single.stoolColor, 'gold');
      expect(records.single.wetDiaperCount, 7);
      expect(records.single.bowelMovementCount, 3);

      final createTransport = FixtureApiJsonTransport({
        'id': 'diaper-new',
        'infant_id': 'infant-fixture',
        'changed_at': '2026-08-08T06:00:00Z',
        'diaper_kind': 'both',
        'wetness': 'medium',
        'stool_color': 'gold',
        'stool_consistency': 'soft',
        'wet_diaper_count': 7,
        'bowel_movement_count': 3,
        'notes': '',
      });
      await RecordsApiRepository(transport: createTransport).createDiaperRecord(
        babyId: 'infant-fixture',
        changedAt: DateTime.parse('2026-08-08T06:00:00Z'),
        kind: DiaperKind.both,
        wetness: DiaperWetness.medium,
        stoolColor: 'gold',
        stoolConsistency: 'soft',
        wetDiaperCount: 7,
        bowelMovementCount: 3,
        idempotencyKey: 'diaper-create-001',
      );

      expect(createTransport.lastPath, diaperRecordsEndpoint);
      expect(createTransport.lastHeaders, {
        'Idempotency-Key': 'diaper-create-001',
      });
      expect(createTransport.lastBody, {
        'infant_id': 'infant-fixture',
        'changed_at': '2026-08-08T06:00:00.000Z',
        'diaper_kind': 'both',
        'wetness': 'medium',
        'stool_color': 'gold',
        'stool_consistency': 'soft',
        'wet_diaper_count': 7,
        'bowel_movement_count': 3,
        'notes': '',
        'source': 'manual',
      });
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

    test('maps measured milk trends', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'date': '2026-07-01',
            'pumped_milk_volume_ml': 0,
            'pumping_count': 2,
            'measured_only': false,
          },
          {
            'date': '2026-07-02',
            'pumped_milk_volume_ml': 210.25,
            'pumping_count': 3,
            'measured_only': true,
          },
        ],
      });
      final repository = RecordsApiRepository(transport: transport);

      final trends = await repository.fetchMilkTrends(
        startDate: DateTime(2026, 6, 2),
        days: 31,
        utcOffsetMinutes: 480,
      );

      expect(transport.lastPath, milkTrendsEndpoint);
      expect(transport.lastQuery, {
        'start_date': '2026-06-02',
        'days': 31,
        'include_today': true,
        'utc_offset_minutes': 480,
      });
      expect(trends.first.measuredVolumeMl, isNull);
      expect(trends.first.pumpingCount, 2);
      expect(trends.first.measuredPumpingCount, 0);
      expect(trends.last.measuredVolumeMl, 210.25);
      expect(trends.last.pumpingCount, 3);
      expect(trends.last.measuredPumpingCount, 3);
    });

    test('rejects legacy milk trend field aliases', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'date': '2026-07-01',
            'measured_volume_ml': 210,
            'pumping_count': 2,
            'measured_pumping_count': 2,
          },
        ],
      });

      await expectLater(
        RecordsApiRepository(
          transport: transport,
        ).fetchMilkTrends(startDate: DateTime(2026, 7, 1), days: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('maps production growth records and owner-scoped query', () async {
      final transport = FixtureApiJsonTransport({
        'items': [
          {
            'id': 'growth-001',
            'weight_kg': 4.2,
            'height_cm': 54.5,
            'head_cm': 36.2,
            'measurement_position': 'recumbent',
            'measurement_context': 'routine',
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
      expect(records.single.measurementPosition, MeasurementPosition.recumbent);
      expect(records.single.measurementContext, MeasurementContext.routine);
      expect(records.single.measuredAt, DateTime.parse('2026-06-29T00:00:00Z'));
    });

    test('creates and updates production growth records', () async {
      final transport = FixtureApiJsonTransport({
        'id': 'growth-001',
        'infant_id': 'infant-fixture',
        'weight_kg': 4.3,
        'height_cm': 55.0,
        'head_cm': 36.5,
        'measurement_position': 'recumbent',
        'measurement_context': 'routine',
        'measured_at': '2026-07-11T08:00:00Z',
      });
      final repository = RecordsApiRepository(transport: transport);

      final created = await repository.createGrowthRecord(
        babyId: 'infant-fixture',
        measuredAt: DateTime.parse('2026-07-11T08:00:00Z'),
        weightKg: 4.3,
        heightCm: 55,
        headCm: 36.5,
        measurementPosition: MeasurementPosition.recumbent,
        measurementContext: MeasurementContext.routine,
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
        'measurement_position': 'recumbent',
        'measurement_context': 'routine',
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

    test(
      'maps the shared feeding summary without converting missing days to zero',
      () async {
        final transport = FixtureApiJsonTransport({
          'days': 7,
          'timezone': 'Asia/Shanghai',
          'feeding_count': 3,
          'measured_volume_count': 2,
          'measured_volume_ml': 175.5,
          'average_measured_volume_ml': 87.75,
          'feeding_method_counts': {'bottle': 2, 'direct_breastfeeding': 1},
          'milk_source_volumes_ml': {'breast_milk': 95.5, 'formula': 80.0},
          'latest_feeding_at': '2026-07-02T08:00:00Z',
          'completed_days': {
            'window_days': 2,
            'recorded_days': 1,
            'measured_days': 1,
            'average_volume_per_measured_day_ml': 95.5,
            'average_feedings_per_recorded_day': 2.0,
            'daily_series': [
              {
                'date': '2026-06-30',
                'measured_volume_ml': null,
                'feeding_count': 0,
                'measured_feeding_count': 0,
              },
              {
                'date': '2026-07-01',
                'measured_volume_ml': 95.5,
                'feeding_count': 2,
                'measured_feeding_count': 1,
              },
            ],
          },
          'comparison': {
            'status': 'insufficient_data',
            'current_average_volume_per_measured_day_ml': 95.5,
            'previous_average_volume_per_measured_day_ml': null,
            'change_percent': null,
            'current_measured_days': 1,
            'previous_measured_days': 0,
            'minimum_measured_days': 5,
          },
          'intake_evaluation_context': {
            'status': 'evidence_available',
            'reason_code': null,
            'growth_measurement_date': '2026-07-01',
            'chronological_age_days': 42,
          },
        });

        final summary = await RecordsApiRepository(transport: transport)
            .fetchFeedingSummary(
              babyId: 'infant-fixture',
              days: 7,
              timezone: 'Asia/Shanghai',
            );

        expect(transport.lastPath, feedingSummaryEndpoint);
        expect(transport.lastQuery, {
          'infant_id': 'infant-fixture',
          'days': 7,
          'timezone': 'Asia/Shanghai',
        });
        expect(summary.measuredVolumeMl, 175.5);
        expect(
          summary.completedDays.dailySeries.first.measuredVolumeMl,
          isNull,
        );
        expect(summary.completedDays.measuredDays, 1);
        expect(
          summary.intakeEvaluationContext.status,
          IntakeEvaluationStatus.evidenceAvailable,
        );
      },
    );

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

    test(
      'write adapters stay within the frozen Product OpenAPI schemas',
      () async {
        final schemas = _productSchemas();
        final feedingTransport = FixtureApiJsonTransport({
          'id': 'feeding-contract',
          'feed_time': '2026-07-11T08:00:00Z',
          'feed_type': 'bottle',
          'volume_ml': 90,
        });
        await RecordsApiRepository(
          transport: feedingTransport,
        ).createFeedingRecord(
          babyId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
          occurredAt: DateTime.utc(2026, 7, 11, 8),
          feedingMethod: FeedingMethod.bottle,
          volumeMl: 90,
        );

        final pumpingTransport = FixtureApiJsonTransport({
          'id': 'pumping-contract',
          'pump_start_time': '2026-07-11T09:00:00Z',
          'pump_type': 'manual',
          'source': 'manual',
          'milk_volume_ml': 110,
        });
        await RecordsApiRepository(
          transport: pumpingTransport,
        ).createPumpMilkRecord(
          occurredAt: DateTime.utc(2026, 7, 11, 9),
          milkVolumeMl: 110,
        );

        _expectBodyMatchesSchema(
          feedingTransport.lastBody!,
          schemas['FeedingRecordCreate']! as Map<String, Object?>,
        );
        _expectBodyMatchesSchema(
          pumpingTransport.lastBody!,
          schemas['PumpingRecordCreate']! as Map<String, Object?>,
        );
      },
    );
  });
}

Map<String, Object?> _productSchemas() {
  final document =
      jsonDecode(
            File(
              'docs/backend-contract/product.openapi.generated.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final components = document['components']! as Map<String, Object?>;
  return components['schemas']! as Map<String, Object?>;
}

void _expectBodyMatchesSchema(
  Map<String, Object?> body,
  Map<String, Object?> schema,
) {
  final properties = (schema['properties']! as Map).keys
      .map((key) => key.toString())
      .toSet();
  final required = (schema['required'] as List? ?? const <Object?>[])
      .map((key) => key.toString())
      .toSet();
  expect(body.keys.toSet().difference(properties), isEmpty);
  expect(required.difference(body.keys.toSet()), isEmpty);
}
