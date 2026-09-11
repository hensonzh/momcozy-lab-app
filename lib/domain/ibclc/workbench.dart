import '../care/appointment.dart';
import '../care/care_episode.dart';
import '../care/clinical_note.dart';
import '../care/consultation_room.dart';
import '../care/service_package.dart';
import '../care/intake.dart';
import '../shared/local_date.dart';

final class WorkbenchIdentity {
  const WorkbenchIdentity({
    required this.provider,
    required this.email,
    required this.mfaExpiresAt,
    required this.serverTime,
  });
  final CareProvider provider;
  final String email;
  final DateTime mfaExpiresAt, serverTime;
}

final class WorkbenchLoginChallenge {
  const WorkbenchLoginChallenge({required this.value, required this.expiresAt});
  final String value;
  final DateTime expiresAt;
}

final class WorkbenchAppointment {
  const WorkbenchAppointment({
    required this.appointment,
    required this.episode,
    required this.package,
    required this.patientRef,
    required this.caseConsent,
    required this.publishedRevision,
    this.patientName,
    this.deliveryDate,
    this.consultation,
    this.noteStatus,
  });
  final CareAppointment appointment;
  final CareEpisode episode;
  final ServicePackage package;
  final String patientRef;
  final String? patientName;
  final LocalDate? deliveryDate;
  final bool caseConsent;
  final CareConsultation? consultation;
  final ClinicalNoteStatus? noteStatus;
  final int publishedRevision;
  String get displayName => caseConsent
      ? (patientName?.trim().isNotEmpty == true ? patientName! : '未填写姓名')
      : '待授权用户';
}

final class WorkbenchAppointments {
  const WorkbenchAppointments({
    required this.date,
    required this.timezone,
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final LocalDate date;
  final String timezone;
  final List<WorkbenchAppointment> items;
  final int total, offset, limit;
  final DateTime serverTime;
}

final class ClientCareService {
  const ClientCareService({
    required this.episode,
    required this.package,
    required this.caseConsent,
  });
  final CareEpisode episode;
  final ServicePackage package;
  final bool caseConsent;
}

final class WorkbenchClient {
  const WorkbenchClient({
    required this.patientRef,
    required this.services,
    this.name,
    this.deliveryDate,
  });
  final String patientRef;
  final String? name;
  final LocalDate? deliveryDate;
  final List<ClientCareService> services;
  bool get hasCaseAccess => services.any((value) => value.caseConsent);
  String get displayName => hasCaseAccess
      ? (name?.trim().isNotEmpty == true ? name! : '未填写姓名')
      : '待授权用户';
}

enum WorkbenchClientFilter { all, active, completed }

final class WorkbenchClients {
  const WorkbenchClients({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final List<WorkbenchClient> items;
  final int total, offset, limit;
  final DateTime serverTime;
}

final class WorkbenchClientDetail {
  const WorkbenchClientDetail({
    required this.client,
    required this.appointments,
    required this.appointmentTotal,
    required this.offset,
    required this.limit,
    required this.serverTime,
  });
  final WorkbenchClient client;
  final List<WorkbenchAppointment> appointments;
  final int appointmentTotal, offset, limit;
  final DateTime serverTime;
}

abstract interface class WorkbenchRepository {
  Future<CareIntake> intake(String appointmentId);
  Future<WorkbenchAppointments> appointments({
    LocalDate? date,
    int offset = 0,
    int limit = 10,
  });
  Future<WorkbenchClients> clients({
    String query = '',
    WorkbenchClientFilter filter = WorkbenchClientFilter.all,
    int offset = 0,
    int limit = 20,
  });
  Future<WorkbenchClientDetail> client(
    String patientRef, {
    int offset = 0,
    int limit = 20,
  });
}
