import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';

void main() {
  group('RecordsApiRepository', () {
    test('maps feeding records and request contract', () async {
      final transport = _transport('feeding', 'success');
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchFeedingRecords(
        userId: 'demo-user-fixture',
        date: DateTime.utc(2026, 6, 29),
      );

      expect(transport.lastPath, feedingRecordsEndpoint);
      expect(transport.lastQuery, {
        'user_id': 'demo-user-fixture',
        'date': '2026-06-29',
      });
      expect(records.single.id, 'feeding-001');
      expect(records.single.type, 'breast_milk');
      expect(records.single.amountMl, 80);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:00:00Z'));
    });

    test('maps feeding aliases and partial empty data', () async {
      final legacy =
          await RecordsApiRepository(
            transport: _transport('feeding', 'legacy_alias'),
          ).fetchFeedingRecords(
            userId: 'demo-user-fixture',
            date: DateTime.utc(2026, 6, 29),
          );
      final empty =
          await RecordsApiRepository(
            transport: _transport('feeding', 'empty'),
          ).fetchFeedingRecords(
            userId: 'demo-user-fixture',
            date: DateTime.utc(2026, 6, 29),
          );
      final partial =
          await RecordsApiRepository(
            transport: _transport('feeding', 'partial'),
          ).fetchFeedingRecords(
            userId: 'demo-user-fixture',
            date: DateTime.utc(2026, 6, 29),
          );

      expect(legacy.single.type, 'breast_milk');
      expect(legacy.single.amountMl, 80);
      expect(empty, isEmpty);
      expect(partial.single.id, 'feeding-001');
      expect(partial.single.type, '');
      expect(partial.single.occurredAt, isNull);
    });

    test('maps pump milk records and request contract', () async {
      final transport = _transport('pump_milk', 'success');
      final repository = RecordsApiRepository(transport: transport);

      final records = await repository.fetchPumpMilkRecords(
        userId: 'demo-user-fixture',
        date: DateTime.utc(2026, 6, 29),
      );

      expect(transport.lastPath, pumpMilkRecordsEndpoint);
      expect(transport.lastQuery, {
        'user_id': 'demo-user-fixture',
        'timestamp': '2026-06-29',
      });
      expect(records.single.id, '3001');
      expect(records.single.title, 'Morning pump');
      expect(records.single.pumpType, 0);
      expect(records.single.pumpSource, 0);
      expect(records.single.amountMl, 120);
      expect(records.single.occurredAt, DateTime.parse('2026-06-29T08:40:00Z'));
    });

    test('maps pump milk aliases and partial empty data', () async {
      final legacy =
          await RecordsApiRepository(
            transport: _transport('pump_milk', 'legacy_alias'),
          ).fetchPumpMilkRecords(
            userId: 'demo-user-fixture',
            date: DateTime.utc(2026, 6, 29),
          );
      final empty =
          await RecordsApiRepository(
            transport: _transport('pump_milk', 'empty'),
          ).fetchPumpMilkRecords(
            userId: 'demo-user-fixture',
            date: DateTime.utc(2026, 6, 29),
          );
      final partial =
          await RecordsApiRepository(
            transport: _transport('pump_milk', 'partial'),
          ).fetchPumpMilkRecords(
            userId: 'demo-user-fixture',
            date: DateTime.utc(2026, 6, 29),
          );

      expect(legacy.single.id, '3001');
      expect(legacy.single.amountMl, 120);
      expect(empty, isEmpty);
      expect(partial.single.id, '3001');
      expect(partial.single.title, '');
      expect(partial.single.occurredAt, isNull);
    });

    test('maps growth records and aliases', () async {
      final successTransport = _transport('growth', 'success');
      final success = await RecordsApiRepository(
        transport: successTransport,
      ).fetchGrowthRecords(userId: 'demo-user-fixture', babyId: 'baby-fixture');
      final legacy = await RecordsApiRepository(
        transport: _transport('growth', 'legacy_alias'),
      ).fetchGrowthRecords(userId: 'demo-user-fixture', babyId: 'baby-fixture');
      final partial = await RecordsApiRepository(
        transport: _transport('growth', 'partial'),
      ).fetchGrowthRecords(userId: 'demo-user-fixture', babyId: 'baby-fixture');

      expect(successTransport.lastPath, growthRecordsEndpoint);
      expect(successTransport.lastQuery, {
        'user_id': 'demo-user-fixture',
        'baby_id': 'baby-fixture',
      });
      expect(success.single.id, 'growth-001');
      expect(success.single.weightGram, 4200);
      expect(success.single.heightCm, 54.5);
      expect(success.single.measuredAt, DateTime.parse('2026-06-29'));
      expect(legacy.single.weightGram, 4200);
      expect(legacy.single.heightCm, 54.5);
      expect(partial.single.id, 'growth-001');
      expect(partial.single.weightGram, isNull);
    });

    test('keeps feeding and growth failures distinct', () async {
      await expectLater(
        RecordsApiRepository(
          transport: _transport('feeding', 'business_error'),
        ).fetchFeedingRecords(
          userId: 'demo-user-fixture',
          date: DateTime.utc(2026, 6, 29),
        ),
        throwsA(isA<ApiBusinessException>()),
      );
      await expectLater(
        RecordsApiRepository(
          transport: _transport('growth', 'http_error'),
        ).fetchGrowthRecords(
          userId: 'demo-user-fixture',
          babyId: 'baby-fixture',
        ),
        throwsA(isA<ApiHttpException>()),
      );
      await expectLater(
        RecordsApiRepository(
          transport: _transport('pump_milk', 'business_error'),
        ).fetchPumpMilkRecords(
          userId: 'demo-user-fixture',
          date: DateTime.utc(2026, 6, 29),
        ),
        throwsA(isA<ApiBusinessException>()),
      );
    });
  });
}

FixtureApiJsonTransport _transport(String domain, String variant) {
  final fixture = readFixtureMap('api/$domain/$variant.json');
  return FixtureApiJsonTransport(
    Map<String, Object?>.from(fixture['response']! as Map),
  );
}
