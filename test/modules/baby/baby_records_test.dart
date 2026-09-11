import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/services/baby/baby_record_codec.dart';
import 'package:momcozy_flutter_app/services/baby/baby_records_api_repository.dart';
import '../../support/fixture_api_transport.dart';

Map<String, Object?> fixture() => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/product_baseline/baby_records.json',
        ).readAsStringSync(),
      )
      as Map,
);
Map<String, Object?> row(String kind) => Map<String, Object?>.from(
  (fixture()['items'] as List).cast<Map>().singleWhere(
    (item) => (item['observation'] as Map)['kind'] == kind,
  ),
);

void main() {
  test(
    'five persisted record types retain dates, units and concrete observations',
    () {
      final records = (fixture()['items'] as List)
          .map(
            (value) => readBabyRecord(Map<String, Object?>.from(value as Map)),
          )
          .toList();
      expect(
        records.map((r) => r.recordKind).toSet(),
        BabyRecordKind.values.toSet(),
      );
      final growth = records.whereType<BabyGrowthRecord>().single;
      expect(growth.recordedOn, LocalDate(2026, 9, 1));
      expect(growth.timezone, 'Asia/Shanghai');
      expect(growth.unit, 'kg');
      expect(writeBabyObservation(growth).containsKey('occurred_at'), isFalse);
      final development = records.whereType<BabyDevelopmentRecord>().single;
      expect(development.label, '看向靠近的脸');
      expect(writeBabyObservation(development).containsKey('label'), isFalse);
    },
  );
  test(
    'unknown intake stays empty and feeding types cannot carry old measurements',
    () {
      final data = row('feeding');
      (data['observation'] as Map)['volume_ml'] = null;
      final unknown = readBabyRecord(data) as BabyFeedingRecord;
      expect(unknown.volumeMl, isNull);
      expect(writeBabyObservation(unknown)['volume_ml'], isNull);
      (data['observation'] as Map)['method'] = 'pump';
      expect(() => readBabyRecord(data), throwsFormatException);
      final growth = row('growth');
      (growth['observation'] as Map)['unit'] = 'lb';
      expect(() => readBabyRecord(growth), throwsFormatException);
    },
  );
  test(
    'repository preserves scope, version and idempotency on mutations',
    () async {
      final data = row('feeding');
      final transport = FixtureApiJsonTransport(data);
      final repository = BabyRecordsApiRepository(transport: transport);
      final saved = readBabyRecord(data) as BabyFeedingRecord;
      final draft = BabyFeedingRecord(
        id: '',
        babyId: saved.babyId,
        occurredAt: saved.occurredAt,
        method: saved.method,
        volumeMl: saved.volumeMl,
      );
      await repository.save(draft, idempotencyKey: 'create-once');
      expect(transport.lastMethod, 'POST');
      expect(transport.lastHeaders!['Idempotency-Key'], 'create-once');
      expect(transport.lastPath, '/v1/babies/${saved.babyId}/records');
      await repository.save(saved, idempotencyKey: 'unused-for-edit');
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastBody!['expected_version'], saved.version);
    },
  );
  test(
    'foreign baby in a response is rejected before reaching page state',
    () async {
      final repository = BabyRecordsApiRepository(
        transport: FixtureApiJsonTransport(fixture()),
      );
      await expectLater(
        repository.list(
          babyId: 'different-baby',
          startDate: LocalDate(2026, 9, 1),
          endDate: LocalDate(2026, 9, 2),
          timezone: 'Asia/Shanghai',
        ),
        throwsA(isA<ProductFailure>()),
      );
    },
  );
}
