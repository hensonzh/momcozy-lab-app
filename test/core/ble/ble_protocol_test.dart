import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ble/ble_protocol.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('BLE protocol fixtures', () {
    test('encode request packets aligned with golden and boundary hex', () {
      final requestFixtures = [
        ..._cases(readFixtureMap('ble/req_golden_packets.json')),
        ..._cases(readFixtureMap('ble/boundary_cases.json')),
      ];

      for (final fixtureCase in requestFixtures) {
        expect(
          bytesToHex(_buildPacket(fixtureCase)),
          fixtureCase['expectedHex'],
          reason: fixtureCase['id'] as String?,
        );
      }
    });

    test(
      'keep standalone hex files aligned with structured golden fixtures',
      () {
        final fixtures = _cases(readFixtureMap('ble/req_golden_packets.json'));
        final byId = {
          for (final fixtureCase in fixtures)
            fixtureCase['id'] as String: fixtureCase,
        };

        expect(
          readMigrationFixture('ble/f0_get_device_info.hex').trim(),
          byId['f0_get_device_info_default_sn']!['expectedHex'],
        );
        expect(
          readMigrationFixture('ble/f2_set_rtc.hex').trim(),
          byId['f2_set_rtc_fixed_timestamp']!['expectedHex'],
        );
        expect(
          readMigrationFixture('ble/b0_set_work_mode.hex').trim(),
          byId['b0_set_work_mode_agent']!['expectedHex'],
        );
        expect(
          readMigrationFixture('ble/b1_set_pump_params.hex').trim(),
          byId['b1_start_deep_gear6_auto']!['expectedHex'],
        );
        expect(
          readMigrationFixture('ble/b2_set_flexible_force_line.hex').trim(),
          byId['b2_set_flexible_force_line_minimal']!['expectedHex'],
        );
        expect(
          readMigrationFixture('ble/b3_set_lactation_curve.hex').trim(),
          byId['b3_set_lactation_curve_typical']!['expectedHex'],
        );
        expect(
          readMigrationFixture('ble/bf_end_run.hex').trim(),
          byId['bf_end_run_reserved_zero']!['expectedHex'],
        );
      },
    );

    test('parse valid frames into stable domain values', () {
      final fixture = readFixtureMap('ble/parse_frames.json');
      for (final fixtureCase in _listOfMaps(fixture['validFrames'])) {
        final frame = parseFrame(
          hexToBytes(fixtureCase['frameHex']! as String),
        );

        expect(frame, isNotNull, reason: fixtureCase['id'] as String?);
        expect(frame!.summary(), fixtureCase['expectedFrame']);

        final parser = fixtureCase['parser'];
        if (parser is String) {
          expect(
            _parseWith(parser, frame.cab),
            fixtureCase['expectedValue'],
            reason: fixtureCase['id'] as String?,
          );
        }
      }
    });

    test('keep standalone E1 status fixture aligned with parser output', () {
      final frame = parseFrame(
        hexToBytes(readMigrationFixture('ble/e1_device_status_input.hex')),
      );

      expect(frame, isNotNull);
      expect(
        parseE1DeviceStatus(frame!.cab),
        readFixtureMap('ble/e1_device_status_expected.json'),
      );
    });

    test('reject invalid frames and parser edge cases with null', () {
      final fixture = readFixtureMap('ble/parse_frames.json');

      for (final fixtureCase in _listOfMaps(fixture['invalidFrames'])) {
        final frame = parseFrame(
          hexToBytes(fixtureCase['frameHex']! as String),
        );

        if (fixtureCase['expectedParseFrame'] == null &&
            fixtureCase.containsKey('expectedParseFrame')) {
          expect(frame, isNull, reason: fixtureCase['id'] as String?);
          continue;
        }

        expect(frame, isNotNull, reason: fixtureCase['id'] as String?);
        expect(frame!.summary(), fixtureCase['expectedFrame']);
        expect(
          _parseWith(fixtureCase['parser']! as String, frame.cab),
          fixtureCase['expectedValue'],
          reason: fixtureCase['id'] as String?,
        );
      }

      for (final fixtureCase in _listOfMaps(fixture['parserEdgeCases'])) {
        expect(
          _parseWith(
            fixtureCase['parser']! as String,
            hexToBytes(fixtureCase['cabHex']! as String),
          ),
          fixtureCase['expectedValue'],
          reason: fixtureCase['id'] as String?,
        );
      }
    });

    test('match cross-platform parity cases for packets and parsers', () {
      final fixture = readFixtureMap('ble/cross_platform_parity.json');

      for (final fixtureCase in _listOfMaps(fixture['requiredParityCases'])) {
        expect(
          bytesToHex(_buildPacket(fixtureCase)),
          fixtureCase['expectedHex'],
          reason: fixtureCase['id'] as String?,
        );
      }

      for (final fixtureCase in _listOfMaps(fixture['parserParityCases'])) {
        final frame = parseFrame(
          hexToBytes(fixtureCase['frameHex']! as String),
        );
        expect(frame, isNotNull, reason: fixtureCase['id'] as String?);
        expect(
          _parseWith(fixtureCase['parser']! as String, frame!.cab),
          fixtureCase['expectedValue'],
          reason: fixtureCase['id'] as String?,
        );
      }
    });

    test(
      'resolve packet side from paired device id without mutating the other side',
      () {
        final fixture = readFixtureMap('ble/side_mapping.json');

        for (final fixtureCase in _listOfMaps(fixture['cases'])) {
          final storeBefore = Map<String, Object?>.from(
            fixtureCase['storeBefore']! as Map,
          );

          expect(
            resolveDeviceSideFromStore(
              storeBefore,
              fixtureCase['incomingDeviceId']! as String,
            ),
            fixtureCase['expectedTouchedSide'],
            reason: fixtureCase['id'] as String?,
          );
          expect(
            parseFrame(hexToBytes(fixtureCase['frameHex']! as String)),
            isNotNull,
          );
        }
      },
    );
  });
}

List<Map<String, Object?>> _cases(Map<String, Object?> fixture) {
  return _listOfMaps(fixture['cases']);
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  return (value! as List)
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

Uint8List _buildPacket(Map<String, Object?> fixtureCase) {
  final args = List<Object?>.from(fixtureCase['args']! as List);
  switch (fixtureCase['builder']) {
    case 'buildAck':
      return buildAck(args[0]! as int);
    case 'buildB0SetWorkMode':
      return buildB0SetWorkMode(args[0]! as int);
    case 'buildB1SetPumpParams':
      return buildB1SetPumpParams(
        args[0]! as int,
        args[1]! as int,
        args[2]! as int,
        args[3]! as int,
      );
    case 'buildB2SetFlexibleForceLine':
      return buildB2SetFlexibleForceLine(
        List<int>.from(args[0]! as List),
        args[1]! as int,
      );
    case 'buildB3SetLactationCurve':
      return buildB3SetLactationCurve(
        args[0]! as int,
        args[1]! as int,
        args[2]! as int,
        args[3]! as int,
        args[4]! as int,
        args[5]! as int,
        args[6]! as int,
      );
    case 'buildBFEndRun':
      return buildBFEndRun();
    case 'buildE0QueryDeviceInfo':
      return buildE0QueryDeviceInfo(args[0]! as int);
    case 'buildE1QueryDeviceStatus':
      return buildE1QueryDeviceStatus();
    case 'buildF0GetDeviceInfo':
      return buildF0GetDeviceInfo();
    case 'buildF1SetUserParams':
      return buildF1SetUserParams(
        args[0]! as int,
        args[1]! as int,
        args[2]! as int,
      );
    case 'buildF2SetRtc':
      return buildF2SetRtc(args[0]! as int);
    case 'buildF3SetFlags':
      return buildF3SetFlags(args[0]! as int, args[1]! as int);
    case 'buildFEPowerOff':
      return buildFEPowerOff(args[0]! as int);
    default:
      throw UnsupportedError(
        'Unsupported BLE fixture builder: ${fixtureCase['builder']}',
      );
  }
}

Map<String, Object?>? _parseWith(String parser, Uint8List cab) {
  switch (parser) {
    case 'parse80RealtimeMilk':
      return parse80RealtimeMilk(cab);
    case 'parseBFEndRunResponse':
      return parseBFEndRunResponse(cab);
    case 'parseD0OperationRecord':
      return parseD0OperationRecord(cab);
    case 'parseD6Battery':
      return parseD6Battery(cab);
    case 'parseE1DeviceStatus':
      return parseE1DeviceStatus(cab);
    case 'parseF0DeviceInfo':
      return parseF0DeviceInfo(cab);
    default:
      throw UnsupportedError('Unsupported BLE fixture parser: $parser');
  }
}
