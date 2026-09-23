import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/mutation_key.dart';
import '../../../shared/zoned_time.dart';

enum BabyDailyTab { mental, wet, stool }

class BabyRecordEditorController extends ChangeNotifier {
  BabyRecordEditorController({
    required this.repository,
    required this.baby,
    required String timezone,
    required this.now,
    required BabyRecordKind kind,
    this.initial,
    this.activeSleep,
    this.diaperKind,
    this.growthMetric = GrowthMetric.weight,
  }) : timezone = initial is DatedBabyRecord ? initial.timezone : timezone,
       kind = initial?.recordKind ?? kind {
    if (initial != null && initial!.babyId != baby.id ||
        activeSleep != null && activeSleep!.babyId != baby.id) {
      throw ArgumentError('Record belongs to another baby');
    }
    occurredAt = now();
    sleepStartedAt = activeSleep?.occurredAt ?? occurredAt;
    sleepEndedAt = activeSleep?.endedAt;
    sleepNote = activeSleep?.note ?? '';
    recordedOn = today;
    switch (initial) {
      case BabyFeedingRecord(
        :final method,
        :final side,
        :final volumeMl,
        :final durationMinutes,
        :final note,
        :final occurredAt,
      ):
        feedingMethod = method;
        feedingSide = side;
        volume = volumeMl?.toString() ?? '';
        duration = durationMinutes?.toString() ?? '';
        feedingNote = note;
        this.occurredAt = occurredAt;
      case BabyDiaperRecord(
        :final kind,
        :final color,
        :final consistency,
        :final signs,
        :final note,
        :final occurredAt,
      ):
        diaperKind = kind;
        stoolColor = color;
        stoolConsistency = consistency;
        stoolSigns = Set.of(signs);
        diaperNote = note;
        this.occurredAt = occurredAt;
      case BabySleepRecord(:final occurredAt, :final endedAt, :final note):
        sleepStartedAt = occurredAt;
        sleepEndedAt = endedAt;
        sleepNote = note;
      case BabyGrowthRecord(
        :final metric,
        :final value,
        :final recordedOn,
        :final measurementSource,
      ):
        this.measurementSource = measurementSource;
        growthMetric = metric;
        growthValues[metric] = value.toString();
        this.recordedOn = recordedOn;
      case BabyDevelopmentRecord(
        :final itemId,
        :final status,
        :final recordedOn,
      ):
        development[itemId] = status;
        this.recordedOn = recordedOn;
      case BabyDailyStatusRecord(
        :final mentalState,
        :final wetCount,
        :final stoolCount,
        :final color,
        :final consistency,
      ):
        this.mentalState = mentalState;
        this.wetCount = wetCount?.toString() ?? '';
        this.stoolCount = stoolCount?.toString() ?? '';
        stoolColor = color;
        stoolConsistency = consistency;
      case null:
        break;
    }
  }
  BabyDailyTab dailyTab = BabyDailyTab.mental;
  BabyMentalState? mentalState;
  String wetCount = '', stoolCount = '';
  bool bottleSelected = false;
  Completer<void>? _saveDone;
  List<BabyRecord>? lastSaved;
  Future<void> get settled => _saveDone?.future ?? Future.value();
  bool get isDaily => kind == BabyRecordKind.dailyStatus;
  bool get canSave {
    if (busy) return false;
    final oldValidation = validation, oldMetric = growthMetric;
    final valid = _draft() != null;
    validation = oldValidation;
    growthMetric = oldMetric;
    return valid;
  }

  void selectDailyTab(BabyDailyTab value) {
    if (!editable) return;
    dailyTab = value;
    notifyListeners();
  }

  void setMentalState(BabyMentalState? value) =>
      _edit(() => mentalState = value);
  void setWetCount(String value) => _edit(() => wetCount = value);
  void setStoolCount(String value) => _edit(() => stoolCount = value);
  void selectBottle(bool value) => _edit(() {
    bottleSelected = value;
    feedingMethod = value ? null : BabyFeedingMethod.breastfeeding;
  });
  final BabyRecordRepository repository;
  final BabyProfile baby;
  final String timezone;
  final DateTime Function() now;
  final BabyRecord? initial;
  final BabySleepRecord? activeSleep;
  BabyRecordKind kind;
  BabyFeedingMethod? feedingMethod;
  FeedingSide? feedingSide;
  String volume = '',
      duration = '',
      feedingNote = '',
      diaperNote = '',
      sleepNote = '';
  DiaperKind? diaperKind;
  StoolColor? stoolColor;
  StoolConsistency? stoolConsistency;
  Set<StoolSign> stoolSigns = {};
  late DateTime occurredAt, sleepStartedAt;
  DateTime? sleepEndedAt;
  late LocalDate recordedOn;
  GrowthMetric growthMetric;
  String? measurementSource;
  void setMeasurementSource(String? value) =>
      _edit(() => measurementSource = value);
  final growthValues = <GrowthMetric, String>{};
  final development = <String, DevelopmentStatus>{};
  bool dirty = false, busy = false, _disposed = false;
  String? validation;
  ProductFailure? failure;
  List<BabyRecord>? _pending;
  String? _key;
  bool get uncertain => _pending != null && !busy;
  bool get editable => !busy;
  bool get editing => initial != null;
  LocalDate get today => dateInTimezone(now(), timezone);
  BabyRecord? get target =>
      initial ?? (kind == BabyRecordKind.sleep ? activeSleep : null);
  bool get hasActiveSleep =>
      kind == BabyRecordKind.sleep &&
      target is BabySleepRecord &&
      (target as BabySleepRecord).endedAt == null;

  void _edit(VoidCallback update) {
    if (!editable || _disposed) return;
    update();
    _pending = null;
    _key = null;
    dirty = true;
    validation = null;
    failure = null;
    notifyListeners();
  }

  void setKind(BabyRecordKind value, {DiaperKind? diaper}) {
    if (editing ||
        ![BabyRecordKind.sleep, BabyRecordKind.diaper].contains(value)) {
      return;
    }
    _edit(() {
      kind = value;
      if (diaper != null) diaperKind = diaper;
    });
  }

  void setFeedingMethod(BabyFeedingMethod? value) =>
      _edit(() => feedingMethod = value);
  void setSide(FeedingSide? value) => _edit(() => feedingSide = value);
  void setVolume(String value) => _edit(() => volume = value);
  void setDuration(String value) => _edit(() => duration = value);
  void setOccurredAt(DateTime value) => _edit(() => occurredAt = value);
  void setDiaperKind(DiaperKind? value) => _edit(() => diaperKind = value);
  void setStoolColor(StoolColor? value) => _edit(() => stoolColor = value);
  void setStoolConsistency(StoolConsistency? value) =>
      _edit(() => stoolConsistency = value);
  void setStoolSigns(Set<StoolSign> value) =>
      _edit(() => stoolSigns = Set.of(value));
  void setSleepStart(DateTime value) => _edit(() => sleepStartedAt = value);
  void setSleepEnd(DateTime? value) => _edit(() => sleepEndedAt = value);
  void setNote(String value) => _edit(() {
    switch (kind) {
      case BabyRecordKind.feeding:
        feedingNote = value;
      case BabyRecordKind.diaper:
        diaperNote = value;
      case BabyRecordKind.sleep:
        sleepNote = value;
      default:
        break;
    }
  });
  String get note => switch (kind) {
    BabyRecordKind.feeding => feedingNote,
    BabyRecordKind.sleep => sleepNote,
    BabyRecordKind.diaper => diaperNote,
    _ => '',
  };
  void setDate(LocalDate value) => _edit(() => recordedOn = value);
  void selectMetric(GrowthMetric value) {
    if (editing && value != (initial as BabyGrowthRecord).metric) return;
    // Changing the visible metric preserves every entered measurement.
    if (editable) {
      growthMetric = value;
      notifyListeners();
    }
  }

  void setGrowthValue(GrowthMetric metric, String value) =>
      _edit(() => growthValues[metric] = value);
  void setDevelopment(String item, DevelopmentStatus? value) => _edit(() {
    if (value == null) {
      development.remove(item);
    } else {
      development[item] = value;
    }
  });

  List<BabyRecord>? _draft() {
    final id = target?.id ?? '', version = target?.version ?? 1;
    final babyId = baby.id;
    List<BabyRecord> records;
    switch (kind) {
      case BabyRecordKind.dailyStatus:
        int? count(String text) => int.tryParse(text.trim());
        if ((wetCount.trim().isNotEmpty && count(wetCount) == null) ||
            (stoolCount.trim().isNotEmpty && count(stoolCount) == null)) {
          return null;
        }
        records = [
          BabyDailyStatusRecord(
            id: id,
            babyId: babyId,
            version: version,
            recordedOn: today,
            timezone: timezone,
            savedAt: now(),
            mentalState: mentalState,
            wetCount: wetCount.trim().isEmpty ? null : count(wetCount),
            stoolCount: stoolCount.trim().isEmpty ? null : count(stoolCount),
            color: stoolColor,
            consistency: stoolConsistency,
          ),
        ];
      case BabyRecordKind.feeding:
        if (feedingMethod == null) {
          validation = '先选择这次的喂养方式。';
          return null;
        }
        final breast = feedingMethod == BabyFeedingMethod.breastfeeding;
        if (breast && feedingSide == null) {
          validation = '请选择这次亲喂的侧别。';
          return null;
        }
        if (breast &&
                duration.trim().isNotEmpty &&
                int.tryParse(duration.trim()) == null ||
            !breast &&
                volume.trim().isNotEmpty &&
                double.tryParse(volume.trim()) == null) {
          validation = breast ? '亲喂时长请填写整数分钟。' : '请检查瓶喂量。';
          return null;
        }
        records = [
          BabyFeedingRecord(
            id: id,
            babyId: babyId,
            version: version,
            occurredAt: occurredAt,
            method: feedingMethod!,
            side: breast ? feedingSide : null,
            volumeMl: breast || volume.trim().isEmpty
                ? null
                : double.parse(volume.trim()),
            durationMinutes: !breast || duration.trim().isEmpty
                ? null
                : int.parse(duration.trim()),
            note: feedingNote.trim(),
          ),
        ];
      case BabyRecordKind.diaper:
        if (diaperKind == null) {
          validation = '先选择这次换到的尿布。';
          return null;
        }
        final hasStool = diaperKind != DiaperKind.wet;
        records = [
          BabyDiaperRecord(
            id: id,
            babyId: babyId,
            version: version,
            occurredAt: occurredAt,
            kind: diaperKind!,
            color: hasStool ? stoolColor : null,
            consistency: hasStool ? stoolConsistency : null,
            signs: hasStool ? Set.unmodifiable(stoolSigns) : const {},
            note: diaperNote.trim(),
          ),
        ];
      case BabyRecordKind.sleep:
        records = [
          BabySleepRecord(
            id: id,
            babyId: babyId,
            version: version,
            occurredAt: sleepStartedAt,
            endedAt: sleepEndedAt,
            note: sleepNote.trim(),
          ),
        ];
      case BabyRecordKind.growth:
        final filled = growthValues.entries
            .where((entry) => entry.value.trim().isNotEmpty)
            .toList();
        if (filled.isEmpty) {
          validation = '请至少填写一项测量数值。';
          return null;
        }
        for (final entry in filled) {
          final value = double.tryParse(entry.value.trim());
          if (value == null ||
              !value.isFinite ||
              value <= 0 ||
              value > (entry.key == GrowthMetric.weight ? 50 : 150)) {
            growthMetric = entry.key;
            validation = '请检查测量数值和单位。体重为 kg，身长与头围为 cm。';
            return null;
          }
        }
        records = [
          for (final entry in filled)
            BabyGrowthRecord(
              id: id,
              babyId: babyId,
              version: version,
              recordedOn: recordedOn,
              timezone: timezone,
              metric: entry.key,
              measurementSource: measurementSource,
              value: double.parse(entry.value.trim()),
            ),
        ];
      case BabyRecordKind.development:
        if (development.isEmpty) {
          validation = '至少记录一项具体行为，拿不准可以选择“不确定”。';
          return null;
        }
        records = [
          for (final entry in development.entries)
            BabyDevelopmentRecord(
              id: id,
              babyId: babyId,
              version: version,
              recordedOn: recordedOn,
              timezone: timezone,
              itemId: entry.key,
              status: entry.value,
            ),
        ];
    }
    if (records.first is DatedBabyRecord) {
      if (recordedOn.compareTo(today) > 0) {
        validation = '记录日期不能晚于今天。';
        return null;
      }
      if (baby.birthDate != null && recordedOn.compareTo(baby.birthDate!) < 0) {
        validation = '记录日期不能早于宝宝出生日期。';
        return null;
      }
    }
    final errors = {
      for (final record in records)
        ...record.validate(inTimezone(now(), timezone)),
    };
    if (errors.isNotEmpty) {
      validation = errors.containsKey('occurred_at')
          ? '发生时间不能晚于现在。'
          : errors.containsKey('ended_at')
          ? '醒来时间需要晚于入睡时间，且不能晚于现在。'
          : errors.containsKey('volume_ml')
          ? '瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。'
          : errors.containsKey('duration_minutes')
          ? '亲喂时长需要为 1–240 分钟，也可以留空。'
          : errors.containsKey('note')
          ? '备注不能超过 2000 字。'
          : '请检查填写内容。';
      return null;
    }
    return List.unmodifiable(records);
  }

  Future<List<BabyRecord>?> save() async {
    if (busy || _disposed) return null;
    validation = null;
    failure = null;
    final records = _pending ?? _draft();
    if (records == null) {
      notifyListeners();
      return null;
    }
    _pending = records;
    _key ??= newMutationKey();
    busy = true;
    _saveDone = Completer<void>();
    notifyListeners();
    try {
      final saved = records.length > 1
          ? await repository.saveBatch(
              records.cast<DatedBabyRecord>(),
              idempotencyKey: _key!,
            )
          : [await repository.save(records.single, idempotencyKey: _key!)];
      if (_disposed) return null;
      _pending = null;
      _key = null;
      dirty = false;
      lastSaved = saved;
      return saved;
    } catch (error) {
      if (_disposed) return null;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      if (![
        ProductFailureKind.offline,
        ProductFailureKind.unavailable,
      ].contains(failure!.kind)) {
        _pending = null;
        _key = null;
      }
      return null;
    } finally {
      _saveDone?.complete();
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
