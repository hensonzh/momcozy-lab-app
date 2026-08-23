import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';

const profileMeEndpoint = '/v1/profile/me';
const profileInfantsEndpoint = '/v1/profile/infants';
const profileOverviewEndpoint = profileMeEndpoint;

class ProfileOverviewApiRepository implements ProfileOverviewRepository {
  const ProfileOverviewApiRepository({
    required this.transport,
    required this.babyId,
    this.now,
  });

  final ApiJsonTransport transport;
  final String babyId;
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
    final mappedInfants = infantItems is List
        ? infantItems
              .map(_mapOrNull)
              .whereType<Map<String, Object?>>()
              .toList(growable: false)
        : const <Map<String, Object?>>[];
    final infantOverviews = mappedInfants
        .map((infant) => _babyProfileOverview(infant, now: now))
        .whereType<BabyProfileOverview>()
        .toList(growable: false);
    final matchingInfant = infantOverviews
        .where((infant) => infant.id == babyId.trim())
        .firstOrNull;
    final selectedInfant = matchingInfant ?? infantOverviews.firstOrNull;
    return ProfileOverview(
      mom: _momProfileOverview(
        profile,
        selectedInfant: selectedInfant,
        now: now,
      ),
      baby: selectedInfant,
      infants: infantOverviews,
    );
  }
}

String? _infantId(Map<String, Object?> data) {
  return _string(data['id'] ?? data['infant_id'] ?? data['infantId'])?.trim();
}

MomProfileOverview? _momProfileOverview(
  Map<String, Object?>? data, {
  BabyProfileOverview? selectedInfant,
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final canonicalActualDeliveryDate = _date(
    data['actual_delivery_date'] ?? data['actualDeliveryDate'],
  );
  final displayName = _string(
    data['display_name'] ??
        data['displayName'] ??
        data['preferred_name'] ??
        data['preferredName'],
  );
  final actualDeliveryDate =
      canonicalActualDeliveryDate ?? selectedInfant?.birthDate;
  if (displayName?.trim().isNotEmpty != true && actualDeliveryDate == null) {
    return null;
  }
  return MomProfileOverview(
    displayName: displayName,
    postpartumDay: _ageDays(actualDeliveryDate, now: now),
    actualDeliveryDate: actualDeliveryDate,
    deliveryType: DeliveryType.tryParse(data['delivery_type']),
    avatarFileId: _nonEmptyString(
      data['selected_avatar_file_id'] ?? data['selectedAvatarFileId'],
    ),
  );
}

BabyProfileOverview? _babyProfileOverview(
  Map<String, Object?>? data, {
  DateTime Function()? now,
}) {
  if (data == null || data.isEmpty) return null;
  final birthDate = _date(data['birth_date']);
  return BabyProfileOverview(
    id: _infantId(data),
    nickname: _string(
      data['infant_name'] ??
          data['nickname'] ??
          data['nickName'] ??
          data['name'],
    ),
    ageDays: _ageDays(birthDate, now: now),
    birthDate: birthDate,
    sex: _nonEmptyString(data['sex'] ?? data['sex_at_birth']),
  );
}

Map<String, Object?>? _mapOrNull(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : null;
}

String? _string(Object? value) => value is String ? value : null;

String? _nonEmptyString(Object? value) {
  final normalized = _string(value)?.trim();
  return normalized?.isNotEmpty == true ? normalized : null;
}

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
