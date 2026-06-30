import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/ble/ble_protocol.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_device_snapshot_binding.dart';

import '../support/fixture_reader.dart';

void main() {
  test(
    'pump device snapshot binding consumes BLE notification frames',
    () async {
      final ble = FakeBlePlatform(
        seedDevices: const [
          BleDeviceSnapshot(
            side: 'L',
            deviceId: 'left-device-id',
            deviceName: 'Left pump',
            connected: true,
          ),
          BleDeviceSnapshot(
            side: 'R',
            deviceId: 'right-device-id',
            deviceName: 'Right pump',
            connected: true,
          ),
        ],
      );
      final binding = PumpDeviceSnapshotBleBinding(ble: ble);
      final updates = <Map<String, Object?>>[];
      final sub = binding.updates.listen(
        (update) => updates.add(update.snapshot.toMap()),
      );

      await binding.start(subscribeConnectedDevices: true);
      expect(
        ble.isSubscribed('left-device-id', defaultPumpNotifyCharacteristicUuid),
        isTrue,
      );
      expect(
        ble.isSubscribed(
          'right-device-id',
          defaultPumpNotifyCharacteristicUuid,
        ),
        isTrue,
      );
      expect(binding.snapshot.left!.deviceName, 'Left pump');
      expect(binding.snapshot.right!.deviceName, 'Right pump');

      ble.emitNotification(
        BleNotification(
          deviceId: 'left-device-id',
          characteristicUuid: defaultPumpNotifyCharacteristicUuid,
          value: hexToBytes(_frameHexById('e1_ack_current_status_15_bytes')),
        ),
      );
      ble.emitNotification(
        BleNotification(
          deviceId: 'right-device-id',
          characteristicUuid: defaultPumpNotifyCharacteristicUuid,
          value: hexToBytes(_frameHexById('d6_device_battery_notification')),
        ),
      );
      ble.emitNotification(
        BleNotification(
          deviceId: 'unknown-device-id',
          characteristicUuid: defaultPumpNotifyCharacteristicUuid,
          value: hexToBytes(_frameHexById('d6_device_battery_notification')),
        ),
      );
      await flushStreams();

      expect(binding.snapshot.left!.battery, 87);
      expect(binding.snapshot.left!.pumpWorkState, 1);
      expect(binding.snapshot.right!.battery, 88);
      expect(updates.length, 3);
      expect(updates.last['R'], containsPair('battery', 88));

      await sub.cancel();
      await binding.dispose();
      await ble.dispose();
    },
  );
}

String _frameHexById(String id) {
  final fixture = readFixtureMap('ble/parse_frames.json');
  final validFrames = (fixture['validFrames']! as List)
      .map((item) => Map<String, Object?>.from(item as Map))
      .toList(growable: false);
  return validFrames.firstWhere((frame) => frame['id'] == id)['frameHex']!
      as String;
}

Future<void> flushStreams() async {
  await Future<void>.delayed(Duration.zero);
}
