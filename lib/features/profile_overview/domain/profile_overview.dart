import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

abstract interface class ProfileOverviewRepository {
  Future<ProfileOverview> fetchOverview();

  Future<MomLifeStage> updateCareStage(MomLifeStage stage);
}

class ProfileOverview {
  const ProfileOverview({this.mom, this.baby});

  final MomProfileOverview? mom;
  final BabyProfileOverview? baby;

  bool get isEmpty => mom == null && baby == null;

  ProfileOverview copyWith({
    MomProfileOverview? mom,
    BabyProfileOverview? baby,
  }) {
    return ProfileOverview(mom: mom ?? this.mom, baby: baby ?? this.baby);
  }
}

class MomProfileOverview {
  const MomProfileOverview({
    this.stage,
    this.postpartumDay,
    this.deliveryDate,
    this.dueDateOrWeek,
  });

  final MomLifeStage? stage;
  final int? postpartumDay;
  final DateTime? deliveryDate;
  final String? dueDateOrWeek;

  MomProfileOverview copyWith({MomLifeStage? stage}) {
    return MomProfileOverview(
      stage: stage ?? this.stage,
      postpartumDay: postpartumDay,
      deliveryDate: deliveryDate,
      dueDateOrWeek: dueDateOrWeek,
    );
  }
}

class BabyProfileOverview {
  const BabyProfileOverview({
    this.id,
    this.nickname,
    this.ageDays,
    this.birthDate,
  });

  final String? id;
  final String? nickname;
  final int? ageDays;
  final DateTime? birthDate;
}
