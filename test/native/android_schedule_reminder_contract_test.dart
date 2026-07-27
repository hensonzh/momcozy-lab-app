import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const kotlinRoot = 'android/app/src/main/kotlin/com/momcozymai/app';

  test('Android schedule reminders use bounded inexact local alarms', () {
    final scheduler = File(
      '$kotlinRoot/ScheduleReminderScheduler.kt',
    ).readAsStringSync();

    expect(scheduler, contains('MAX_REMINDERS = 64'));
    expect(scheduler, contains('setAndAllowWhileIdle'));
    expect(scheduler, isNot(contains('setExact')));
    expect(scheduler, isNot(contains('setAlarmClock')));
    expect(scheduler, contains('Context.MODE_PRIVATE'));
    expect(scheduler, contains('distinctBy'));
    expect(scheduler, isNot(contains('bearer')));
  });

  test('Android schedule notifications stay private and route to one task', () {
    final receiver = File(
      '$kotlinRoot/ScheduleReminderReceiver.kt',
    ).readAsStringSync();

    expect(receiver, contains('Notification.VISIBILITY_PRIVATE'));
    expect(receiver, contains('POST_NOTIFICATIONS'));
    expect(receiver, contains('.path("/schedule")'));
    expect(receiver, contains('appendQueryParameter("date"'));
    expect(receiver, contains('appendQueryParameter("task_id"'));
    expect(receiver, contains('你有一项计划即将开始'));
    expect(receiver, isNot(contains('reminder.title')));
  });

  test('Android manifest restores reminders after reboot', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File('$kotlinRoot/MainActivity.kt').readAsStringSync();

    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('.ScheduleReminderReceiver'));
    expect(manifest, contains('.ScheduleReminderBootReceiver'));
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(
      manifest,
      contains(
        'android:name=".ScheduleReminderBootReceiver"\n'
        '            android:enabled="true"\n'
        '            android:exported="false"',
      ),
    );
    expect(activity, contains('scheduleReminderSupport'));
    expect(activity, contains('scheduleReminderState'));
    expect(activity, contains('setScheduleReminders'));
  });
}
