import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_knowledge_content.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_knowledge_selection.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

void main() {
  test(
    'knowledge changes at local eight and ignores another baby and later events',
    () {
      final records = [
        BabyFeedingRecord(
          id: 'feed',
          babyId: 'baby',
          occurredAt: DateTime.utc(2026, 9, 7, 1),
          method: BabyFeedingMethod.formula,
        ),
        BabyDiaperRecord(
          id: 'diaper',
          babyId: 'baby',
          occurredAt: DateTime.utc(2026, 9, 8, 1),
          kind: DiaperKind.dirty,
        ),
        BabySleepRecord(
          id: 'foreign',
          babyId: 'other',
          occurredAt: DateTime.utc(2026, 9, 8, 23),
        ),
      ];
      BabyKnowledgeTopic topic(DateTime now) => selectBabyKnowledge(
        now: now,
        timezone: 'Asia/Shanghai',
        babyId: 'baby',
        records: records,
      );
      expect(topic(DateTime.utc(2026, 9, 8)), BabyKnowledgeTopic.feeding);
      expect(
        topic(DateTime.utc(2026, 9, 8, 23, 59)),
        BabyKnowledgeTopic.feeding,
      );
      expect(topic(DateTime.utc(2026, 9, 9)), BabyKnowledgeTopic.diaper);
    },
  );
  test(
    'dated measurements become eligible on the next completed date, without invented timestamps',
    () {
      final record = BabyGrowthRecord(
        id: 'growth',
        babyId: 'baby',
        recordedOn: LocalDate(2026, 9, 8),
        timezone: 'Asia/Shanghai',
        metric: GrowthMetric.weight,
        value: 4.2,
      );
      BabyKnowledgeTopic topic(DateTime now) => selectBabyKnowledge(
        now: now,
        timezone: 'Asia/Shanghai',
        babyId: 'baby',
        records: [record],
      );
      expect(
        topic(DateTime.utc(2026, 9, 8, 10)),
        isNot(BabyKnowledgeTopic.growth),
      );
      expect(topic(DateTime.utc(2026, 9, 9)), BabyKnowledgeTopic.growth);
    },
  );
  test(
    'daily sleep uses elapsed overlap while intake and nursing keep distinct known quantities',
    () {
      final now = DateTime.utc(2026, 9, 8, 10);
      final values = [
        BabySleepRecord(
          id: 'cross',
          babyId: 'baby',
          occurredAt: DateTime.utc(2026, 9, 7, 23),
          endedAt: DateTime.utc(2026, 9, 8, 2),
        ),
        BabySleepRecord(
          id: 'overlap',
          babyId: 'baby',
          occurredAt: DateTime.utc(2026, 9, 8, 1),
          endedAt: DateTime.utc(2026, 9, 8, 3),
        ),
        BabyFeedingRecord(
          id: 'unknown',
          babyId: 'baby',
          occurredAt: now,
          method: BabyFeedingMethod.formula,
        ),
        BabyFeedingRecord(
          id: 'nursing',
          babyId: 'baby',
          occurredAt: now,
          method: BabyFeedingMethod.breastfeeding,
          side: FeedingSide.both,
          durationMinutes: 12,
        ),
        BabyFeedingRecord(
          id: 'foreign',
          babyId: 'other',
          occurredAt: now,
          method: BabyFeedingMethod.expressedMilk,
          volumeMl: 90,
        ),
      ];
      final summary = BabyDaySummary.fromRecords(
        values,
        babyId: 'baby',
        window: zonedDayWindow(LocalDate(2026, 9, 8), 'UTC'),
        now: now,
      );
      expect(summary.sleepDuration, const Duration(hours: 3));
      expect(summary.sleepCount, 2);
      expect(summary.longestSleep, const Duration(hours: 2));
      expect(summary.feedingCount, 2);
      expect(summary.measuredIntakeMl, isNull);
      expect(summary.nursingMinutes, 12);
    },
  );
}
