import '../shared/local_date.dart';
import 'care_episode.dart';
import 'service_package.dart';

enum AppointmentStatus {
  held,
  confirmed,
  inProgress,
  completed,
  cancelled,
  expired,
}

enum EmergencyStatus { clear, needsHelp }

final class CareAppointment {
  const CareAppointment({
    required this.id,
    required this.episodeId,
    required this.providerId,
    required this.providerName,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.region,
    required this.status,
    required this.holdExpiresAt,
    required this.version,
    required this.intakeVersion,
    this.confirmedAt,
    this.cancelledAt,
  });
  final String id, episodeId, providerId, providerName, timezone, region;
  final DateTime startsAt, endsAt, holdExpiresAt;
  final DateTime? confirmedAt, cancelledAt;
  final AppointmentStatus status;
  final int version, intakeVersion;
  Duration get duration => endsAt.difference(startsAt);
  bool activeAt(DateTime now) =>
      status == AppointmentStatus.confirmed ||
      status == AppointmentStatus.inProgress ||
      (status == AppointmentStatus.held && holdExpiresAt.isAfter(now));
}

final class BookingEligibility {
  const BookingEligibility({
    required this.id,
    required this.episodeId,
    required this.region,
    required this.serviceSuitable,
    required this.emergencyStatus,
    required this.eligible,
    required this.reason,
    required this.expiresAt,
  });
  final String id, episodeId, region, reason;
  final bool eligible, serviceSuitable;
  final EmergencyStatus emergencyStatus;
  final DateTime expiresAt;
  bool validAt(DateTime now) => eligible && expiresAt.isAfter(now);
}

final class BookingContext {
  const BookingContext({
    required this.episode,
    required this.providers,
    required this.appointments,
    required this.serverTime,
    this.eligibility,
  });
  final CareEpisode episode;
  final List<CareProvider> providers;
  final List<CareAppointment> appointments;
  final BookingEligibility? eligibility;
  final DateTime serverTime;
}

final class AppointmentSlot {
  const AppointmentSlot({
    required this.startsAt,
    required this.endsAt,
    required this.available,
  });
  final DateTime startsAt, endsAt;
  final bool available;
  Duration get duration => endsAt.difference(startsAt);
}

final class AppointmentAvailability {
  const AppointmentAvailability({
    required this.providerId,
    required this.date,
    required this.timezone,
    required this.slots,
    required this.serverTime,
  });
  final String providerId, timezone;
  final LocalDate date;
  final List<AppointmentSlot> slots;
  final DateTime serverTime;
}

abstract interface class AppointmentRepository {
  Future<BookingContext> context(String episodeId);
  Future<BookingEligibility> precheck(
    String episodeId, {
    required String region,
    required bool serviceSuitable,
    required EmergencyStatus emergencyStatus,
  });
  Future<AppointmentAvailability> availability(
    String episodeId, {
    required String eligibilityId,
    required String providerId,
    required LocalDate date,
  });
  Future<CareAppointment> hold(
    String episodeId, {
    required String eligibilityId,
    required String providerId,
    required DateTime startsAt,
    required String idempotencyKey,
  });
  Future<CareAppointment> read(String appointmentId);
  Future<CareAppointment> confirm(
    String appointmentId, {
    required int expectedVersion,
  });
  Future<CareAppointment> cancel(
    String appointmentId, {
    required int expectedVersion,
  });
}
