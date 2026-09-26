import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
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
      expect(c.validation, contains('method'));
      c.setFeedingMethod(BabyFeedingMethod.breastfeeding);
      expect(await c.save(), isNull);
      expect(c.validation, contains('side'));
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
  test('bottle feeding requires a positive measured amount', () async {
    for (final method in [
      BabyFeedingMethod.expressedMilk,
      BabyFeedingMethod.formula,
    ]) {
      final repo = BabyTestRecords();
      final c = editor(repo, BabyRecordKind.feeding);
      addTearDown(c.dispose);
      c.setFeedingMethod(method);
      expect(c.canSave, isFalse);
      expect(await c.save(), isNull);
      expect(c.validation, contains('amount'));
      expect(repo.values, isEmpty);
      c.setVolume('0');
      expect(c.canSave, isFalse);
      c.setVolume('1001');
      expect(c.canSave, isFalse);
      c.setVolume('90');
      expect(c.canSave, isTrue);
      final saved = (await c.save())!.single as BabyFeedingRecord;
      expect(saved.method, method);
      expect(saved.volumeMl, 90);
    }
  });

  test(
    'failed growth batch retries the unchanged measurements with the same key',
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
    'legacy sleep editing after a failed response submits the revised end time',
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
      expect(result.endedAt, now);
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
    expect(c.validation, contains('date of birth'));
    c.setDate(LocalDate(2026, 9, 8));
    final result = (await c.save())!.single as BabyDevelopmentRecord;
    expect(result.recordedOn, LocalDate(2026, 9, 8));
    expect(result.timezone, 'Asia/Shanghai');
    expect(result.status, DevelopmentStatus.unsure);
  });
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
