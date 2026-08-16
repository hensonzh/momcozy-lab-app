import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/plan/presentation/plan_controller.dart';

void main() {
  test(
    'keeps overview and plan details as explicit reversible levels',
    () async {
      final selectedDay = DateTime(2026, 10, 22);
      final controller = PlanController(
        repository: _MutablePlanRepository(selectedDay),
        initialWeek: selectedDay,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.surface, PlanSurface.overview);
      expect(controller.state.period, PlanPeriod.day);
      controller.openPlanDetails('plan-1');
      expect(controller.state.surface, PlanSurface.detail);
      controller.showOverview();
      expect(controller.state.surface, PlanSurface.overview);
    },
  );

  test('updates a session and refreshes the selected Plan day', () async {
    final selectedDay = DateTime(2026, 10, 22);
    final repository = _MutablePlanRepository(selectedDay);
    final controller = PlanController(
      repository: repository,
      initialWeek: selectedDay,
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.canEditSessions, isTrue);

    await controller.updateSession(
      sessionId: 'session-1',
      title: 'Updated recovery session',
      scheduledAt: DateTime(2026, 10, 22, 9, 30),
    );

    expect(repository.updatedSessionId, 'session-1');
    expect(repository.updatedTitle, 'Updated recovery session');
    expect(repository.fetchCount, 2);
    expect(
      controller.state.dashboard!.sessions.single.title,
      'Updated recovery session',
    );
  });

  test(
    'updates task state by stable id and refreshes the selected day',
    () async {
      final selectedDay = DateTime(2026, 10, 22);
      final repository = _MutablePlanRepository(selectedDay);
      final controller = PlanController(
        repository: repository,
        initialWeek: selectedDay,
      );
      addTearDown(controller.dispose);

      await controller.load();
      await controller.updateSessionState(
        sessionId: 'session-1',
        state: PlanTaskState.skipped,
      );

      expect(repository.updatedStateSessionId, 'session-1');
      expect(repository.updatedState, PlanTaskState.skipped);
      expect(repository.fetchCount, 2);
      expect(
        controller.state.dashboard!.sessions.single.status,
        PlanSessionStatus.skipped,
      );
    },
  );
}

class _MutablePlanRepository
    implements PlanRepository, PlanSessionMutationRepository {
  _MutablePlanRepository(this.selectedDay);

  final DateTime selectedDay;
  int fetchCount = 0;
  String? updatedSessionId;
  String updatedTitle = 'Recovery session';
  DateTime scheduledAt = DateTime(2026, 10, 22, 8);
  String? updatedStateSessionId;
  PlanTaskState updatedState = PlanTaskState.pending;

  @override
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf}) async {
    fetchCount += 1;
    return PlanDashboard(
      weekOf: weekOf,
      plans: const [
        CarePlan(
          id: 'plan-1',
          category: PlanCategory.yoga,
          title: 'Yoga',
          summary: 'Daily recovery',
        ),
      ],
      sessions: [
        PlanSession(
          id: 'session-1',
          planId: 'plan-1',
          title: updatedTitle,
          scheduledAt: scheduledAt,
          status: switch (updatedState) {
            PlanTaskState.pending => PlanSessionStatus.next,
            PlanTaskState.completed => PlanSessionStatus.completed,
            PlanTaskState.skipped => PlanSessionStatus.skipped,
          },
        ),
      ],
    );
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    updatedSessionId = sessionId;
    updatedTitle = title;
    this.scheduledAt = scheduledAt;
  }

  @override
  Future<void> updateSessionState({
    required String sessionId,
    required PlanTaskState state,
  }) async {
    updatedStateSessionId = sessionId;
    updatedState = state;
  }
}
