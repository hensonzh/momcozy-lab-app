import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/pump_session/domain/pump_workstate.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';

void main() {
  group('PumpWorkstateApiRepository', () {
    test('posts workstate body and maps reply contract', () async {
      final transport = _transport('success');
      final repository = PumpWorkstateApiRepository(transport: transport);

      final reply = await repository.uploadWorkstate(
        userId: 'demo-user-fixture',
        left: const PumpSideWorkstate(state: 1, mode: 'deep', level: 6),
        right: const PumpSideWorkstate(state: 0, mode: 'stimulate', level: 3),
      );

      expect(transport.lastPath, pumpWorkstateEndpoint);
      expect(transport.lastBody, {
        'user_id': 'demo-user-fixture',
        'device_left': {'state': 1, 'mode': 'deep', 'level': 6},
        'device_right': {'state': 0, 'mode': 'stimulate', 'level': 3},
      });
      expect(reply.needReply, isTrue);
      expect(reply.output, 'Pump state received.');
      expect(reply.replyCode, 'pump_state_changed');
      expect(reply.replySide, 'left');
    });

    test('accepts legacy aliases and partial empty data', () async {
      final legacy = await PumpWorkstateApiRepository(
        transport: _transport('legacy_alias'),
      ).uploadWorkstate(userId: 'demo-user-fixture');
      final empty = await PumpWorkstateApiRepository(
        transport: _transport('empty'),
      ).uploadWorkstate(userId: 'demo-user-fixture');
      final partial = await PumpWorkstateApiRepository(
        transport: _transport('partial'),
      ).uploadWorkstate(userId: 'demo-user-fixture');

      expect(legacy.needReply, isTrue);
      expect(legacy.replyCode, 'pump_state_changed');
      expect(legacy.replySide, 'left');
      expect(empty.isEmpty, isTrue);
      expect(partial.isEmpty, isTrue);
    });

    test('keeps business and HTTP failures distinct', () async {
      await expectLater(
        PumpWorkstateApiRepository(
          transport: _transport('business_error'),
        ).uploadWorkstate(userId: 'demo-user-fixture'),
        throwsA(isA<ApiBusinessException>()),
      );
      await expectLater(
        PumpWorkstateApiRepository(
          transport: _transport('http_error'),
        ).uploadWorkstate(userId: 'demo-user-fixture'),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}

FixtureApiJsonTransport _transport(String variant) {
  final fixture = readFixtureMap('api/pump/$variant.json');
  return FixtureApiJsonTransport(
    Map<String, Object?>.from(fixture['response']! as Map),
  );
}
