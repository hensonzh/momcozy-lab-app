import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/pump_session/domain/pump_workstate.dart';

const pumpWorkstateEndpoint = '/v1/devices/pump-telemetry';

class PumpWorkstateApiRepository implements PumpWorkstateRepository {
  const PumpWorkstateApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<PumpWorkstateReply> uploadWorkstate({
    String deviceId = 'app-pump-session',
    PumpSideWorkstate? left,
    PumpSideWorkstate? right,
  }) async {
    final response = await transport.postJson(
      pumpWorkstateEndpoint,
      body: {
        'device_id': _deviceId(deviceId),
        'event_type': 'workstate',
        'occurred_at': _apiTimestamp(DateTime.now()),
        'payload': {
          if (left != null) 'left': left.toRequestJson(),
          if (right != null) 'right': right.toRequestJson(),
        },
      },
    );
    return PumpWorkstateReply(
      needReply: false,
      output: 'Pump telemetry accepted.',
      replyCode: _string(response['event_type']),
    );
  }
}

String _deviceId(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'app-pump-session' : trimmed;
}

String _apiTimestamp(DateTime value) {
  return value.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
}

String? _string(Object? value) => value is String ? value : null;
