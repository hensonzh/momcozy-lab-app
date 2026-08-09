import 'package:meta/meta.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

abstract interface class MaternalCareOverviewRepository {
  Future<MaternalCareOverview> fetchOverview({required DateTime onDate});
}

enum PregnancyProgressState { ready, missingDueDate, outOfRange }

enum PregnancyTrimester { first, second, third }

extension PregnancyTrimesterLabel on PregnancyTrimester {
  String get label => switch (this) {
    PregnancyTrimester.first => 'First Trimester',
    PregnancyTrimester.second => 'Second Trimester',
    PregnancyTrimester.third => 'Third Trimester',
  };
}

@immutable
class PregnancyProgress {
  const PregnancyProgress({
    required this.state,
    this.gestationalWeek,
    this.daysRemaining,
    this.trimester,
  });

  final PregnancyProgressState state;
  final int? gestationalWeek;
  final int? daysRemaining;
  final PregnancyTrimester? trimester;
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
  const MaternalCareOverview({this.stage, this.pregnancy, this.program});

  final MomLifeStage? stage;
  final PregnancyProgress? pregnancy;
  final MaternalProgramProgress? program;

  MaternalCareOverview withStage(MomLifeStage value) {
    return MaternalCareOverview(
      stage: value,
      pregnancy: pregnancy,
      program: program,
    );
  }
}
