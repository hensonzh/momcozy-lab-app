abstract interface class StatusRepository {
  Future<StatusOverview> fetchOverview({required String userId});
}

class StatusOverview {
  const StatusOverview({this.mom, this.baby});

  final MomStatus? mom;
  final BabyStatus? baby;

  bool get isEmpty => mom == null && baby == null;
}

class MomStatus {
  const MomStatus({this.stage, this.postpartumDay});

  final String? stage;
  final int? postpartumDay;
}

class BabyStatus {
  const BabyStatus({this.nickname, this.ageDays});

  final String? nickname;
  final int? ageDays;
}
