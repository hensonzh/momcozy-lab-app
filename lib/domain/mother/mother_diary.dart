import '../shared/local_date.dart';

enum SleepTotalBand {
  underThreeHours,
  threeToFourHours,
  fourToFiveHours,
  fiveToSixHours,
  sixHoursPlus,
  unknown,
}

enum SleepInterruptions { none, oneToTwo, threeToFour, fivePlus, unknown }

enum SleepStretchBand {
  underOneHour,
  oneToTwoHours,
  twoToThreeHours,
  threeHoursPlus,
  unknown,
}

enum SleepRecovery { restored, managing, exhausted }

enum DayRestBand {
  none,
  underThirtyMinutes,
  thirtyToSixtyMinutes,
  sixtyMinutesPlus,
}

enum ResleepDifficulty { easy, somewhatHard, hard }

enum RestDisruption {
  feeding,
  baby,
  discomfort,
  cannotSleep,
  environment,
  other,
}

enum BodyEnergy { energized, managing, depleted }

enum DiscomfortSite { lowerAbdomen, perineum, cesarean, back, headChest, other }

enum DiscomfortSeverity { mild, noticeable, hardToIgnore }

enum BodyImpact { none, some, careLimited }

enum RecoveryTrend { better, same, worse }

enum Urination { normal, leakingUrgency, painfulDifficult }

enum Bowel { smooth, difficult, painfulPiles }

enum MoodTone { steady, tense, low, reactive, unclear }

enum MoodPressure {
  babyWorry,
  feedingPressure,
  bodyRecovery,
  sleepLoss,
  familyFriction,
  selfDoubt,
  noTime,
  unclear,
}

enum MoodImpact { none, some, hard }

enum MoodSupport { supported, carryingMost, alone }

final class MotherRest {
  MotherRest copyWith({
    SleepTotalBand? Function()? total,
    SleepInterruptions? Function()? interruptions,
    SleepStretchBand? Function()? longestStretch,
    SleepRecovery? Function()? recovery,
    DayRestBand? Function()? dayRest,
    ResleepDifficulty? Function()? resleepDifficulty,
    Set<RestDisruption>? disruptions,
  }) => MotherRest(
    total: total == null ? this.total : total(),
    interruptions: interruptions == null ? this.interruptions : interruptions(),
    longestStretch: longestStretch == null
        ? this.longestStretch
        : longestStretch(),
    recovery: recovery == null ? this.recovery : recovery(),
    dayRest: dayRest == null ? this.dayRest : dayRest(),
    resleepDifficulty: resleepDifficulty == null
        ? this.resleepDifficulty
        : resleepDifficulty(),
    disruptions: disruptions ?? this.disruptions,
  );
  const MotherRest({
    this.total,
    this.interruptions,
    this.longestStretch,
    this.recovery,
    this.dayRest,
    this.resleepDifficulty,
    this.disruptions = const {},
  });
  final SleepTotalBand? total;
  final SleepInterruptions? interruptions;
  final SleepStretchBand? longestStretch;
  final SleepRecovery? recovery;
  final DayRestBand? dayRest;
  final ResleepDifficulty? resleepDifficulty;
  final Set<RestDisruption> disruptions;
  bool get isEmpty =>
      total == null &&
      interruptions == null &&
      longestStretch == null &&
      recovery == null &&
      dayRest == null &&
      resleepDifficulty == null &&
      disruptions.isEmpty;
}

final class MotherBody {
  MotherBody copyWith({
    BodyEnergy? Function()? energy,
    Set<DiscomfortSite>? discomfortSites,
    DiscomfortSeverity? Function()? severity,
    BodyImpact? Function()? impact,
    RecoveryTrend? Function()? trend,
    Urination? Function()? urination,
    Bowel? Function()? bowel,
    String? note,
  }) => MotherBody(
    energy: energy == null ? this.energy : energy(),
    discomfortSites: discomfortSites ?? this.discomfortSites,
    severity: severity == null ? this.severity : severity(),
    impact: impact == null ? this.impact : impact(),
    trend: trend == null ? this.trend : trend(),
    urination: urination == null ? this.urination : urination(),
    bowel: bowel == null ? this.bowel : bowel(),
    note: note ?? this.note,
  );
  const MotherBody({
    this.energy,
    this.discomfortSites = const {},
    this.severity,
    this.impact,
    this.trend,
    this.urination,
    this.bowel,
    this.note = '',
  });
  final BodyEnergy? energy;
  final Set<DiscomfortSite> discomfortSites;
  final DiscomfortSeverity? severity;
  final BodyImpact? impact;
  final RecoveryTrend? trend;
  final Urination? urination;
  final Bowel? bowel;
  final String note;
  bool get isEmpty =>
      energy == null &&
      discomfortSites.isEmpty &&
      severity == null &&
      impact == null &&
      trend == null &&
      urination == null &&
      bowel == null &&
      note.trim().isEmpty;
}

final class MotherMood {
  MotherMood copyWith({
    MoodTone? Function()? tone,
    Set<MoodPressure>? pressures,
    MoodImpact? Function()? impact,
    MoodSupport? Function()? support,
  }) => MotherMood(
    tone: tone == null ? this.tone : tone(),
    pressures: pressures ?? this.pressures,
    impact: impact == null ? this.impact : impact(),
    support: support == null ? this.support : support(),
  );
  const MotherMood({
    this.tone,
    this.pressures = const {},
    this.impact,
    this.support,
  });
  final MoodTone? tone;
  final Set<MoodPressure> pressures;
  final MoodImpact? impact;
  final MoodSupport? support;
  bool get isEmpty =>
      tone == null && pressures.isEmpty && impact == null && support == null;
}

/// Self reports only; measured milk and clinical interpretations live elsewhere.
final class MotherDiary {
  const MotherDiary({
    this.rest = const MotherRest(),
    this.body = const MotherBody(),
    this.mood = const MotherMood(),
  });
  final MotherRest rest;
  final MotherBody body;
  final MotherMood mood;
  int get completedGroups => [
    !rest.isEmpty,
    !body.isEmpty,
    !mood.isEmpty,
  ].where((value) => value).length;
  bool get isEmpty => completedGroups == 0;
  MotherDiary copyWith({
    MotherRest? rest,
    MotherBody? body,
    MotherMood? mood,
  }) => MotherDiary(
    rest: rest ?? this.rest,
    body: body ?? this.body,
    mood: mood ?? this.mood,
  );
}

final class MotherDiaryEntry {
  const MotherDiaryEntry({
    required this.id,
    required this.ownerUserId,
    required this.date,
    required this.diary,
    required this.version,
    required this.updatedAt,
  });
  final String id;
  final String ownerUserId;
  final LocalDate date;
  final MotherDiary diary;
  final int version;
  final DateTime updatedAt;
}

abstract interface class MotherDiaryRepository {
  Future<List<MotherDiaryEntry>> list({
    required LocalDate start,
    required LocalDate end,
  });
  Future<MotherDiaryEntry> save({
    required LocalDate date,
    required MotherDiary diary,
    required int expectedVersion,
  });
}
