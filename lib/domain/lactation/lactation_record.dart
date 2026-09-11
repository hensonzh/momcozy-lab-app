import '../shared/local_date.dart';
import '../shared/record_deletion.dart';

enum BreastSide { left, right }

enum BreastComfort { comfortable, full, painful, uncertain }

sealed class LactationObservation {
  const LactationObservation({
    required this.occurredAt,
    required this.side,
    this.feeling,
    this.note = '',
  });
  final DateTime occurredAt;
  final BreastSide side;
  final BreastComfort? feeling;
  final String note;

  Map<String, String> validate(DateTime now) => {
    if (occurredAt.isAfter(now)) 'occurred_at': 'future_time',
    if (note.length > 2000) 'note': 'too_long',
  };
}

final class PumpObservation extends LactationObservation {
  const PumpObservation({
    required super.occurredAt,
    required super.side,
    this.volumeMl,
    super.feeling,
    super.note,
  });
  final double? volumeMl;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (volumeMl != null &&
        (!volumeMl!.isFinite || volumeMl! < 0 || volumeMl! > 2000))
      'volume_ml': 'out_of_range',
  };
}

final class NursingObservation extends LactationObservation {
  const NursingObservation({
    required super.occurredAt,
    required super.side,
    this.durationMinutes,
    super.feeling,
    super.note,
  });
  final int? durationMinutes;
  @override
  Map<String, String> validate(DateTime now) => {
    ...super.validate(now),
    if (durationMinutes != null &&
        (durationMinutes! < 0 || durationMinutes! > 240))
      'duration_minutes': 'out_of_range',
  };
}

final class LactationRecord {
  const LactationRecord({
    required this.id,
    required this.ownerUserId,
    required this.version,
    required this.observation,
  });
  final String id;
  final String ownerUserId;
  final int version;
  final LactationObservation observation;
}

final class LactationDaySummary {
  const LactationDaySummary._({
    required this.pumpCount,
    required this.nursingCount,
    required this.measuredVolumeMl,
    required this.unmeasuredPumpCount,
    required this.nursingMinutes,
  });
  factory LactationDaySummary.fromRecords(
    Iterable<LactationRecord> records, {
    required String ownerUserId,
    required DayWindow window,
  }) {
    var pumps = 0;
    var nurses = 0;
    var unmeasured = 0;
    double? ml;
    int? minutes;
    for (final record in records) {
      final observation = record.observation;
      if (record.ownerUserId != ownerUserId ||
          !window.contains(observation.occurredAt)) {
        continue;
      }
      switch (observation) {
        case PumpObservation(:final volumeMl):
          pumps++;
          if (volumeMl == null) {
            unmeasured++;
          } else {
            ml = (ml ?? 0) + volumeMl;
          }
        case NursingObservation(:final durationMinutes):
          nurses++;
          if (durationMinutes != null) {
            minutes = (minutes ?? 0) + durationMinutes;
          }
      }
    }
    return LactationDaySummary._(
      pumpCount: pumps,
      nursingCount: nurses,
      measuredVolumeMl: ml,
      unmeasuredPumpCount: unmeasured,
      nursingMinutes: minutes,
    );
  }
  final int pumpCount;
  final int nursingCount;
  final double? measuredVolumeMl;
  final int unmeasuredPumpCount;
  final int? nursingMinutes;
  int get recordCount => pumpCount + nursingCount;
}

abstract interface class LactationRepository {
  Future<List<LactationRecord>> list(DayWindow window);
  Future<LactationRecord> create(
    LactationObservation observation, {
    required String idempotencyKey,
  });
  Future<LactationRecord> update(
    String id,
    LactationObservation observation, {
    required int expectedVersion,
  });
  Future<RecordDeletion> delete(String id, {required int expectedVersion});
  Future<LactationRecord> restore(String id, {required int expectedVersion});
}
