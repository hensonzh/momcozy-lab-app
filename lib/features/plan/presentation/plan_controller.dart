import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';

enum PlanLoadPhase { loading, empty, success, error }

enum PlanPeriod { day, month }

enum PlanSurface { overview, detail }

@immutable
class PlanViewState {
  const PlanViewState({
    required this.phase,
    required this.weekOf,
    this.dashboard,
    this.selectedPlanId,
    this.errorMessage,
    this.period = PlanPeriod.day,
    this.surface = PlanSurface.overview,
  });

  final PlanLoadPhase phase;
  final DateTime weekOf;
  final PlanDashboard? dashboard;
  final String? selectedPlanId;
  final String? errorMessage;
  final PlanPeriod period;
  final PlanSurface surface;

  CarePlan? get selectedPlan {
    final plans = dashboard?.plans ?? const <CarePlan>[];
    if (plans.isEmpty) return null;
    for (final plan in plans) {
      if (plan.id == selectedPlanId) return plan;
    }
    return plans.first;
  }
}

class PlanController extends ChangeNotifier {
  PlanController({required this.repository, required DateTime initialWeek})
    : _state = _initialState(repository, initialWeek);

  final PlanRepository repository;
  PlanViewState _state;
  int _loadGeneration = 0;

  PlanViewState get state => _state;

  bool get canEditSessions => repository is PlanSessionMutationRepository;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final weekOf = _state.weekOf;
    _state = PlanViewState(
      phase: PlanLoadPhase.loading,
      weekOf: weekOf,
      dashboard: _state.dashboard,
      selectedPlanId: _state.selectedPlanId,
      period: _state.period,
      surface: _state.surface,
    );
    notifyListeners();
    try {
      final dashboard = await repository.fetchDashboard(weekOf: weekOf);
      if (generation != _loadGeneration) return;
      final keepsSelectedPlan = dashboard.plans.any(
        (plan) => plan.id == _state.selectedPlanId,
      );
      final selectedPlanId = keepsSelectedPlan
          ? _state.selectedPlanId
          : dashboard.plans.firstOrNull?.id;
      _state = PlanViewState(
        phase: dashboard.isEmpty ? PlanLoadPhase.empty : PlanLoadPhase.success,
        weekOf: weekOf,
        dashboard: dashboard,
        selectedPlanId: selectedPlanId,
        period: _state.period,
        surface: dashboard.isEmpty || !keepsSelectedPlan
            ? PlanSurface.overview
            : _state.surface,
      );
    } catch (_) {
      if (generation != _loadGeneration) return;
      _state = PlanViewState(
        phase: PlanLoadPhase.error,
        weekOf: weekOf,
        dashboard: _state.dashboard,
        selectedPlanId: _state.selectedPlanId,
        errorMessage: 'Plans could not be loaded.',
        period: _state.period,
        surface: _state.surface,
      );
    }
    notifyListeners();
  }

  void selectPlan(String planId) {
    final dashboard = _state.dashboard;
    if (dashboard == null ||
        !dashboard.plans.any((plan) => plan.id == planId) ||
        planId == _state.selectedPlanId) {
      return;
    }
    _state = PlanViewState(
      phase: _state.phase,
      weekOf: _state.weekOf,
      dashboard: dashboard,
      selectedPlanId: planId,
      period: _state.period,
      surface: _state.surface,
    );
    notifyListeners();
  }

  void openPlanDetails(String planId) {
    final dashboard = _state.dashboard;
    if (dashboard == null ||
        !dashboard.plans.any((plan) => plan.id == planId)) {
      return;
    }
    if (_state.selectedPlanId == planId &&
        _state.surface == PlanSurface.detail) {
      return;
    }
    _state = PlanViewState(
      phase: _state.phase,
      weekOf: _state.weekOf,
      dashboard: dashboard,
      selectedPlanId: planId,
      errorMessage: _state.errorMessage,
      period: _state.period,
      surface: PlanSurface.detail,
    );
    notifyListeners();
  }

  void showOverview() {
    if (_state.surface == PlanSurface.overview) return;
    _state = PlanViewState(
      phase: _state.phase,
      weekOf: _state.weekOf,
      dashboard: _state.dashboard,
      selectedPlanId: _state.selectedPlanId,
      errorMessage: _state.errorMessage,
      period: _state.period,
      surface: PlanSurface.overview,
    );
    notifyListeners();
  }

  void selectPeriod(PlanPeriod period) {
    if (_state.period == period) return;
    _state = PlanViewState(
      phase: _state.phase,
      weekOf: _state.weekOf,
      dashboard: _state.dashboard,
      selectedPlanId: _state.selectedPlanId,
      errorMessage: _state.errorMessage,
      period: period,
      surface: _state.surface,
    );
    notifyListeners();
  }

  Future<void> selectDay(DateTime value) async {
    final selectedDay = _dateOnly(value);
    if (selectedDay == _state.weekOf) return;
    _state = PlanViewState(
      phase: PlanLoadPhase.loading,
      weekOf: selectedDay,
      dashboard: _state.dashboard,
      selectedPlanId: _state.selectedPlanId,
      period: _state.period,
      surface: _state.surface,
    );
    notifyListeners();
    await load();
  }

  Future<void> browseWeek(int direction) async {
    if (direction == 0) return;
    await selectDay(_state.weekOf.add(Duration(days: direction * 7)));
  }

  Future<void> updateSession({
    required String sessionId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    if (repository is! PlanSessionMutationRepository) {
      throw UnsupportedError('This Plan source does not support editing.');
    }
    final mutationRepository = repository as PlanSessionMutationRepository;
    await mutationRepository.updateSession(
      sessionId: sessionId,
      title: title,
      scheduledAt: scheduledAt,
    );
    await load();
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

PlanViewState _initialState(PlanRepository repository, DateTime initialWeek) {
  final weekOf = _dateOnly(initialWeek);
  final dashboard = switch (repository) {
    PlanDashboardSnapshotProvider provider => provider.snapshotFor(
      weekOf: weekOf,
    ),
    _ => null,
  };
  return PlanViewState(
    phase: dashboard == null
        ? PlanLoadPhase.loading
        : dashboard.isEmpty
        ? PlanLoadPhase.empty
        : PlanLoadPhase.success,
    weekOf: weekOf,
    dashboard: dashboard,
    selectedPlanId: dashboard?.plans.firstOrNull?.id,
  );
}
