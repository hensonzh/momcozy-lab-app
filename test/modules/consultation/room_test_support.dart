import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:momcozy_flutter_app/services/consultations/device_check.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/modules/consultation/application/room_controller.dart';
import 'package:momcozy_flutter_app/services/consultations/consultation_media.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_api_repository.dart';
import 'package:momcozy_flutter_app/services/consultations/room_codec.dart';
import '../../support/fixture_api_transport.dart';

Map<String, Object?> roomFixture() => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/product_baseline/room_context.json',
        ).readAsStringSync(),
      )
      as Map,
);

class _ReadyCamera extends Fake implements lk.LocalVideoTrack {
  @override
  Future<bool> stop() async => true;
  @override
  Future<bool> dispose() async => true;
}

class TestReadyDeviceCheck extends ConsultationDeviceCheck {
  @override
  Future<void> start() async {
    video = _ReadyCamera();
    microphoneAvailable = true;
  }
}

class TestRoomRepository implements ConsultationRoomRepository {
  TestRoomRepository({Map<String, Object?>? fixture})
    : json = fixture ?? roomFixture();
  final Map<String, Object?> json;
  final keys = <String>[];
  final sentPresence = <ParticipantPresence>[];
  int endCalls = 0, prepareCalls = 0;
  Future<ConsultationJoin>? nextJoin;
  ConsultationRoomContext get context => readRoomContext(json);
  void ready() {
    json['video_consent'] = true;
    final now = context.serverTime;
    json['location'] = {
      'id': 'location',
      'region': 'CA',
      'decision': 'passed',
      'created_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(minutes: 30)).toIso8601String(),
    };
  }

  void room({
    String status = 'waiting_room',
    String roomStatus = 'ready',
    int version = 1,
  }) {
    json['consultation'] = {
      'id': 'room',
      'appointment_id': context.appointment.id,
      'episode_id': context.appointment.episodeId,
      'version': version,
      'status': status,
      'room_status': roomStatus,
      'video_provider': 'sandbox',
      'started_at': null,
      'ended_at': null,
      'end_reason': null,
    };
  }

  @override
  Future<ConsultationRoomContext> load(String appointmentId) async => context;
  @override
  Future<ConsultationRoomContext> prepare(String appointmentId) async {
    prepareCalls++;
    room();
    return context;
  }

  @override
  Future<ConsultationJoin> join(
    String appointmentId, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    return nextJoin ??
        ConsultationJoin(
          context: context,
          connectionId: 'connection',
          credentials: null,
        );
  }

  @override
  Future<ConsultationRoomContext> presence(
    String appointmentId, {
    required String connectionId,
    required ParticipantPresence presence,
  }) async {
    sentPresence.add(presence);
    return context;
  }

  @override
  Future<ConsultationLocation> checkLocation(
    String appointmentId,
    String region,
  ) async {
    ready();
    return context.location!;
  }

  @override
  Future<ConsultationRoomContext> start(
    String appointmentId, {
    required int expectedVersion,
  }) async {
    room(status: 'in_progress', version: 2);
    return context;
  }

  @override
  Future<ConsultationRoomContext> end(
    String appointmentId, {
    required int expectedVersion,
    required ConsultationEndReason reason,
  }) async {
    endCalls++;
    room(status: 'note_pending', version: 3, roomStatus: 'closing');
    return context;
  }
}

class TestConsultationMedia extends ConsultationMedia {
  @override
  ConsultationMediaState state = ConsultationMediaState.disconnected;
  int disconnectCalls = 0, connectCalls = 0;
  @override
  bool get microphoneOn => false;
  @override
  bool get cameraOn => false;
  @override
  bool get sandbox => true;
  @override
  bool get busy => false;
  @override
  bool get weakNetwork => false;
  @override
  bool get audioPlaybackBlocked => false;
  @override
  String? get error => null;
  @override
  Future<void> connect(
    ConsultationCredentials? credentials, {
    required VideoProvider provider,
  }) async {
    connectCalls++;
    state = ConsultationMediaState.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    state = ConsultationMediaState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> toggleMicrophone() async {}
  @override
  Future<void> toggleCamera() async {}
  @override
  Future<void> enableAudio() async {}
}

ConsultationRoomController testController(
  TestRoomRepository repository,
  TestConsultationMedia media,
) => ConsultationRoomController(
  repository: repository,
  consents: IntakeApiRepository(transport: FixtureApiJsonTransport({})),
  appointmentId: repository.context.appointment.id,
  media: media,
  now: () => repository.context.serverTime,
);
