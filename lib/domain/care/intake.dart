import '../baby/baby_profile.dart';
import '../shared/local_date.dart';
import 'appointment.dart';

enum IntakeSymptom {
  latchDifficulty,
  feedingPain,
  supplyConcern,
  frequentWaking,
  pumpingSchedule,
  other,
}

enum CareConsentScope { ibclcCase, video, aiContext, notifications }

final class CareConsent {
  const CareConsent({
    required this.id,
    required this.episodeId,
    required this.scope,
    required this.active,
    required this.version,
    required this.policyVersion,
    required this.recordedAt,
  });
  final String id, episodeId, policyVersion;
  final CareConsentScope scope;
  final bool active;
  final int version;
  final DateTime recordedAt;
}

final class IntakeProfile {
  const IntakeProfile({
    required this.baby,
    required this.deliveryDate,
    required this.region,
  });
  final BabyProfile baby;
  final LocalDate deliveryDate;
  final String region;
}

final class IntakeContent {
  const IntakeContent({
    required this.symptoms,
    required this.feedingGoal,
    required this.supportNeeded,
    required this.profile,
  });
  final Set<IntakeSymptom> symptoms;
  final String feedingGoal, supportNeeded;
  final IntakeProfile profile;
}

final class CareIntake {
  const CareIntake({
    required this.id,
    required this.appointmentId,
    required this.episodeId,
    required this.version,
    required this.content,
    required this.submittedAt,
  });
  final String id, appointmentId, episodeId;
  final int version;
  final IntakeContent content;
  final DateTime submittedAt;
}

final class IntakeContext {
  const IntakeContext({
    required this.appointment,
    required this.babies,
    required this.consents,
    required this.policyVersion,
    this.intake,
    this.previousIntake,
    this.deliveryDate,
  });
  final CareAppointment appointment;
  final CareIntake? intake, previousIntake;
  final List<BabyProfile> babies;
  final List<CareConsent> consents;
  final LocalDate? deliveryDate;
  final String policyVersion;
  CareConsent? consent(CareConsentScope scope) =>
      consents.where((value) => value.scope == scope).firstOrNull;
}

abstract interface class IntakeRepository {
  Future<IntakeContext> load(String appointmentId);
  Future<CareIntake> save(
    String appointmentId, {
    required IntakeContent content,
    required int expectedVersion,
    required int expectedConsentVersion,
    required String policyVersion,
  });
  Future<List<CareConsent>> consents(String episodeId);
  Future<CareConsent> setConsent(
    String episodeId, {
    required CareConsentScope scope,
    required bool active,
    required int expectedVersion,
    required String policyVersion,
  });
}
