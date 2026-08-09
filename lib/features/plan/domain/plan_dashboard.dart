import 'package:meta/meta.dart';

abstract interface class PlanRepository {
  Future<PlanDashboard> fetchDashboard({required DateTime weekOf});
}

abstract interface class PlanDashboardSnapshotProvider {
  PlanDashboard? snapshotFor({required DateTime weekOf});
}

abstract interface class PlanSessionMutationRepository {
  Future<void> updateSession({
    required String sessionId,
    required String title,
    required DateTime scheduledAt,
  });
}

enum PlanCategory { lactation, yoga, pelvicFloor, other }

extension PlanCategoryLabel on PlanCategory {
  String get label => switch (this) {
    PlanCategory.lactation => 'Lactation',
    PlanCategory.yoga => 'Yoga',
    PlanCategory.pelvicFloor => 'Pelvic Floor',
    PlanCategory.other => 'Plan',
  };
}

enum PlanSessionStatus { completed, next, upcoming }

@immutable
class CarePlan {
  const CarePlan({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    this.weekNumber = 1,
    this.totalWeeks = 8,
    this.sessionsPerDay = 5,
    this.dailyTargetVolumeMl = 600,
    this.todayVolumeMl = 0,
    this.weeklyTargetVolumeMl = 4200,
    this.weeklyVolumeMl = 0,
  });

  final String id;
  final PlanCategory category;
  final String title;
  final String summary;
  final int weekNumber;
  final int totalWeeks;
  final int sessionsPerDay;
  final int dailyTargetVolumeMl;
  final int todayVolumeMl;
  final int weeklyTargetVolumeMl;
  final int weeklyVolumeMl;
}

@immutable
class PlanSession {
  const PlanSession({
    required this.id,
    required this.planId,
    required this.title,
    required this.scheduledAt,
    required this.status,
    this.valueLabel,
  });

  final String id;
  final String planId;
  final String title;
  final DateTime scheduledAt;
  final PlanSessionStatus status;
  final String? valueLabel;
}

@immutable
class PlanDashboard {
  const PlanDashboard({
    required this.weekOf,
    this.plans = const <CarePlan>[],
    this.sessions = const <PlanSession>[],
    this.weeklyCompletedSessions,
    this.weeklyTotalSessions,
  });

  factory PlanDashboard.empty({required DateTime weekOf}) {
    return PlanDashboard(weekOf: weekOf);
  }

  final DateTime weekOf;
  final List<CarePlan> plans;
  final List<PlanSession> sessions;
  final int? weeklyCompletedSessions;
  final int? weeklyTotalSessions;

  bool get isEmpty => plans.isEmpty;

  bool get isSinglePlan => plans.length == 1;

  List<PlanSession> sessionsFor(String planId) => sessions
      .where((session) => session.planId == planId)
      .toList(growable: false);

  int get completedThisWeek =>
      weeklyCompletedSessions ??
      sessions
          .where((session) => session.status == PlanSessionStatus.completed)
          .length;

  int get totalThisWeek => weeklyTotalSessions ?? sessions.length;
}
