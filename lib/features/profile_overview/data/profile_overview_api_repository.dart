import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';

const profileMeEndpoint = '/v1/profile/me';
const profileInfantsEndpoint = '/v1/profile/infants';
const profileOverviewEndpoint = profileMeEndpoint;

class ProfileOverviewApiRepository implements ProfileOverviewRepository {
  const ProfileOverviewApiRepository({required this.transport, this.now});

  final ApiJsonTransport transport;
  final DateTime Function()? now;

  @override
  Future<ProfileOverview> fetchOverview() async {
    final responses = await Future.wait([
      transport.getJson(profileMeEndpoint),
      transport.getJson(profileInfantsEndpoint),
    ]);
    final profile = responses[0];
    final infants = responses[1];
    final infantItems = infants['items'];
    final firstInfant = infantItems is List && infantItems.isNotEmpty
        ? _mapOrNull(infantItems.first)
        : null;
    return ProfileOverview(
      mom: _momProfileOverview(profile, now: now),
      baby: _babyProfileOverview(firstInfant, now: now),
    );
  }
}

MomProfileOverview? _momProfileOverview(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final deliveryDate = _date(data['delivery_date']);
  final dueDateOrWeek = _string(
    data['birth_prep_due_date_or_week'] ?? data['birthPrepDueDateOrWeek'],
  );
  if (deliveryDate == null && dueDateOrWeek?.trim().isNotEmpty != true) {
    return null;
  }
  return MomProfileOverview(
    stage: _stageFromDeliveryDate(deliveryDate, now: now),
    postpartumDay: _ageDays(deliveryDate, now: now),
    deliveryDate: deliveryDate,
    dueDateOrWeek: dueDateOrWeek,
  );
}

BabyProfileOverview? _babyProfileOverview(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final birthDate = _date(data['birth_date']);
  return BabyProfileOverview(
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
