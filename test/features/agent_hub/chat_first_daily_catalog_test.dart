import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_daily_advice.dart';

void main() {
  late DailyAdviceCatalog catalog;
  setUpAll(() {
    catalog = DailyAdviceCatalog.fromJson(
      jsonDecode(
            File(
              'assets/content/baby_daily_advice_0_364.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>,
    );
  });

  test(
    'exactly 365 explicit unique entries with no missing or duplicated days',
    () {
      expect(catalog.entries.length, 365);
      expect(
        catalog.entries.map((e) => e.day).toList(),
        List.generate(365, (i) => i),
      );
      expect(catalog.entries.map((e) => e.text).toSet().length, 365);
      for (final entry in catalog.entries) {
        expect(
          entry.text.runes.length,
          inInclusiveRange(35, 65),
          reason: 'day ${entry.day}',
        );
        expect(entry.text, contains('；'), reason: 'day ${entry.day}');
        expect(entry.sourceIds, isNotEmpty, reason: 'day ${entry.day}');
        expect(entry.text, isNot(contains('今天一定')));
        expect(entry.text, isNot(contains('不用担心')));
      }
      expect(catalog.entryFor(365), isNull);
      expect(catalog.entryFor(-1), isNull);
    },
  );

  test('daily guidance is not a stage-prefixed repeating 21-day template', () {
    final guidance = catalog.entries
        .map((entry) => entry.text.split('；').skip(1).join('；'))
        .toList();
    expect(guidance.every((text) => text.isNotEmpty), isTrue);
    expect(
      catalog.entries.every((entry) => entry.text.runes.length >= 40),
      isTrue,
    );
    expect(
      guidance.toSet().length,
      365,
      reason: 'A unique week label must not conceal a repeated action.',
    );
    final meanLength =
        catalog.entries
            .map((entry) => entry.text.runes.length)
            .reduce((a, b) => a + b) /
        365;
    expect(meanLength, greaterThanOrEqualTo(43));
  });

  test(
    'without records returns that exact day, not a recurring stage suggestion',
    () {
      final today = LocalDate(2026, 10, 22);
      final baby = BabyProfile(
        id: 'baby',
        name: 'Baby',
        birthDate: today.addDays(-43),
      );
      final result = dailyBannerFor(
        [baby],
        selectedBabyId: 'baby',
        today: today,
        catalog: catalog,
      );
      expect(result?.ageDays, 43);
      expect(result?.advice, catalog.entryFor(43)?.text);
      expect(result?.advice, isNot(catalog.entryFor(44)?.text));
    },
  );

  test(
    'a record-derived line uses only selected baby, recent events, and the daily focus',
    () {
      final today = LocalDate(2026, 10, 22);
      final baby = BabyProfile(
        id: 'baby',
        name: 'Baby',
        birthDate: today.addDays(-42),
      );
      final feeding = BabyFeedingRecord(
        id: 'f1',
        babyId: 'baby',
        occurredAt: DateTime.utc(2026, 10, 21, 8),
        method: BabyFeedingMethod.breastfeeding,
        side: FeedingSide.left,
      );
      final old = BabyFeedingRecord(
        id: 'old',
        babyId: 'baby',
        occurredAt: DateTime.utc(2026, 10, 18, 8),
        method: BabyFeedingMethod.breastfeeding,
        side: FeedingSide.left,
      );
      final result = dailyBannerFor(
        [baby],
        selectedBabyId: 'baby',
        today: today,
        catalog: catalog,
        recentRecords: [feeding, old],
        recentWindowStart: DateTime.utc(2026, 10, 20, 16),
        now: DateTime.utc(2026, 10, 22, 8),
      );
      final base = catalog.entryFor(42)!.text;
      expect(catalog.entryFor(42)!.topic, DailyAdviceTopic.feeding);
      expect(result!.advice, contains('记录1次喂养'));
      expect(result.advice, contains(base.split('；').first));
      expect(result.advice, contains(base.split('；').last));
      expect(result.advice!.runes.length, lessThanOrEqualTo(65));
    },
  );

  test(
    'rejected stale, foreign, future and unrelated records never change day copy',
    () {
      final today = LocalDate(2026, 10, 22);
      final baby = BabyProfile(
        id: 'baby',
        name: 'Baby',
        birthDate: today.addDays(-42),
      );
      BabyFeedingRecord feed(String id, String owner, DateTime time) =>
          BabyFeedingRecord(
            id: id,
            babyId: owner,
            occurredAt: time,
            method: BabyFeedingMethod.breastfeeding,
            side: FeedingSide.left,
          );
      final base = catalog.entryFor(42)!.text;
      final result = dailyBannerFor(
        [baby],
        selectedBabyId: 'baby',
        today: today,
        catalog: catalog,
        recentWindowStart: DateTime.utc(2026, 10, 20, 16),
        now: DateTime.utc(2026, 10, 22, 8),
        recentRecords: [
          feed('foreign', 'other', DateTime.utc(2026, 10, 21, 8)),
          feed('old', 'baby', DateTime.utc(2026, 10, 19, 8)),
          feed('future', 'baby', DateTime.utc(2026, 10, 23, 8)),
        ],
      );
      expect(result?.advice, base);
    },
  );

  test('incomplete and duplicate catalog entries are rejected', () {
    final source =
        jsonDecode(
              File(
                'assets/content/baby_daily_advice_0_364.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final missing = Map<String, Object?>.from(source);
    missing['entries'] = List.of(source['entries'] as List)..removeLast();
    expect(() => DailyAdviceCatalog.fromJson(missing), throwsFormatException);
    final duplicate = Map<String, Object?>.from(source);
    final entries = List.of(source['entries'] as List);
    entries[43] = entries[42];
    duplicate['entries'] = entries;
    expect(() => DailyAdviceCatalog.fromJson(duplicate), throwsFormatException);
  });

  test('every day maps to its own topic source and correct age window', () {
    for (final entry in catalog.entries) {
      expect(entry.sourceIds, isNotEmpty);
      expect(entry.text.runes.length, inInclusiveRange(35, 65));
      if (entry.day < 168) {
        expect(entry.text, isNot(contains('已开始辅食')));
      }
      if (entry.topic == DailyAdviceTopic.sleep) {
        expect(entry.sourceIds, contains('cdc_sleep'));
      }
      if (entry.topic == DailyAdviceTopic.development ||
          entry.topic == DailyAdviceTopic.play) {
        expect(entry.sourceIds, contains('cdc_milestones'));
      }
    }
  });

  test(
    'record-driven personalization stays within length for all 365 days',
    () {
      final today = LocalDate(2026, 10, 22);
      for (final entry in catalog.entries) {
        final baby = BabyProfile(
          id: 'baby',
          name: 'Baby',
          birthDate: today.addDays(-entry.day),
        );
        final recordedAt = DateTime.utc(2026, 10, 21, 8);
        final event = switch (entry.topic) {
          DailyAdviceTopic.feeding => BabyFeedingRecord(
            id: 'feed',
            babyId: 'baby',
            occurredAt: recordedAt,
            method: BabyFeedingMethod.breastfeeding,
            side: FeedingSide.left,
          ),
          DailyAdviceTopic.diaper => BabyDiaperRecord(
            id: 'diaper',
            babyId: 'baby',
            occurredAt: recordedAt,
            kind: DiaperKind.wet,
          ),
          DailyAdviceTopic.sleep => BabySleepRecord(
            id: 'sleep',
            babyId: 'baby',
            occurredAt: recordedAt,
            endedAt: recordedAt.add(const Duration(hours: 1)),
          ),
          _ => null,
        };
        final result = dailyBannerFor(
          [baby],
          selectedBabyId: 'baby',
          today: today,
          catalog: catalog,
          recentRecords: [?event],
          recentWindowStart: DateTime.utc(2026, 10, 20, 16),
          now: DateTime.utc(2026, 10, 22, 8),
        )!;
        expect(
          result.advice!.runes.length,
          inInclusiveRange(35, 65),
          reason: 'day ${entry.day}',
        );
        if (event != null) {
          expect(result.advice, contains('记录1'), reason: 'day ${entry.day}');
        } else {
          expect(result.advice, entry.text);
        }
      }
    },
  );

  test('year boundary has no fabricated day-365 text', () {
    final today = LocalDate(2026, 10, 22);
    final baby = BabyProfile(
      id: 'baby',
      name: 'Baby',
      birthDate: today.addDays(-365),
    );
    final result = dailyBannerFor(
      [baby],
      selectedBabyId: 'baby',
      today: today,
      catalog: catalog,
    );
    expect(result?.ageDays, 365);
    expect(result?.advice, isNull);
  });
}
