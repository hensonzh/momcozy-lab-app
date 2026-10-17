import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:uuid/uuid.dart';

/// Choices accepted by the existing owner-scoped Me observation contract.
/// There is no free-form health assessment in this entry point.
const chatFirstWellbeingChoices = <MeMetric, List<String>>{
  MeMetric.energy: ['有力气', '还撑得住', '很疲惫'],
  MeMetric.sleep: ['少于 3 小时', '3–4 小时', '4–5 小时', '5–6 小时', '6 小时以上', '不确定'],
  MeMetric.mood: ['不太好', '一般', '不错'],
};

/// These are only the maternal facts actually collected by chat-first setup.
class ChatFirstMotherSummary {
  const ChatFirstMotherSummary({
    required this.age,
    required this.deliveryCount,
    required this.deliveryDate,
    required this.gestationWeeks,
    required this.gestationDays,
    required this.babyCount,
    required this.concerns,
  });

  final int age;
  final int deliveryCount;
  final String deliveryDate;
  final int gestationWeeks;
  final int gestationDays;
  final int babyCount;
  final List<String> concerns;

  factory ChatFirstMotherSummary.fromMap(Map<String, Object?> response) {
    final rawProfile = response['profile'];
    final rawConcerns = response['concerns'];
    if (rawProfile is! Map || rawConcerns is! List) {
      throw const FormatException('Incomplete maternal profile.');
    }
    final profile = Map<String, Object?>.from(rawProfile);
    final age = profile['age'];
    final deliveryCount = profile['delivery_count'];
    final deliveryDate = profile['actual_delivery_date'];
    final gestationWeeks = profile['gestation_weeks'];
    final gestationDays = profile['gestation_days'];
    final babyCount = profile['baby_count'];
    if (age is! int ||
        deliveryCount is! int ||
        deliveryDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(deliveryDate) ||
        DateTime.tryParse(deliveryDate) == null ||
        gestationWeeks is! int ||
        gestationDays is! int ||
        babyCount is! int) {
      throw const FormatException('Incomplete maternal profile.');
    }
    return ChatFirstMotherSummary(
      age: age,
      deliveryCount: deliveryCount,
      deliveryDate: deliveryDate,
      gestationWeeks: gestationWeeks,
      gestationDays: gestationDays,
      babyCount: babyCount,
      concerns: [
        for (final raw in rawConcerns)
          if (raw is Map &&
              raw['ended'] != true &&
              raw['note'] is String &&
              (raw['note'] as String).trim().isNotEmpty)
            (raw['note'] as String).trim(),
      ],
    );
  }
}

class ChatFirstMotherRepository {
  const ChatFirstMotherRepository(this.transport);

  final ApiJsonTransport transport;

  Future<ChatFirstMotherSummary> get(DateTime now) async {
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, local.day);
    final end = DateTime(local.year, local.month, local.day + 1);
    final response = await transport.getJson(
      '/v1/profile/me-experience',
      query: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    );
    return ChatFirstMotherSummary.fromMap(response);
  }

  Future<ChatFirstPumpingToday> getPumpingToday(DateTime now) async =>
      ChatFirstPumpingToday(
        await RecordsApiRepository(
          transport: transport,
        ).fetchPumpMilkRecords(date: now),
      );

  Future<ChatFirstWellbeing> getWellbeing(DateTime now) async {
    final local = now.toLocal();
    Future<ChatFirstWellbeingDay> readDay(int offset) async {
      final date = DateTime(local.year, local.month, local.day + offset);
      final end = DateTime(local.year, local.month, local.day + offset + 1);
      final response = await transport.getJson(
        '/v1/profile/me-experience',
        query: {
          'start': date.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );
      final rawRecords = response['records'];
      if (rawRecords is! List) {
        throw const FormatException('Maternal status records are unavailable.');
      }
      final records = <MeObservation>[];
      for (final raw in rawRecords) {
        if (raw is! Map) {
          throw const FormatException('Invalid maternal status record.');
        }
        if (!const {'energy', 'sleep', 'mood', 'pain'}.contains(raw['kind'])) {
          continue;
        }
        final record = MeObservation.fromJson(Map<String, Object?>.from(raw));
        final at = record.occurredAt.toLocal();
        if (at.year == date.year &&
            at.month == date.month &&
            at.day == date.day) {
          records.add(record);
        }
      }
      records.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return ChatFirstWellbeingDay(date: date, records: records);
    }

    return ChatFirstWellbeing(await Future.wait([readDay(-1), readDay(0)]));
  }

  Future<MeObservation> saveWellbeing({
    required String id,
    required MeMetric kind,
    required String value,
    required DateTime occurredAt,
  }) async {
    if (!Uuid.isValidUUID(fromString: id) ||
        chatFirstWellbeingChoices[kind]?.contains(value) != true) {
      throw const FormatException('Unsupported self-reported status.');
    }
    if (transport is! ApiJsonMutationTransport) {
      throw UnsupportedError('Maternal status saves are unavailable.');
    }
    final record = MeObservation(
      id: id,
      kind: kind,
      occurredAt: occurredAt,
      value: value,
    );
    final response = await (transport as ApiJsonMutationTransport).putJson(
      '/v1/profile/me-experience/records/$id',
      body: record.toJson(),
    );
    final saved = MeObservation.fromJson(response);
    if (saved.id != id ||
        saved.kind != kind ||
        saved.value != value ||
        saved.occurredAt.toUtc() != occurredAt.toUtc()) {
      throw const FormatException('Maternal status save was not confirmed.');
    }
    return saved;
  }

  Future<ChatFirstMilkTrend> getMilkTrend(
    DateTime now, {
    required String timezone,
  }) async {
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, local.day - 6);
    final days = await RecordsApiRepository(
      transport: transport,
    ).fetchMilkTrends(startDate: start, days: 7, timezone: timezone);
    if (days.length != 7) {
      throw const FormatException('Incomplete seven-day trend response.');
    }
    for (var index = 0; index < days.length; index++) {
      final expected = DateTime(start.year, start.month, start.day + index);
      if (days[index].date != expected) {
        throw const FormatException('Unexpected trend calendar day.');
      }
    }
    return ChatFirstMilkTrend(days);
  }
}

/// Reads the same owner-scoped pumping endpoint used by chat-first record saves.
/// A missing amount is not treated as zero when presenting a measured total.
class ChatFirstPumpingToday {
  ChatFirstPumpingToday(List<PumpMilkRecord> records)
    : records = List.unmodifiable(records),
      measuredVolumeMl =
          records.length < 100 &&
              records.every((record) => record.measuredVolumeMl != null)
          ? records.fold<double>(
              0,
              (total, record) => total + record.measuredVolumeMl!,
            )
          : null;

  final List<PumpMilkRecord> records;
  final double? measuredVolumeMl;

  int get count => records.length;
  // The Product list contract caps this response at 100 without pagination.
  bool get mayBeTruncated => count == 100;
}

/// Seven actual calendar days; never present a partial aggregate as a daily average.
class ChatFirstMilkTrend {
  ChatFirstMilkTrend(List<MilkTrendDay> days) : days = List.unmodifiable(days);

  final List<MilkTrendDay> days;

  bool get hasSavedPumping => days.any((day) => day.pumpingCount > 0);

  bool get hasCompleteWindow {
    if (days.length != 7 || days.any((day) => !day.complete)) return false;
    for (var index = 1; index < days.length; index++) {
      final previous = days[index - 1].date;
      final expected = DateTime(
        previous.year,
        previous.month,
        previous.day + 1,
      );
      if (days[index].date != expected) return false;
    }
    return true;
  }

  double? get averageDailyMl {
    if (!hasCompleteWindow ||
        !hasSavedPumping ||
        days.any((day) => day.measuredVolumeMl == null)) {
      return null;
    }
    return days.fold<double>(0, (total, day) => total + day.measuredVolumeMl!) /
        7;
  }
}

/// Only recorded maternal state observations, never inferred health status.
class ChatFirstWellbeingDay {
  ChatFirstWellbeingDay({
    required this.date,
    required List<MeObservation> records,
  }) : records = List.unmodifiable(records);

  final DateTime date;
  final List<MeObservation> records;
}

class ChatFirstWellbeing {
  ChatFirstWellbeing(List<ChatFirstWellbeingDay> days)
    : days = List.unmodifiable(days);

  final List<ChatFirstWellbeingDay> days;
  int get recordCount => days.fold(0, (sum, day) => sum + day.records.length);
}
