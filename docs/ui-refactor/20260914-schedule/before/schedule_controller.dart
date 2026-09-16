import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/service_package.dart';
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
    this.catalog,
    this.error,
  });
  final SchedulePhase phase;
  final LocalDate month, selected;
  final SchedulePageData? page;
  final ServiceCatalog? catalog;
  final ProductFailure? error;
  ScheduleState copyWith({
    SchedulePhase? phase,
    LocalDate? month,
    LocalDate? selected,
    SchedulePageData? page,
    ServiceCatalog? catalog,
    ProductFailure? error,
    bool clearError = false,
  }) => ScheduleState(
    phase: phase ?? this.phase,
    month: month ?? this.month,
    selected: selected ?? this.selected,
    page: page ?? this.page,
    catalog: catalog ?? this.catalog,
    error: clearError ? null : error ?? this.error,
  );
}

final class ScheduleController extends ChangeNotifier {
  ScheduleController({
    required this.repository,
    required this.timezoneProvider,
    required this.catalogLoader,
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
  final Future<ServiceCatalog> Function() catalogLoader;
  final DateTime Function() _now;
  late ScheduleState state;
  bool _disposed = false;

  Future<void> load({LocalDate? selected}) async {
    final target = selected ?? state.selected;
    state = state.copyWith(
      phase: SchedulePhase.loading,
      selected: target,
      month: LocalDate(target.year, target.month, 1),
      clearError: true,
    );
    notifyListeners();
    try {
      final timezone = await timezoneProvider();
      final first = state.month;
      final gridStart = first.addDays(-(first.weekday - 1));
      final gridEnd = gridStart.addDays(42);
      final results = await Future.wait([
        repository.read(start: gridStart, end: gridEnd, timezone: timezone),
        catalogLoader(),
      ]);
      if (_disposed) return;
      state = state.copyWith(
        phase: SchedulePhase.ready,
        page: results[0] as SchedulePageData,
        catalog: results[1] as ServiceCatalog,
      );
    } catch (error) {
      if (_disposed) return;
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
    state = state.copyWith(
      selected: date,
      month: LocalDate(date.year, date.month, 1),
    );
    notifyListeners();
  }

  void shiftMonth(int amount) {
    final month = state.month.addMonths(amount);
    state = state.copyWith(month: month, selected: month);
    unawaited(load(selected: month));
  }

  Future<void> savePersonal({
    PersonalScheduleEntry? existing,
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    String? idempotencyKey,
  }) async {
    if (existing == null) {
      await repository.create(
        title: title,
        date: date,
        startTime: startTime,
        note: note,
        idempotencyKey:
            idempotencyKey ??
            'schedule-${DateTime.now().microsecondsSinceEpoch}',
      );
    } else {
      await repository.update(
        existing,
        title: title,
        date: date,
        startTime: startTime,
        note: note,
      );
    }
    await load(selected: date);
  }

  Future<void> deletePersonal(PersonalScheduleEntry entry) async {
    await repository.delete(entry);
    await load();
  }

  Future<void> updateTask(
    ScheduledPlan plan,
    PublishedCareTask task,
    CareTaskStatus status,
  ) async {
    await repository.updateTask(
      publicationId: plan.publication.id,
      sourceKey: task.content.sourceKey,
      expectedVersion: task.progressVersion,
      status: status,
    );
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
