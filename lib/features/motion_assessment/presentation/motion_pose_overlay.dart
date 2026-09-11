import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_preview_transform.dart';

@immutable
class MotionSkeletonConnection {
  const MotionSkeletonConnection(this.start, this.end);

  final MotionPoseLandmarkType start;
  final MotionPoseLandmarkType end;

  @override
  bool operator ==(Object other) {
    return other is MotionSkeletonConnection &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

/// MediaPipe's full body graph, including the face, hands, and feet that are
/// omitted by the compact assessment-only skeleton.
@visibleForTesting
const motionSkeletonConnections = <MotionSkeletonConnection>[
  MotionSkeletonConnection(
    MotionPoseLandmarkType.nose,
    MotionPoseLandmarkType.leftEyeInner,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftEyeInner,
    MotionPoseLandmarkType.leftEye,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftEye,
    MotionPoseLandmarkType.leftEyeOuter,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftEyeOuter,
    MotionPoseLandmarkType.leftEar,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.nose,
    MotionPoseLandmarkType.rightEyeInner,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightEyeInner,
    MotionPoseLandmarkType.rightEye,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightEye,
    MotionPoseLandmarkType.rightEyeOuter,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightEyeOuter,
    MotionPoseLandmarkType.rightEar,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.mouthLeft,
    MotionPoseLandmarkType.mouthRight,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftEar,
    MotionPoseLandmarkType.leftShoulder,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightEar,
    MotionPoseLandmarkType.rightShoulder,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftShoulder,
    MotionPoseLandmarkType.rightShoulder,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftShoulder,
    MotionPoseLandmarkType.leftElbow,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftElbow,
    MotionPoseLandmarkType.leftWrist,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftWrist,
    MotionPoseLandmarkType.leftPinky,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftWrist,
    MotionPoseLandmarkType.leftIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftWrist,
    MotionPoseLandmarkType.leftThumb,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftPinky,
    MotionPoseLandmarkType.leftIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightShoulder,
    MotionPoseLandmarkType.rightElbow,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightElbow,
    MotionPoseLandmarkType.rightWrist,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightWrist,
    MotionPoseLandmarkType.rightPinky,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightWrist,
    MotionPoseLandmarkType.rightIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightWrist,
    MotionPoseLandmarkType.rightThumb,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightPinky,
    MotionPoseLandmarkType.rightIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftShoulder,
    MotionPoseLandmarkType.leftHip,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightShoulder,
    MotionPoseLandmarkType.rightHip,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftHip,
    MotionPoseLandmarkType.rightHip,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftHip,
    MotionPoseLandmarkType.leftKnee,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftKnee,
    MotionPoseLandmarkType.leftAnkle,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftAnkle,
    MotionPoseLandmarkType.leftHeel,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftHeel,
    MotionPoseLandmarkType.leftFootIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.leftAnkle,
    MotionPoseLandmarkType.leftFootIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightHip,
    MotionPoseLandmarkType.rightKnee,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightKnee,
    MotionPoseLandmarkType.rightAnkle,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightAnkle,
    MotionPoseLandmarkType.rightHeel,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightHeel,
    MotionPoseLandmarkType.rightFootIndex,
  ),
  MotionSkeletonConnection(
    MotionPoseLandmarkType.rightAnkle,
    MotionPoseLandmarkType.rightFootIndex,
  ),
];

class MotionPoseOverlay extends StatelessWidget {
  const MotionPoseOverlay({super.key, required this.observation});

  final MotionPoseObservation? observation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: MotionSkeletonPainter(observation)),
    );
  }
}

class MotionSkeletonPainter extends CustomPainter {
  const MotionSkeletonPainter(this.observation);

  final MotionPoseObservation? observation;

  static const _minimumConfidence = 0.5;
  static const _leftColor = MomCozyColors.motionLeft;
  static const _rightColor = MomCozyColors.motionRight;
  static const _centerColor = MomCozyColors.motionCenter;
  static const _multiplePoseColors = <Color>[
    MomCozyColors.motionPersonFirst,
    MomCozyColors.motionPersonSecond,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final frame = observation;
    if (frame == null || frame.poses.isEmpty || size.isEmpty) return;
    final transform = MotionPreviewTransform.aspectFill(
      inputWidth: frame.inputWidth,
      inputHeight: frame.inputHeight,
      viewport: size,
    );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final jointGlow = Paint()..style = PaintingStyle.fill;
    final jointHalo = Paint()
      ..color = MomCozyColors.onMedia.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;
    final joint = Paint()..style = PaintingStyle.fill;

    for (var poseIndex = 0; poseIndex < frame.poses.length; poseIndex++) {
      final pose = frame.poses[poseIndex];
      for (final connection in motionSkeletonConnections) {
        final start = pose.landmark(connection.start);
        final end = pose.landmark(connection.end);
        if (!_isVisible(start) || !_isVisible(end)) continue;
        final color = _connectionColor(
          connection,
          poseIndex: poseIndex,
          poseCount: frame.poses.length,
        );
        final startPoint = transform.project(Offset(start!.x, start.y));
        final endPoint = transform.project(Offset(end!.x, end.y));
        glow.color = color.withValues(alpha: 0.2);
        line.color = color.withValues(alpha: 0.96);
        canvas.drawLine(startPoint, endPoint, glow);
        canvas.drawLine(startPoint, endPoint, line);
      }

      for (final entry in pose.landmarks.entries) {
        final landmark = entry.value;
        if (!_isVisible(landmark)) continue;
        final color = _landmarkColor(
          entry.key,
          poseIndex: poseIndex,
          poseCount: frame.poses.length,
        );
        final center = transform.project(Offset(landmark.x, landmark.y));
        jointGlow.color = color.withValues(alpha: 0.22);
        joint.color = color;
        canvas.drawCircle(center, 8, jointGlow);
        canvas.drawCircle(center, 5.5, jointHalo);
        canvas.drawCircle(center, 3.5, joint);
      }
    }
  }

  static bool _isVisible(MotionPoseLandmark? landmark) {
    return landmark != null &&
        landmark.x.isFinite &&
        landmark.y.isFinite &&
        landmark.isReliable(minimumConfidence: _minimumConfidence);
  }

  static Color _connectionColor(
    MotionSkeletonConnection connection, {
    required int poseIndex,
    required int poseCount,
  }) {
    if (poseCount > 1) {
      return _multiplePoseColors[poseIndex % _multiplePoseColors.length];
    }
    final startSide = _sideOf(connection.start);
    final endSide = _sideOf(connection.end);
    if (startSide == _BodySide.left && endSide == _BodySide.left) {
      return _leftColor;
    }
    if (startSide == _BodySide.right && endSide == _BodySide.right) {
      return _rightColor;
    }
    return _centerColor;
  }

  static Color _landmarkColor(
    MotionPoseLandmarkType type, {
    required int poseIndex,
    required int poseCount,
  }) {
    if (poseCount > 1) {
      return _multiplePoseColors[poseIndex % _multiplePoseColors.length];
    }
    return switch (_sideOf(type)) {
      _BodySide.left => _leftColor,
      _BodySide.right => _rightColor,
      _BodySide.center => _centerColor,
    };
  }

  static _BodySide _sideOf(MotionPoseLandmarkType type) {
    return switch (type) {
      MotionPoseLandmarkType.leftEyeInner ||
      MotionPoseLandmarkType.leftEye ||
      MotionPoseLandmarkType.leftEyeOuter ||
      MotionPoseLandmarkType.leftEar ||
      MotionPoseLandmarkType.mouthLeft ||
      MotionPoseLandmarkType.leftShoulder ||
      MotionPoseLandmarkType.leftElbow ||
      MotionPoseLandmarkType.leftWrist ||
      MotionPoseLandmarkType.leftPinky ||
      MotionPoseLandmarkType.leftIndex ||
      MotionPoseLandmarkType.leftThumb ||
      MotionPoseLandmarkType.leftHip ||
      MotionPoseLandmarkType.leftKnee ||
      MotionPoseLandmarkType.leftAnkle ||
      MotionPoseLandmarkType.leftHeel ||
      MotionPoseLandmarkType.leftFootIndex => _BodySide.left,
      MotionPoseLandmarkType.rightEyeInner ||
      MotionPoseLandmarkType.rightEye ||
      MotionPoseLandmarkType.rightEyeOuter ||
      MotionPoseLandmarkType.rightEar ||
      MotionPoseLandmarkType.mouthRight ||
      MotionPoseLandmarkType.rightShoulder ||
      MotionPoseLandmarkType.rightElbow ||
      MotionPoseLandmarkType.rightWrist ||
      MotionPoseLandmarkType.rightPinky ||
      MotionPoseLandmarkType.rightIndex ||
      MotionPoseLandmarkType.rightThumb ||
      MotionPoseLandmarkType.rightHip ||
      MotionPoseLandmarkType.rightKnee ||
      MotionPoseLandmarkType.rightAnkle ||
      MotionPoseLandmarkType.rightHeel ||
      MotionPoseLandmarkType.rightFootIndex => _BodySide.right,
      MotionPoseLandmarkType.nose => _BodySide.center,
    };
  }

  @override
  bool shouldRepaint(covariant MotionSkeletonPainter oldDelegate) {
    return oldDelegate.observation != observation;
  }
}

enum _BodySide { left, right, center }
