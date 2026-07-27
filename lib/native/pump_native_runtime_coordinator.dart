import 'package:app/native/ble_pump_protocol_platform.dart';
import 'package:app/native/p0_platform_interfaces.dart';
import 'package:app/native/pump_agent_upload_snapshot_sync.dart';
import 'package:app/native/pump_device_snapshot_binding.dart';

class PumpNativeRuntimeCoordinator {
  PumpNativeRuntimeCoordinator({
    required BlePlatform ble,
    required PumpAgentUploadPlatform upload,
    PumpDeviceSnapshotBleBinding? snapshotBinding,
    PumpAgentUploadSnapshotSync? snapshotSync,
    BlePumpProtocolPlatform? protocol,
  }) {
    final binding = snapshotBinding ?? PumpDeviceSnapshotBleBinding(ble: ble);
    this.snapshotBinding = binding;
    this.snapshotSync =
        snapshotSync ??
        PumpAgentUploadSnapshotSync(snapshotBinding: binding, upload: upload);
    this.protocol =
        protocol ??
        BlePumpProtocolPlatform(
          ble: ble,
          deviceIdForSide: _deviceIdForSide,
          stateForSide: _stateForSide,
        );
  }

  late final PumpDeviceSnapshotBleBinding snapshotBinding;
  late final PumpAgentUploadSnapshotSync snapshotSync;
  late final BlePumpProtocolPlatform protocol;

  Future<void> start({bool subscribeConnectedDevices = true}) async {
    await snapshotBinding.start(
      subscribeConnectedDevices: subscribeConnectedDevices,
    );
    await snapshotSync.start();
  }

  Future<void> flushUploads() => snapshotSync.flush();

  Future<void> dispose() async {
    await protocol.dispose();
    await snapshotSync.dispose();
    await snapshotBinding.dispose();
  }

  String? _deviceIdForSide(PumpSide side) {
    return switch (side) {
      PumpSide.left => snapshotBinding.snapshot.left?.deviceId,
      PumpSide.right => snapshotBinding.snapshot.right?.deviceId,
    };
  }

  PumpProtocolSideState? _stateForSide(PumpSide side) {
    final device = switch (side) {
      PumpSide.left => snapshotBinding.snapshot.left,
      PumpSide.right => snapshotBinding.snapshot.right,
    };
    if (device == null || !device.connected) return null;
    return PumpProtocolSideState(
      startStop: device.pumpWorkState ?? 0,
      mode: device.pumpMode ?? 0,
      gear: device.gear ?? 0,
      scene: device.pumpScene ?? 0,
    );
  }
}
