import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_finalization.dart';

abstract interface class MotionAssessmentRepository {
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
    bool keyFrameUploadEnabled = false,
  });

  Future<MotionAssessmentSession> update({
    required String assessmentId,
    required String status,
    String pauseReason = '',
    Map<String, Object?>? resultSummary,
  });

  Future<MotionAssessmentSession> updatePlan({
    required String assessmentId,
    required List<String> targets,
    required int expectedRevision,
    required bool confirmed,
  });

  Future<void> stageFinalization(MotionAssessmentFinalization finalization);

  Future<MotionAssessmentSession> finalize(
    MotionAssessmentFinalization finalization,
  );

  Future<void> retryPendingFinalizations();
}

class MotionAssessmentApiRepository implements MotionAssessmentRepository {
  const MotionAssessmentApiRepository({
    required this.transport,
    this.finalizationStore,
  });

  final ApiJsonTransport transport;
  final MotionAssessmentFinalizationStore? finalizationStore;

  @override
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
    bool keyFrameUploadEnabled = false,
  }) async {
    final json = await transport.postJson(
      '/v1/motion-assessments',
      body: {
        'target': target,
        'pose_engine': poseEngine,
        'source_artifact_id': sourceArtifactId,
        'locale': locale,
        'keyframe_upload_enabled': keyFrameUploadEnabled,
      },
    );
    return MotionAssessmentSession.fromJson(json);
  }

  @override
  Future<MotionAssessmentSession> update({
    required String assessmentId,
    required String status,
    String pauseReason = '',
    Map<String, Object?>? resultSummary,
  }) async {
    final mutationTransport = transport;
    if (mutationTransport is! ApiJsonMutationTransport) {
      throw StateError('Motion assessment updates require mutation transport.');
    }
    final body = <String, Object?>{
      'status': status,
      'pause_reason': pauseReason,
    };
    if (resultSummary != null) body['result_summary'] = resultSummary;
    final json = await (mutationTransport as ApiJsonMutationTransport)
        .patchJson('/v1/motion-assessments/$assessmentId', body: body);
    return MotionAssessmentSession.fromJson(json);
  }

  @override
  Future<MotionAssessmentSession> updatePlan({
    required String assessmentId,
    required List<String> targets,
    required int expectedRevision,
    required bool confirmed,
  }) async {
    final mutationTransport = transport;
    if (mutationTransport is! ApiJsonMutationTransport) {
      throw StateError('Motion assessment plans require mutation transport.');
    }
    final json = await (mutationTransport as ApiJsonMutationTransport).putJson(
      '/v1/motion-assessments/$assessmentId/plan',
      body: {
        'targets': List<String>.unmodifiable(targets),
        'expected_revision': expectedRevision,
        'confirmed': confirmed,
      },
    );
    return MotionAssessmentSession.fromJson(json);
  }

  @override
  Future<void> stageFinalization(
    MotionAssessmentFinalization finalization,
  ) async {
    final store = finalizationStore;
    if (store == null) {
      throw StateError('Motion finalization persistence is not configured.');
    }
    await store.upsert(finalization);
  }

  @override
  Future<MotionAssessmentSession> finalize(
    MotionAssessmentFinalization finalization,
  ) async {
    await stageFinalization(finalization);
    final session = await _sendFinalization(finalization);
    await finalizationStore!.remove(finalization.finalizationId);
    return session;
  }

  @override
  Future<void> retryPendingFinalizations() async {
    final store = finalizationStore;
    if (store == null) return;
    List<MotionAssessmentFinalization> pending;
    try {
      pending = await store.readAll();
    } catch (_) {
      return;
    }
    for (final finalization in pending) {
      try {
        await _sendFinalization(finalization);
        await store.remove(finalization.finalizationId);
      } catch (_) {
        // Keep the durable payload for the next launch or network resume.
      }
    }
  }

  Future<MotionAssessmentSession> _sendFinalization(
    MotionAssessmentFinalization finalization,
  ) async {
    final mutationTransport = transport;
    if (mutationTransport is! ApiJsonMutationTransport) {
      throw StateError(
        'Motion assessment finalization requires mutation transport.',
      );
    }
    final json = await (mutationTransport as ApiJsonMutationTransport).putJson(
      '/v1/motion-assessments/${finalization.assessmentId}/finalization',
      body: finalization.toJson(includeAssessmentId: false),
    );
    return MotionAssessmentSession.fromJson(json);
  }
}
