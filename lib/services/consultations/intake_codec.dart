import '../../domain/baby/baby_profile.dart';
import '../../domain/care/intake.dart';
import '../../domain/shared/local_date.dart';
import '../appointments/appointment_codec.dart';
import '../baby/baby_profile_codec.dart';
import '../shared/json_value.dart';

const intakeSymptomWire = EnumWire<IntakeSymptom>({
  IntakeSymptom.latchDifficulty: 'latch_difficulty',
  IntakeSymptom.feedingPain: 'feeding_pain',
  IntakeSymptom.supplyConcern: 'supply_concern',
  IntakeSymptom.frequentWaking: 'frequent_waking',
  IntakeSymptom.pumpingSchedule: 'pumping_schedule',
  IntakeSymptom.other: 'other',
});
const careConsentScopeWire = EnumWire<CareConsentScope>({
  CareConsentScope.ibclcCase: 'ibclc_case',
  CareConsentScope.video: 'video',
  CareConsentScope.aiContext: 'ai_context',
  CareConsentScope.notifications: 'notifications',
});
CareConsent readCareConsent(Map<String, Object?> json) => CareConsent(
  id: jsonString(json['id']),
  episodeId: jsonString(json['episode_id']),
  scope: careConsentScopeWire.read(json['scope'])!,
  active: jsonBool(json['active']),
  version: jsonInt(json['version']),
  policyVersion: jsonString(json['policy_version']),
  recordedAt: jsonInstant(json['recorded_at']),
);
IntakeProfile readIntakeProfile(Map<String, Object?> json) => IntakeProfile(
  baby: BabyProfile(
    id: jsonString(json['baby_id']),
    name: jsonString(json['baby_name']),
    birthDate: LocalDate.parse(jsonString(json['baby_birth_date'])),
    sex: babySexWire.read(json['baby_sex'])!,
    feedingMode: feedingModeWire.read(json['feeding_mode'])!,
  ),
  deliveryDate: LocalDate.parse(jsonString(json['delivery_date'])),
  region: jsonString(json['region']),
);
CareIntake readIntake(Map<String, Object?> json) => CareIntake(
  id: jsonString(json['id']),
  appointmentId: jsonString(json['appointment_id']),
  episodeId: jsonString(json['episode_id']),
  version: jsonInt(json['version']),
  submittedAt: jsonInstant(json['submitted_at']),
  content: IntakeContent(
    symptoms: intakeSymptomWire.readSet(json['symptoms']),
    feedingGoal: jsonString(json['feeding_goal']),
    supportNeeded: jsonString(json['support_needed']),
    profile: readIntakeProfile(jsonObject(json['profile'])),
  ),
);
IntakeContext readIntakeContext(Map<String, Object?> json) => IntakeContext(
  appointment: readAppointment(jsonObject(json['appointment'])),
  intake: json['intake'] == null
      ? null
      : readIntake(jsonObject(json['intake'])),
  previousIntake: json['previous_intake'] == null
      ? null
      : readIntake(jsonObject(json['previous_intake'])),
  consents: jsonList(json['consents'], readCareConsent),
  policyVersion: jsonString(json['consent_policy_version']),
  deliveryDate: json['delivery_date'] == null
      ? null
      : LocalDate.parse(jsonString(json['delivery_date'])),
  babies: jsonList(json['babies'], readBabyProfile),
);
Map<String, Object?> writeIntakeContent(IntakeContent content) => {
  'symptoms': intakeSymptomWire.writeSet(content.symptoms),
  'feeding_goal': content.feedingGoal,
  'support_needed': content.supportNeeded,
  'profile': {
    'baby_id': content.profile.baby.id,
    'baby_name': content.profile.baby.name,
    'baby_birth_date': content.profile.baby.birthDate.toString(),
    'baby_sex': babySexWire.write(content.profile.baby.sex),
    'feeding_mode': feedingModeWire.write(content.profile.baby.feedingMode),
    'delivery_date': content.profile.deliveryDate.toString(),
    'region': content.profile.region,
  },
};
