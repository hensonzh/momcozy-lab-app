import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_pose_overlay.dart';

void main() {
  test('overlay covers face, hands, torso, legs, and feet', () {
    expect(motionSkeletonConnections.length, greaterThanOrEqualTo(30));
    expect(
      motionSkeletonConnections,
      contains(
        const MotionSkeletonConnection(
          MotionPoseLandmarkType.nose,
          MotionPoseLandmarkType.leftEyeInner,
        ),
      ),
    );
    expect(
      motionSkeletonConnections,
      contains(
        const MotionSkeletonConnection(
          MotionPoseLandmarkType.leftWrist,
          MotionPoseLandmarkType.leftIndex,
        ),
      ),
    );
    expect(
      motionSkeletonConnections,
      contains(
        const MotionSkeletonConnection(
          MotionPoseLandmarkType.leftAnkle,
          MotionPoseLandmarkType.leftHeel,
        ),
      ),
    );
  });

  test('painter renders reliable landmarks and skeleton segments', () async {
    final observation = _observation();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(240, 400);

    MotionSkeletonPainter(observation).paint(canvas, size);

    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    var paintedPixels = 0;
    for (var index = 3; index < bytes!.lengthInBytes; index += 4) {
      if (bytes.getUint8(index) > 0) paintedPixels += 1;
    }
    expect(paintedPixels, greaterThan(1000));
  });

  test('painter repaints whenever a new camera observation arrives', () {
    final first = _observation(timestampMs: 1);
    final second = _observation(timestampMs: 67);

    expect(
      MotionSkeletonPainter(first).shouldRepaint(MotionSkeletonPainter(first)),
      isFalse,
    );
    expect(
      MotionSkeletonPainter(second).shouldRepaint(MotionSkeletonPainter(first)),
      isTrue,
    );
  });

  test(
    'painted keypoints follow the body coordinates in the next frame',
    () async {
      final firstCenter = await _paintedCentroidX(_observation());
      final movedCenter = await _paintedCentroidX(_observation(xOffset: 0.12));

      expect(movedCenter, greaterThan(firstCenter + 20));
    },
  );
}

Future<double> _paintedCentroidX(MotionPoseObservation observation) async {
  const size = Size(240, 400);
  final recorder = ui.PictureRecorder();
  MotionSkeletonPainter(observation).paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(bytes, isNotNull);
  var paintedPixels = 0;
  var totalX = 0.0;
  for (var y = 0; y < size.height.toInt(); y++) {
    for (var x = 0; x < size.width.toInt(); x++) {
      final alphaIndex = (y * size.width.toInt() + x) * 4 + 3;
      if (bytes!.getUint8(alphaIndex) == 0) continue;
      paintedPixels += 1;
      totalX += x;
    }
  }
  expect(paintedPixels, greaterThan(0));
  return totalX / paintedPixels;
}

MotionPoseObservation _observation({int timestampMs = 1, double xOffset = 0}) {
  final landmarks = <MotionPoseLandmarkType, MotionPoseLandmark>{};
  for (var index = 0; index < MotionPoseLandmarkType.values.length; index++) {
    final type = MotionPoseLandmarkType.values[index];
    landmarks[type] = MotionPoseLandmark(
      x: 0.18 + (index % 5) * 0.14 + xOffset,
      y: 0.08 + (index ~/ 5) * 0.125,
      z: 0,
      visibility: 0.95,
      presence: 0.95,
    );
  }
  return MotionPoseObservation(
    timestamp: Duration(milliseconds: timestampMs),
    poses: [
      MotionPose(
        centerX: 0.5,
        centerY: 0.5,
        bodyScale: 0.8,
        landmarks: landmarks,
      ),
    ],
    inferenceTime: const Duration(milliseconds: 12),
    inputWidth: 720,
    inputHeight: 1200,
  );
}
