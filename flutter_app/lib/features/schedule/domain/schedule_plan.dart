abstract interface class ScheduleRepository {
  Future<ScheduleDayPlan> fetchDayPlan({required DateTime day});
}

class ScheduleDayPlan {
  const ScheduleDayPlan({required this.tasks});

  final List<ScheduleTask> tasks;

  bool get isEmpty => tasks.isEmpty;
}

class ScheduleTask {
  const ScheduleTask({
    required this.id,
    required this.title,
    required this.completed,
    this.remindAt,
  });

  final String id;
  final String title;
  final bool completed;
  final DateTime? remindAt;
}
