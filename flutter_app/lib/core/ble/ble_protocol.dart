import 'dart:typed_data';

const sop = 0xaa;
const fcf = 0x55;
const ctReq = 0x00;
const ctAck = 0x01;
const calMax = 100;

const _cidF0 = 0xf0;
const _cidF1 = 0xf1;
const _cidF2 = 0xf2;
const _cidF3 = 0xf3;
const _cidFe = 0xfe;
const _cidB0 = 0xb0;
const _cidB1 = 0xb1;
const _cidB2 = 0xb2;
const _cidB3 = 0xb3;
const _cidBf = 0xbf;
const _cidE0 = 0xe0;
const _cidE1 = 0xe1;

class BleFrame {
  const BleFrame({
    required this.ct,
    required this.cid,
    required this.cal,
    required this.cab,
  });

  final int ct;
  final int cid;
  final int cal;
  final Uint8List cab;

  Map<String, Object?> summary() => {
    'ct': ct,
    'cid': cid,
    'cal': cal,
    'cabHex': bytesToHex(cab),
  };
}

int checksum8(Uint8List data) {
  var sum = 0;
  for (final byte in data) {
    sum += byte;
  }
  return (~(sum & 0xff)) & 0xff;
}

Uint8List buildReq(int cid, Uint8List cab) {
  final cal = cab.length;
  if (cal > calMax) {
    throw ArgumentError('CAL $cal > $calMax');
  }

  final output = Uint8List(5 + cal + 1);
  output[0] = sop;
  output[1] = fcf;
  output[2] = ctReq;
  output[3] = cid & 0xff;
  output[4] = cal & 0xff;
  output.setRange(5, 5 + cal, cab);
  output[output.length - 1] = checksum8(output.sublist(0, output.length - 1));
  return output;
}

Uint8List buildF0GetDeviceInfo([int sn = 0xaa551100]) {
  return buildReq(_cidF0, uint32Le(sn));
}

Uint8List buildF1SetUserParams(
  int stimulateGear,
  int lactateGear,
  int persist,
) {
  return buildReq(
    _cidF1,
    Uint8List.fromList([
      stimulateGear & 0xff,
      lactateGear & 0xff,
      persist & 0xff,
    ]),
  );
}

Uint8List buildF2SetRtc(int utcSeconds) {
  return buildReq(_cidF2, uint32Le(utcSeconds));
}

Uint8List buildF3SetFlags(int flagsByte, int persist) {
  return buildReq(
    _cidF3,
    Uint8List.fromList([flagsByte & 0xff, persist & 0xff]),
  );
}

Uint8List buildFEPowerOff([int reboot = 0]) {
  return buildReq(_cidFe, Uint8List.fromList([reboot & 0xff]));
}

Uint8List buildB0SetWorkMode(int mode) {
  return buildReq(_cidB0, Uint8List.fromList([mode & 0xff]));
}

Uint8List buildB1SetPumpParams(int startStop, int mode, int gear, int scene) {
  return buildReq(
    _cidB1,
    Uint8List.fromList([
      startStop & 0xff,
      mode & 0xff,
      gear & 0xff,
      scene & 0xff,
    ]),
  );
}

Uint8List buildB2SetFlexibleForceLine(List<int> cabWithoutValid, int persist) {
  return buildReq(
    _cidB2,
    Uint8List.fromList([
      ...cabWithoutValid.map((byte) => byte & 0xff),
      persist & 0xff,
    ]),
  );
}

Uint8List buildB3SetLactationCurve(
  int mode,
  int gear,
  int freqCpm,
  int pressure,
  int holdPressure,
  int holdTimeMs,
  int persist,
) {
  return buildReq(
    _cidB3,
    Uint8List.fromList([
      mode & 0xff,
      gear & 0xff,
      freqCpm & 0xff,
      pressure & 0xff,
      (pressure >> 8) & 0xff,
      holdPressure & 0xff,
      (holdPressure >> 8) & 0xff,
      holdTimeMs & 0xff,
      (holdTimeMs >> 8) & 0xff,
      persist & 0xff,
    ]),
  );
}

Uint8List buildE0QueryDeviceInfo(int queryType) {
  return buildReq(_cidE0, Uint8List.fromList([queryType & 0xff]));
}

Uint8List buildE1QueryDeviceStatus() {
  return buildReq(_cidE1, Uint8List(0));
}

Uint8List buildBFEndRun() {
  return buildReq(_cidBf, Uint8List.fromList([0]));
}

Uint8List buildAck(int cid) {
  final output = Uint8List.fromList([sop, fcf, ctAck, cid & 0xff, 0, 0]);
  output[5] = checksum8(output.sublist(0, 5));
  return output;
}

BleFrame? parseFrame(Uint8List buffer) {
  if (buffer.length < 5) return null;
  if (buffer[0] != sop || buffer[1] != fcf) return null;

  final cal = buffer[4];
  if (cal > calMax || buffer.length != 5 + cal + 1) return null;

  final expected = checksum8(buffer.sublist(0, buffer.length - 1));
  if (buffer.last != expected) return null;

  return BleFrame(
    ct: buffer[2],
    cid: buffer[3],
    cal: cal,
    cab: Uint8List.fromList(buffer.sublist(5, 5 + cal)),
  );
}

Map<String, Object?>? parseF0DeviceInfo(Uint8List cab) {
  if (cab.length < 4) return null;
  return {
    'productModel': cab[0],
    'hwPlatform': cab[1],
    'hwVersion': _versionByteToString(cab[2]),
    'softwareVersion': _versionByteToString(cab[3]),
  };
}

Map<String, Object?>? parseE1DeviceStatus(Uint8List cab) {
  if (cab.length < 10) return null;
  final data = ByteData.sublistView(cab);
  final bootTime = data.getUint32(0, Endian.little);

  if (cab.length >= 15) {
    return {
      'bootTime': bootTime,
      'workMode': cab[4],
      'pumpMode': cab[5],
      'gear': cab[6],
      'scene': cab[7],
      'workState': cab[8],
      'batteryPct': cab[9],
      'charging': cab[10],
      'duration': data.getUint16(11, Endian.little),
      'pumpGearCalibStimulate': cab[13],
      'pumpGearCalibDeep': cab[14],
    };
  }

  if (cab.length >= 11) {
    return {
      'bootTime': bootTime,
      'workMode': cab[4],
      'pumpMode': cab[5],
      'gear': cab[6],
      'scene': cab[7],
      'workState': cab[8],
      'batteryPct': cab[9],
      'charging': cab[10],
      'duration': 0,
      'pumpGearCalibStimulate': 0,
      'pumpGearCalibDeep': 0,
    };
  }

  return {
    'bootTime': bootTime,
    'workMode': cab[4],
    'pumpMode': cab[5],
    'gear': cab[6],
    'scene': 0,
    'workState': cab[7],
    'batteryPct': cab[8],
    'charging': cab[9],
    'duration': 0,
    'pumpGearCalibStimulate': 0,
    'pumpGearCalibDeep': 0,
  };
}

Map<String, Object?>? parseD0OperationRecord(Uint8List cab) {
  if (cab.length < 15) return null;
  final data = ByteData.sublistView(cab);
  return {
    'timestamp': data.getUint32(0, Endian.little),
    'beforeStartStop': cab[4],
    'beforeMode': cab[5],
    'beforeGear': cab[6],
    'beforeAutoFlag': cab[7],
    'afterStartStop': cab[8],
    'afterMode': cab[9],
    'afterGear': cab[10],
    'afterAutoFlag': cab[11],
    'source': cab[12],
    'duration': data.getUint16(13, Endian.little),
  };
}

Map<String, Object?>? parseD6Battery(Uint8List cab) {
  if (cab.length < 6) return null;
  return {
    'timestamp': ByteData.sublistView(cab).getUint32(0, Endian.little),
    'charging': cab[4],
    'batteryPct': cab[5],
  };
}

Map<String, Object?>? parse80RealtimeMilk(Uint8List cab) {
  if (cab.length < 0x17) return null;
  final data = ByteData.sublistView(cab);
  return {
    'timestamp': data.getUint32(0, Endian.little),
    'flowFloat': data.getFloat32(4, Endian.little),
    'milkMlX10': data.getUint16(8, Endian.little),
    'milkFlag': cab[10] & 0x01,
    'moFlag': (cab[10] & 0x02) >> 1,
    'bandpower': data.getFloat32(11, Endian.little),
    'pitchX10': data.getInt16(15, Endian.little),
    'rollX10': data.getInt16(17, Endian.little),
    'pressureCh1X10': data.getUint16(19, Endian.little),
    'pressureCh2X10': data.getUint16(21, Endian.little),
  };
}

Map<String, Object?>? parseBFEndRunResponse(Uint8List cab) {
  if (cab.length < 6) return null;
  final data = ByteData.sublistView(cab);
  return {
    'timestamp': data.getUint32(0, Endian.little),
    'milkMlX10': data.getUint16(4, Endian.little),
  };
}

String? resolveDeviceSideFromStore(
  Map<String, Object?> storeBefore,
  String incomingDeviceId,
) {
  for (final side in const ['L', 'R']) {
    final device = storeBefore[side];
    if (device is Map && device['deviceId'] == incomingDeviceId) return side;
  }
  return null;
}

Uint8List uint32Le(int value) {
  final output = Uint8List(4);
  ByteData.sublistView(output).setUint32(0, value, Endian.little);
  return output;
}

Uint8List hexToBytes(String value) {
  final clean = value.trim();
  if (clean.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(clean)) {
    throw FormatException('Invalid hex fixture: $value');
  }
  final output = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < output.length; i += 1) {
    output[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return output;
}

String bytesToHex(Uint8List bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String _versionByteToString(int byte) => '${byte ~/ 10}.${byte % 10}';
