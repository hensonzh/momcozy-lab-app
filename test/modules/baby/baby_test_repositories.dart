import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/domain/shared/record_deletion.dart';
import 'package:momcozy_flutter_app/services/baby/baby_record_codec.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

final babyTestNow = DateTime.utc(2026, 9, 8, 10);
final babyTestProfile = BabyProfile(
  id: 'baby',
  name: 'Luna',
  birthDate: LocalDate(2026, 8, 18),
  sex: BabySex.female,
  version: 1,
);

class BabyTestProfiles implements BabyProfileRepository {
  List<BabyProfile> values = [babyTestProfile];
  @override
  Future<List<BabyProfile>> list() async => values;
  @override
  Future<BabyProfile> save(
    BabyProfile profile, {
    required String timezone,
    String? idempotencyKey,
  }) async {
    final saved = BabyProfile(
      id: profile.id.isEmpty ? 'new-baby' : profile.id,
      name: profile.name,
      birthDate: profile.birthDate,
      sex: profile.sex,
      feedingMode: profile.feedingMode,
      version: (profile.version ?? 0) + 1,
    );
    values = [...values.where((value) => value.id != saved.id), saved];
    return saved;
  }
}

class BabyTestRecords implements BabyRecordRepository {
  List<BabyRecord> values = [];
  List<String> keys = [];
  final submissions = <List<BabyRecord>>[];
  final creates = <String, List<BabyRecord>>{};
  final removed = <String, BabyRecord>{};
  final deletes = <String, RecordDeletion>{};
  final restores = <String, BabyRecord>{};
  final deleteVersions = <int>[], restoreVersions = <int>[];
  bool failSave = false, failDelete = false, failRestore = false;
  ProductFailure? loadFailure;
  int _id = 0;

  BabyRecord _copy(BabyRecord record, String id, int version) {
    final observation = writeBabyObservation(record);
    if (record is BabyGrowthRecord) observation['unit'] = record.unit;
    if (record is BabyDevelopmentRecord) observation['label'] = record.label;
    return readBabyRecord({
      'id': id,
      'baby_id': record.babyId,
      'version': version,
      'created_at': babyTestNow.toIso8601String(),
      'updated_at': babyTestNow.toIso8601String(),
      'observation': observation,
    });
  }

  Future<List<BabyRecord>> _save(List<BabyRecord> records, String key) async {
    keys.add(key);
    submissions.add(records);
    var saved = creates[key];
    if (saved == null) {
      saved = [
        for (final record in records)
          _copy(
            record,
            record.id.isEmpty ? 'record-${++_id}' : record.id,
            record.id.isEmpty ? 1 : record.version + 1,
          ),
      ];
      values = [
        ...values.where((value) => !saved!.any((item) => item.id == value.id)),
        ...saved,
      ];
      creates[key] = saved;
    }
    if (failSave) {
      failSave = false;
      throw const ProductFailure(ProductFailureKind.unavailable);
    }
    return saved;
  }

  @override
  Future<BabyRecord> save(
    BabyRecord record, {
    required String idempotencyKey,
  }) async => (await _save([record], idempotencyKey)).single;
  @override
  Future<List<BabyRecord>> saveBatch(
    List<DatedBabyRecord> records, {
    required String idempotencyKey,
  }) => _save(records, idempotencyKey);
  @override
  Future<RecordDeletion> delete(
    String id, {
    required String babyId,
    required int expectedVersion,
  }) async {
    deleteVersions.add(expectedVersion);
    if (!deletes.containsKey(id)) {
      removed[id] = values.singleWhere(
        (value) => value.id == id && value.babyId == babyId,
      );
      deletes[id] = RecordDeletion(id: id, version: expectedVersion + 1);
      values.removeWhere((value) => value.id == id);
    }
    if (failDelete) {
      failDelete = false;
      throw const ProductFailure(ProductFailureKind.offline);
    }
    return deletes[id]!;
  }

  @override
  Future<BabyRecord> restore(
    String id, {
    required String babyId,
    required int expectedVersion,
  }) async {
    restoreVersions.add(expectedVersion);
    if (!restores.containsKey(id)) {
      restores[id] = _copy(removed[id]!, id, expectedVersion + 1);
      values.add(restores[id]!);
    }
    if (failRestore) {
      failRestore = false;
      throw const ProductFailure(ProductFailureKind.unavailable);
    }
    return restores[id]!;
  }

  @override
  Future<List<BabyGrowthRecord>> latestGrowth(String babyId) async {
    if (loadFailure != null) throw loadFailure!;
    final sorted =
        values
            .whereType<BabyGrowthRecord>()
            .where((value) => value.babyId == babyId)
            .toList()
          ..sort((a, b) => b.recordedOn.compareTo(a.recordedOn));
    return [
      for (final metric in GrowthMetric.values)
        ?sorted.where((value) => value.metric == metric).firstOrNull,
    ];
  }

  @override
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  }) async {
    if (loadFailure != null) throw loadFailure!;
    final window = DayWindow(
      zonedDayWindow(startDate, timezone).start,
      zonedDayWindow(endDate, timezone).start,
    );
    final items = values
        .where(
          (value) =>
              value.babyId == babyId &&
              (kind == null || value.recordKind == kind) &&
              switch (value) {
                DatedBabyRecord(:final recordedOn) =>
                  recordedOn.compareTo(startDate) >= 0 &&
                      recordedOn.compareTo(endDate) < 0,
                BabySleepRecord(:final occurredAt, :final endedAt) =>
                  occurredAt.isBefore(window.end) &&
                      (endedAt ?? babyTestNow).isAfter(window.start),
                TimedBabyRecord(:final occurredAt) => window.contains(
                  occurredAt,
                ),
              },
        )
        .toList();
    return BabyRecordPage(
      items: items.skip(offset).take(limit).toList(),
      total: items.length,
      offset: offset,
      limit: limit,
      serverTime: babyTestNow,
    );
  }
}
