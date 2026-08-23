import 'package:meta/meta.dart';

abstract interface class MaternalCareOverviewRepository {
  Future<MaternalCareOverview> fetchOverview({required DateTime onDate});
}

@immutable
class MaternalProgramProgress {
  const MaternalProgramProgress({
    required this.planId,
    required this.title,
    required this.completedSessions,
    required this.totalSessions,
  });

  final String planId;
  final String title;
  final int completedSessions;
  final int totalSessions;
}

@immutable
class MaternalCareOverview {
  const MaternalCareOverview({this.program});

  final MaternalProgramProgress? program;
}
