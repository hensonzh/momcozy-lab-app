import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';

void main() {
  test(
    'status-only updates omit result_summary so the server preserves it',
    () async {
      final transport = _FakeTransport();
      final repository = MotionAssessmentApiRepository(transport: transport);

      await repository.update(
        assessmentId: 'assessment-1',
        status: 'paused',
        pauseReason: 'multiple_people',
      );

      expect(transport.lastPatchBody, {
        'status': 'paused',
        'pause_reason': 'multiple_people',
      });
    },
  );
}

class _FakeTransport implements ApiJsonTransport, ApiJsonMutationTransport {
  Map<String, Object?>? lastPatchBody;

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastPatchBody = Map.of(body);
    return {
      'id': 'assessment-1',
      'target': 'forward_head',
      'status': body['status'],
      'pose_engine': 'mediapipe_pose_landmarker',
      'privacy': {
        'video_upload_enabled': false,
        'landmark_upload_enabled': false,
      },
      'pause_reason': body['pause_reason'],
      'result_summary': const <String, Object?>{},
    };
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}
