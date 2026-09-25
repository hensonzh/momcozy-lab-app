import '../../domain/care/care_episode.dart';
import '../../domain/care/intake.dart';
import '../../domain/baby/baby_profile.dart';

const episodeStatusLabels = {
  CareEpisodeStatus.active: 'Care in progress',
  CareEpisodeStatus.provisioningPending: 'Service purchased',
  CareEpisodeStatus.paused: 'Care paused',
  CareEpisodeStatus.completed: 'Care completed',
  CareEpisodeStatus.cancelled: 'Care canceled',
};
const careStageLabels = {
  CareStage.preparation: 'Preparing for your consultation',
  CareStage.initialConsultation: 'Initial consultation',
  CareStage.activeCare: 'Following your care plan',
  CareStage.followUp: 'Ongoing follow-up',
  CareStage.conclusion: 'Care summary',
};

const intakeSymptomLabels = {
  IntakeSymptom.latchDifficulty: 'Latching difficulties',
  IntakeSymptom.feedingPain: 'Pain during feeding',
  IntakeSymptom.supplyConcern: 'Milk supply concerns',
  IntakeSymptom.frequentWaking: 'Frequent waking',
  IntakeSymptom.pumpingSchedule: 'Pumping schedule',
  IntakeSymptom.other: 'Other',
};
const feedingModeLabels = {
  FeedingMode.breastfeeding: 'Exclusive breastfeeding',
  FeedingMode.expressedMilk: 'Bottle-fed breast milk',
  FeedingMode.mixed: 'Combination feeding',
  FeedingMode.formula: 'Formula feeding',
  FeedingMode.unknown: 'Select an option',
};
