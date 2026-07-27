import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:app/features/pump_session/domain/pump_workstate.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('PumpWorkstateApiRepository', () {
    test('posts production telemetry body and maps ack', () async {
      final transport = FixtureApiJsonTransport(const {
        'id': 'telemetry-001',
        'owner_user_id': 'user-001',
        'device_id': 'pump-device-001',
        'event_type': 'workstate',
        'occurred_at': '2026-07-01T10:00:00Z',
        'payload': <String, Object?>{},
      });
      final repository = PumpWorkstateApiRepository(transport: transport);

      final reply = await repository.uploadWorkstate(
        deviceId: 'pump-device-001',
        left: const PumpSideWorkstate(state: 1, mode: 'deep', level: 6),
        right: const PumpSideWorkstate(state: 0, mode: 'stimulate', level: 3),
      );

      expect(transport.lastPath, pumpWorkstateEndpoint);
      expect(transport.lastBody?['user_id'], isNull);
      expect(transport.lastBody?['device_id'], 'pump-device-001');
      expect(transport.lastBody?['event_type'], 'workstate');
      expect(transport.lastBody?['occurred_at'], isA<String>());
      expect(transport.lastBody?['payload'], {
        'left': {'state': 1, 'mode': 'deep', 'level': 6},
        'right': {'state': 0, 'mode': 'stimulate', 'level': 3},
      });
      expect(reply.needReply, isFalse);
      expect(reply.output, 'Pump telemetry accepted.');
      expect(reply.replyCode, 'workstate');
      expect(reply.replySide, isNull);
    });

    test('keeps HTTP failures typed', () async {
      await expectLater(
        PumpWorkstateApiRepository(
          transport: FixtureApiJsonTransport(const {
            'http_status': 503,
            'status_text': 'Service Unavailable',
          }),
        ).uploadWorkstate(),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}
