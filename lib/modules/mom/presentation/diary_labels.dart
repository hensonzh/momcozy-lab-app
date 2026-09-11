import '../../../domain/mother/mother_diary.dart';

const sleepTotalLabels = <SleepTotalBand, String>{
  SleepTotalBand.underThreeHours: '<3 小时',
  SleepTotalBand.threeToFourHours: '3–4 小时',
  SleepTotalBand.fourToFiveHours: '4–5 小时',
  SleepTotalBand.fiveToSixHours: '5–6 小时',
  SleepTotalBand.sixHoursPlus: '≥6 小时',
  SleepTotalBand.unknown: '记不清',
};

const interruptionsLabels = <SleepInterruptions, String>{
  SleepInterruptions.none: '没有',
  SleepInterruptions.oneToTwo: '1–2 次',
  SleepInterruptions.threeToFour: '3–4 次',
  SleepInterruptions.fivePlus: '5 次以上',
  SleepInterruptions.unknown: '记不清',
};

const stretchLabels = <SleepStretchBand, String>{
  SleepStretchBand.underOneHour: '<1 小时',
  SleepStretchBand.oneToTwoHours: '1–2 小时',
  SleepStretchBand.twoToThreeHours: '2–3 小时',
  SleepStretchBand.threeHoursPlus: '≥3 小时',
  SleepStretchBand.unknown: '记不清',
};

const recoveryLabels = <SleepRecovery, String>{
  SleepRecovery.restored: '有恢复',
  SleepRecovery.managing: '勉强能撑',
  SleepRecovery.exhausted: '很疲惫',
};

const dayRestLabels = <DayRestBand, String>{
  DayRestBand.none: '没有',
  DayRestBand.underThirtyMinutes: '<30 分钟',
  DayRestBand.thirtyToSixtyMinutes: '30–60 分钟',
  DayRestBand.sixtyMinutesPlus: '≥1 小时',
};

const resleepLabels = <ResleepDifficulty, String>{
  ResleepDifficulty.easy: '容易',
  ResleepDifficulty.somewhatHard: '有点难',
  ResleepDifficulty.hard: '很难',
};

const disruptionLabels = <RestDisruption, String>{
  RestDisruption.feeding: '喂奶',
  RestDisruption.baby: '宝宝醒了',
  RestDisruption.discomfort: '身体不适',
  RestDisruption.cannotSleep: '睡不回去',
  RestDisruption.environment: '环境影响',
  RestDisruption.other: '其他',
};

const energyLabels = <BodyEnergy, String>{
  BodyEnergy.energized: '有力气',
  BodyEnergy.managing: '勉强应付',
  BodyEnergy.depleted: '身体被掏空',
};

const siteLabels = <DiscomfortSite, String>{
  DiscomfortSite.lowerAbdomen: '下腹 / 宫缩',
  DiscomfortSite.perineum: '会阴 / 伤口',
  DiscomfortSite.cesarean: '剖腹产切口',
  DiscomfortSite.back: '腰背',
  DiscomfortSite.headChest: '头痛 / 胸闷',
  DiscomfortSite.other: '其他',
};

const severityLabels = <DiscomfortSeverity, String>{
  DiscomfortSeverity.mild: '轻微',
  DiscomfortSeverity.noticeable: '明显',
  DiscomfortSeverity.hardToIgnore: '很难忽略',
};

const bodyImpactLabels = <BodyImpact, String>{
  BodyImpact.none: '没有影响',
  BodyImpact.some: '有一点影响',
  BodyImpact.careLimited: '影响走路 / 抱宝宝',
};

const trendLabels = <RecoveryTrend, String>{
  RecoveryTrend.better: '好一些',
  RecoveryTrend.same: '差不多',
  RecoveryTrend.worse: '更不舒服',
};

const urinationLabels = <Urination, String>{
  Urination.normal: '正常',
  Urination.leakingUrgency: '尿急 / 漏尿',
  Urination.painfulDifficult: '刺痛 / 困难',
};

const bowelLabels = <Bowel, String>{
  Bowel.smooth: '顺畅',
  Bowel.difficult: '费力',
  Bowel.painfulPiles: '疼痛 / 痔疮',
};

const toneLabels = <MoodTone, String>{
  MoodTone.steady: '还算平稳',
  MoodTone.tense: '有点绷着',
  MoodTone.low: '低落 / 没力气',
  MoodTone.reactive: '很容易被触发',
  MoodTone.unclear: '说不清楚',
};

const pressureLabels = <MoodPressure, String>{
  MoodPressure.babyWorry: '担心宝宝',
  MoodPressure.feedingPressure: '喂养压力',
  MoodPressure.bodyRecovery: '身体恢复',
  MoodPressure.sleepLoss: '睡不好',
  MoodPressure.familyFriction: '和家人相处',
  MoodPressure.selfDoubt: '对自己没信心',
  MoodPressure.noTime: '没有自己的时间',
  MoodPressure.unclear: '说不清楚',
};

const moodImpactLabels = <MoodImpact, String>{
  MoodImpact.none: '没有影响',
  MoodImpact.some: '有一点影响',
  MoodImpact.hard: '很难完成日常事情',
};

const supportLabels = <MoodSupport, String>{
  MoodSupport.supported: '有人帮到我',
  MoodSupport.carryingMost: '有人，但主要还是我在扛',
  MoodSupport.alone: '基本靠自己',
};
