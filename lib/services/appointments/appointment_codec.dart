import '../../domain/care/appointment.dart';
import '../../domain/shared/local_date.dart';
import '../care/care_codec.dart';
import '../shared/json_value.dart';

const appointmentStatusWire = EnumWire<AppointmentStatus>({
  AppointmentStatus.held: 'held',
  AppointmentStatus.confirmed: 'confirmed',
  AppointmentStatus.inProgress: 'in_progress',
  AppointmentStatus.completed: 'completed',
  AppointmentStatus.cancelled: 'cancelled',
  AppointmentStatus.expired: 'expired',
});
const emergencyStatusWire = EnumWire<EmergencyStatus>({
  EmergencyStatus.clear: 'clear',
  EmergencyStatus.needsHelp: 'needs_help',
});

CareAppointment readAppointment(Map<String, Object?> json) => CareAppointment(
  id: jsonString(json['id']),
  episodeId: jsonString(json['episode_id']),
  providerId: jsonString(json['provider_id']),
  providerName: jsonString(json['provider_name']),
  startsAt: jsonInstant(json['starts_at']),
  endsAt: jsonInstant(json['ends_at']),
  timezone: jsonString(json['timezone']),
  region: jsonString(json['region']),
  status: appointmentStatusWire.read(json['status'])!,
  holdExpiresAt: jsonInstant(json['hold_expires_at']),
  version: jsonInt(json['version']),
  intakeVersion: jsonInt(json['intake_version']),
  confirmedAt: json['confirmed_at'] == null
      ? null
      : jsonInstant(json['confirmed_at']),
  cancelledAt: json['cancelled_at'] == null
      ? null
      : jsonInstant(json['cancelled_at']),
);
BookingEligibility readBookingEligibility(Map<String, Object?> json) =>
    BookingEligibility(
      id: jsonString(json['id']),
      episodeId: jsonString(json['episode_id']),
      region: jsonString(json['region']),
      serviceSuitable: jsonBool(json['service_suitable']),
      emergencyStatus: emergencyStatusWire.read(json['emergency_status'])!,
      eligible: jsonBool(json['eligible']),
      reason: jsonString(json['reason']),
      expiresAt: jsonInstant(json['expires_at']),
    );
BookingContext readBookingContext(Map<String, Object?> json) => BookingContext(
  episode: readCareEpisode(jsonObject(json['episode'])),
  providers: jsonList(json['providers'], readCareProvider),
  appointments: jsonList(json['appointments'], readAppointment),
  serverTime: jsonInstant(json['server_time']),
  eligibility: json['eligibility'] == null
      ? null
      : readBookingEligibility(jsonObject(json['eligibility'])),
);
AppointmentAvailability readAvailability(Map<String, Object?> json) =>
    AppointmentAvailability(
      providerId: jsonString(json['provider_id']),
      date: LocalDate.parse(jsonString(json['date'])),
      timezone: jsonString(json['timezone']),
      serverTime: jsonInstant(json['server_time']),
      slots: jsonList(
        json['slots'],
        (json) => AppointmentSlot(
          startsAt: jsonInstant(json['starts_at']),
          endsAt: jsonInstant(json['ends_at']),
          available: jsonBool(json['available']),
        ),
      ),
    );
