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

MomStatus? _momStatus(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final deliveryDate = _date(data['delivery_date']);
  final summary = _string(data['daily_summary']);
  if (deliveryDate == null && summary == null) return null;
  return MomStatus(
    stage: summary ?? _stageFromDeliveryDate(deliveryDate, now: now),
    postpartumDay: _ageDays(deliveryDate, now: now),
  );
}

BabyStatus? _babyStatus(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final birthDate = _date(data['birth_date']);
  return BabyStatus(
    nickname: _string(
      data['infant_name'] ?? data['nickname'] ?? data['nickName'],
    ),
    ageDays: _ageDays(birthDate, now: now),
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
  final value = (now ?? DateTime.now)().toUtc();
  return DateTime.utc(value.year, value.month, value.day);
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
  final start = DateTime.utc(date.year, date.month, date.day);
  return _today(now).difference(start).inDays;
}
