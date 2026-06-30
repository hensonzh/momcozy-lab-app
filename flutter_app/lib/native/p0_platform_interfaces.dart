import 'dart:async';

import 'package:momcozy_flutter_app/core/privacy/log_redactor.dart';

enum BlePermissionState { unknown, denied, granted }

enum PumpSide { left, right }

enum PumpAgentUploadSide { left, right, both }

enum PumpAgentUploadSource { device, app, agent }

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

class PumpAgentUploadProgress {
  const PumpAgentUploadProgress({
    this.processL = 0,
    this.processR = 0,
    this.processAll = 0,
    this.elapsedSeconds = 0,
  });

  final int processL;
  final int processR;
  final int processAll;
  final int elapsedSeconds;

  Map<String, Object?> toMap() => {
    'processL': processL,
    'processR': processR,
    'processAll': processAll,
    'elapsedSeconds': elapsedSeconds,
  };
}

class PumpAgentUploadCall {
  const PumpAgentUploadCall({
    required this.method,
    this.payload = const <String, Object?>{},
  });

  final String method;
  final Map<String, Object?> payload;
}

class PumpAgentUploadFailure {
  const PumpAgentUploadFailure({
    required this.method,
    required this.code,
    required this.message,
    this.retryable = false,
    this.payload = const <String, Object?>{},
  });

  final String method;
  final String code;
  final String message;
  final bool retryable;
  final Map<String, Object?> payload;
}

class PumpAgentUploadResult {
  const PumpAgentUploadResult({
    this.body = const <String, Object?>{},
    this.response = const <String, Object?>{},
    this.progress = const PumpAgentUploadProgress(),
    this.deduped = false,
  });

  final Map<String, Object?> body;
  final Map<String, Object?> response;
  final PumpAgentUploadProgress progress;
  final bool deduped;
}

abstract interface class PumpAgentUploadPlatform {
  Stream<PumpAgentUploadCall> get calls;
  Stream<PumpAgentUploadFailure> get failures;

  Future<void> setConfig({
    required String apiBaseUrl,
    required String bearerToken,
    required String userId,
  });
  Future<PumpAgentUploadProgress> sampleFromSnapshot();
  Future<PumpAgentUploadProgress> resetProgress();
  Future<void> markStepStop(PumpAgentUploadSide side);
  Future<void> markStepPause(PumpAgentUploadSide side);
  Future<void> setOperationSource(
    PumpAgentUploadSide side,
    PumpAgentUploadSource source,
  );
  Future<PumpAgentUploadResult> uploadWorkstate({required String userId});
  Future<PumpAgentUploadResult> getProcessData({required String userId});
  Future<PumpAgentUploadResult> uploadProcess({required String userId});
  Future<PumpAgentUploadResult> uploadMilkRecord({
    required String userId,
    required int endedAtMs,
  });
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

class FakePumpAgentUploadPlatform implements PumpAgentUploadPlatform {
  PumpAgentUploadProgress progress = const PumpAgentUploadProgress();
  final List<PumpAgentUploadCall> recordedCalls = [];
  final List<PumpAgentUploadFailure> recordedFailures = [];
  final Set<String> completedUploadKeys = <String>{};
  final Set<String> dedupedUploadKeys = <String>{};
  final StreamController<PumpAgentUploadCall> _callController =
      StreamController<PumpAgentUploadCall>.broadcast();
  final StreamController<PumpAgentUploadFailure> _failureController =
      StreamController<PumpAgentUploadFailure>.broadcast();

  @override
  Stream<PumpAgentUploadCall> get calls => _callController.stream;

  @override
  Stream<PumpAgentUploadFailure> get failures => _failureController.stream;

  @override
  Future<void> setConfig({
    required String apiBaseUrl,
    required String bearerToken,
    required String userId,
  }) async {
    _recordCall(
      'setConfig',
      payload: {
        'apiBaseUrl': apiBaseUrl,
        'bearerToken': bearerToken,
        'userId': userId,
      },
      redactPayload: true,
    );
  }

  @override
  Future<PumpAgentUploadProgress> sampleFromSnapshot() async {
    _recordCall('sampleFromSnapshot');
    return progress;
  }

  @override
  Future<PumpAgentUploadProgress> resetProgress() async {
    progress = const PumpAgentUploadProgress();
    _recordCall('resetProgress');
    return progress;
  }

  @override
  Future<void> markStepStop(PumpAgentUploadSide side) async {
    _recordCall('markStepStop', payload: {'side': _uploadSideValue(side)});
  }

  @override
  Future<void> markStepPause(PumpAgentUploadSide side) async {
    _recordCall('markStepPause', payload: {'side': _uploadSideValue(side)});
  }

  @override
  Future<void> setOperationSource(
    PumpAgentUploadSide side,
    PumpAgentUploadSource source,
  ) async {
    _recordCall(
      'setOperationSource',
      payload: {
        'side': _uploadSideValue(side),
        'source': _uploadSourceValue(source),
      },
    );
  }

  @override
  Future<PumpAgentUploadResult> uploadWorkstate({
    required String userId,
  }) async {
    return _recordUpload('uploadWorkstate', {'userId': userId});
  }

  @override
  Future<PumpAgentUploadResult> getProcessData({required String userId}) async {
    final body = <String, Object?>{'userId': userId};
    _recordCall('getProcessData', payload: body);
    return PumpAgentUploadResult(
      body: Map<String, Object?>.unmodifiable(body),
      response: const {'error': 0},
      progress: progress,
    );
  }

  @override
  Future<PumpAgentUploadResult> uploadProcess({required String userId}) async {
    return _recordUpload('uploadProcess', {'userId': userId});
  }

  @override
  Future<PumpAgentUploadResult> uploadMilkRecord({
    required String userId,
    required int endedAtMs,
  }) async {
    return _recordUpload('uploadMilkRecord', {
      'userId': userId,
      'endedAtMs': endedAtMs,
    });
  }

  void emitFailure({
    required String method,
    required String code,
    required String message,
    Map<String, Object?> payload = const <String, Object?>{},
    bool retryable = false,
  }) {
    final failure = PumpAgentUploadFailure(
      method: method,
      code: code,
      message: message,
      retryable: retryable,
      payload: redactLogMap(payload),
    );
    recordedFailures.add(failure);
    _failureController.add(failure);
  }

  Future<void> dispose() async {
    await _callController.close();
    await _failureController.close();
  }

  PumpAgentUploadResult _recordUpload(
    String method,
    Map<String, Object?> body,
  ) {
    final frozenBody = Map<String, Object?>.unmodifiable(body);
    final key = '$method:${_stableValueKey(frozenBody)}';
    final deduped = !completedUploadKeys.add(key);
    if (deduped) dedupedUploadKeys.add(key);
    _recordCall(method, payload: {...frozenBody, if (deduped) 'deduped': true});
    return PumpAgentUploadResult(
      body: frozenBody,
      response: const {'error': 0},
      progress: progress,
      deduped: deduped,
    );
  }

  void _recordCall(
    String method, {
    Map<String, Object?> payload = const <String, Object?>{},
    bool redactPayload = false,
  }) {
    final safePayload = redactPayload
        ? redactLogMap(payload)
        : Map<String, Object?>.unmodifiable(payload);
    final call = PumpAgentUploadCall(method: method, payload: safePayload);
    recordedCalls.add(call);
    _callController.add(call);
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

String _uploadSideValue(PumpAgentUploadSide side) {
  return switch (side) {
    PumpAgentUploadSide.left => 'L',
    PumpAgentUploadSide.right => 'R',
    PumpAgentUploadSide.both => 'both',
  };
}

String _uploadSourceValue(PumpAgentUploadSource source) {
  return switch (source) {
    PumpAgentUploadSource.device => 'device',
    PumpAgentUploadSource.app => 'app',
    PumpAgentUploadSource.agent => 'agent',
  };
}

String _stableValueKey(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return '{${keys.map((key) => '$key:${_stableValueKey(value[key])}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_stableValueKey).join(',')}]';
  }
  return '$value';
}
