import '../../domain/care/care_episode.dart';
import '../../domain/care/intake.dart';
import '../../domain/baby/baby_profile.dart';

const episodeStatusLabels = {
  CareEpisodeStatus.active: '服务进行中',
  CareEpisodeStatus.provisioningPending: '已购服务',
  CareEpisodeStatus.paused: '服务已暂停',
  CareEpisodeStatus.completed: '服务已完成',
  CareEpisodeStatus.cancelled: '服务已取消',
};
const careStageLabels = {
  CareStage.preparation: '咨询准备',
  CareStage.initialConsultation: '首次咨询',
  CareStage.activeCare: '方案执行',
  CareStage.followUp: '持续跟进',
  CareStage.conclusion: '阶段总结',
};

const intakeSymptomLabels = {
  IntakeSymptom.latchDifficulty: '含乳困难',
  IntakeSymptom.feedingPain: '喂养疼痛',
  IntakeSymptom.supplyConcern: '奶量担心',
  IntakeSymptom.frequentWaking: '宝宝频繁醒来',
  IntakeSymptom.pumpingSchedule: '泵奶安排',
  IntakeSymptom.other: '其他',
};
const feedingModeLabels = {
  FeedingMode.breastfeeding: '纯母乳',
  FeedingMode.expressedMilk: '母乳瓶喂',
  FeedingMode.mixed: '混合喂养',
  FeedingMode.formula: '配方奶',
  FeedingMode.unknown: '请选择',
};
