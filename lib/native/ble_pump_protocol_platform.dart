import 'dart:async';

import 'package:app/core/ble/ble_protocol.dart';
import 'package:app/native/p0_platform_interfaces.dart';

const defaultPumpCommandCharacteristicUuid =
    '0000af01-0000-1000-8000-00805f9b34fb';

typedef PumpDeviceIdForSide = String? Function(PumpSide side);
typedef PumpProtocolStateForSide =
    PumpProtocolSideState? Function(PumpSide side);

class PumpProtocolSideState {
  const PumpProtocolSideState({
    required this.startStop,
    required this.mode,
    required this.gear,
    required this.scene,
  });

  final int startStop;
  final int mode;
  final int gear;
  final int scene;

  PumpParamsRequest toRequest({
    int? startStop,
    int? mode,
    int? gear,
    int? scene,
  }) {
    return PumpParamsRequest(
      startStop: startStop ?? this.startStop,
      mode: mode ?? this.mode,
      gear: gear ?? this.gear,
      scene: scene ?? this.scene,
    );
  }
}

class BlePumpProtocolPlatform implements PumpProtocolPlatform {
  BlePumpProtocolPlatform({
    required this.ble,
    required this.deviceIdForSide,
    required this.stateForSide,
    this.commandCharacteristicUuid = defaultPumpCommandCharacteristicUuid,
  });

  final BlePlatform ble;
  final PumpDeviceIdForSide deviceIdForSide;
  final PumpProtocolStateForSide stateForSide;
  final String commandCharacteristicUuid;
  final List<PumpProtocolCommand> recordedCommands = [];
  final StreamController<PumpProtocolCommand> _commandController =
      StreamController<PumpProtocolCommand>.broadcast();

  @override
  Stream<PumpProtocolCommand> get commands => _commandController.stream;

  @override
  Future<void> setPumpParams(PumpSide side, PumpParamsRequest request) async {
    await _sendPumpParamsCommand(
      name: 'setPumpParams',
      side: side,
      request: request,
      payload: {
        'startStop': request.startStop,
        'mode': request.mode,
        'gear': request.gear,
        'scene': request.scene,
      },
    );
  }

  @override
  Future<void> powerOff(PumpSide side, {bool reboot = false}) async {
    await _send(
      PumpProtocolCommand(
        name: 'powerOff',
        side: side,
        payload: {'reboot': reboot},
      ),
      buildFEPowerOff(reboot ? 1 : 0),
    );
  }

  @override
  Future<void> endRun(PumpSide side) async {
    await _send(
      PumpProtocolCommand(name: 'endRun', side: side),
      buildBFEndRun(),
    );
  }

  @override
  Future<void> getDeviceInfo(PumpSide side) async {
    await _send(
      PumpProtocolCommand(name: 'getDeviceInfo', side: side),
      buildF0GetDeviceInfo(),
    );
  }

  @override
  Future<void> setRtc(PumpSide side, int utcSeconds) async {
    await _send(
      PumpProtocolCommand(
        name: 'setRtc',
        side: side,
        payload: {'utcSeconds': utcSeconds},
      ),
      buildF2SetRtc(utcSeconds),
    );
  }

  @override
  Future<void> queryDeviceStatus(PumpSide side) async {
    await _send(
      PumpProtocolCommand(name: 'queryDeviceStatus', side: side),
      buildE1QueryDeviceStatus(),
    );
  }

  @override
  Future<void> adjustGearForSide(PumpSide side, int gear) async {
    final state = _stateOrThrow(side);
    await _sendPumpParamsCommand(
      name: 'adjustGearForSide',
      side: side,
      request: state.toRequest(gear: gear),
      payload: {'gear': gear},
    );
  }

  @override
  Future<void> setModeForSide(PumpSide side, int mode) async {
    final state = _stateOrThrow(side);
    await _sendPumpParamsCommand(
      name: 'setModeForSide',
      side: side,
      request: state.toRequest(mode: mode),
      payload: {'mode': mode},
    );
  }

  @override
  Future<void> setSceneForSide(PumpSide side, int scene) async {
    final state = _stateOrThrow(side);
    await _sendPumpParamsCommand(
      name: 'setSceneForSide',
      side: side,
      request: state.toRequest(scene: scene),
      payload: {'scene': scene},
    );
  }

  @override
  Future<void> setStartStopForSide(PumpSide side, int startStop) async {
    final state = _stateOrThrow(side);
    await _sendPumpParamsCommand(
      name: 'setStartStopForSide',
      side: side,
      request: state.toRequest(startStop: startStop),
      payload: {'startStop': startStop},
    );
  }

  Future<void> dispose() async {
    await _commandController.close();
  }

  Future<void> _send(PumpProtocolCommand command, List<int> packet) async {
    final deviceId = deviceIdForSide(command.side);
    if (deviceId == null || deviceId.isEmpty) {
      throw StateError('No BLE device for pump side ${command.side.name}');
    }
    await ble.writeWithoutResponse(deviceId, commandCharacteristicUuid, packet);
    _record(command);
  }

  Future<void> _sendPumpParamsCommand({
    required String name,
    required PumpSide side,
    required PumpParamsRequest request,
    required Map<String, Object?> payload,
  }) async {
    await _send(
      PumpProtocolCommand(name: name, side: side, payload: payload),
      buildB1SetPumpParams(
        request.startStop,
        request.mode,
        request.gear,
        request.scene,
      ),
    );
  }

  PumpProtocolSideState _stateOrThrow(PumpSide side) {
    final state = stateForSide(side);
    if (state == null) {
      throw StateError('No pump protocol state for side ${side.name}');
    }
    return state;
  }

  void _record(PumpProtocolCommand command) {
    recordedCommands.add(command);
    _commandController.add(command);
  }
}
