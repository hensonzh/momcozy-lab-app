import 'package:flutter/foundation.dart';
import '../../../domain/lactation/lactation_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../domain/shared/record_deletion.dart';
import '../../../shared/mutation_key.dart';

enum LactationMethod { pump, nurse }

final class LactationDraft {
  const LactationDraft({
    required this.occurredAt,
    this.method = LactationMethod.pump,
    this.side = BreastSide.left,
    this.measurement = '',
    this.feeling,
    this.note = '',
  });
  factory LactationDraft.fromObservation(LactationObservation value) =>
      LactationDraft(
        occurredAt: value.occurredAt.toLocal(),
        side: value.side,
        feeling: value.feeling,
        note: value.note,
        method: value is PumpObservation
            ? LactationMethod.pump
            : LactationMethod.nurse,
        measurement: switch (value) {
          PumpObservation(:final volumeMl) =>
            volumeMl == null ? '' : '$volumeMl',
          NursingObservation(:final durationMinutes) =>
            durationMinutes == null ? '' : '$durationMinutes',
        },
      );
  final DateTime occurredAt;
  final LactationMethod method;
  final BreastSide side;
  final String measurement;
  final BreastComfort? feeling;
  final String note;

  LactationDraft copyWith({
    DateTime? occurredAt,
    LactationMethod? method,
    BreastSide? side,
    String? measurement,
    BreastComfort? Function()? feeling,
    String? note,
  }) => LactationDraft(
    occurredAt: occurredAt ?? this.occurredAt,
    method: method ?? this.method,
    side: side ?? this.side,
    measurement: method != null && method != this.method
        ? ''
        : measurement ?? this.measurement,
    feeling: feeling != null ? feeling() : this.feeling,
    note: note ?? this.note,
  );

  LactationObservation get observation => switch (method) {
    LactationMethod.pump => PumpObservation(
      occurredAt: occurredAt,
      side: side,
      feeling: feeling,
      note: note.trim(),
      volumeMl: measurement.trim().isEmpty
          ? null
          : double.tryParse(measurement.trim()),
    ),
    LactationMethod.nurse => NursingObservation(
      occurredAt: occurredAt,
      side: side,
      feeling: feeling,
      note: note.trim(),
      durationMinutes: measurement.trim().isEmpty
          ? null
          : int.tryParse(measurement.trim()),
    ),
  };

  Map<String, String> errors(DateTime now) => {
    ...observation.validate(now),
    if (measurement.trim().isNotEmpty &&
        (method == LactationMethod.pump
            ? double.tryParse(measurement.trim()) == null
            : int.tryParse(measurement.trim()) == null))
      'measurement': 'invalid_number',
  };
}

/// The same create key and submitted draft survive an uncertain network result.
class LactationController extends ChangeNotifier {
  LactationController({
    required this.repository,
    required this.ownerUserId,
    required this.date,
    required this.now,
    String Function()? mutationKey,
  }) : mutationKey = mutationKey ?? newMutationKey;
  final LactationRepository repository;
  final String ownerUserId;
  final LocalDate date;
  final DateTime Function() now;
  final String Function() mutationKey;
  List<LactationRecord> records = const [];
  bool loading = true;
  bool busy = false;
  bool loaded = false;
  ProductFailure? failure;
  LactationDraft? draft;
  LactationRecord? editing;
  RecordDeletion? deletion;
  Map<String, String> validationErrors = const {};
  String? _key;
  LactationObservation? _pending;
  bool _disposed = false;
  int _generation = 0;
  bool get uncertainSave => _pending != null && !busy;
  bool get canEdit => draft != null && !busy && !uncertainSave;
  List<LactationRecord> get todayRecords => List.unmodifiable(
    records.where(
      (record) =>
          record.ownerUserId == ownerUserId &&
          date.localWindow.contains(record.observation.occurredAt),
    ),
  );
  LactationDaySummary summary(LocalDate day) => LactationDaySummary.fromRecords(
    records,
    ownerUserId: ownerUserId,
    window: day.localWindow,
  );

  Future<void> load() async {
    if (busy) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.list(
        DayWindow(date.addDays(-29).localWindow.start, date.localWindow.end),
      );
      if (_disposed || generation != _generation) return;
      records = List.unmodifiable(
        result.where((record) => record.ownerUserId == ownerUserId),
      );
      loaded = true;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      failure = _failure(error);
    }
    loading = false;
    notifyListeners();
  }

  void begin([LactationRecord? record]) {
    if (busy || loading || !loaded) return;
    editing = record;
    final instant = now().toLocal();
    draft = record == null
        ? LactationDraft(
            occurredAt: date == LocalDate.fromDateTime(instant)
                ? instant
                : DateTime(date.year, date.month, date.day, 12),
          )
        : LactationDraft.fromObservation(record.observation);
    _key = mutationKey();
    _pending = null;
    validationErrors = const {};
    failure = null;
    notifyListeners();
  }

  void edit(LactationDraft value) {
    if (!canEdit) return;
    draft = value;
    validationErrors = const {};
    failure = null;
    notifyListeners();
  }

  void cancel() {
    if (busy) return;
    draft = null;
    editing = null;
    _pending = null;
    _key = null;
    validationErrors = const {};
    failure = null;
    notifyListeners();
  }

  Future<bool> save() async {
    final value = draft;
    if (value == null || busy) return false;
    validationErrors = value.errors(now());
    if (validationErrors.isNotEmpty) {
      notifyListeners();
      return false;
    }
    final observation = _pending ?? value.observation;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final original = editing;
      final result = original == null
          ? await repository.create(observation, idempotencyKey: _key!)
          : await repository.update(
              original.id,
              observation,
              expectedVersion: original.version,
            );
      if (_disposed) return false;
      _upsert(result);
      busy = false;
      cancel();
      return true;
    } catch (error) {
      if (_disposed) return false;
      failure = _failure(error);
      _pending = switch (failure!.kind) {
        ProductFailureKind.offline ||
        ProductFailureKind.unavailable => observation,
        _ => null,
      };
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(LactationRecord record) async {
    if (busy || draft != null) return false;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final receipt = await repository.delete(
        record.id,
        expectedVersion: record.version,
      );
      if (_disposed) return false;
      deletion = receipt;
      records = List.unmodifiable(
        records.where((item) => item.id != record.id),
      );
      busy = false;
      notifyListeners();
      return true;
    } catch (error) {
      if (_disposed) return false;
      failure = _failure(error);
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> undoDelete() async {
    final receipt = deletion;
    if (receipt == null || busy) return;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.restore(
        receipt.id,
        expectedVersion: receipt.version,
      );
      if (_disposed) return;
      _upsert(result);
      deletion = null;
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
    }
    busy = false;
    notifyListeners();
  }

  void _upsert(LactationRecord record) {
    records = List.unmodifiable(
      [record, ...records.where((item) => item.id != record.id)]..sort(
        (a, b) => b.observation.occurredAt.compareTo(a.observation.occurredAt),
      ),
    );
  }

  ProductFailure _failure(Object error) => error is ProductFailure
      ? error
      : const ProductFailure(ProductFailureKind.unavailable);
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
