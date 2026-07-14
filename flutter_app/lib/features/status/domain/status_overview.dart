abstract interface class StatusRepository {
  Future<StatusOverview> fetchOverview();
}

class StatusOverview {
  const StatusOverview({this.mom, this.baby});

  final MomStatus? mom;
  final BabyStatus? baby;

  bool get isEmpty => mom == null && baby == null;
}

class MomStatus {
  const MomStatus({
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

class BabyStatus {
  const BabyStatus({this.id, this.nickname, this.ageDays, this.birthDate});

  final String? id;
  final String? nickname;
  final int? ageDays;
  final DateTime? birthDate;
}
