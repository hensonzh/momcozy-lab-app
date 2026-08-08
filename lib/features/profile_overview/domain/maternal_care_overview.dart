import 'package:flutter/foundation.dart';
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

enum ProgramProgressState { ready, empty }

enum CapabilityState { available, unavailable }

@immutable
class PregnancyProgress {
  const PregnancyProgress({
    required this.state,
    this.expectedDueDate,
    this.gestationalWeek,
    this.gestationalDay,
    this.daysRemaining,
    this.trimester,
  });

  final PregnancyProgressState state;
  final DateTime? expectedDueDate;
  final int? gestationalWeek;
  final int? gestationalDay;
  final int? daysRemaining;
  final PregnancyTrimester? trimester;
}

@immutable
class MaternalProgramProgress {
  const MaternalProgramProgress({
    required this.state,
    required this.planId,
    required this.planType,
    required this.title,
    required this.completedSessions,
    required this.totalSessions,
  });

  final ProgramProgressState state;
  final String planId;
  final String planType;
  final String title;
  final int completedSessions;
  final int totalSessions;
}

@immutable
class MaternalCareCapabilities {
  const MaternalCareCapabilities({
    this.pregnancyProgress = CapabilityState.unavailable,
    this.programProgress = CapabilityState.unavailable,
    this.cycleTracking = CapabilityState.unavailable,
    this.bodyProfile = CapabilityState.unavailable,
    this.waterRecords = CapabilityState.unavailable,
    this.vitalRecords = CapabilityState.unavailable,
  });

  final CapabilityState pregnancyProgress;
  final CapabilityState programProgress;
  final CapabilityState cycleTracking;
  final CapabilityState bodyProfile;
  final CapabilityState waterRecords;
  final CapabilityState vitalRecords;
}

@immutable
class MaternalCareOverview {
  const MaternalCareOverview({
    this.stage,
    this.pregnancy,
    this.program,
    this.capabilities = const MaternalCareCapabilities(),
    this.generatedAt,
  });

  final MomLifeStage? stage;
  final PregnancyProgress? pregnancy;
  final MaternalProgramProgress? program;
  final MaternalCareCapabilities capabilities;
  final DateTime? generatedAt;

  MaternalCareOverview withStage(MomLifeStage value) {
    return MaternalCareOverview(
      stage: value,
      pregnancy: pregnancy,
      program: program,
      capabilities: capabilities,
      generatedAt: generatedAt,
    );
  }
}
