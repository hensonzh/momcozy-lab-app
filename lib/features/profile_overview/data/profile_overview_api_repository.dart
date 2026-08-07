import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
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
    final selectedInfant =
        matchingInfant ??
        (infantOverviews.length == 1 ? infantOverviews.single : null);
    return ProfileOverview(
      mom: _momProfileOverview(profile, now: now),
      baby: selectedInfant,
      infants: infantOverviews,
    );
  }

  @override
  Future<MomLifeStage> updateCareStage(MomLifeStage stage) async {
    final mutations = transport;
    if (mutations is! ApiJsonMutationTransport) {
      throw UnsupportedError('Profile updates require JSON mutation support.');
    }
    final response = await (mutations as ApiJsonMutationTransport).putJson(
      profileMeEndpoint,
      body: {'current_care_stage': stage.wireValue},
    );
    final saved = MomLifeStage.tryParse(response['current_care_stage']);
    if (saved == null) {
      throw const FormatException(
        'Profile update response is missing current_care_stage.',
      );
    }
    return saved;
  }
}

String? _infantId(Map<String, Object?> data) {
  return _string(data['id'] ?? data['infant_id'] ?? data['infantId'])?.trim();
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
  final displayName = _string(data['display_name'] ?? data['displayName']);
  final explicitStage = MomLifeStage.tryParse(
    data['current_care_stage'] ?? data['currentCareStage'],
  );
  if (deliveryDate == null &&
      dueDateOrWeek?.trim().isNotEmpty != true &&
      displayName?.trim().isNotEmpty != true &&
      explicitStage == null) {
    return null;
  }
  final hasStageEvidence =
      deliveryDate != null || dueDateOrWeek?.trim().isNotEmpty == true;
  final stage =
      explicitStage ??
      (hasStageEvidence
          ? MomLifeStage.resolve(
              deliveryDate: deliveryDate,
              hasPregnancyDetails: dueDateOrWeek?.trim().isNotEmpty == true,
              now: now,
            )
          : null);
  return MomProfileOverview(
    displayName: displayName,
    stage: stage,
    postpartumDay: stage == MomLifeStage.postpartum
        ? _ageDays(deliveryDate, now: now)
        : null,
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
    id: _infantId(data),
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

int? _ageDays(DateTime? date, {DateTime Function()? now}) {
  if (date == null) return null;
  final start = DateTime(date.year, date.month, date.day);
  return _today(now).difference(start).inDays;
}
