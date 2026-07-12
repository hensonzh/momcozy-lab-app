import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';

abstract interface class ScheduleReminderGateway {
  bool get isSupported;

  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  });
}

class UnsupportedScheduleReminderGateway implements ScheduleReminderGateway {
  const UnsupportedScheduleReminderGateway();

  @override
  bool get isSupported => false;

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) async => false;
}

abstract interface class ScheduleReminderPreferenceStore {
  Future<bool> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

class DisabledScheduleReminderPreferenceStore
    implements ScheduleReminderPreferenceStore {
  const DisabledScheduleReminderPreferenceStore();

  @override
  Future<bool> readEnabled() async => false;

  @override
  Future<void> writeEnabled(bool enabled) async {}
}
