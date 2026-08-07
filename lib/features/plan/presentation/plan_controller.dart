import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';

enum PlanLoadPhase { loading, empty, success, error }

@immutable
class PlanViewState {
  const PlanViewState({
    required this.phase,
    required this.weekOf,
    this.dashboard,
    this.selectedPlanId,
    this.errorMessage,
  });

  final PlanLoadPhase phase;
  final DateTime weekOf;
  final PlanDashboard? dashboard;
  final String? selectedPlanId;
  final String? errorMessage;

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
    : _state = PlanViewState(
        phase: PlanLoadPhase.loading,
        weekOf: _dateOnly(initialWeek),
      );

  final PlanRepository repository;
  PlanViewState _state;
  int _loadGeneration = 0;

  PlanViewState get state => _state;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final weekOf = _state.weekOf;
    _state = PlanViewState(
      phase: PlanLoadPhase.loading,
      weekOf: weekOf,
      dashboard: _state.dashboard,
      selectedPlanId: _state.selectedPlanId,
    );
    notifyListeners();
    try {
      final dashboard = await repository.fetchDashboard(weekOf: weekOf);
      if (generation != _loadGeneration) return;
      final selectedPlanId =
          dashboard.plans.any((plan) => plan.id == _state.selectedPlanId)
          ? _state.selectedPlanId
          : dashboard.plans.firstOrNull?.id;
      _state = PlanViewState(
        phase: dashboard.isEmpty ? PlanLoadPhase.empty : PlanLoadPhase.success,
        weekOf: weekOf,
        dashboard: dashboard,
        selectedPlanId: selectedPlanId,
      );
    } catch (_) {
      if (generation != _loadGeneration) return;
      _state = PlanViewState(
        phase: PlanLoadPhase.error,
        weekOf: weekOf,
        dashboard: _state.dashboard,
        selectedPlanId: _state.selectedPlanId,
        errorMessage: 'Plans could not be loaded.',
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
    );
    notifyListeners();
  }

  Future<void> browseWeek(int direction) async {
    if (direction == 0) return;
    _state = PlanViewState(
      phase: PlanLoadPhase.loading,
      weekOf: _state.weekOf.add(Duration(days: direction * 7)),
      dashboard: _state.dashboard,
      selectedPlanId: _state.selectedPlanId,
    );
    notifyListeners();
    await load();
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
