import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';

const maternalCareOverviewEndpoint = '/v1/care-overview/me';

class MaternalCareOverviewApiRepository
    implements MaternalCareOverviewRepository {
  const MaternalCareOverviewApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<MaternalCareOverview> fetchOverview({required DateTime onDate}) async {
    final response = await transport.getJson(
      maternalCareOverviewEndpoint,
      query: {'date': _apiDate(onDate)},
    );
    return _overview(response);
  }
}

MaternalCareOverview _overview(Map<String, Object?> data) {
  return MaternalCareOverview(program: _program(_mapOrNull(data['program'])));
}

MaternalProgramProgress? _program(Map<String, Object?>? data) {
  if (data == null) return null;
  final completed = _integer(data['completed_sessions']);
  final total = _integer(data['total_sessions']);
  if (completed == null ||
      total == null ||
      completed < 0 ||
      total < 0 ||
      completed > total) {
    throw const FormatException('Program progress counts are invalid.');
  }
  return MaternalProgramProgress(
    planId: _requiredString(data, 'plan_id'),
    title: _requiredString(data, 'title'),
    completedSessions: completed,
    totalSessions: total,
  );
}

Map<String, Object?>? _mapOrNull(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : null;
}

String _requiredString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$key is required.');
}

int? _integer(Object? value) => value is int ? value : null;

String _apiDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
