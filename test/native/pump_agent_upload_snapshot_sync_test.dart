import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ble/ble_protocol.dart';
import 'package:app/native/p0_platform_interfaces.dart';
import 'package:app/native/pump_agent_upload_snapshot_sync.dart';
import 'package:app/native/pump_device_snapshot_binding.dart';

import '../support/fixture_reader.dart';

void main() {
  test('pump agent upload snapshot sync forwards binding updates', () async {
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
    final binding = PumpDeviceSnapshotBleBinding(ble: ble);
    await binding.start(subscribeConnectedDevices: true);

    final upload = FakePumpAgentUploadPlatform();
    final sync = PumpAgentUploadSnapshotSync(
      snapshotBinding: binding,
      upload: upload,
    );
    await sync.start();
    expect(upload.recordedCalls.map((call) => call.method), [
      'updateDeviceSnapshot',
    ]);
    expect(upload.recordedCalls.single.payload['snapshot'], {
      'L': {
        'deviceId': '***',
        'deviceName': 'Left pump',
        'connected': true,
        'battery': 0,
        'flangeSize': 24,
        'sealSize': 'M',
        'model': '',
        'firmware': '-',
        'serialNumber': '***',
      },
      'R': null,
    });

    ble.emitNotification(
      BleNotification(
        deviceId: 'left-device-id',
        characteristicUuid: defaultPumpNotifyCharacteristicUuid,
        value: hexToBytes(_frameHexById('e1_ack_current_status_15_bytes')),
      ),
    );
    await flushStreams();
    await sync.flush();

    expect(upload.recordedCalls.map((call) => call.method), [
      'updateDeviceSnapshot',
      'updateDeviceSnapshot',
    ]);
    final snapshot = upload.recordedCalls.last.payload['snapshot']! as Map;
    expect(snapshot['L'], containsPair('pumpWorkState', 1));
    expect(snapshot['L'], containsPair('battery', 87));

    await sync.dispose();
    await binding.dispose();
    await ble.dispose();
  });
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
