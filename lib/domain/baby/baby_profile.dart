import '../shared/local_date.dart';

enum BabySex { female, male, unspecified }

enum FeedingMode { breastfeeding, expressedMilk, mixed, formula, unknown }

final class BabyProfile {
  const BabyProfile({
    required this.id,
    required this.name,
    this.birthDate,
    this.sex = BabySex.unspecified,
    this.feedingMode = FeedingMode.unknown,
    this.version,
  });
  final String id;
  final String name;
  final LocalDate? birthDate;
  final BabySex sex;
  final FeedingMode feedingMode;

  /// Absent on a draft or the immutable profile copied into an intake revision.
  final int? version;

  int? ageDays(LocalDate today) {
    final birth = birthDate;
    if (birth == null || birth.compareTo(today) > 0) return null;
    return today.daysSince(birth);
  }
}

abstract interface class BabyProfileRepository {
  Future<List<BabyProfile>> list();
  Future<BabyProfile> save(
    BabyProfile profile, {
    required String timezone,
    required String idempotencyKey,
  });
}
