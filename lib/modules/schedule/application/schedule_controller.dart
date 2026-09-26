import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../data/schedule_api_repository.dart';
import '../domain/schedule.dart';

enum SchedulePhase { loading, ready, failure }

final class ScheduleState {
  const ScheduleState({
    required this.phase,
    required this.month,
    required this.selected,
    this.page,
    this.error,
  });
  final SchedulePhase phase;
  final LocalDate month, selected;
  final SchedulePageData? page;
  final ProductFailure? error;
  ScheduleState copyWith({
    SchedulePhase? phase,
    LocalDate? month,
    LocalDate? selected,
    SchedulePageData? page,
    ProductFailure? error,
    bool clearError = false,
  }) => ScheduleState(
    phase: phase ?? this.phase,
    month: month ?? this.month,
    selected: selected ?? this.selected,
    page: page ?? this.page,
    error: clearError ? null : error ?? this.error,
  );
}

final class ScheduleController extends ChangeNotifier {
  ScheduleController({
    required this.repository,
    required this.timezoneProvider,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final today = _now();
    final current = LocalDate(today.year, today.month, today.day);
    state = ScheduleState(
      phase: SchedulePhase.loading,
      month: LocalDate(today.year, today.month, 1),
      selected: current,
    );
  }
  final ScheduleRepository repository;
  final Future<String> Function() timezoneProvider;
  final DateTime Function() _now;
  late ScheduleState state;
  bool _disposed = false;
  int _loadGeneration = 0;
  LocalDate? _loadedMonth, _activeTarget;
  Future<void>? _activeLoad;
  bool get hasCurrentMonth => _loadedMonth == state.month;

  Future<void> load({LocalDate? selected}) {
    if (_disposed) return Future.value();
    final target = selected ?? state.selected;
    if (_activeLoad != null && _activeTarget == target) return _activeLoad!;
    final generation = ++_loadGeneration;
    _activeTarget = target;
    final request = _read(target, generation);
    _activeLoad = request;
    return request.whenComplete(() {
      if (generation == _loadGeneration) {
        _activeLoad = null;
        _activeTarget = null;
      }
    });
  }

  Future<void> _read(LocalDate target, int generation) async {
    final month = LocalDate(target.year, target.month, 1);
    state = state.copyWith(
      phase: SchedulePhase.loading,
      selected: target,
      month: month,
      clearError: true,
    );
    notifyListeners();
    try {
      final timezone = await timezoneProvider();
      final start = month.addDays(1 - month.weekday);
      final page = await repository.read(
        start: start,
        end: start.addDays(42),
        timezone: timezone,
      );
      if (_disposed || generation != _loadGeneration) return;
      _loadedMonth = month;
      state = state.copyWith(
        phase: SchedulePhase.ready,
        page: page,
        clearError: true,
      );
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      state = state.copyWith(
        phase: SchedulePhase.failure,
        error: error is ProductFailure
            ? error
            : const ProductFailure(ProductFailureKind.unavailable),
      );
    }
    if (!_disposed) notifyListeners();
  }

  void select(LocalDate date) {
    if (_disposed) return;
    final month = LocalDate(date.year, date.month, 1);
    final sameScope =
        month == _loadedMonth ||
        (_activeTarget != null &&
            month == LocalDate(_activeTarget!.year, _activeTarget!.month, 1));
    if (month == _loadedMonth &&
        _activeTarget != null &&
        month != LocalDate(_activeTarget!.year, _activeTarget!.month, 1)) {
      _invalidateReads();
      state = state.copyWith(phase: SchedulePhase.ready, clearError: true);
    }
    state = state.copyWith(selected: date, month: month);
    if (sameScope) {
      notifyListeners();
    } else {
      unawaited(load(selected: date));
    }
  }

  void shiftMonth(int amount) => select(state.selected.addMonths(amount));

  void _invalidateReads() {
    ++_loadGeneration;
    _activeLoad = null;
    _activeTarget = null;
  }

  Future<PersonalScheduleEntry> savePersonal({
    PersonalScheduleEntry? existing,
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    String? idempotencyKey,
  }) async {
    final PersonalScheduleEntry saved;
    if (existing == null) {
      saved = await repository.create(
        title: title,
        date: date,
        startTime: startTime,
        note: note,
        idempotencyKey:
            idempotencyKey ??
            'schedule-${DateTime.now().microsecondsSinceEpoch}',
      );
    } else {
      saved = await repository.update(
        existing,
        title: title,
        date: date,
        startTime: startTime,
        note: note,
      );
    }
    if (_disposed) return saved;
    _invalidateReads();
    if (state.page != null) {
      state = state.copyWith(
        phase: SchedulePhase.ready,
        clearError: true,
        selected: saved.date,
        month: LocalDate(saved.date.year, saved.date.month, 1),
        page: state.page!.copyWith(
          personal: [
            ...state.page!.personal.where((entry) => entry.id != saved.id),
            saved,
          ],
        ),
      );
      notifyListeners();
    }
    if (state.page == null || _loadedMonth != state.month) {
      await load(selected: saved.date);
    }
    return saved;
  }

  Future<void> deletePersonal(PersonalScheduleEntry entry) async {
    await repository.delete(entry);
    if (_disposed) return;
    _invalidateReads();
    if (state.page == null) {
      await load();
      return;
    }
    state = state.copyWith(
      phase: SchedulePhase.ready,
      clearError: true,
      page: state.page!.copyWith(
        personal: state.page!.personal.where((e) => e.id != entry.id).toList(),
      ),
    );
    notifyListeners();
    if (_loadedMonth != state.month) {
      await load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
