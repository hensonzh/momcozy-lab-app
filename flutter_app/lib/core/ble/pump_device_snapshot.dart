import 'dart:typed_data';

import 'ble_protocol.dart';

enum PumpDeviceSide { left, right }

class PumpGearMemory {
  const PumpGearMemory({this.stimulate, this.deep});

  final int? stimulate;
  final int? deep;

  PumpGearMemory copyWith({int? stimulate, int? deep}) {
    return PumpGearMemory(
      stimulate: stimulate ?? this.stimulate,
      deep: deep ?? this.deep,
    );
  }

  Map<String, Object?> toMap() => {
    if (stimulate != null) 'stimulate': stimulate,
    if (deep != null) 'deep': deep,
  };
}

class PumpDeviceSideState {
  const PumpDeviceSideState({
    required this.deviceId,
    this.deviceName = '',
    this.connected = false,
    this.battery = 0,
    this.rssi,
    this.flangeSize = 24,
    this.sealSize = 'M',
    this.model = '',
    this.firmware = '-',
    this.serialNumber = '',
    this.pumpMode,
    this.gear,
    this.pumpWorkState,
    this.pumpScene,
    this.duration,
    this.finalMilkMl,
    this.pumpGearMemoryAi,
    this.pumpGearMemoryManual,
    this.pumpGearCalib,
    this.flowFloat,
    this.milkMl,
    this.milkFlag,
    this.moFlag,
    this.bandpower,
    this.pitch,
    this.roll,
    this.pressureCh1,
    this.pressureCh2,
    this.lastDeviceWorkstateTs,
    this.lastDeviceProcessTs,
  });

  final String deviceId;
  final String deviceName;
  final bool connected;
  final int battery;
  final int? rssi;
  final int flangeSize;
  final String sealSize;
  final String model;
  final String firmware;
  final String serialNumber;
  final int? pumpMode;
  final int? gear;
  final int? pumpWorkState;
  final int? pumpScene;
  final int? duration;
  final double? finalMilkMl;
  final PumpGearMemory? pumpGearMemoryAi;
  final PumpGearMemory? pumpGearMemoryManual;
  final PumpGearMemory? pumpGearCalib;
  final double? flowFloat;
  final double? milkMl;
  final int? milkFlag;
  final int? moFlag;
  final double? bandpower;
  final double? pitch;
  final double? roll;
  final double? pressureCh1;
  final double? pressureCh2;
  final String? lastDeviceWorkstateTs;
  final String? lastDeviceProcessTs;

  PumpDeviceSideState copyWith({
    String? deviceId,
    String? deviceName,
    bool? connected,
    int? battery,
    int? rssi,
    int? flangeSize,
    String? sealSize,
    String? model,
    String? firmware,
    String? serialNumber,
    int? pumpMode,
    int? gear,
    int? pumpWorkState,
    int? pumpScene,
    int? duration,
    double? finalMilkMl,
    PumpGearMemory? pumpGearMemoryAi,
    PumpGearMemory? pumpGearMemoryManual,
    PumpGearMemory? pumpGearCalib,
    double? flowFloat,
    double? milkMl,
    int? milkFlag,
    int? moFlag,
    double? bandpower,
    double? pitch,
    double? roll,
    double? pressureCh1,
    double? pressureCh2,
    String? lastDeviceWorkstateTs,
    String? lastDeviceProcessTs,
  }) {
    return PumpDeviceSideState(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      connected: connected ?? this.connected,
      battery: battery ?? this.battery,
      rssi: rssi ?? this.rssi,
      flangeSize: flangeSize ?? this.flangeSize,
      sealSize: sealSize ?? this.sealSize,
      model: model ?? this.model,
      firmware: firmware ?? this.firmware,
      serialNumber: serialNumber ?? this.serialNumber,
      pumpMode: pumpMode ?? this.pumpMode,
      gear: gear ?? this.gear,
      pumpWorkState: pumpWorkState ?? this.pumpWorkState,
      pumpScene: pumpScene ?? this.pumpScene,
      duration: duration ?? this.duration,
      finalMilkMl: finalMilkMl ?? this.finalMilkMl,
      pumpGearMemoryAi: pumpGearMemoryAi ?? this.pumpGearMemoryAi,
      pumpGearMemoryManual: pumpGearMemoryManual ?? this.pumpGearMemoryManual,
      pumpGearCalib: pumpGearCalib ?? this.pumpGearCalib,
      flowFloat: flowFloat ?? this.flowFloat,
      milkMl: milkMl ?? this.milkMl,
      milkFlag: milkFlag ?? this.milkFlag,
      moFlag: moFlag ?? this.moFlag,
      bandpower: bandpower ?? this.bandpower,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      pressureCh1: pressureCh1 ?? this.pressureCh1,
      pressureCh2: pressureCh2 ?? this.pressureCh2,
      lastDeviceWorkstateTs:
          lastDeviceWorkstateTs ?? this.lastDeviceWorkstateTs,
      lastDeviceProcessTs: lastDeviceProcessTs ?? this.lastDeviceProcessTs,
    );
  }

  Map<String, Object?> toMap() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'connected': connected,
    'battery': battery,
    if (rssi != null) 'rssi': rssi,
    'flangeSize': flangeSize,
    'sealSize': sealSize,
    'model': model,
    'firmware': firmware,
    'serialNumber': serialNumber,
    if (pumpMode != null) 'pumpMode': pumpMode,
    if (gear != null) 'gear': gear,
    if (pumpWorkState != null) 'pumpWorkState': pumpWorkState,
    if (pumpScene != null) 'pumpScene': pumpScene,
    if (duration != null) 'duration': duration,
    if (finalMilkMl != null) 'finalMilkMl': finalMilkMl,
    if (pumpGearMemoryAi != null) 'pumpGearMemoryAi': pumpGearMemoryAi!.toMap(),
    if (pumpGearMemoryManual != null)
      'pumpGearMemoryManual': pumpGearMemoryManual!.toMap(),
    if (pumpGearCalib != null) 'pumpGearCalib': pumpGearCalib!.toMap(),
    if (flowFloat != null) 'flowFloat': flowFloat,
    if (milkMl != null) 'milkMl': milkMl,
    if (milkFlag != null) 'milkFlag': milkFlag,
    if (moFlag != null) 'moFlag': moFlag,
    if (bandpower != null) 'bandpower': bandpower,
    if (pitch != null) 'pitch': pitch,
    if (roll != null) 'roll': roll,
    if (pressureCh1 != null) 'pressureCh1': pressureCh1,
    if (pressureCh2 != null) 'pressureCh2': pressureCh2,
    if (lastDeviceWorkstateTs != null)
      'lastDeviceWorkstateTs': lastDeviceWorkstateTs,
    if (lastDeviceProcessTs != null) 'lastDeviceProcessTs': lastDeviceProcessTs,
  };
}

class PumpDeviceSnapshot {
  const PumpDeviceSnapshot({
    this.left,
    this.right,
    this.leftBandpowerMax = 0,
    this.rightBandpowerMax = 0,
  });

  final PumpDeviceSideState? left;
  final PumpDeviceSideState? right;
  final double leftBandpowerMax;
  final double rightBandpowerMax;

  PumpDeviceSnapshotUpdate applyProtocolFrame({
    required String deviceId,
    required Uint8List value,
  }) {
    final frame = parseFrame(value);
    if (frame == null) return PumpDeviceSnapshotUpdate(this, changed: false);

    switch (frame.cid) {
      case _cidF0:
        if (frame.ct != ctAck) break;
        return _applyToDevice(deviceId, (device, side) {
          final parsed = parseF0DeviceInfo(frame.cab);
          if (parsed == null) return null;
          return _replaceSide(
            side,
            device.copyWith(firmware: _string(parsed['softwareVersion'])),
          );
        });
      case _cidE1:
        if (frame.ct != ctAck) break;
        return _applyToDevice(deviceId, (device, side) {
          final parsed = parseE1DeviceStatus(frame.cab);
          if (parsed == null) return null;
          final ts = _timestampFromSeconds(_int(parsed['bootTime']));
          return _replaceSide(
            side,
            device.copyWith(
              battery: _clamp(
                _int(parsed['batteryPct'], device.battery),
                0,
                100,
              ),
              pumpMode: _clamp(_int(parsed['pumpMode']), 0, 2),
              gear: _clamp(_int(parsed['gear']), 0, 14),
              pumpWorkState: _int(parsed['workState']),
              pumpScene: _int(parsed['scene']) != 0 ? 1 : 0,
              duration: _int(parsed['duration']),
              pumpGearCalib: PumpGearMemory(
                stimulate: _int(parsed['pumpGearCalibStimulate']),
                deep: _int(parsed['pumpGearCalibDeep']),
              ),
              lastDeviceWorkstateTs: ts,
            ),
          );
        });
      case _cidD6:
        return _applyToDevice(deviceId, (device, side) {
          final parsed = parseD6Battery(frame.cab);
          if (parsed == null) return null;
          return _replaceSide(
            side,
            device.copyWith(
              battery: _clamp(
                _int(parsed['batteryPct'], device.battery),
                0,
                100,
              ),
              lastDeviceWorkstateTs: _timestampFromSeconds(
                _int(parsed['timestamp']),
              ),
            ),
          );
        });
      case _cidD0:
        return _applyToDevice(deviceId, (device, side) {
          final parsed = parseD0OperationRecord(frame.cab);
          if (parsed == null) return null;
          final mode = _clamp(
            _int(parsed['afterMode'], device.pumpMode ?? 0),
            0,
            2,
          );
          final gear = _clamp(
            _int(parsed['afterGear'], device.gear ?? 0),
            0,
            14,
          );
          final scene = _int(parsed['afterAutoFlag']) != 0 ? 1 : 0;
          final patched = _patchGearMemory(device, scene, mode, gear);
          return _replaceSide(
            side,
            patched.copyWith(
              pumpScene: scene,
              pumpWorkState: _int(parsed['afterStartStop']) == 1 ? 1 : 0,
              pumpMode: mode,
              gear: gear,
              duration: _int(parsed['duration']) > 0
                  ? _int(parsed['duration'])
                  : null,
              lastDeviceWorkstateTs: _timestampFromSeconds(
                _int(parsed['timestamp']),
              ),
            ),
          );
        });
      case _cid80:
        return _applyToDevice(deviceId, (device, side) {
          final parsed = parse80RealtimeMilk(frame.cab);
          if (parsed == null) return null;
          final rawBandpower = _nonNegativeDouble(parsed['bandpower']);
          final maxBandpower = side == PumpDeviceSide.left
              ? _max(leftBandpowerMax, rawBandpower)
              : _max(rightBandpowerMax, rawBandpower);
          final storedBandpower = rawBandpower < 500
              ? 0.0
              : rawBandpower / maxBandpower;
          return _replaceSide(
            side,
            device.copyWith(
              flowFloat: _double(parsed['flowFloat']),
              milkMl: _double(parsed['milkMlX10']) / 10.0,
              milkFlag: _int(parsed['milkFlag']),
              moFlag: _int(parsed['moFlag']),
              bandpower: storedBandpower,
              pitch: _double(parsed['pitchX10']) / 10.0,
              roll: _double(parsed['rollX10']) / 10.0,
              pressureCh1: _double(parsed['pressureCh1X10']) / 10.0,
              pressureCh2: _double(parsed['pressureCh2X10']) / 10.0,
              lastDeviceProcessTs: _timestampFromSeconds(
                _int(parsed['timestamp']),
              ),
            ),
            leftBandpowerMax: side == PumpDeviceSide.left ? maxBandpower : null,
            rightBandpowerMax: side == PumpDeviceSide.right
                ? maxBandpower
                : null,
          );
        });
      case _cidBf:
        if (frame.ct != ctAck) break;
        return _applyToDevice(deviceId, (device, side) {
          final parsed = parseBFEndRunResponse(frame.cab);
          if (parsed == null) return null;
          return _replaceSide(
            side,
            device.copyWith(finalMilkMl: _double(parsed['milkMlX10']) / 10.0),
          );
        });
      case _cidFe:
        if (frame.ct != ctAck) break;
        return _applyToDevice(deviceId, (device, side) {
          return _replaceSide(side, device.copyWith(pumpWorkState: 0));
        });
    }

    return PumpDeviceSnapshotUpdate(this, changed: false);
  }

  PumpDeviceSide? sideForDeviceId(String deviceId) {
    if (deviceId.isEmpty) return null;
    if (left?.deviceId == deviceId) return PumpDeviceSide.left;
    if (right?.deviceId == deviceId) return PumpDeviceSide.right;
    return null;
  }

  Map<String, Object?> toMap() => {'L': left?.toMap(), 'R': right?.toMap()};

  PumpDeviceSnapshot replaceSide(
    PumpDeviceSide side,
    PumpDeviceSideState device, {
    double? leftBandpowerMax,
    double? rightBandpowerMax,
  }) {
    return PumpDeviceSnapshot(
      left: side == PumpDeviceSide.left ? device : left,
      right: side == PumpDeviceSide.right ? device : right,
      leftBandpowerMax: leftBandpowerMax ?? this.leftBandpowerMax,
      rightBandpowerMax: rightBandpowerMax ?? this.rightBandpowerMax,
    );
  }

  PumpDeviceSnapshotUpdate _applyToDevice(
    String deviceId,
    PumpDeviceSnapshot? Function(
      PumpDeviceSideState device,
      PumpDeviceSide side,
    )
    update,
  ) {
    final side = sideForDeviceId(deviceId);
    final device = switch (side) {
      PumpDeviceSide.left => left,
      PumpDeviceSide.right => right,
      null => null,
    };
    if (side == null || device == null) {
      return PumpDeviceSnapshotUpdate(this, changed: false);
    }
    final next = update(device, side);
    if (next == null) return PumpDeviceSnapshotUpdate(this, changed: false);
    return PumpDeviceSnapshotUpdate(next, changed: true);
  }

  PumpDeviceSnapshot _replaceSide(
    PumpDeviceSide side,
    PumpDeviceSideState device, {
    double? leftBandpowerMax,
    double? rightBandpowerMax,
  }) {
    return replaceSide(
      side,
      device,
      leftBandpowerMax: leftBandpowerMax ?? this.leftBandpowerMax,
      rightBandpowerMax: rightBandpowerMax ?? this.rightBandpowerMax,
    );
  }
}

class PumpDeviceSnapshotUpdate {
  const PumpDeviceSnapshotUpdate(this.snapshot, {required this.changed});

  final PumpDeviceSnapshot snapshot;
  final bool changed;
}

PumpDeviceSideState _patchGearMemory(
  PumpDeviceSideState device,
  int scene,
  int mode,
  int gear,
) {
  final memory = scene == 1
      ? _patchMemory(device.pumpGearMemoryAi, mode, gear)
      : _patchMemory(device.pumpGearMemoryManual, mode, gear);
  return scene == 1
      ? device.copyWith(pumpGearMemoryAi: memory)
      : device.copyWith(pumpGearMemoryManual: memory);
}

PumpGearMemory _patchMemory(PumpGearMemory? memory, int mode, int gear) {
  final clamped = _clamp(gear, 0, 14);
  if (mode == 0) {
    return (memory ?? const PumpGearMemory()).copyWith(stimulate: clamped);
  }
  if (mode == 1) {
    return (memory ?? const PumpGearMemory()).copyWith(deep: clamped);
  }
  return PumpGearMemory(stimulate: clamped, deep: clamped);
}

String? _timestampFromSeconds(int seconds) {
  if (seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toIso8601String();
}

String _string(Object? value, [String fallback = '']) {
  return value?.toString() ?? fallback;
}

int _int(Object? value, [int fallback = 0]) {
  return switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value) ?? fallback,
    _ => fallback,
  };
}

double _double(Object? value, [double fallback = 0]) {
  return switch (value) {
    double() => value,
    num() => value.toDouble(),
    String() => double.tryParse(value) ?? fallback,
    _ => fallback,
  };
}

double _nonNegativeDouble(Object? value) {
  final next = _double(value);
  return next < 0 ? 0 : next;
}

double _max(double left, double right) => left >= right ? left : right;

int _clamp(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

const _cidF0 = 0xf0;
const _cidE1 = 0xe1;
const _cidD0 = 0xd0;
const _cidD6 = 0xd6;
const _cid80 = 0x80;
const _cidBf = 0xbf;
const _cidFe = 0xfe;
