import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

const _motionPoseViewType = 'com.momcozymai.motion_pose/preview';

enum MotionPoseCameraFacing { front, back }

abstract interface class MotionPosePlatform {
  String get engineName;

  Stream<MotionPoseObservation> get observations;

  Future<bool> requestCameraPermission();

  Future<void> start();

  Future<void> stop();
}

class NativeMotionPosePlatform implements MotionPosePlatform {
  NativeMotionPosePlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel('com.momcozymai.motion_pose/control'),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.momcozymai.motion_pose/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<MotionPoseObservation>? _observations;

  @override
  String get engineName => defaultTargetPlatform == TargetPlatform.iOS
      ? 'apple_vision_body_pose'
      : 'mediapipe_pose_landmarker';

  @override
  Stream<MotionPoseObservation> get observations =>
      _observations ??= _eventChannel.receiveBroadcastStream().map(
        motionPoseObservationFromNative,
      );

  @override
  Future<bool> requestCameraPermission() async {
    return await _methodChannel.invokeMethod<bool>('requestPermission') ??
        false;
  }

  @override
  Future<void> start() => _methodChannel.invokeMethod<void>('start');

  @override
  Future<void> stop() => _methodChannel.invokeMethod<void>('stop');
}

class MotionPosePreview extends StatelessWidget {
  const MotionPosePreview({
    super.key,
    this.cameraFacing = MotionPoseCameraFacing.front,
  });

  final MotionPoseCameraFacing cameraFacing;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: _motionPoseViewType,
        creationParams: {'camera_facing': cameraFacing.name},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const UiKitView(viewType: _motionPoseViewType);
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          '动态评估仅支持 Android 与 iOS',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

@visibleForTesting
MotionPoseObservation motionPoseObservationFromNative(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Invalid native pose observation.');
  }
  final map = Map<Object?, Object?>.from(raw);
  final rawPoses = map['poses'];
  final poses = <MotionPose>[];
  if (rawPoses is List) {
    for (final rawPose in rawPoses) {
      if (rawPose is! Map) continue;
      final poseMap = Map<Object?, Object?>.from(rawPose);
      final rawLandmarks = poseMap['landmarks'];
      final landmarks = <MotionPoseLandmarkType, MotionPoseLandmark>{};
      if (rawLandmarks is List) {
        for (
          var index = 0;
          index < rawLandmarks.length &&
              index < MotionPoseLandmarkType.values.length;
          index++
        ) {
          final rawLandmark = rawLandmarks[index];
          if (rawLandmark is! Map) continue;
          final value = Map<Object?, Object?>.from(rawLandmark);
          landmarks[MotionPoseLandmarkType.values[index]] = MotionPoseLandmark(
            x: _double(value['x']),
            y: _double(value['y']),
            z: _double(value['z']),
            visibility: _double(value['visibility']),
            presence: _double(value['presence']),
          );
        }
      }
      poses.add(
        MotionPose(
          centerX: _double(poseMap['center_x']),
          centerY: _double(poseMap['center_y']),
          bodyScale: _double(poseMap['body_scale']),
          landmarks: Map.unmodifiable(landmarks),
        ),
      );
    }
  }
  return MotionPoseObservation(
    timestamp: Duration(milliseconds: _int(map['timestamp_ms'])),
    poses: List.unmodifiable(poses),
    inferenceTime: Duration(milliseconds: _int(map['inference_ms'])),
    inputWidth: _positiveInt(map['input_width']),
    inputHeight: _positiveInt(map['input_height']),
  );
}

double _double(Object? value) => value is num ? value.toDouble() : 0;

int _int(Object? value) => value is num ? value.toInt() : 0;

int _positiveInt(Object? value) {
  final parsed = _int(value);
  return parsed > 0 ? parsed : 1;
}
