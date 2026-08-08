import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

abstract interface class ProfileOverviewRepository {
  Future<ProfileOverview> fetchOverview();

  Future<MomLifeStage> updateCareStage(MomLifeStage stage);

  Future<DeliveryType?> updateDeliveryType(DeliveryType? deliveryType);
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
    this.stage,
    this.postpartumDay,
    this.expectedDueDate,
    this.actualDeliveryDate,
    this.deliveryType,
    this.dueDateOrWeek,
    this.avatarFileId,
  });

  final String? displayName;
  final MomLifeStage? stage;
  final int? postpartumDay;
  final DateTime? expectedDueDate;
  final DateTime? actualDeliveryDate;
  final DeliveryType? deliveryType;
  final String? dueDateOrWeek;
  final String? avatarFileId;

  MomProfileOverview copyWith({MomLifeStage? stage}) {
    return MomProfileOverview(
      displayName: displayName,
      stage: stage ?? this.stage,
      postpartumDay: postpartumDay,
      expectedDueDate: expectedDueDate,
      actualDeliveryDate: actualDeliveryDate,
      deliveryType: deliveryType,
      dueDateOrWeek: dueDateOrWeek,
      avatarFileId: avatarFileId,
    );
  }
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
