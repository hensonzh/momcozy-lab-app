import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/status/data/status_preference_store.dart';
import 'package:app/features/status/domain/status_selection.dart';

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

  test('stores care stage under an account-scoped key', () async {
    const first = FlutterSecureStatusPreferenceStore(userId: 'user/a');
    const second = FlutterSecureStatusPreferenceStore(userId: 'user/b');

    await first.writeCareStage(StatusCareStage.pregnancy);
    await second.writeCareStage(StatusCareStage.postpartum);

    expect(first.storageKey, contains('user.user%2Fa.status.careStage'));
    expect(second.storageKey, contains('user.user%2Fb.status.careStage'));
    expect(await first.readCareStage(), StatusCareStage.pregnancy);
    expect(await second.readCareStage(), StatusCareStage.postpartum);
  });

  test('ignores malformed and unsupported stored values', () async {
    const store = FlutterSecureStatusPreferenceStore(userId: 'user');
    values[store.storageKey] = 'pregnancy';
    expect(await store.readCareStage(), isNull);

    values[store.storageKey] = '"unexpected"';
    expect(await store.readCareStage(), isNull);
  });
}
