import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';

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
      mom: _momStatus(profile, now: now),
      baby: _babyStatus(firstInfant, now: now),
    );
  }
}

MomStatus? _momStatus(Map<String, Object?>? data, {DateTime Function()? now}) {
  if (data == null || data.isEmpty) return null;
  final deliveryDate = _date(data['delivery_date']);
  final dueDateOrWeek = _string(
    data['birth_prep_due_date_or_week'] ?? data['birthPrepDueDateOrWeek'],
  );
  if (deliveryDate == null && dueDateOrWeek?.trim().isNotEmpty != true) {
    return null;
  }
  return MomStatus(
    stage: _stageFromDeliveryDate(deliveryDate, now: now),
    postpartumDay: _ageDays(deliveryDate, now: now),
    deliveryDate: deliveryDate,
    dueDateOrWeek: dueDateOrWeek,
  );
}

BabyStatus? _babyStatus(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final birthDate = _date(data['birth_date']);
  return BabyStatus(
    id: _string(data['id'] ?? data['infant_id'] ?? data['infantId']),
    nickname: _string(
      data['infant_name'] ?? data['nickname'] ?? data['nickName'],
    ),
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

String? _stageFromDeliveryDate(
  DateTime? deliveryDate, {
  DateTime Function()? now,
}) {
  if (deliveryDate == null) return null;
  return deliveryDate.isAfter(_today(now)) ? '孕期' : '哺乳期';
}

int? _ageDays(DateTime? date, {DateTime Function()? now}) {
  if (date == null) return null;
  final start = DateTime(date.year, date.month, date.day);
  return _today(now).difference(start).inDays;
}
