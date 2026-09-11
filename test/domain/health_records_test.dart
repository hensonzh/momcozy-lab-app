import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/lactation/lactation_record.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8, 12);
  final window = DayWindow(DateTime.utc(2026, 9, 8), DateTime.utc(2026, 9, 9));

  test(
    'calendar dates reject overflow and count days without DST arithmetic',
    () {
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDate.parse('2026-9-8'), throwsFormatException);
      expect(LocalDate(2026, 9, 8).daysSince(LocalDate(2026, 8, 18)), 21);
      expect(LocalDate(2026, 12, 31).addDays(1).toString(), '2027-01-01');
    },
  );

  test('milk summary is owner scoped, counts only measured pump volume', () {
    final records = [
      LactationRecord(
        id: 'p1',
        ownerUserId: 'mom',
        version: 1,
        observation: PumpObservation(
          occurredAt: now,
          side: BreastSide.left,
          volumeMl: 55,
        ),
      ),
      LactationRecord(
        id: 'p2',
        ownerUserId: 'mom',
        version: 1,
        observation: PumpObservation(occurredAt: now, side: BreastSide.right),
      ),
      LactationRecord(
        id: 'n1',
        ownerUserId: 'mom',
        version: 1,
        observation: NursingObservation(
          occurredAt: now,
          side: BreastSide.left,
          durationMinutes: 20,
        ),
      ),
      LactationRecord(
        id: 'other',
        ownerUserId: 'other-mom',
        version: 1,
        observation: PumpObservation(
          occurredAt: now,
          side: BreastSide.left,
          volumeMl: 300,
        ),
      ),
      LactationRecord(
        id: 'tomorrow',
        ownerUserId: 'mom',
        version: 1,
        observation: PumpObservation(
          occurredAt: window.end,
          side: BreastSide.left,
          volumeMl: 50,
        ),
      ),
    ];
    final summary = LactationDaySummary.fromRecords(
      records,
      ownerUserId: 'mom',
      window: window,
    );
    expect(summary.measuredVolumeMl, 55);
    expect(summary.pumpCount, 2);
    expect(summary.nursingCount, 1);
    expect(summary.nursingMinutes, 20);
    expect(summary.unmeasuredPumpCount, 1);
    expect(summary.recordCount, 3);
  });

  test('unrecorded milk and a measured zero are distinguishable', () {
    expect(
      LactationDaySummary.fromRecords(
        [],
        ownerUserId: 'mom',
        window: window,
      ).measuredVolumeMl,
      isNull,
    );
    final record = LactationRecord(
      id: 'p',
      ownerUserId: 'mom',
      version: 1,
      observation: PumpObservation(
        occurredAt: now,
        side: BreastSide.left,
        volumeMl: 0,
      ),
    );
    expect(
      LactationDaySummary.fromRecords(
        [record],
        ownerUserId: 'mom',
        window: window,
      ).measuredVolumeMl,
      0,
    );
  });

  test(
    'lactation rejects future times and invalid measurements but allows unknown',
    () {
      expect(
        PumpObservation(occurredAt: now, side: BreastSide.left).validate(now),
        isEmpty,
      );
      expect(
        PumpObservation(
          occurredAt: now.add(const Duration(minutes: 1)),
          side: BreastSide.left,
        ).validate(now),
        contains('occurred_at'),
      );
      expect(
        PumpObservation(
          occurredAt: now,
          side: BreastSide.left,
          volumeMl: double.nan,
        ).validate(now),
        contains('volume_ml'),
      );
      expect(
        PumpObservation(
          occurredAt: now,
          side: BreastSide.right,
          volumeMl: 2001,
        ).validate(now),
        contains('volume_ml'),
      );
      expect(
        NursingObservation(
          occurredAt: now,
          side: BreastSide.left,
          durationMinutes: 241,
        ).validate(now),
        contains('duration_minutes'),
      );
    },
  );

  test(
    'daily diary groups retain partial self reports without fake completion',
    () {
      const empty = MotherDiary();
      expect(empty.isEmpty, isTrue);
      const rest = MotherRest(total: SleepTotalBand.fourToFiveHours);
      final entry = empty.copyWith(
        rest: rest,
        mood: const MotherMood(tone: MoodTone.steady),
      );
      expect(entry.completedGroups, 2);
      expect(entry.rest.total, SleepTotalBand.fourToFiveHours);
      expect(entry.body.isEmpty, isTrue);
      expect(entry.copyWith(mood: const MotherMood()).completedGroups, 1);
    },
  );

  test(
    'baby records are isolated, nursing duration never increases intake',
    () {
      final records = <BabyRecord>[
        BabyFeedingRecord(
          id: 'f1',
          babyId: 'luna',
          occurredAt: now,
          method: BabyFeedingMethod.breastfeeding,
          durationMinutes: 20,
        ),
        BabyFeedingRecord(
          id: 'f2',
          babyId: 'luna',
          occurredAt: now,
          method: BabyFeedingMethod.expressedMilk,
          volumeMl: 60,
        ),
        BabyFeedingRecord(
          id: 'f3',
          babyId: 'milo',
          occurredAt: now,
          method: BabyFeedingMethod.formula,
          volumeMl: 100,
        ),
        BabyDiaperRecord(
          id: 'd1',
          babyId: 'luna',
          occurredAt: now,
          kind: DiaperKind.both,
        ),
        BabySleepRecord(
          id: 's1',
          babyId: 'luna',
          occurredAt: window.start.subtract(const Duration(hours: 1)),
          endedAt: window.start.add(const Duration(hours: 2)),
        ),
        BabySleepRecord(
          id: 's2',
          babyId: 'luna',
          occurredAt: now.subtract(const Duration(minutes: 30)),
        ),
      ];
      final summary = BabyDaySummary.fromRecords(
        records,
        babyId: 'luna',
        window: window,
        now: now,
      );
      expect(summary.feedingCount, 2);
      expect(summary.measuredIntakeMl, 60);
      expect(summary.wetCount, 1);
      expect(summary.dirtyCount, 1);
      expect(summary.sleepDuration, const Duration(hours: 2, minutes: 30));
      expect(summary.activeSleep?.id, 's2');
    },
  );

  test('sleep overlaps are counted once and bounded by the selected day', () {
    final records = [
      BabySleepRecord(
        id: 's1',
        babyId: 'luna',
        occurredAt: window.start,
        endedAt: window.start.add(const Duration(hours: 2)),
      ),
      BabySleepRecord(
        id: 's2',
        babyId: 'luna',
        occurredAt: window.start.add(const Duration(hours: 1)),
        endedAt: window.start.add(const Duration(hours: 3)),
      ),
    ];
    expect(
      BabyDaySummary.fromRecords(
        records,
        babyId: 'luna',
        window: window,
        now: now,
      ).sleepDuration,
      const Duration(hours: 3),
    );
  });
}
