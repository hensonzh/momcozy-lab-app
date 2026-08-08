import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

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
  return MaternalCareOverview(
    stage: MomLifeStage.tryParse(data['stage']),
    pregnancy: _pregnancy(_mapOrNull(data['pregnancy'])),
    program: _program(_mapOrNull(data['program'])),
  );
}

PregnancyProgress? _pregnancy(Map<String, Object?>? data) {
  if (data == null) return null;
  final state = switch (_requiredString(data, 'state')) {
    'ready' => PregnancyProgressState.ready,
    'missing_due_date' => PregnancyProgressState.missingDueDate,
    'out_of_range' => PregnancyProgressState.outOfRange,
    _ => throw const FormatException('Unknown pregnancy progress state.'),
  };
  if (state != PregnancyProgressState.ready) {
    return PregnancyProgress(state: state);
  }
  final week = _integer(data['gestational_week']);
  final daysRemaining = _integer(data['days_remaining']);
  final trimester = _trimester(data['trimester']);
  if (week == null ||
      week < 0 ||
      week > 40 ||
      daysRemaining == null ||
      daysRemaining < 0 ||
      daysRemaining > 280 ||
      trimester == null) {
    throw const FormatException('Ready pregnancy progress is incomplete.');
  }
  return PregnancyProgress(
    state: state,
    gestationalWeek: week,
    daysRemaining: daysRemaining,
    trimester: trimester,
  );
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

PregnancyTrimester? _trimester(Object? value) => switch (value) {
  'first' => PregnancyTrimester.first,
  'second' => PregnancyTrimester.second,
  'third' => PregnancyTrimester.third,
  _ => null,
};

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
