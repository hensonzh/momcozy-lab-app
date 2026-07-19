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

  group('canonical milliliter input conversion', () {
    test('rounds mL input to the nearest whole mL with half values up', () {
      expect(MomCozyVolumeUnit.milliliters.toCanonicalMilliliters(120.49), 120);
      expect(MomCozyVolumeUnit.milliliters.toCanonicalMilliliters(120.5), 121);
      expect(MomCozyVolumeUnit.milliliters.toCanonicalMilliliters(-0.0), 0);
    });

    test('converts ounce input and preserves displayed tenth-ounce values', () {
      for (final ounces in <double>[0, 0.1, 1, 8.1, 16.9]) {
        final milliliters = MomCozyVolumeUnit.ounces.toCanonicalMilliliters(
          ounces,
        );

        expect(milliliters, isNotNull, reason: '$ounces oz must convert');
        expect(
          MomCozyVolumeUnit.ounces.formatMilliliters(milliliters!.toDouble()),
          ounces.toStringAsFixed(1),
        );
      }
      expect(MomCozyVolumeUnit.ounces.toCanonicalMilliliters(1), 30);
      expect(MomCozyVolumeUnit.ounces.toCanonicalMilliliters(8.1), 240);
    });

    test('rejects negative, non-finite, and overflowing input', () {
      for (final unit in MomCozyVolumeUnit.values) {
        expect(unit.toCanonicalMilliliters(-0.01), isNull);
        expect(unit.toCanonicalMilliliters(double.nan), isNull);
        expect(unit.toCanonicalMilliliters(double.infinity), isNull);
        expect(unit.toCanonicalMilliliters(double.negativeInfinity), isNull);
      }
      expect(
        MomCozyVolumeUnit.ounces.toCanonicalMilliliters(double.maxFinite),
        isNull,
      );
    });
  });
}
