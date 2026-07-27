import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/status/domain/status_overview.dart';

const statusProfileEndpoint = '/v1/profile/me';
const statusInfantsEndpoint = '/v1/profile/infants';
const statusOverviewEndpoint = statusProfileEndpoint;

class StatusApiRepository implements StatusRepository {
  const StatusApiRepository({required this.transport, this.now});

  final ApiJsonTransport transport;
  final DateTime Function()? now;

  @override
  Future<StatusOverview> fetchOverview() async {
    final profile = await transport.getJson(statusProfileEndpoint);
    final infants = await transport.getJson(statusInfantsEndpoint);
    final infantItems = infants['items'];
    final firstInfant = infantItems is List && infantItems.isNotEmpty
        ? _mapOrNull(infantItems.first)
        : null;
    return StatusOverview(
      mom: _momStatus(profile, firstInfant, now: now),
      baby: _babyStatus(firstInfant, now: now),
    );
  }
}

MomStatus? _momStatus(
  Map<String, Object?>? data,
  Map<String, Object?>? infant, {
  DateTime Function()? now,
}) {
  final estimatedDueDate = _date(data?['estimated_due_date']);
  final birthDate = _date(infant?['birth_date']);
  if (estimatedDueDate == null && birthDate == null) {
    return null;
  }
  return MomStatus(
    stage: birthDate == null ? '孕期' : '哺乳期',
    postpartumDay: _ageDays(birthDate, now: now),
    estimatedDueDate: estimatedDueDate,
  );
}

BabyStatus? _babyStatus(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final birthDate = _date(data['birth_date']);
  return BabyStatus(
    id: _string(data['id']),
    nickname: _string(data['name']),
    ageDays: _ageDays(birthDate, now: now),
    birthDate: birthDate,
  );
}

Map<String, Object?>? _mapOrNull(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : null;
}

String? _string(Object? value) => value is String ? value : null;

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime _today(DateTime Function()? now) {
  final value = (now ?? DateTime.now)();
  return DateTime(value.year, value.month, value.day);
}

int? _ageDays(DateTime? date, {DateTime Function()? now}) {
  if (date == null) return null;
  final start = DateTime(date.year, date.month, date.day);
  return _today(now).difference(start).inDays;
}
