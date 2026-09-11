import '../shared/local_date.dart';

enum DeliveryMethod { vaginal, cesarean, assistedVaginal, other, unknown }

final class MotherProfile {
  const MotherProfile({
    required this.userId,
    required this.displayName,
    required this.timezone,
    this.regionCode,
    this.deliveryDate,
    this.deliveryMethod,
    this.avatarFileId,
  });

  final String userId;
  final String displayName;
  final String timezone;
  final String? regionCode;
  final LocalDate? deliveryDate;
  final DeliveryMethod? deliveryMethod;
  final String? avatarFileId;
  int? postpartumDay(LocalDate today) {
    final birth = deliveryDate;
    if (birth == null || birth.compareTo(today) > 0) return null;
    return today.daysSince(birth);
  }
}

abstract interface class MotherProfileRepository {
  Future<MotherProfile> get();
}
