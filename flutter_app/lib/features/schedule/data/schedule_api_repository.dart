import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';

const scheduleDayPlanEndpoint = '/v1/plan/query-task';

class ScheduleApiRepository implements ScheduleRepository {
  const ScheduleApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<ScheduleDayPlan> fetchDayPlan({
    required String userId,
    required DateTime day,
  }) async {
    final response = await transport.getJson(
      scheduleDayPlanEndpoint,
      query: {'user_id': userId, 'timestamp': _apiTimestamp(day)},
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    final rawTasks = data['tasks'] ?? data['taskList'];
    final tasks = rawTasks is List
        ? rawTasks
              .whereType<Map>()
              .map((task) => _task(Map<String, Object?>.from(task)))
              .toList(growable: false)
        : const <ScheduleTask>[];

    return ScheduleDayPlan(tasks: tasks);
  }
}

ScheduleTask _task(Map<String, Object?> data) {
  return ScheduleTask(
    id: _string(data['id'] ?? data['taskId']) ?? '',
    title: _string(data['title'] ?? data['text']) ?? '',
    completed: _bool(data['completed'] ?? data['done']) ?? false,
    remindAt: _dateTime(data['remind_at'] ?? data['remindAt']),
  );
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String _apiTimestamp(DateTime day) {
  return day.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
}

String? _string(Object? value) => value is String ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
