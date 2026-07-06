import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';

const scheduleDayPlanEndpoint = '/v1/plans/tasks/list';

class ScheduleApiRepository implements ScheduleRepository {
  const ScheduleApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<ScheduleDayPlan> fetchDayPlan({required DateTime day}) async {
    final response = await transport.getJson(
      scheduleDayPlanEndpoint,
      query: {'task_date': _apiDate(day), 'limit': 50},
    );
    final rawTasks = response['items'];
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
  final title = _titleWithTime(
    _string(data['task_time']),
    _string(data['title']) ?? '',
  );
  return ScheduleTask(
    id: _string(data['id']) ?? '',
    title: title,
    completed: _isCompleted(_string(data['status'])),
    remindAt: _localDateTime(
      _string(data['task_date']),
      _string(data['task_time']),
    ),
  );
}

String _apiDate(DateTime day) {
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

String _titleWithTime(String? taskTime, String title) {
  final time = _normalizedTime(taskTime);
  if (time == null || title.startsWith('$time ')) return title;
  return '$time $title';
}

bool _isCompleted(String? status) {
  final normalized = status?.trim().toLowerCase();
  return normalized == 'completed' || normalized == 'done';
}

DateTime? _localDateTime(String? date, String? time) {
  final parsedDate = _dateParts(date);
  final parsedTime = _timeParts(time);
  if (parsedDate == null || parsedTime == null) return null;
  return DateTime(
    parsedDate.$1,
    parsedDate.$2,
    parsedDate.$3,
    parsedTime.$1,
    parsedTime.$2,
  );
}

(int, int, int)? _dateParts(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return (year, month, day);
}

(int, int)? _timeParts(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return (hour, minute);
}

String? _normalizedTime(String? value) {
  final parts = _timeParts(value);
  if (parts == null) return null;
  return '${parts.$1.toString().padLeft(2, '0')}:'
      '${parts.$2.toString().padLeft(2, '0')}';
}

String? _string(Object? value) => value is String ? value : null;
