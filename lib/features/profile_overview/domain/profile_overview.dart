import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';

abstract interface class ProfileOverviewRepository {
  Future<ProfileOverview> fetchOverview();
}

class ProfileOverview {
  const ProfileOverview({
    this.mom,
    this.baby,
    this.infants = const <BabyProfileOverview>[],
  });

  final MomProfileOverview? mom;
  final BabyProfileOverview? baby;
  final List<BabyProfileOverview> infants;

  bool get isEmpty => mom == null && baby == null && infants.isEmpty;

  ProfileOverview copyWith({
    MomProfileOverview? mom,
    BabyProfileOverview? baby,
    List<BabyProfileOverview>? infants,
  }) {
    return ProfileOverview(
      mom: mom ?? this.mom,
      baby: baby ?? this.baby,
      infants: infants ?? this.infants,
    );
  }
}

class MomProfileOverview {
  const MomProfileOverview({
    this.displayName,
    this.postpartumDay,
    this.actualDeliveryDate,
    this.deliveryType,
    this.avatarFileId,
  });

  final String? displayName;
  final int? postpartumDay;
  final DateTime? actualDeliveryDate;
  final DeliveryType? deliveryType;
  final String? avatarFileId;
}

class BabyProfileOverview {
  const BabyProfileOverview({
    this.id,
    this.nickname,
    this.ageDays,
    this.birthDate,
    this.sex,
  });

  final String? id;
  final String? nickname;
  final int? ageDays;
  final DateTime? birthDate;
  final String? sex;
}
