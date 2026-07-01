import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pump_session/domain/pump_workstate.dart';

const pumpWorkstateEndpoint = '/v1/pump/workstate';

class PumpWorkstateApiRepository implements PumpWorkstateRepository {
  const PumpWorkstateApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<PumpWorkstateReply> uploadWorkstate({
    required String userId,
    PumpSideWorkstate? left,
    PumpSideWorkstate? right,
  }) async {
    final response = await transport.postJson(
      pumpWorkstateEndpoint,
      body: {
        'user_id': userId,
        if (left != null) 'device_left': left.toRequestJson(),
        if (right != null) 'device_right': right.toRequestJson(),
      },
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    return PumpWorkstateReply(
      needReply: _bool(data['need_reply'] ?? data['needReply']) ?? false,
      output: _string(data['output']) ?? '',
      replyCode: _string(data['reply_code'] ?? data['replyCode']),
      replySide: _string(data['reply_side'] ?? data['replySide']),
    );
  }
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

bool? _bool(Object? value) => value is bool ? value : null;

String? _string(Object? value) => value is String ? value : null;
