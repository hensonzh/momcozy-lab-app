import 'dart:async';

import 'package:momcozy_flutter_app/core/ble/pump_device_snapshot.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_device_snapshot_binding.dart';

class PumpAgentUploadSnapshotSync {
  PumpAgentUploadSnapshotSync({
    required this.snapshotBinding,
    required this.upload,
  });

  final PumpDeviceSnapshotBleBinding snapshotBinding;
  final PumpAgentUploadPlatform upload;

  StreamSubscription<PumpDeviceSnapshotUpdate>? _sub;
  Future<void> _tail = Future<void>.value();

  Future<void> start({bool sendCurrentSnapshot = true}) async {
    if (sendCurrentSnapshot) _enqueue(snapshotBinding.snapshot);
    _sub ??= snapshotBinding.updates.listen(
      (update) => _enqueue(update.snapshot),
    );
    await flush();
  }

  Future<void> flush() => _tail;

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await flush();
  }

  void _enqueue(PumpDeviceSnapshot snapshot) {
    _tail = _tail
        .catchError((_) {})
        .then((_) => upload.updateDeviceSnapshot(snapshot));
  }
}
