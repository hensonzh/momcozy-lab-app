class MotionAssessmentSession {
  const MotionAssessmentSession({
    required this.id,
    required this.target,
    required this.status,
    required this.poseEngine,
    required this.videoUploadEnabled,
    required this.landmarkUploadEnabled,
    this.keyFrameUploadEnabled = false,
    required this.pauseReason,
    required this.resultSummary,
    this.requestedTargets = const [],
    this.planRevision = 0,
    this.planConfirmed = false,
  });

  factory MotionAssessmentSession.fromJson(Map<String, Object?> json) {
    final privacy = json['privacy'] is Map
        ? Map<String, Object?>.from(json['privacy']! as Map)
        : const <String, Object?>{};
    final result = json['result_summary'] is Map
        ? Map<String, Object?>.from(json['result_summary']! as Map)
        : const <String, Object?>{};
    return MotionAssessmentSession(
      id: json['id']?.toString() ?? '',
      target: json['target']?.toString() ?? 'forward_head',
      status: json['status']?.toString() ?? 'ready',
      poseEngine:
          json['pose_engine']?.toString() ?? 'mediapipe_pose_landmarker',
      videoUploadEnabled: privacy['video_upload_enabled'] == true,
      landmarkUploadEnabled: privacy['landmark_upload_enabled'] == true,
      keyFrameUploadEnabled: privacy['keyframe_upload_enabled'] == true,
      pauseReason: json['pause_reason']?.toString() ?? '',
      resultSummary: Map<String, Object?>.unmodifiable(result),
      requestedTargets: List<String>.unmodifiable(
        (json['requested_targets'] is List
                ? json['requested_targets']! as List
                : const [])
            .map((item) => item.toString()),
      ),
      planRevision: json['plan_revision'] is int
          ? json['plan_revision']! as int
          : 0,
      planConfirmed: json['plan_confirmed'] == true,
    );
  }

  final String id;
  final String target;
  final String status;
  final String poseEngine;
  final bool videoUploadEnabled;
  final bool landmarkUploadEnabled;
  final bool keyFrameUploadEnabled;
  final String pauseReason;
  final Map<String, Object?> resultSummary;
  final List<String> requestedTargets;
  final int planRevision;
  final bool planConfirmed;
}
