import '../../core/network/api_json_transport.dart';
import '../../domain/care/appointment.dart';
import '../../domain/shared/local_date.dart';
import '../shared/product_failure_mapper.dart';
import 'appointment_codec.dart';

class AppointmentApiRepository implements AppointmentRepository {
  const AppointmentApiRepository({required this.transport});
  final ApiJsonTransport transport;
  String _episode(String id) => '/v1/care/episodes/${Uri.encodeComponent(id)}';
  String _appointment(String id) =>
      '/v1/care/appointments/${Uri.encodeComponent(id)}';
  @override
  Future<BookingContext> context(String episodeId) => withProductFailure(
    () async => readBookingContext(
      await transport.getJson('${_episode(episodeId)}/booking'),
    ),
  );
  @override
  Future<BookingEligibility> precheck(
    String episodeId, {
    required String region,
    required bool serviceSuitable,
    required EmergencyStatus emergencyStatus,
  }) => withProductFailure(
    () async => readBookingEligibility(
      await transport.postJson(
        '${_episode(episodeId)}/booking-eligibility',
        body: {
          'region': region,
          'service_suitable': serviceSuitable,
          'emergency_status': emergencyStatusWire.write(emergencyStatus),
        },
      ),
    ),
  );
  @override
  Future<AppointmentAvailability> availability(
    String episodeId, {
    required String eligibilityId,
    required String providerId,
    required LocalDate date,
  }) => withProductFailure(
    () async => readAvailability(
      await transport.getJson(
        '${_episode(episodeId)}/availability',
        query: {
          'eligibility_id': eligibilityId,
          'provider_id': providerId,
          'date': date.toString(),
        },
      ),
    ),
  );
  @override
  Future<CareAppointment> hold(
    String episodeId, {
    required String eligibilityId,
    required String providerId,
    required DateTime startsAt,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readAppointment(
      await transport.postJson(
        '${_episode(episodeId)}/holds',
        body: {
          'eligibility_id': eligibilityId,
          'provider_id': providerId,
          'starts_at': startsAt.toUtc().toIso8601String(),
        },
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    ),
  );
  @override
  Future<CareAppointment> read(String appointmentId) => withProductFailure(
    () async =>
        readAppointment(await transport.getJson(_appointment(appointmentId))),
  );
  @override
  Future<CareAppointment> confirm(
    String appointmentId, {
    required int expectedVersion,
  }) => withProductFailure(
    () async => readAppointment(
      await transport.postJson(
        '${_appointment(appointmentId)}/confirm',
        body: {'expected_version': expectedVersion},
      ),
    ),
  );
  @override
  Future<CareAppointment> cancel(
    String appointmentId, {
    required int expectedVersion,
  }) => withProductFailure(
    () async => readAppointment(
      await transport.postJson(
        '${_appointment(appointmentId)}/cancel',
        body: {'expected_version': expectedVersion},
      ),
    ),
  );
}
