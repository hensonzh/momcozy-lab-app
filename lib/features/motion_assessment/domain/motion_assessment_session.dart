class MotionAssessmentSession {
  const MotionAssessmentSession({
    required this.id,
    required this.target,
    required this.status,
    required this.poseEngine,
    required this.videoUploadEnabled,
    required this.landmarkUploadEnabled,
    required this.pauseReason,
    required this.resultSummary,
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
      pauseReason: json['pause_reason']?.toString() ?? '',
      resultSummary: Map<String, Object?>.unmodifiable(result),
    );
  }

  final String id;
  final String target;
  final String status;
  final String poseEngine;
  final bool videoUploadEnabled;
  final bool landmarkUploadEnabled;
  final String pauseReason;
  final Map<String, Object?> resultSummary;
}
