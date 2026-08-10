import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_finalization.dart';

void main() {
  test('persists only the explicit per-session key frame consent', () async {
    final transport = _FakeTransport();
    final repository = MotionAssessmentApiRepository(transport: transport);

    final session = await repository.create(
      target: 'posture_screen',
      poseEngine: 'mediapipe_pose_landmarker',
      keyFrameUploadEnabled: true,
    );

    expect(transport.lastPostPath, '/v1/motion-assessments');
    expect(transport.lastPostBody?['keyframe_upload_enabled'], isTrue);
    expect(transport.lastPostBody, isNot(contains('video_upload_enabled')));
    expect(session.keyFrameUploadEnabled, isTrue);
  });

  test('updates a voice-selected plan with optimistic concurrency', () async {
    final transport = _FakeTransport();
    final repository = MotionAssessmentApiRepository(transport: transport);

    final session = await repository.updatePlan(
      assessmentId: 'assessment-1',
      targets: const ['forward_head', 'trunk_lateral_lean'],
      expectedRevision: 3,
      confirmed: true,
    );

    expect(transport.lastPutPath, '/v1/motion-assessments/assessment-1/plan');
    expect(transport.lastPutBody, {
      'targets': ['forward_head', 'trunk_lateral_lean'],
      'expected_revision': 3,
      'confirmed': true,
    });
    expect(session.requestedTargets, ['forward_head', 'trunk_lateral_lean']);
    expect(session.planRevision, 4);
    expect(session.planConfirmed, isTrue);
  });

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

  test(
    'retains a pending finalization until the idempotent PUT is acknowledged',
    () async {
      final transport = _FakeTransport()..putFailuresRemaining = 1;
      final store = _FakeFinalizationStore();
      final repository = MotionAssessmentApiRepository(
        transport: transport,
        finalizationStore: store,
      );
      final finalization = MotionAssessmentFinalization(
        finalizationId: 'finalization-assessment-1-v1',
        assessmentId: 'assessment-1',
        outcome: MotionAssessmentOutcome.completed,
        resultSummary: const {'metric': 'craniovertebral_angle', 'value': 49.0},
        processSummary: const {
          'segment_count': 2,
          'completion_confirmation': 'voice_confirmed',
        },
        safetyEvents: const [],
        clientRevision: 1,
      );

      await repository.stageFinalization(finalization);
      expect(store.pending, [finalization]);

      await expectLater(repository.finalize(finalization), throwsStateError);
      expect(store.pending, [finalization]);

      await repository.retryPendingFinalizations();
      expect(store.pending, isEmpty);
      expect(transport.putCalls, 2);
      expect(
        transport.lastPutPath,
        '/v1/motion-assessments/assessment-1/finalization',
      );
      expect(
        transport.lastPutBody?['finalization_id'],
        finalization.finalizationId,
      );
      expect(transport.lastPutBody?['outcome'], 'completed');
    },
  );
}

class _FakeTransport implements ApiJsonTransport, ApiJsonMutationTransport {
  Map<String, Object?>? lastPostBody;
  String? lastPostPath;
  Map<String, Object?>? lastPatchBody;
  Map<String, Object?>? lastPutBody;
  String? lastPutPath;
  int putFailuresRemaining = 0;
  int putCalls = 0;

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
  }) async {
    lastPostPath = path;
    lastPostBody = Map.of(body);
    return {
      'id': 'assessment-1',
      'target': body['target'],
      'status': 'ready',
      'pose_engine': body['pose_engine'],
      'privacy': {
        'video_upload_enabled': false,
        'landmark_upload_enabled': false,
        'keyframe_upload_enabled': body['keyframe_upload_enabled'],
      },
      'pause_reason': '',
      'result_summary': const <String, Object?>{},
    };
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    putCalls += 1;
    lastPutPath = path;
    lastPutBody = Map.of(body);
    if (path.endsWith('/plan')) {
      return {
        'id': 'assessment-1',
        'target': 'posture_screen',
        'status': 'ready',
        'pose_engine': 'mediapipe_pose_landmarker',
        'privacy': {
          'video_upload_enabled': false,
          'landmark_upload_enabled': false,
        },
        'pause_reason': '',
        'result_summary': const <String, Object?>{},
        'requested_targets': body['targets'],
        'plan_revision': (body['expected_revision'] as int) + 1,
        'plan_confirmed': body['confirmed'],
      };
    }
    if (putFailuresRemaining > 0) {
      putFailuresRemaining -= 1;
      throw StateError('network unavailable');
    }
    return {
      'id': 'assessment-1',
      'target': 'forward_head',
      'status': body['outcome'],
      'pose_engine': 'mediapipe_pose_landmarker',
      'privacy': {
        'video_upload_enabled': false,
        'landmark_upload_enabled': false,
      },
      'pause_reason': '',
      'result_summary': body['result_summary'],
      'finalization_id': body['finalization_id'],
    };
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}

class _FakeFinalizationStore implements MotionAssessmentFinalizationStore {
  final List<MotionAssessmentFinalization> pending = [];

  @override
  Future<List<MotionAssessmentFinalization>> readAll() async =>
      List.of(pending);

  @override
  Future<void> remove(String finalizationId) async {
    pending.removeWhere((item) => item.finalizationId == finalizationId);
  }

  @override
  Future<void> upsert(MotionAssessmentFinalization finalization) async {
    pending.removeWhere(
      (item) => item.finalizationId == finalization.finalizationId,
    );
    pending.add(finalization);
  }
}
