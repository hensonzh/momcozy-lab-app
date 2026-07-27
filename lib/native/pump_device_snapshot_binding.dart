import 'dart:async';
import 'dart:typed_data';

import 'package:app/core/ble/pump_device_snapshot.dart';
import 'package:app/native/p0_platform_interfaces.dart';

const defaultPumpNotifyCharacteristicUuid =
    '0000af02-0000-1000-8000-00805f9b34fb';

class PumpDeviceSnapshotBleBinding {
  PumpDeviceSnapshotBleBinding({
    required this.ble,
    PumpDeviceSnapshot initialSnapshot = const PumpDeviceSnapshot(),
    this.notifyCharacteristicUuid = defaultPumpNotifyCharacteristicUuid,
  }) : snapshot = initialSnapshot;

  final BlePlatform ble;
  final String notifyCharacteristicUuid;
  final StreamController<PumpDeviceSnapshotUpdate> _updateController =
      StreamController<PumpDeviceSnapshotUpdate>.broadcast();

  StreamSubscription<BleNotification>? _notificationSub;
  PumpDeviceSnapshot snapshot;

  Stream<PumpDeviceSnapshotUpdate> get updates => _updateController.stream;

  Stream<PumpDeviceSnapshot> get snapshots =>
      updates.map((update) => update.snapshot);

  Future<void> start({bool subscribeConnectedDevices = false}) async {
    await seedConnectedDevices(
      subscribeNotifications: subscribeConnectedDevices,
    );
    _notificationSub ??= ble.notifications.listen(_handleNotification);
  }

  Future<void> seedConnectedDevices({
    bool subscribeNotifications = false,
  }) async {
    final devices = await ble.getConnectedDevices();
    seedDevices(devices);
    if (subscribeNotifications) {
      for (final device in devices) {
        await ble.startNotifications(device.deviceId, notifyCharacteristicUuid);
      }
    }
  }

  void seedDevices(Iterable<BleDeviceSnapshot> devices) {
    var next = snapshot;
    var changed = false;
    for (final device in devices) {
      final side = _sideFromBleValue(device.side);
      if (side == null) continue;
      final current = side == PumpDeviceSide.left ? next.left : next.right;
      final seeded = (current ?? PumpDeviceSideState(deviceId: device.deviceId))
          .copyWith(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            connected: device.connected,
          );
      next = next.replaceSide(side, seeded);
      changed = true;
    }
    if (changed) _emit(PumpDeviceSnapshotUpdate(next, changed: true));
  }

  Future<void> dispose() async {
    await _notificationSub?.cancel();
    _notificationSub = null;
    await _updateController.close();
  }

  void _handleNotification(BleNotification notification) {
    final update = snapshot.applyProtocolFrame(
      deviceId: notification.deviceId,
      value: Uint8List.fromList(notification.value),
    );
    if (update.changed) _emit(update);
  }

  void _emit(PumpDeviceSnapshotUpdate update) {
    snapshot = update.snapshot;
    _updateController.add(update);
  }

  PumpDeviceSide? _sideFromBleValue(String value) {
    return switch (value.toUpperCase()) {
      'L' || 'LEFT' => PumpDeviceSide.left,
      'R' || 'RIGHT' => PumpDeviceSide.right,
      _ => null,
    };
  }
}
