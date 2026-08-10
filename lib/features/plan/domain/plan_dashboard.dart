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
    this.weekNumber,
    this.totalWeeks,
    this.sessionsPerDay,
    this.dailyTargetVolumeMl,
    this.todayVolumeMl,
    this.weeklyTargetVolumeMl,
    this.weeklyVolumeMl,
    this.startDate,
    this.endDate,
    this.durationDays,
    this.goal,
    this.basisMode,
    this.pumpingSessionsPerDay,
    this.breastfeedingAnchorsPerDay,
  });

  final String id;
  final PlanCategory category;
  final String title;
  final String summary;
  final int? weekNumber;
  final int? totalWeeks;
  final int? sessionsPerDay;
  final int? dailyTargetVolumeMl;
  final int? todayVolumeMl;
  final int? weeklyTargetVolumeMl;
  final int? weeklyVolumeMl;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationDays;
  final String? goal;
  final String? basisMode;
  final int? pumpingSessionsPerDay;
  final int? breastfeedingAnchorsPerDay;

  bool get hasVolumeProgress =>
      dailyTargetVolumeMl != null &&
      todayVolumeMl != null &&
      weeklyTargetVolumeMl != null &&
      weeklyVolumeMl != null;

  String? get goalLabel => switch (goal) {
    'increase_supply' => 'Increase Supply',
    'maintain_supply' => 'Maintain Supply',
    'reduce_supply' => 'Reduce Supply',
    _ => null,
  };

  int? dayNumberOn(DateTime selectedDay) {
    final start = startDate;
    final duration = durationDays;
    if (start == null || duration == null || duration <= 0) return null;
    final normalizedStart = DateTime.utc(start.year, start.month, start.day);
    final normalizedSelected = DateTime.utc(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final day = normalizedSelected.difference(normalizedStart).inDays + 1;
    return day.clamp(1, duration);
  }
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
