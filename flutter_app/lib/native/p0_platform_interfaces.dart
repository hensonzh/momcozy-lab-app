import 'dart:async';

enum BlePermissionState { unknown, denied, granted }

enum PumpSide { left, right }

enum PumpSessionNativeEventType {
  started,
  updated,
  stopped,
  completionNotice,
  autoEndNotice,
}

class BleDeviceSnapshot {
  const BleDeviceSnapshot({
    required this.side,
    required this.deviceId,
    required this.deviceName,
    this.connected = false,
  });

  final String side;
  final String deviceId;
  final String deviceName;
  final bool connected;

  BleDeviceSnapshot copyWith({bool? connected}) {
    return BleDeviceSnapshot(
      side: side,
      deviceId: deviceId,
      deviceName: deviceName,
      connected: connected ?? this.connected,
    );
  }
}

class BleScanFailure {
  const BleScanFailure({required this.code, required this.message});

  final String code;
  final String message;
}

class BleNotification {
  const BleNotification({
    required this.deviceId,
    required this.characteristicUuid,
    required this.value,
  });

  final String deviceId;
  final String characteristicUuid;
  final List<int> value;
}

abstract interface class BlePlatform {
  Stream<BleDeviceSnapshot> get scanResults;
  Stream<BleScanFailure> get scanFailures;
  Stream<BleNotification> get notifications;

  Future<BlePermissionState> permissionState();
  Future<BlePermissionState> requestPermission();
  Future<void> openBluetoothSettings();
  Future<void> openAppSettings();
  Future<void> startScan();
  Future<void> stopScan();
  Future<List<BleDeviceSnapshot>> getConnectedDevices();
  Future<void> connect(String deviceId);
  Future<void> disconnect(String deviceId);
  Future<List<int>> read(String deviceId, String characteristicUuid);
  Future<void> write(
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  );
  Future<void> writeWithoutResponse(
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  );
  Future<void> startNotifications(String deviceId, String characteristicUuid);
  Future<void> stopNotifications(String deviceId, String characteristicUuid);
}

class PumpParamsRequest {
  const PumpParamsRequest({
    required this.startStop,
    required this.mode,
    required this.gear,
    required this.scene,
  });

  final int startStop;
  final int mode;
  final int gear;
  final int scene;
}

class PumpProtocolCommand {
  const PumpProtocolCommand({
    required this.name,
    required this.side,
    this.payload = const <String, Object?>{},
  });

  final String name;
  final PumpSide side;
  final Map<String, Object?> payload;
}

abstract interface class PumpProtocolPlatform {
  Stream<PumpProtocolCommand> get commands;

  Future<void> setPumpParams(PumpSide side, PumpParamsRequest request);
  Future<void> powerOff(PumpSide side, {bool reboot = false});
  Future<void> endRun(PumpSide side);
  Future<void> getDeviceInfo(PumpSide side);
  Future<void> setRtc(PumpSide side, int utcSeconds);
  Future<void> queryDeviceStatus(PumpSide side);
  Future<void> adjustGearForSide(PumpSide side, int gear);
  Future<void> setModeForSide(PumpSide side, int mode);
  Future<void> setSceneForSide(PumpSide side, int scene);
  Future<void> setStartStopForSide(PumpSide side, int startStop);
}

class PumpSessionSnapshot {
  const PumpSessionSnapshot({
    required this.active,
    required this.elapsedSeconds,
    this.leftMilkMl = 0,
    this.rightMilkMl = 0,
    this.paused = false,
  });

  final bool active;
  final int elapsedSeconds;
  final int leftMilkMl;
  final int rightMilkMl;
  final bool paused;
}

class PumpSessionNativeEvent {
  const PumpSessionNativeEvent({
    required this.type,
    this.snapshot,
    this.payload = const <String, Object?>{},
  });

  final PumpSessionNativeEventType type;
  final PumpSessionSnapshot? snapshot;
  final Map<String, Object?> payload;
}

class PendingNativeRoute {
  const PendingNativeRoute({
    required this.path,
    this.notifyJson,
    this.autoEndTeardown = false,
  });

  final String path;
  final Map<String, Object?>? notifyJson;
  final bool autoEndTeardown;

  Map<String, Object?> toMap() => {
    'path': path,
    if (notifyJson != null) 'notifyJson': notifyJson,
    if (autoEndTeardown) 'autoEndTeardown': true,
  };
}

abstract interface class PumpSessionForegroundServicePlatform {
  Stream<PumpSessionNativeEvent> get events;

  Future<bool> requestPermission();
  Future<void> start(PumpSessionSnapshot snapshot);
  Future<void> update(PumpSessionSnapshot snapshot);
  Future<void> stop();
  Future<void> showCompletionNotice(PumpSessionSnapshot snapshot);
  Future<void> showAutoEndNotice(PumpSessionSnapshot snapshot);
  Future<void> enqueuePendingNavigate(PendingNativeRoute route);
  Future<PendingNativeRoute?> consumePendingNavigate();
  Future<PumpSessionSnapshot?> restoreSnapshot();
}

abstract interface class PumpWakeLockPlatform {
  Future<void> acquire();
  Future<void> release();
}

abstract interface class RouteIntentPlatform {
  Stream<PendingNativeRoute> get activeRoutes;

  Future<void> enqueuePendingRoute(PendingNativeRoute route);
  Future<PendingNativeRoute?> consumePendingRoute();
  void dispatchActiveRoute(PendingNativeRoute route);
}

class FakeBlePlatform implements BlePlatform {
  FakeBlePlatform({
    List<BleDeviceSnapshot> seedDevices = const [],
    BlePermissionState initialPermission = BlePermissionState.unknown,
  }) : _permissionState = initialPermission,
       _devices = {for (final device in seedDevices) device.deviceId: device};

  final Map<String, BleDeviceSnapshot> _devices;
  final Map<String, List<int>> _readValues = {};
  final Set<String> _notificationKeys = {};
  final List<Map<String, Object?>> writes = [];
  final StreamController<BleDeviceSnapshot> _scanController =
      StreamController<BleDeviceSnapshot>.broadcast();
  final StreamController<BleScanFailure> _scanFailureController =
      StreamController<BleScanFailure>.broadcast();
  final StreamController<BleNotification> _notificationController =
      StreamController<BleNotification>.broadcast();
  BlePermissionState _permissionState;
  bool scanning = false;
  bool openedBluetoothSettings = false;
  bool openedAppSettings = false;

  @override
  Stream<BleDeviceSnapshot> get scanResults => _scanController.stream;

  @override
  Stream<BleScanFailure> get scanFailures => _scanFailureController.stream;

  @override
  Stream<BleNotification> get notifications => _notificationController.stream;

  @override
  Future<BlePermissionState> permissionState() async => _permissionState;

  @override
  Future<BlePermissionState> requestPermission() async {
    _permissionState = BlePermissionState.granted;
    return _permissionState;
  }

  @override
  Future<void> openBluetoothSettings() async {
    openedBluetoothSettings = true;
  }

  @override
  Future<void> openAppSettings() async {
    openedAppSettings = true;
  }

  void addScanResult(BleDeviceSnapshot snapshot) {
    _devices[snapshot.deviceId] = snapshot;
    if (scanning) _scanController.add(snapshot);
  }

  void failScan(BleScanFailure failure) {
    if (scanning) _scanFailureController.add(failure);
  }

  void setReadValue(
    String deviceId,
    String characteristicUuid,
    List<int> value,
  ) {
    _readValues[_key(deviceId, characteristicUuid)] = List<int>.unmodifiable(
      value,
    );
  }

  void emitNotification(BleNotification notification) {
    if (_notificationKeys.contains(
      _key(notification.deviceId, notification.characteristicUuid),
    )) {
      _notificationController.add(notification);
    }
  }

  bool isSubscribed(String deviceId, String characteristicUuid) {
    return _notificationKeys.contains(_key(deviceId, characteristicUuid));
  }

  @override
  Future<void> startScan() async {
    _ensurePermission();
    scanning = true;
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
  }

  @override
  Future<List<BleDeviceSnapshot>> getConnectedDevices() async {
    return _devices.values
        .where((device) => device.connected)
        .toList(growable: false);
  }

  @override
  Future<void> connect(String deviceId) async {
    final current = _deviceOrThrow(deviceId);
    _devices[deviceId] = current.copyWith(connected: true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final current = _deviceOrThrow(deviceId);
    _devices[deviceId] = current.copyWith(connected: false);
  }

  @override
  Future<List<int>> read(String deviceId, String characteristicUuid) async {
    _deviceOrThrow(deviceId);
    return List<int>.from(
      _readValues[_key(deviceId, characteristicUuid)] ?? const [],
    );
  }

  @override
  Future<void> write(
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  ) async {
    _recordWrite('write', deviceId, characteristicUuid, bytes);
  }

  @override
  Future<void> writeWithoutResponse(
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  ) async {
    _recordWrite('writeWithoutResponse', deviceId, characteristicUuid, bytes);
  }

  @override
  Future<void> startNotifications(
    String deviceId,
    String characteristicUuid,
  ) async {
    _deviceOrThrow(deviceId);
    _notificationKeys.add(_key(deviceId, characteristicUuid));
  }

  @override
  Future<void> stopNotifications(
    String deviceId,
    String characteristicUuid,
  ) async {
    _notificationKeys.remove(_key(deviceId, characteristicUuid));
  }

  Future<void> dispose() async {
    await _scanController.close();
    await _scanFailureController.close();
    await _notificationController.close();
  }

  void _recordWrite(
    String method,
    String deviceId,
    String characteristicUuid,
    List<int> bytes,
  ) {
    _deviceOrThrow(deviceId);
    writes.add({
      'method': method,
      'deviceId': deviceId,
      'characteristicUuid': characteristicUuid,
      'bytes': List<int>.unmodifiable(bytes),
    });
  }

  BleDeviceSnapshot _deviceOrThrow(String deviceId) {
    final device = _devices[deviceId];
    if (device == null) {
      throw StateError('Unknown BLE device: $deviceId');
    }
    return device;
  }

  void _ensurePermission() {
    if (_permissionState != BlePermissionState.granted) {
      throw StateError('BLE permission is not granted.');
    }
  }

  static String _key(String deviceId, String characteristicUuid) {
    return '$deviceId::$characteristicUuid';
  }
}

class FakePumpProtocolPlatform implements PumpProtocolPlatform {
  final List<PumpProtocolCommand> recordedCommands = [];
  final StreamController<PumpProtocolCommand> _commandController =
      StreamController<PumpProtocolCommand>.broadcast();

  @override
  Stream<PumpProtocolCommand> get commands => _commandController.stream;

  @override
  Future<void> setPumpParams(PumpSide side, PumpParamsRequest request) async {
    _record(
      PumpProtocolCommand(
        name: 'setPumpParams',
        side: side,
        payload: {
          'startStop': request.startStop,
          'mode': request.mode,
          'gear': request.gear,
          'scene': request.scene,
        },
      ),
    );
  }

  @override
  Future<void> powerOff(PumpSide side, {bool reboot = false}) async {
    _record(
      PumpProtocolCommand(
        name: 'powerOff',
        side: side,
        payload: {'reboot': reboot},
      ),
    );
  }

  @override
  Future<void> endRun(PumpSide side) async {
    _record(PumpProtocolCommand(name: 'endRun', side: side));
  }

  @override
  Future<void> getDeviceInfo(PumpSide side) async {
    _record(PumpProtocolCommand(name: 'getDeviceInfo', side: side));
  }

  @override
  Future<void> setRtc(PumpSide side, int utcSeconds) async {
    _record(
      PumpProtocolCommand(
        name: 'setRtc',
        side: side,
        payload: {'utcSeconds': utcSeconds},
      ),
    );
  }

  @override
  Future<void> queryDeviceStatus(PumpSide side) async {
    _record(PumpProtocolCommand(name: 'queryDeviceStatus', side: side));
  }

  @override
  Future<void> adjustGearForSide(PumpSide side, int gear) async {
    _record(
      PumpProtocolCommand(
        name: 'adjustGearForSide',
        side: side,
        payload: {'gear': gear},
      ),
    );
  }

  @override
  Future<void> setModeForSide(PumpSide side, int mode) async {
    _record(
      PumpProtocolCommand(
        name: 'setModeForSide',
        side: side,
        payload: {'mode': mode},
      ),
    );
  }

  @override
  Future<void> setSceneForSide(PumpSide side, int scene) async {
    _record(
      PumpProtocolCommand(
        name: 'setSceneForSide',
        side: side,
        payload: {'scene': scene},
      ),
    );
  }

  @override
  Future<void> setStartStopForSide(PumpSide side, int startStop) async {
    _record(
      PumpProtocolCommand(
        name: 'setStartStopForSide',
        side: side,
        payload: {'startStop': startStop},
      ),
    );
  }

  Future<void> dispose() async {
    await _commandController.close();
  }

  void _record(PumpProtocolCommand command) {
    recordedCommands.add(command);
    _commandController.add(command);
  }
}

class FakePumpSessionForegroundServicePlatform
    implements PumpSessionForegroundServicePlatform {
  FakePumpSessionForegroundServicePlatform({this.permissionGranted = true});

  final StreamController<PumpSessionNativeEvent> _eventController =
      StreamController<PumpSessionNativeEvent>.broadcast();
  PumpSessionSnapshot? _snapshot;
  PendingNativeRoute? _pendingRoute;
  bool permissionGranted;

  @override
  Stream<PumpSessionNativeEvent> get events => _eventController.stream;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> start(PumpSessionSnapshot snapshot) async {
    _snapshot = snapshot;
    _emit(
      PumpSessionNativeEvent(
        type: PumpSessionNativeEventType.started,
        snapshot: snapshot,
      ),
    );
  }

  @override
  Future<void> update(PumpSessionSnapshot snapshot) async {
    if (_snapshot == null) throw StateError('Pump session has not started.');
    _snapshot = snapshot;
    _emit(
      PumpSessionNativeEvent(
        type: PumpSessionNativeEventType.updated,
        snapshot: snapshot,
      ),
    );
  }

  @override
  Future<void> stop() async {
    final previous = _snapshot;
    _snapshot = null;
    _emit(
      PumpSessionNativeEvent(
        type: PumpSessionNativeEventType.stopped,
        snapshot: previous,
      ),
    );
  }

  @override
  Future<void> showCompletionNotice(PumpSessionSnapshot snapshot) async {
    _emit(
      PumpSessionNativeEvent(
        type: PumpSessionNativeEventType.completionNotice,
        snapshot: snapshot,
      ),
    );
  }

  @override
  Future<void> showAutoEndNotice(PumpSessionSnapshot snapshot) async {
    _emit(
      PumpSessionNativeEvent(
        type: PumpSessionNativeEventType.autoEndNotice,
        snapshot: snapshot,
      ),
    );
  }

  @override
  Future<void> enqueuePendingNavigate(PendingNativeRoute route) async {
    _pendingRoute = route;
  }

  @override
  Future<PendingNativeRoute?> consumePendingNavigate() async {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  @override
  Future<PumpSessionSnapshot?> restoreSnapshot() async => _snapshot;

  Future<void> dispose() async {
    await _eventController.close();
  }

  void _emit(PumpSessionNativeEvent event) {
    _eventController.add(event);
  }
}

class FakePumpWakeLockPlatform implements PumpWakeLockPlatform {
  var acquireCount = 0;

  bool get held => acquireCount > 0;

  @override
  Future<void> acquire() async {
    acquireCount += 1;
  }

  @override
  Future<void> release() async {
    if (acquireCount > 0) acquireCount -= 1;
  }
}

class FakeRouteIntentPlatform implements RouteIntentPlatform {
  final StreamController<PendingNativeRoute> _activeRouteController =
      StreamController<PendingNativeRoute>.broadcast();
  PendingNativeRoute? _pending;

  @override
  Stream<PendingNativeRoute> get activeRoutes => _activeRouteController.stream;

  @override
  Future<void> enqueuePendingRoute(PendingNativeRoute route) async {
    _pending = route;
  }

  @override
  Future<PendingNativeRoute?> consumePendingRoute() async {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  @override
  void dispatchActiveRoute(PendingNativeRoute route) {
    _activeRouteController.add(route);
  }

  Future<void> dispose() async {
    await _activeRouteController.close();
  }
}
