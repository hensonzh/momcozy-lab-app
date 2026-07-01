import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';

const statusOverviewEndpoint = '/v1/mom-baby/info/query';

class StatusApiRepository implements StatusRepository {
  const StatusApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<StatusOverview> fetchOverview({required String userId}) async {
    final response = await transport.getJson(
      statusOverviewEndpoint,
      query: {'user_id': userId},
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    return StatusOverview(
      mom: _momStatus(_mapOrNull(data['mom'] ?? data['motherInfo'])),
      baby: _babyStatus(_mapOrNull(data['baby'] ?? data['babyInfo'])),
    );
  }
}

MomStatus? _momStatus(Map<String, Object?>? data) {
  if (data == null || data.isEmpty) return null;
  return MomStatus(
    stage: _string(data['stage']),
    postpartumDay: _int(data['postpartum_day'] ?? data['postpartumDay']),
  );
}

BabyStatus? _babyStatus(Map<String, Object?>? data) {
  if (data == null || data.isEmpty) return null;
  return BabyStatus(
    nickname: _string(data['nickname'] ?? data['nickName']),
    ageDays: _int(data['age_days'] ?? data['ageDays']),
  );
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

Map<String, Object?>? _mapOrNull(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : null;
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;
