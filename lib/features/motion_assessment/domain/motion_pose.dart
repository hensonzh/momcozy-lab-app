enum MotionPoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

class MotionPoseLandmark {
  const MotionPoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
    required this.presence,
  });

  final double x;
  final double y;
  final double z;
  final double visibility;
  final double presence;

  bool isReliable({double minimumConfidence = 0.65}) {
    return visibility >= minimumConfidence && presence >= minimumConfidence;
  }
}

class MotionPose {
  const MotionPose({
    required this.centerX,
    required this.centerY,
    required this.bodyScale,
    required this.landmarks,
  });

  final double centerX;
  final double centerY;
  final double bodyScale;
  final Map<MotionPoseLandmarkType, MotionPoseLandmark> landmarks;

  MotionPoseLandmark? landmark(MotionPoseLandmarkType type) => landmarks[type];
}

class MotionPoseObservation {
  const MotionPoseObservation({
    required this.timestamp,
    required this.poses,
    required this.inferenceTime,
    this.inputWidth = 1,
    this.inputHeight = 1,
  });

  final Duration timestamp;
  final List<MotionPose> poses;
  final Duration inferenceTime;
  final int inputWidth;
  final int inputHeight;
}
