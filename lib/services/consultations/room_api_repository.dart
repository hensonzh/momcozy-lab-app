import '../../core/network/api_json_transport.dart';
import '../../domain/care/consultation_room.dart';
import '../shared/product_failure_mapper.dart';
import 'room_codec.dart';

class ConsultationRoomApiRepository implements ConsultationRoomRepository {
  const ConsultationRoomApiRepository({required this.transport});
  final ApiJsonTransport transport;
  String _path(String id) => '/v1/care/appointments/${Uri.encodeComponent(id)}';
  @override
  Future<ConsultationRoomContext> load(String appointmentId) =>
      withProductFailure(
        () async => readRoomContext(
          await transport.getJson('${_path(appointmentId)}/room'),
        ),
      );
  @override
  Future<ConsultationLocation> checkLocation(
    String appointmentId,
    String region,
  ) => withProductFailure(
    () async => readConsultationLocation(
      await transport.postJson(
        '${_path(appointmentId)}/location-check',
        body: {'region': region},
      ),
    ),
  );
  @override
  Future<ConsultationRoomContext> prepare(String appointmentId) =>
      withProductFailure(
        () async => readRoomContext(
          await transport.postJson('${_path(appointmentId)}/room'),
        ),
      );
  @override
  Future<ConsultationJoin> join(
    String appointmentId, {
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readRoomJoin(
      await transport.postJson(
        '${_path(appointmentId)}/room/join',
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    ),
  );
  @override
  Future<ConsultationRoomContext> presence(
    String appointmentId, {
    required String connectionId,
    required ParticipantPresence presence,
  }) => withProductFailure(
    () async => readRoomContext(
      await (transport as ApiJsonMutationTransport).putJson(
        '${_path(appointmentId)}/room/presence',
        body: {
          'connection_id': connectionId,
          'presence': participantPresenceWire.write(presence),
        },
      ),
    ),
  );
  @override
  Future<ConsultationRoomContext> start(
    String appointmentId, {
    required int expectedVersion,
  }) => withProductFailure(
    () async => readRoomContext(
      await transport.postJson(
        '${_path(appointmentId)}/room/start',
        body: {'expected_version': expectedVersion},
      ),
    ),
  );
  @override
  Future<ConsultationRoomContext> end(
    String appointmentId, {
    required int expectedVersion,
    required ConsultationEndReason reason,
  }) => withProductFailure(
    () async => readRoomContext(
      await transport.postJson(
        '${_path(appointmentId)}/room/end',
        body: {
          'expected_version': expectedVersion,
          'reason': consultationEndReasonWire.write(reason),
        },
      ),
    ),
  );
}
