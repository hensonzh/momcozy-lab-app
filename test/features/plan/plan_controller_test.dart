import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/plan/presentation/plan_controller.dart';

void main() {
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
}

class _MutablePlanRepository
    implements PlanRepository, PlanSessionMutationRepository {
  _MutablePlanRepository(this.selectedDay);

  final DateTime selectedDay;
  int fetchCount = 0;
  String? updatedSessionId;
  String updatedTitle = 'Recovery session';
  DateTime scheduledAt = DateTime(2026, 10, 22, 8);

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
          status: PlanSessionStatus.next,
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
}
