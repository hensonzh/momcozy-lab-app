import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/schedule/data/android_schedule_reminder_gateway.dart';
import 'package:app/features/schedule/domain/schedule_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test.schedule.reminders');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'requestPermission' => {'granted': true},
            'setScheduleReminders' => {
              'supported': true,
              'enabled': (call.arguments as Map)['enabled'],
              'permissionGranted': true,
              'scheduledCount': 2,
            },
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'enabling schedules only unique pending future tasks without text',
    () async {
      final gateway = AndroidScheduleReminderGateway(
        ownerScope: 'owner-a',
        channel: channel,
        now: () => DateTime.utc(2026, 7, 3, 10),
        supported: true,
      );

      final enabled = await gateway.setEnabled(
        enabled: true,
        tasks: [
          ScheduleTask(
            id: 'future-b',
            title: 'private feeding title',
            state: ScheduleTaskState.pending,
            remindAt: DateTime.utc(2026, 7, 4, 8),
          ),
          ScheduleTask(
            id: 'future-a',
            title: 'private pumping title',
            state: ScheduleTaskState.pending,
            remindAt: DateTime.utc(2026, 7, 3, 12),
          ),
          ScheduleTask(
            id: 'past',
            title: 'past',
            state: ScheduleTaskState.pending,
            remindAt: DateTime.utc(2026, 7, 3, 9),
          ),
          ScheduleTask(
            id: 'done',
            title: 'done',
            state: ScheduleTaskState.completed,
            remindAt: DateTime.utc(2026, 7, 3, 13),
          ),
          ScheduleTask(
            id: 'future-a',
            title: 'duplicate',
            state: ScheduleTaskState.pending,
            remindAt: DateTime.utc(2026, 7, 3, 12),
          ),
        ],
      );

      expect(enabled, isTrue);
      expect(calls.map((call) => call.method), [
        'requestPermission',
        'setScheduleReminders',
      ]);
      final args = Map<String, Object?>.from(calls.last.arguments as Map);
      expect(args['enabled'], isTrue);
      expect(args['ownerScope'], 'owner-a');
      expect(args.toString(), isNot(contains('private')));
      expect(args['reminders'], [
        {
          'taskId': 'future-a',
          'date': '2026-07-03',
          'triggerAtMillis': DateTime.utc(
            2026,
            7,
            3,
            12,
          ).millisecondsSinceEpoch,
        },
        {
          'taskId': 'future-b',
          'date': '2026-07-04',
          'triggerAtMillis': DateTime.utc(2026, 7, 4, 8).millisecondsSinceEpoch,
        },
      ]);
    },
  );

  test(
    'disabling cancels without asking for notification permission',
    () async {
      final gateway = AndroidScheduleReminderGateway(
        ownerScope: 'owner-a',
        channel: channel,
        supported: true,
      );

      expect(await gateway.setEnabled(enabled: false, tasks: const []), isTrue);
      expect(calls.map((call) => call.method), ['setScheduleReminders']);
      final args = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(args['enabled'], isFalse);
      expect(args['reminders'], isEmpty);
    },
  );

  test('permission denial and native state mismatch fail honestly', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'granted': false};
        });
    final gateway = AndroidScheduleReminderGateway(
      ownerScope: 'owner-a',
      channel: channel,
      supported: true,
    );

    expect(await gateway.setEnabled(enabled: true, tasks: const []), isFalse);
    expect(calls.map((call) => call.method), ['requestPermission']);

    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'requestPermission' => {'granted': true},
            _ => {
              'supported': true,
              'enabled': false,
              'permissionGranted': true,
            },
          };
        });
    expect(await gateway.setEnabled(enabled: true, tasks: const []), isFalse);
  });
}
