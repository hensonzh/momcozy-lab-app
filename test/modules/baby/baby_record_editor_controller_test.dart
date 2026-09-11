import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_records_controller.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import 'baby_test_repositories.dart';

void main() {
  BabyRecordEditorController editor(
    BabyTestRecords repo,
    BabyRecordKind kind, {
    BabyRecord? initial,
    BabySleepRecord? active,
    DateTime Function()? now,
  }) => BabyRecordEditorController(
    repository: repo,
    baby: babyTestProfile,
    timezone: 'Asia/Shanghai',
    now: now ?? () => babyTestNow,
    kind: kind,
    initial: initial,
    activeSleep: active,
  );

  test(
    'feeding requires method and breast side, and changing method cannot invent an intake amount',
    () async {
      final repo = BabyTestRecords(),
          c = editor(BabyTestRecords(), BabyRecordKind.feeding);
      addTearDown(c.dispose);
      expect(await c.save(), isNull);
      expect(c.validation, contains('方式'));
      c.setFeedingMethod(BabyFeedingMethod.breastfeeding);
      expect(await c.save(), isNull);
      expect(c.validation, contains('侧别'));
      c.setSide(FeedingSide.both);
      final unknown = (await c.save())!.single as BabyFeedingRecord;
      expect(unknown.volumeMl, isNull);
      expect(unknown.durationMinutes, isNull);
      final other = editor(repo, BabyRecordKind.feeding);
      addTearDown(other.dispose);
      other.setFeedingMethod(BabyFeedingMethod.formula);
      other.setVolume('90');
      other.setFeedingMethod(BabyFeedingMethod.breastfeeding);
      other.setSide(FeedingSide.left);
      other.setDuration('12');
      final nursing = (await other.save())!.single as BabyFeedingRecord;
      expect(nursing.volumeMl, isNull);
      expect(nursing.durationMinutes, 12);
    },
  );
  test(
    'uncertain growth batch keeps the same measurements and key until confirmed',
    () async {
      final repo = BabyTestRecords()..failSave = true;
      final c = editor(repo, BabyRecordKind.growth);
      addTearDown(c.dispose);
      c.setGrowthValue(GrowthMetric.weight, '4.2');
      c.selectMetric(GrowthMetric.length);
      c.setGrowthValue(GrowthMetric.length, '54');
      expect(await c.save(), isNull);
      expect(c.uncertain, isTrue);
      expect(repo.values, hasLength(2));
      c.setGrowthValue(GrowthMetric.length, '60');
      expect(c.growthValues[GrowthMetric.length], '54');
      final result = await c.save();
      expect(result, hasLength(2));
      expect(repo.values, hasLength(2));
      expect(repo.keys.toSet(), hasLength(1));
      expect(repo.submissions.first[0], same(repo.submissions.last[0]));
      expect(c.uncertain, isFalse);
    },
  );
  test(
    'waking an existing sleep retries its original end time and version',
    () async {
      var now = babyTestNow;
      final sleep = BabySleepRecord(
        id: 'sleep',
        babyId: babyTestProfile.id,
        version: 4,
        occurredAt: babyTestNow.subtract(const Duration(hours: 2)),
      );
      final repo = BabyTestRecords()
        ..values = [sleep]
        ..failSave = true;
      final c = editor(
        repo,
        BabyRecordKind.sleep,
        active: sleep,
        now: () => now,
      );
      addTearDown(c.dispose);
      c.setSleepEnd(now);
      expect(await c.save(), isNull);
      now = now.add(const Duration(minutes: 20));
      c.setSleepEnd(now);
      final result = (await c.save())!.single as BabySleepRecord;
      expect(result.id, 'sleep');
      expect(result.endedAt, babyTestNow);
      expect(repo.values, hasLength(1));
      expect(repo.submissions.last.single.version, 4);
    },
  );
  test('observations keep calendar dates and cannot precede birth', () async {
    final c = editor(BabyTestRecords(), BabyRecordKind.development);
    addTearDown(c.dispose);
    c.setDevelopment('looks-at-face', DevelopmentStatus.unsure);
    c.setDate(LocalDate(2026, 8, 17));
    expect(await c.save(), isNull);
    expect(c.validation, contains('出生日期'));
    c.setDate(LocalDate(2026, 9, 8));
    final result = (await c.save())!.single as BabyDevelopmentRecord;
    expect(result.recordedOn, LocalDate(2026, 9, 8));
    expect(result.timezone, 'Asia/Shanghai');
    expect(result.status, DevelopmentStatus.unsure);
  });
  test(
    'delete and undo recover uncertain responses using the exact receipt versions',
    () async {
      final record = BabyFeedingRecord(
        id: 'feeding',
        babyId: babyTestProfile.id,
        version: 7,
        occurredAt: babyTestNow,
        method: BabyFeedingMethod.formula,
      );
      final repo = BabyTestRecords()
        ..values = [record]
        ..failDelete = true
        ..failRestore = true;
      final c = BabyRecordsController(
        repository: repo,
        baby: babyTestProfile,
        timezone: 'UTC',
        now: () => babyTestNow,
      );
      addTearDown(c.dispose);
      await c.load();
      expect(await c.delete(record), isFalse);
      expect(c.uncertainMutation, isTrue);
      await c.select(kind: BabyRecordKind.growth);
      expect(c.kind, BabyRecordKind.feeding);
      await c.retryMutation();
      expect(c.records.value, isEmpty);
      expect(c.deletion!.version, 8);
      expect(repo.deleteVersions, [7, 7]);
      expect(await c.undo(), isFalse);
      expect(c.uncertainMutation, isTrue);
      await c.retryMutation();
      expect(c.records.value, hasLength(1));
      expect(c.deletion, isNull);
      expect(repo.restoreVersions, [8, 8]);
    },
  );
  test(
    'local clock rejects the DST gap and distinguishes both repeated times',
    () {
      expect(
        zonedWallClockCandidates(
          LocalDate(2026, 3, 8),
          2,
          30,
          'America/New_York',
        ),
        isEmpty,
      );
      final repeated = zonedWallClockCandidates(
        LocalDate(2026, 11, 1),
        1,
        30,
        'America/New_York',
      );
      expect(repeated, [
        DateTime.utc(2026, 11, 1, 5, 30),
        DateTime.utc(2026, 11, 1, 6, 30),
      ]);
    },
  );
}
