import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ble/ble_protocol.dart';
import 'package:app/native/p0_platform_interfaces.dart';
import 'package:app/native/pump_device_snapshot_binding.dart';
import 'package:app/native/pump_native_runtime_coordinator.dart';

import '../support/fixture_reader.dart';

void main() {
  test(
    'pump native runtime coordinator wires snapshot, upload, and protocol',
    () async {
      final ble = FakeBlePlatform(
        seedDevices: const [
          BleDeviceSnapshot(
            side: 'L',
            deviceId: 'left-device-id',
            deviceName: 'Left pump',
            connected: true,
          ),
        ],
      );
      final upload = FakePumpAgentUploadPlatform();
      final runtime = PumpNativeRuntimeCoordinator(ble: ble, upload: upload);

      await runtime.start();
      await runtime.protocol.queryDeviceStatus(PumpSide.left);
      expect(ble.writes.single['bytes'], hexToBytes('aa5500e1001f'));

      ble.emitNotification(
        BleNotification(
          deviceId: 'left-device-id',
          characteristicUuid: defaultPumpNotifyCharacteristicUuid,
          value: hexToBytes(_frameHexById('e1_ack_current_status_15_bytes')),
        ),
      );
      await flushStreams();
      await runtime.flushUploads();

      await runtime.protocol.adjustGearForSide(PumpSide.left, 5);
      expect(ble.writes.last['bytes'], hexToBytes('aa5500b1040101050143'));
      expect(upload.recordedCalls.map((call) => call.method), [
        'updateDeviceSnapshot',
        'updateDeviceSnapshot',
      ]);
      expect(
        upload.recordedCalls.last.payload['snapshot'],
        containsPair('L', containsPair('pumpWorkState', 1)),
      );

      await runtime.dispose();
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
