import 'dart:async';

import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

const defaultMmcBleChannelName = 'com.momcozymai.flutter/mmc_ble';
const defaultPumpSessionNotificationChannelName =
    'com.momcozymai.flutter/pump_session_notification';
const defaultPumpGattServiceUuid = '0000af00-0000-1000-8000-00805f9b34fb';

class AndroidBlePlatform implements BlePlatform {
  AndroidBlePlatform({
    MethodChannel? channel,
    this.defaultServiceUuid = defaultPumpGattServiceUuid,
  }) : _channel = channel ?? const MethodChannel(defaultMmcBleChannelName) {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  final MethodChannel _channel;
  final String defaultServiceUuid;
  final StreamController<BleDeviceSnapshot> _scanController =
      StreamController<BleDeviceSnapshot>.broadcast();
  final StreamController<BleScanFailure> _scanFailureController =
      StreamController<BleScanFailure>.broadcast();
  final StreamController<BleNotification> _notificationController =
      StreamController<BleNotification>.broadcast();

  @override
  Stream<BleDeviceSnapshot> get scanResults => _scanController.stream;

  @override
  Stream<BleScanFailure> get scanFailures => _scanFailureController.stream;

  @override
  Stream<BleNotification> get notifications => _notificationController.stream;

  @override
  Future<BlePermissionState> permissionState() async {
    final result = await _channel.invokeMethod<Object?>('permissionState');
    return _permissionStateFromResult(result);
  }

  @override
  Future<BlePermissionState> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<Object?>('initialize');
      return _permissionStateFromResult(
        result,
        fallback: BlePermissionState.granted,
      );
    } on PlatformException {
      return BlePermissionState.denied;
    }
  }

  @override
  Future<void> openBluetoothSettings() async {
    await _channel.invokeMethod<void>('openBluetoothSettings');
  }

  @override
  Future<void> openAppSettings() async {
    await _channel.invokeMethod<void>('openAppSettings');
  }

  @override
  Future<void> startScan() async {
    await _channel.invokeMethod<void>('requestLEScan');
  }

  @override
  Future<void> stopScan() async {
    await _channel.invokeMethod<void>('stopLEScan');
  }

  @override
  Future<List<BleDeviceSnapshot>> getConnectedDevices() async {
    final result = await _channel.invokeMethod<Object?>('getConnectedDevices');
    final devices = _mapFrom(result)['devices'];
    if (devices is! Iterable) return const [];
    return devices
        .whereType<Object?>()
        .map((device) => _deviceSnapshotFromMap(_mapFrom(device)))
        .toList(growable: false);
  }

  @override
  Future<void> connect(String deviceId) async {
    await _channel.invokeMethod<void>('connect', {'deviceId': deviceId});
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _channel.invokeMethod<void>('disconnect', {'deviceId': deviceId});
  }

  @override
  Future<List<int>> read(String deviceId, String characteristicUuid) async {
    final result = await _channel.invokeMethod<Object?>(
      'read',
      _gattArgs(deviceId, characteristicUuid),
    );
    return _intList(_mapFrom(result)['value']);
  }

  @override
  Future<void> write(
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  ) async {
    await _channel.invokeMethod<void>('write', {
      ..._gattArgs(deviceId, characteristicUuid),
      'value': List<int>.unmodifiable(bytes),
    });
  }

  @override
  Future<void> writeWithoutResponse(
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  ) async {
    await _channel.invokeMethod<void>('writeWithoutResponse', {
      ..._gattArgs(deviceId, characteristicUuid),
      'value': List<int>.unmodifiable(bytes),
    });
  }

  @override
  Future<void> startNotifications(
    String deviceId,
    String characteristicUuid,
  ) async {
    await _channel.invokeMethod<void>(
      'startNotifications',
      _gattArgs(deviceId, characteristicUuid),
    );
  }

  @override
  Future<void> stopNotifications(
    String deviceId,
    String characteristicUuid,
  ) async {
    await _channel.invokeMethod<void>(
      'stopNotifications',
      _gattArgs(deviceId, characteristicUuid),
    );
  }

  Future<void> handleNativeEvent(
    String eventName,
    Map<String, Object?> payload,
  ) async {
    switch (eventName) {
      case 'scanResult':
        _scanController.add(
          _deviceSnapshotFromMap(_mapFrom(payload['device'])),
        );
        break;
      case 'scanFailed':
        final code = payload['errorCode'] ?? payload['code'] ?? 'unknown';
        _scanFailureController.add(
          BleScanFailure(code: '$code', message: 'BLE scan failed: $code'),
        );
        break;
      case 'notification':
        _notificationController.add(
          BleNotification(
            deviceId: _string(payload['deviceId']),
            characteristicUuid: _string(
              payload['characteristicUuid'] ?? payload['characteristicUUID'],
            ),
            value: _intList(payload['value']),
          ),
        );
        break;
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _scanController.close();
    await _scanFailureController.close();
    await _notificationController.close();
  }

  Map<String, Object?> _gattArgs(String deviceId, String characteristicUuid) {
    return {
      'deviceId': deviceId,
      'serviceUUID': defaultServiceUuid,
      'characteristicUUID': characteristicUuid,
    };
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    await handleNativeEvent(call.method, _mapFrom(call.arguments));
  }
}

class AndroidPumpSessionForegroundServicePlatform
    implements PumpSessionForegroundServicePlatform {
  AndroidPumpSessionForegroundServicePlatform({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel(defaultPumpSessionNotificationChannelName);

  final MethodChannel _channel;
  final StreamController<PumpSessionNativeEvent> _eventController =
      StreamController<PumpSessionNativeEvent>.broadcast();

  @override
  Stream<PumpSessionNativeEvent> get events => _eventController.stream;

  @override
  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<Object?>('requestPermission');
    if (result is bool) return result;
    return _mapFrom(result)['granted'] == true;
  }

  @override
  Future<void> start(PumpSessionSnapshot snapshot) async {
    await _channel.invokeMethod<void>('start', _snapshotArgs(snapshot));
  }

  @override
  Future<void> update(PumpSessionSnapshot snapshot) async {
    await _channel.invokeMethod<void>('update', _snapshotArgs(snapshot));
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> showCompletionNotice(PumpSessionSnapshot snapshot) async {
    await _channel.invokeMethod<void>(
      'showCompletionNotice',
      _snapshotArgs(snapshot),
    );
  }

  @override
  Future<void> showAutoEndNotice(PumpSessionSnapshot snapshot) async {
    await _channel.invokeMethod<void>('showAutoEndNotice', {
      ..._snapshotArgs(snapshot),
      'path': '/',
      'autoEndTeardown': true,
    });
  }

  @override
  Future<void> enqueuePendingNavigate(PendingNativeRoute route) async {
    await _channel.invokeMethod<void>('enqueuePendingNavigate', route.toMap());
  }

  @override
  Future<PendingNativeRoute?> consumePendingNavigate() async {
    final result = await _channel.invokeMethod<Object?>(
      'consumePendingNavigate',
    );
    final map = _mapFrom(result);
    final path = _nullableString(map['path']);
    if (path == null || path.isEmpty) return null;
    return PendingNativeRoute(
      path: path,
      notifyJson: _nullableMap(map['notifyJson']),
      autoEndTeardown: map['autoEndTeardown'] == true,
    );
  }

  @override
  Future<PumpSessionSnapshot?> restoreSnapshot() async {
    final result = await _channel.invokeMethod<Object?>('restoreSnapshot');
    final map = _mapFrom(result);
    if (map.isEmpty) return null;
    return PumpSessionSnapshot(
      active: map['active'] == true,
      elapsedSeconds: _intValue(map['elapsedSeconds']),
      leftMilkMl: _intValue(map['leftMilkMl']),
      rightMilkMl: _intValue(map['rightMilkMl']),
      paused: map['paused'] == true,
    );
  }

  void dispatchNativeEvent(PumpSessionNativeEvent event) {
    _eventController.add(event);
  }

  Future<void> dispose() async {
    await _eventController.close();
  }

  Map<String, Object?> _snapshotArgs(PumpSessionSnapshot snapshot) {
    return {
      'active': snapshot.active,
      'state': snapshot.paused ? 'paused' : 'running',
      'elapsedSeconds': snapshot.elapsedSeconds,
      'leftMilkMl': snapshot.leftMilkMl,
      'rightMilkMl': snapshot.rightMilkMl,
      'paused': snapshot.paused,
      'processAll': snapshot.active ? 0 : 100,
    };
  }
}

BlePermissionState _permissionStateFromResult(
  Object? result, {
  BlePermissionState fallback = BlePermissionState.unknown,
}) {
  final value = result is String
      ? result
      : _nullableString(_mapFrom(result)['state']);
  return switch (value) {
    'granted' => BlePermissionState.granted,
    'denied' => BlePermissionState.denied,
    'unknown' => BlePermissionState.unknown,
    _ => fallback,
  };
}

BleDeviceSnapshot _deviceSnapshotFromMap(Map<String, Object?> map) {
  return BleDeviceSnapshot(
    side: _string(map['side']),
    deviceId: _string(map['deviceId']),
    deviceName: _string(map['deviceName'] ?? map['name'] ?? map['localName']),
    connected: map['connected'] == true,
  );
}

Map<String, Object?> _mapFrom(Object? raw) {
  if (raw is Map) {
    return {for (final entry in raw.entries) '${entry.key}': entry.value};
  }
  return const <String, Object?>{};
}

Map<String, Object?>? _nullableMap(Object? raw) {
  final map = _mapFrom(raw);
  return map.isEmpty ? null : map;
}

List<int> _intList(Object? raw) {
  if (raw is Iterable) {
    return raw.map(_intValue).toList(growable: false);
  }
  return const [];
}

int _intValue(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse('$raw') ?? 0;
}

String _string(Object? raw) => raw == null ? '' : '$raw';

String? _nullableString(Object? raw) => raw == null ? null : '$raw';
