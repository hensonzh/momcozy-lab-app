import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';

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

  test('uses the migrated account-scoped volume unit key', () async {
    const first = FlutterSecureVolumeUnitPreferenceStore(userId: 'user/a');
    const second = FlutterSecureVolumeUnitPreferenceStore(userId: 'user/b');

    await first.write(MomCozyVolumeUnit.ounces);
    await second.write(MomCozyVolumeUnit.milliliters);

    expect(first.storageKey, contains('user.user%2Fa.preferences.volumeUnit'));
    expect(second.storageKey, contains('user.user%2Fb.preferences.volumeUnit'));
    expect(await first.read(), MomCozyVolumeUnit.ounces);
    expect(await second.read(), MomCozyVolumeUnit.milliliters);
  });

  test('matches legacy volume formatting exactly', () {
    expect(MomCozyVolumeUnit.milliliters.formatMilliliters(120.4), '120');
    expect(MomCozyVolumeUnit.ounces.formatMilliliters(240), '8.1');
    expect(MomCozyVolumeUnit.ounces.formatMilliliters(-1), '0.0');
  });
}
