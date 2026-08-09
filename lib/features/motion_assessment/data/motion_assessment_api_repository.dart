import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';

abstract interface class MotionAssessmentRepository {
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
  });

  Future<MotionAssessmentSession> update({
    required String assessmentId,
    required String status,
    String pauseReason = '',
    Map<String, Object?>? resultSummary,
  });
}

class MotionAssessmentApiRepository implements MotionAssessmentRepository {
  const MotionAssessmentApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
  }) async {
    final json = await transport.postJson(
      '/v1/motion-assessments',
      body: {
        'target': target,
        'pose_engine': poseEngine,
        'source_artifact_id': sourceArtifactId,
        'locale': locale,
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
}
