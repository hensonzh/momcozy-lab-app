abstract interface class ProfileOverviewRepository {
  Future<ProfileOverview> fetchOverview();
}

class ProfileOverview {
  const ProfileOverview({this.mom, this.baby});

  final MomProfileOverview? mom;
  final BabyProfileOverview? baby;

  bool get isEmpty => mom == null && baby == null;
}

class MomProfileOverview {
  const MomProfileOverview({
    this.stage,
    this.postpartumDay,
    this.deliveryDate,
    this.dueDateOrWeek,
  });

  final String? stage;
  final int? postpartumDay;
  final DateTime? deliveryDate;
  final String? dueDateOrWeek;
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
