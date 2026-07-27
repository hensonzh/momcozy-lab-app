import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ble/ble_protocol.dart';
import 'package:app/native/ble_pump_protocol_platform.dart';
import 'package:app/native/p0_platform_interfaces.dart';

void main() {
  test('BLE pump protocol platform writes packet goldens', () async {
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
    final states = <PumpSide, PumpProtocolSideState>{
      PumpSide.left: const PumpProtocolSideState(
        startStop: 1,
        mode: 1,
        gear: 6,
        scene: 1,
      ),
    };
    final protocol = BlePumpProtocolPlatform(
      ble: ble,
      deviceIdForSide: (side) =>
          side == PumpSide.left ? 'left-device-id' : null,
      stateForSide: (side) => states[side],
    );

    await protocol.setPumpParams(
      PumpSide.left,
      const PumpParamsRequest(startStop: 1, mode: 1, gear: 6, scene: 1),
    );
    await protocol.queryDeviceStatus(PumpSide.left);
    await protocol.adjustGearForSide(PumpSide.left, 5);

    expect(ble.writes.map((write) => write['bytes']), [
      hexToBytes('aa5500b1040101060142'),
      hexToBytes('aa5500e1001f'),
      hexToBytes('aa5500b1040101050143'),
    ]);
    expect(
      ble.writes.every((write) => write['method'] == 'writeWithoutResponse'),
      isTrue,
    );
    expect(
      ble.writes.every(
        (write) =>
            write['characteristicUuid'] == defaultPumpCommandCharacteristicUuid,
      ),
      isTrue,
    );
    expect(protocol.recordedCommands.map((command) => command.name), [
      'setPumpParams',
      'queryDeviceStatus',
      'adjustGearForSide',
    ]);

    await protocol.dispose();
    await ble.dispose();
  });

  test(
    'BLE pump protocol platform requires side device and protocol state',
    () async {
      final ble = FakeBlePlatform();
      final protocol = BlePumpProtocolPlatform(
        ble: ble,
        deviceIdForSide: (_) => null,
        stateForSide: (_) => null,
      );

      expect(
        protocol.queryDeviceStatus(PumpSide.left),
        throwsA(isA<StateError>()),
      );
      expect(
        protocol.adjustGearForSide(PumpSide.left, 5),
        throwsA(isA<StateError>()),
      );

      await protocol.dispose();
      await ble.dispose();
    },
  );
}
