import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_reminder_preference_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};

  setUp(() {
    values.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<String, Object?>.from(call.arguments as Map);
          final key = arguments['key'] as String?;
          return switch (call.method) {
            'read' => key == null ? null : values[key],
            'write' => () {
              if (key != null) values[key] = arguments['value'] as String;
              return null;
            }(),
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the account-scoped reminder key', () async {
    const first = FlutterSecureScheduleReminderPreferenceStore(
      userId: 'user/a',
    );
    const second = FlutterSecureScheduleReminderPreferenceStore(
      userId: 'user/b',
    );

    values[first.storageKey] = 'true';
    expect(await first.readEnabled(), isTrue);
    await second.writeEnabled(false);

    expect(
      first.storageKey,
      contains('user.user%2Fa.notifications.scheduleReminderOn'),
    );
    expect(
      second.storageKey,
      contains('user.user%2Fb.notifications.scheduleReminderOn'),
    );
    expect(values[second.storageKey], 'false');
  });
}
