import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/ble/ble_protocol.dart';
import 'package:momcozy_flutter_app/core/ble/pump_device_snapshot.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Pump device snapshot reducer', () {
    test('applies legacy protocol frames to the matching side only', () {
      var snapshot = _seedSnapshot();

      final e1 = _apply(
        snapshot,
        'left-device-id',
        'e1_ack_current_status_15_bytes',
      );
      expect(e1.changed, isTrue);
      snapshot = e1.snapshot;
      expect(snapshot.left!.battery, 87);
      expect(snapshot.left!.pumpMode, 1);
      expect(snapshot.left!.gear, 6);
      expect(snapshot.left!.pumpWorkState, 1);
      expect(snapshot.left!.pumpScene, 1);
      expect(snapshot.left!.duration, 900);
      expect(snapshot.left!.pumpGearCalib!.toMap(), {
        'stimulate': 4,
        'deep': 8,
      });
      expect(snapshot.left!.lastDeviceWorkstateTs, _fixtureIso);
      expect(snapshot.right!.battery, 30);

      final d6 = _apply(
        snapshot,
        'right-device-id',
        'd6_device_battery_notification',
      );
      expect(d6.changed, isTrue);
      snapshot = d6.snapshot;
      expect(snapshot.right!.battery, 88);
      expect(snapshot.right!.lastDeviceWorkstateTs, _fixtureIso);
      expect(snapshot.left!.battery, 87);

      final d0 = _apply(
        snapshot,
        'left-device-id',
        'd0_operation_record_notification',
      );
      expect(d0.changed, isTrue);
      snapshot = d0.snapshot;
      expect(snapshot.left!.pumpMode, 1);
      expect(snapshot.left!.gear, 6);
      expect(snapshot.left!.pumpWorkState, 1);
      expect(snapshot.left!.pumpScene, 1);
      expect(snapshot.left!.pumpGearMemoryAi!.toMap(), {'deep': 6});

      final milk = _apply(
        snapshot,
        'left-device-id',
        '80_realtime_milk_notification',
      );
      expect(milk.changed, isTrue);
      snapshot = milk.snapshot;
      expect(snapshot.left!.flowFloat, 1.25);
      expect(snapshot.left!.milkMl, 20.5);
      expect(snapshot.left!.milkFlag, 1);
      expect(snapshot.left!.moFlag, 1);
      expect(snapshot.left!.bandpower, 0);
      expect(snapshot.left!.pitch, -12.3);
      expect(snapshot.left!.roll, 4.5);
      expect(snapshot.left!.pressureCh1, 25);
      expect(snapshot.left!.pressureCh2, 31);
      expect(snapshot.left!.lastDeviceProcessTs, _fixtureIso);

      final endRun = _apply(
        snapshot,
        'left-device-id',
        'bf_ack_end_run_response',
      );
      expect(endRun.changed, isTrue);
      snapshot = endRun.snapshot;
      expect(snapshot.left!.finalMilkMl, 20.5);

      final unknown = _apply(
        snapshot,
        'unknown-device-id',
        'd6_device_battery_notification',
      );
      expect(unknown.changed, isFalse);
      expect(unknown.snapshot, same(snapshot));
    });

    test('honors side mapping fixtures without mutating the other side', () {
      final fixture = readFixtureMap('ble/side_mapping.json');
      for (final fixtureCase in _listOfMaps(fixture['cases'])) {
        final snapshot = _seedSnapshot();
        final frameHex = fixtureCase['frameHex']! as String;
        final result = snapshot.applyProtocolFrame(
          deviceId: fixtureCase['incomingDeviceId']! as String,
          value: hexToBytes(frameHex),
        );

        final expectedSide = fixtureCase['expectedTouchedSide'];
        expect(
          result.changed,
          expectedSide != null,
          reason: fixtureCase['id'] as String?,
        );
        if (expectedSide == 'L') {
          expect(result.snapshot.left!.battery, 88);
          expect(result.snapshot.right!.battery, 30);
        } else if (expectedSide == 'R') {
          expect(result.snapshot.left!.battery, 20);
          expect(result.snapshot.right!.battery, 88);
        } else {
          expect(result.snapshot, same(snapshot));
        }
      }
    });
  });
}

PumpDeviceSnapshot _seedSnapshot() {
  return const PumpDeviceSnapshot(
    left: PumpDeviceSideState(
      deviceId: 'left-device-id',
      deviceName: 'Left pump',
      connected: true,
      battery: 20,
      model: 'M9',
      firmware: '-',
      serialNumber: 'left-sn',
    ),
    right: PumpDeviceSideState(
      deviceId: 'right-device-id',
      deviceName: 'Right pump',
      connected: true,
      battery: 30,
      model: 'M9',
      firmware: '-',
      serialNumber: 'right-sn',
    ),
  );
}

PumpDeviceSnapshotUpdate _apply(
  PumpDeviceSnapshot snapshot,
  String deviceId,
  String fixtureId,
) {
  final frameHex = _frameHexById(fixtureId);
  return snapshot.applyProtocolFrame(
    deviceId: deviceId,
    value: hexToBytes(frameHex),
  );
}

String _frameHexById(String id) {
  final fixture = readFixtureMap('ble/parse_frames.json');
  final validFrames = _listOfMaps(fixture['validFrames']);
  return validFrames.firstWhere((frame) => frame['id'] == id)['frameHex']!
      as String;
}

List<Map<String, Object?>> _listOfMaps(Object? raw) {
  return (raw! as List)
      .map((item) => Map<String, Object?>.from(item as Map))
      .toList(growable: false);
}

const _fixtureIso = '2026-06-28T23:00:00.000Z';
