import '../../domain/ibclc/workbench.dart';
import '../../domain/ibclc/workbench_calendar.dart';
import '../../domain/shared/local_date.dart';
import '../appointments/appointment_codec.dart';
import '../care/care_codec.dart';
import '../consultations/room_codec.dart';
import '../documentation/documentation_codec.dart';
import '../shared/json_value.dart';

const workbenchClientFilterWire = EnumWire<WorkbenchClientFilter>({
  WorkbenchClientFilter.all: 'all',
  WorkbenchClientFilter.active: 'active',
  WorkbenchClientFilter.completed: 'completed',
});

WorkbenchCalendar readWorkbenchCalendar(Map<String, Object?> json) =>
    WorkbenchCalendar(
      weekStart: LocalDate.parse(jsonString(json['week_start'])),
      timezone: jsonString(json['timezone']),
      items: jsonList(json['items'], readWorkbenchAppointment),
      total: jsonInt(json['total']),
      offset: jsonInt(json['offset']),
      limit: jsonInt(json['limit']),
      serverTime: jsonInstant(json['server_time']),
    );

WorkbenchIdentity readWorkbenchIdentity(Map<String, Object?> json) =>
    WorkbenchIdentity(
      provider: readCareProvider(jsonObject(json['provider'])),
      email: jsonString(json['email']),
      mfaExpiresAt: jsonInstant(json['mfa_expires_at']),
      serverTime: jsonInstant(json['server_time']),
    );
WorkbenchAppointment readWorkbenchAppointment(Map<String, Object?> json) =>
    WorkbenchAppointment(
      appointment: readAppointment(jsonObject(json['appointment'])),
      episode: readCareEpisode(jsonObject(json['episode'])),
      package: readServicePackage(jsonObject(json['package'])),
      patientRef: jsonString(json['patient_ref']),
      patientName: json['patient_name'] as String?,
      deliveryDate: json['delivery_date'] == null
          ? null
          : LocalDate.parse(jsonString(json['delivery_date'])),
      caseConsent: jsonBool(json['case_consent']),
      publishedRevision: jsonInt(json['published_revision']),
      consultation: json['consultation'] == null
          ? null
          : readConsultation(jsonObject(json['consultation'])),
      noteStatus: json['note_status'] == null
          ? null
          : noteStatusWire.read(json['note_status']),
    );
WorkbenchAppointments readWorkbenchAppointments(Map<String, Object?> json) =>
    WorkbenchAppointments(
      date: LocalDate.parse(jsonString(json['date'])),
      timezone: jsonString(json['timezone']),
      items: jsonList(json['items'], readWorkbenchAppointment),
      total: jsonInt(json['total']),
      offset: jsonInt(json['offset']),
      limit: jsonInt(json['limit']),
      serverTime: jsonInstant(json['server_time']),
    );
ClientCareService readClientService(Map<String, Object?> json) =>
    ClientCareService(
      episode: readCareEpisode(jsonObject(json['episode'])),
      package: readServicePackage(jsonObject(json['package'])),
      caseConsent: jsonBool(json['case_consent']),
    );
WorkbenchClient readWorkbenchClient(Map<String, Object?> json) =>
    WorkbenchClient(
      patientRef: jsonString(json['patient_ref']),
      name: json['name'] as String?,
      deliveryDate: json['delivery_date'] == null
          ? null
          : LocalDate.parse(jsonString(json['delivery_date'])),
      services: jsonList(json['services'], readClientService),
    );
WorkbenchClients readWorkbenchClients(Map<String, Object?> json) =>
    WorkbenchClients(
      items: jsonList(json['items'], readWorkbenchClient),
      total: jsonInt(json['total']),
      offset: jsonInt(json['offset']),
      limit: jsonInt(json['limit']),
      serverTime: jsonInstant(json['server_time']),
    );
WorkbenchClientDetail readWorkbenchClientDetail(Map<String, Object?> json) =>
    WorkbenchClientDetail(
      client: readWorkbenchClient(jsonObject(json['client'])),
      appointments: jsonList(json['appointments'], readWorkbenchAppointment),
      appointmentTotal: jsonInt(json['appointment_total']),
      offset: jsonInt(json['offset']),
      limit: jsonInt(json['limit']),
      serverTime: jsonInstant(json['server_time']),
    );
