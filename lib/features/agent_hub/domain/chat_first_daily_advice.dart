import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';

/// Editorial day 0–364 content. Each entry is immutable and independently
/// addressable. A missing or invalid entry must never silently show yesterday's.
enum DailyAdviceTopic { feeding, diaper, sleep, development, play, safety }

final class DailyAdviceEntry {
  const DailyAdviceEntry({
    required this.day,
    required this.topic,
    required this.text,
    required this.sourceIds,
  });
  final int day;
  final DailyAdviceTopic topic;
  final String text;
  final List<String> sourceIds;
}

final class DailyAdviceCatalog {
  DailyAdviceCatalog._(this.entries);
  final List<DailyAdviceEntry> entries;

  factory DailyAdviceCatalog.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 || json['entries'] is! List) {
      throw const FormatException('Invalid daily advice catalog.');
    }
    final values = (json['entries'] as List)
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid daily advice entry.');
          }
          final day = raw['day'];
          final text = raw['text'];
          final topic = raw['topic'];
          final sources = raw['source_ids'];
          const allowedSources = {
            'aap_feeding',
            'aap_stool',
            'cdc_solids',
            'cdc_sleep',
            'cdc_milestones',
            'cdc_choking',
          };
          if (day is! int ||
              text is! String ||
              topic is! String ||
              text.runes.length < 35 ||
              text.runes.length > 65 ||
              !text.contains('；') ||
              sources is! List ||
              sources.isEmpty ||
              sources.any(
                (source) =>
                    source is! String || !allowedSources.contains(source),
              )) {
            throw const FormatException('Invalid daily advice entry.');
          }
          final parsed = DailyAdviceTopic.values
              .where((value) => value.name == topic)
              .firstOrNull;
          if (parsed == null) {
            throw const FormatException('Unknown daily advice topic.');
          }
          return DailyAdviceEntry(
            day: day,
            topic: parsed,
            text: text,
            sourceIds: List<String>.unmodifiable(sources.cast<String>()),
          );
        })
        .toList(growable: false);
    if (values.length != 365 ||
        values.map((entry) => entry.text).toSet().length != 365 ||
        List.generate(365, (day) => day).any((day) => values[day].day != day)) {
      throw const FormatException(
        'Incomplete or duplicated daily advice catalog.',
      );
    }
    return DailyAdviceCatalog._(List.unmodifiable(values));
  }

  DailyAdviceEntry? entryFor(int day) =>
      day >= 0 && day < entries.length ? entries[day] : null;
}

final class ChatFirstDailyBanner {
  const ChatFirstDailyBanner({required this.ageDays, required this.advice});
  final int ageDays;
  final String? advice;
}

ChatFirstDailyBanner? dailyBannerFor(
  List<BabyProfile> babies, {
  required String selectedBabyId,
  required LocalDate today,
  required DailyAdviceCatalog catalog,
  List<BabyRecord> recentRecords = const [],
  DateTime? recentWindowStart,
  DateTime? now,
}) {
  final selected = selectedBabyId.trim();
  final baby = selected.isNotEmpty
      ? babies.where((item) => item.id == selected).firstOrNull
      : babies.length == 1
      ? babies.single
      : null;
  final days = baby?.ageDays(today);
  if (days == null) return null;
  return _banner(
    days,
    catalog: catalog,
    babyId: baby!.id,
    recentRecords: recentRecords,
    recentWindowStart: recentWindowStart,
    now: now,
  );
}

ChatFirstDailyBanner? dailyBannerFromDeliveryDate(
  LocalDate? deliveryDate,
  LocalDate today, {
  required DailyAdviceCatalog catalog,
}) {
  if (deliveryDate == null || deliveryDate.compareTo(today) > 0) return null;
  return _banner(today.daysSince(deliveryDate), catalog: catalog);
}

ChatFirstDailyBanner _banner(
  int days, {
  required DailyAdviceCatalog catalog,
  String? babyId,
  List<BabyRecord> recentRecords = const [],
  DateTime? recentWindowStart,
  DateTime? now,
}) {
  final entry = catalog.entryFor(days);
  if (entry == null) return ChatFirstDailyBanner(ageDays: days, advice: null);
  final count = babyId == null || recentWindowStart == null || now == null
      ? 0
      : recentRecords.where((record) {
          if (record.babyId != babyId ||
              record is! TimedBabyRecord ||
              record.occurredAt.isBefore(recentWindowStart) ||
              record.occurredAt.isAfter(now)) {
            return false;
          }
          return switch (entry.topic) {
            DailyAdviceTopic.feeding => record is BabyFeedingRecord,
            DailyAdviceTopic.diaper => record is BabyDiaperRecord,
            DailyAdviceTopic.sleep =>
              record is BabySleepRecord &&
                  record.endedAt != null &&
                  !record.endedAt!.isAfter(now),
            _ => false,
          };
        }).length;
  if (count == 0) {
    return ChatFirstDailyBanner(ageDays: days, advice: entry.text);
  }
  final prefix = switch (entry.topic) {
    DailyAdviceTopic.feeding => '近两天记录$count次喂养',
    DailyAdviceTopic.diaper => '近两天记录$count次换尿布',
    DailyAdviceTopic.sleep => '近两天记录$count段睡眠',
    _ => '',
  };
  // Keep the entire age-day editorial guidance; the record is an observed
  // context, not a diagnosis or a replacement for today's advice.
  final personalized = '$prefix；${entry.text}';
  return ChatFirstDailyBanner(
    ageDays: days,
    advice: personalized.runes.length <= 65 ? personalized : entry.text,
  );
}
