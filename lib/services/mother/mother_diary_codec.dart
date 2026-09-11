import '../../domain/mother/mother_diary.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';

const sleepTotal = EnumWire<SleepTotalBand>({
  SleepTotalBand.underThreeHours: 'under-3h',
  SleepTotalBand.threeToFourHours: '3-4h',
  SleepTotalBand.fourToFiveHours: '4-5h',
  SleepTotalBand.fiveToSixHours: '5-6h',
  SleepTotalBand.sixHoursPlus: '6h-plus',
  SleepTotalBand.unknown: 'unknown',
});

const interruptions = EnumWire<SleepInterruptions>({
  SleepInterruptions.none: 'none',
  SleepInterruptions.oneToTwo: '1-2',
  SleepInterruptions.threeToFour: '3-4',
  SleepInterruptions.fivePlus: '5-plus',
  SleepInterruptions.unknown: 'unknown',
});

const sleepStretch = EnumWire<SleepStretchBand>({
  SleepStretchBand.underOneHour: 'under-1h',
  SleepStretchBand.oneToTwoHours: '1-2h',
  SleepStretchBand.twoToThreeHours: '2-3h',
  SleepStretchBand.threeHoursPlus: '3h-plus',
  SleepStretchBand.unknown: 'unknown',
});

const sleepRecovery = EnumWire<SleepRecovery>({
  SleepRecovery.restored: 'restored',
  SleepRecovery.managing: 'managing',
  SleepRecovery.exhausted: 'exhausted',
});

const dayRest = EnumWire<DayRestBand>({
  DayRestBand.none: 'none',
  DayRestBand.underThirtyMinutes: 'under-30m',
  DayRestBand.thirtyToSixtyMinutes: '30-60m',
  DayRestBand.sixtyMinutesPlus: '60m-plus',
});

const resleep = EnumWire<ResleepDifficulty>({
  ResleepDifficulty.easy: 'easy',
  ResleepDifficulty.somewhatHard: 'somewhat-hard',
  ResleepDifficulty.hard: 'hard',
});

const restDisruption = EnumWire<RestDisruption>({
  RestDisruption.feeding: 'feeding',
  RestDisruption.baby: 'baby',
  RestDisruption.discomfort: 'discomfort',
  RestDisruption.cannotSleep: 'cannot-sleep',
  RestDisruption.environment: 'environment',
  RestDisruption.other: 'other',
});

const bodyEnergy = EnumWire<BodyEnergy>({
  BodyEnergy.energized: 'energized',
  BodyEnergy.managing: 'managing',
  BodyEnergy.depleted: 'depleted',
});

const discomfortSite = EnumWire<DiscomfortSite>({
  DiscomfortSite.lowerAbdomen: 'lower-abdomen',
  DiscomfortSite.perineum: 'perineum',
  DiscomfortSite.cesarean: 'c-section',
  DiscomfortSite.back: 'back',
  DiscomfortSite.headChest: 'head-chest',
  DiscomfortSite.other: 'other',
});

const severity = EnumWire<DiscomfortSeverity>({
  DiscomfortSeverity.mild: 'mild',
  DiscomfortSeverity.noticeable: 'noticeable',
  DiscomfortSeverity.hardToIgnore: 'hard-to-ignore',
});

const bodyImpact = EnumWire<BodyImpact>({
  BodyImpact.none: 'none',
  BodyImpact.some: 'some',
  BodyImpact.careLimited: 'care-limited',
});

const recoveryTrend = EnumWire<RecoveryTrend>({
  RecoveryTrend.better: 'better',
  RecoveryTrend.same: 'same',
  RecoveryTrend.worse: 'worse',
});

const urination = EnumWire<Urination>({
  Urination.normal: 'normal',
  Urination.leakingUrgency: 'leaking-urgency',
  Urination.painfulDifficult: 'painful-difficult',
});

const bowel = EnumWire<Bowel>({
  Bowel.smooth: 'smooth',
  Bowel.difficult: 'difficult',
  Bowel.painfulPiles: 'painful-piles',
});

const moodTone = EnumWire<MoodTone>({
  MoodTone.steady: 'steady',
  MoodTone.tense: 'tense',
  MoodTone.low: 'low',
  MoodTone.reactive: 'reactive',
  MoodTone.unclear: 'unclear',
});

const moodPressure = EnumWire<MoodPressure>({
  MoodPressure.babyWorry: 'baby-worry',
  MoodPressure.feedingPressure: 'feeding-pressure',
  MoodPressure.bodyRecovery: 'body-recovery',
  MoodPressure.sleepLoss: 'sleep-loss',
  MoodPressure.familyFriction: 'family-friction',
  MoodPressure.selfDoubt: 'self-doubt',
  MoodPressure.noTime: 'no-time',
  MoodPressure.unclear: 'unclear',
});

const moodImpact = EnumWire<MoodImpact>({
  MoodImpact.none: 'none',
  MoodImpact.some: 'some',
  MoodImpact.hard: 'hard',
});

const moodSupport = EnumWire<MoodSupport>({
  MoodSupport.supported: 'supported',
  MoodSupport.carryingMost: 'carrying-most',
  MoodSupport.alone: 'alone',
});

MotherDiaryEntry readMotherDiaryEntry(Map<String, Object?> json) =>
    MotherDiaryEntry(
      id: jsonString(json['id']),
      ownerUserId: jsonString(json['owner_user_id']),
      date: LocalDate.parse(jsonString(json['entry_date'])),
      diary: readMotherDiary(jsonObject(json['diary'])),
      version: jsonInt(json['version']),
      updatedAt: DateTime.parse(jsonString(json['updated_at'])),
    );

MotherDiary readMotherDiary(Map<String, Object?> json) {
  requireOnlyKeys(json, {'rest', 'body', 'mood'});
  final rest = jsonObject(json['rest'] ?? <String, Object?>{});
  final body = jsonObject(json['body'] ?? <String, Object?>{});
  final mood = jsonObject(json['mood'] ?? <String, Object?>{});
  requireOnlyKeys(rest, {
    'total',
    'interruptions',
    'longest_stretch',
    'recovery',
    'day_rest',
    'resleep_difficulty',
    'disruptions',
  });
  requireOnlyKeys(body, {
    'energy',
    'discomfort_sites',
    'severity',
    'impact',
    'trend',
    'urination',
    'bowel',
    'note',
  });
  requireOnlyKeys(mood, {'tone', 'pressures', 'impact', 'support'});
  return MotherDiary(
    rest: MotherRest(
      total: sleepTotal.read(rest['total']),
      interruptions: interruptions.read(rest['interruptions']),
      longestStretch: sleepStretch.read(rest['longest_stretch']),
      recovery: sleepRecovery.read(rest['recovery']),
      dayRest: dayRest.read(rest['day_rest']),
      resleepDifficulty: resleep.read(rest['resleep_difficulty']),
      disruptions: restDisruption.readSet(rest['disruptions']),
    ),
    body: MotherBody(
      energy: bodyEnergy.read(body['energy']),
      discomfortSites: discomfortSite.readSet(body['discomfort_sites']),
      severity: severity.read(body['severity']),
      impact: bodyImpact.read(body['impact']),
      trend: recoveryTrend.read(body['trend']),
      urination: urination.read(body['urination']),
      bowel: bowel.read(body['bowel']),
      note: jsonString(body['note'] ?? ''),
    ),
    mood: MotherMood(
      tone: moodTone.read(mood['tone']),
      pressures: moodPressure.readSet(mood['pressures']),
      impact: moodImpact.read(mood['impact']),
      support: moodSupport.read(mood['support']),
    ),
  );
}

Map<String, Object?> writeMotherDiary(MotherDiary value) => {
  'rest': {
    'total': sleepTotal.write(value.rest.total),
    'interruptions': interruptions.write(value.rest.interruptions),
    'longest_stretch': sleepStretch.write(value.rest.longestStretch),
    'recovery': sleepRecovery.write(value.rest.recovery),
    'day_rest': dayRest.write(value.rest.dayRest),
    'resleep_difficulty': resleep.write(value.rest.resleepDifficulty),
    'disruptions': restDisruption.writeSet(value.rest.disruptions),
  },
  'body': {
    'energy': bodyEnergy.write(value.body.energy),
    'discomfort_sites': discomfortSite.writeSet(value.body.discomfortSites),
    'severity': severity.write(value.body.severity),
    'impact': bodyImpact.write(value.body.impact),
    'trend': recoveryTrend.write(value.body.trend),
    'urination': urination.write(value.body.urination),
    'bowel': bowel.write(value.body.bowel),
    'note': value.body.note,
  },
  'mood': {
    'tone': moodTone.write(value.mood.tone),
    'pressures': moodPressure.writeSet(value.mood.pressures),
    'impact': moodImpact.write(value.mood.impact),
    'support': moodSupport.write(value.mood.support),
  },
};
