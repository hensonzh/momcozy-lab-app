import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_reminder.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';

const _maxNativeScheduleReminders = 64;

class AndroidScheduleReminderGateway implements ScheduleReminderGateway {
  AndroidScheduleReminderGateway({
    required this.ownerScope,
    MethodChannel? channel,
    DateTime Function()? now,
    bool? supported,
  }) : _channel =
           channel ??
           const MethodChannel(defaultPumpSessionNotificationChannelName),
       _now = now ?? DateTime.now,
       _supportedOverride = supported;

  final String ownerScope;
  final MethodChannel _channel;
  final DateTime Function() _now;
  final bool? _supportedOverride;

  @override
  bool get isSupported =>
      _supportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) async {
    if (!isSupported || ownerScope.trim().isEmpty) return false;
    try {
      if (enabled) {
        final permission = _map(
          await _channel.invokeMethod<Object?>('requestPermission'),
        );
        if (permission['granted'] != true) return false;
      }
      final response = _map(
        await _channel.invokeMethod<Object?>('setScheduleReminders', {
          'enabled': enabled,
          'ownerScope': ownerScope.trim(),
          'reminders': enabled ? _reminders(tasks) : const <Object?>[],
        }),
      );
      return response['supported'] == true &&
          response['enabled'] == enabled &&
          (!enabled || response['permissionGranted'] == true);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  List<Map<String, Object?>> _reminders(List<ScheduleTask> tasks) {
    final now = _now();
    final unique = <String, ScheduleTask>{};
    for (final task in tasks) {
      final remindAt = task.remindAt;
      if (task.state != ScheduleTaskState.pending ||
          remindAt == null ||
          !remindAt.isAfter(now)) {
        continue;
      }
      unique['${task.id}:${remindAt.millisecondsSinceEpoch}'] = task;
    }
    final normalized = unique.values.toList(growable: false)
      ..sort((left, right) {
        final timeOrder = left.remindAt!.compareTo(right.remindAt!);
        return timeOrder != 0 ? timeOrder : left.id.compareTo(right.id);
      });
    return [
      for (final task in normalized.take(_maxNativeScheduleReminders))
        {
          'taskId': task.id,
          'date': _dateKey(task.remindAt!),
          'triggerAtMillis': task.remindAt!.millisecondsSinceEpoch,
        },
    ];
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return Map<String, Object?>.from(value);
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
