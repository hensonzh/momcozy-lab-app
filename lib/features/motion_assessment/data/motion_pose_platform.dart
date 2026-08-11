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

/// Optional camera capability used by the Realtime visual-assistance layer.
///
/// Pose inference remains the source of truth. Implementations capture only a
/// single, bounded analysis frame when explicitly requested.
abstract interface class MotionKeyFrameCapturePlatform {
  Future<MotionPoseKeyFrame> captureKeyFrame();
}

class MotionPoseKeyFrame {
  const MotionPoseKeyFrame({
    required this.id,
    required this.bytes,
    required this.mimeType,
    required this.capturedAtMs,
    required this.width,
    required this.height,
  });

  final String id;
  final Uint8List bytes;
  final String mimeType;
  final int capturedAtMs;
  final int width;
  final int height;
}

class NativeMotionPosePlatform
    implements MotionPosePlatform, MotionKeyFrameCapturePlatform {
  NativeMotionPosePlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    @visibleForTesting Stream<Object?>? nativeEvents,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel('com.momcozymai.motion_pose/control'),
       _nativeEvents =
           nativeEvents ??
           (eventChannel ??
                   const EventChannel('com.momcozymai.motion_pose/events'))
               .receiveBroadcastStream();

  final MethodChannel _methodChannel;
  final Stream<Object?> _nativeEvents;
  Stream<MotionPoseObservation>? _observations;
  Future<void>? _pendingStart;
  Completer<bool>? _pendingReady;
  bool _ready = false;

  @override
  String get engineName => defaultTargetPlatform == TargetPlatform.iOS
      ? 'apple_vision_body_pose'
      : 'mediapipe_pose_landmarker';

  @override
  Stream<MotionPoseObservation> get observations =>
      _observations ??= _nativeEvents
          .where(_isPoseObservationEvent)
          .map(motionPoseObservationFromNative);

  @override
  Future<bool> requestCameraPermission() async {
    return await _methodChannel.invokeMethod<bool>('requestPermission') ??
        false;
  }

  @override
  Future<void> start() {
    if (_ready) return Future<void>.value();
    return _pendingStart ??= _startAndWaitForModel().whenComplete(() {
      _pendingStart = null;
    });
  }

  @override
  Future<void> stop() async {
    _ready = false;
    final pendingReady = _pendingReady;
    if (pendingReady != null && !pendingReady.isCompleted) {
      pendingReady.complete(false);
    }
    await _methodChannel.invokeMethod<void>('stop');
  }

  @override
  Future<MotionPoseKeyFrame> captureKeyFrame() async {
    final raw = await _methodChannel
        .invokeMethod<Object?>('captureKeyFrame', const {
          'max_width': 448,
          'jpeg_quality': 60,
          'max_bytes': 122880,
        })
        .timeout(
          const Duration(milliseconds: 1800),
          onTimeout: () => throw PlatformException(
            code: 'key_frame_timeout',
            message: 'No camera analysis frame was available in time.',
          ),
        );
    return motionPoseKeyFrameFromNative(raw);
  }

  Future<void> _startAndWaitForModel() async {
    final ready = Completer<bool>();
    _pendingReady = ready;
    late final StreamSubscription<Object?> subscription;
    subscription = _nativeEvents.listen(
      (event) {
        if (_nativeEventType(event) == 'model_ready' && !ready.isCompleted) {
          ready.complete(true);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ready.isCompleted) ready.completeError(error, stackTrace);
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(
            PlatformException(
              code: 'pose_event_stream_closed',
              message: 'Motion pose event stream closed before model startup',
            ),
          );
        }
      },
    );
    try {
      await _methodChannel.invokeMethod<void>('start');
      final becameReady = await ready.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw PlatformException(
          code: 'pose_start_timeout',
          message: 'Motion pose model did not become ready within 20 seconds',
        ),
      );
      if (!becameReady) {
        throw PlatformException(
          code: 'camera_start_cancelled',
          message: 'Motion pose startup was cancelled',
        );
      }
      _ready = true;
    } finally {
      if (identical(_pendingReady, ready)) _pendingReady = null;
      await subscription.cancel();
    }
  }
}

@visibleForTesting
MotionPoseKeyFrame motionPoseKeyFrameFromNative(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Invalid native pose key frame.');
  }
  final map = Map<Object?, Object?>.from(raw);
  final rawBytes = map['bytes'];
  final bytes = switch (rawBytes) {
    Uint8List value => value,
    List<int> value => Uint8List.fromList(value),
    _ => throw const FormatException('Pose key frame has no JPEG bytes.'),
  };
  final id = map['id']?.toString().trim() ?? '';
  final mimeType = map['mime_type']?.toString().trim().toLowerCase() ?? '';
  final width = _positiveInt(map['width']);
  final height = _positiveInt(map['height']);
  if (id.isEmpty || mimeType != 'image/jpeg' || bytes.isEmpty) {
    throw const FormatException('Pose key frame metadata is invalid.');
  }
  return MotionPoseKeyFrame(
    id: id,
    bytes: bytes,
    mimeType: mimeType,
    capturedAtMs: _int(map['captured_at_ms']),
    width: width,
    height: height,
  );
}

bool _isPoseObservationEvent(Object? event) {
  final type = _nativeEventType(event);
  return type == null || type == 'observation';
}

String? _nativeEventType(Object? event) {
  if (event is! Map) return null;
  final type = event['event'];
  return type is String ? type : null;
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
            presence: _optionalDouble(value['presence']),
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

double? _optionalDouble(Object? value) =>
    value is num ? value.toDouble() : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

int _positiveInt(Object? value) {
  final parsed = _int(value);
  return parsed > 0 ? parsed : 1;
}
