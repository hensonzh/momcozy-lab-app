import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retains native input dimensions for geometry and preview transforms',
    () {
      final observation = motionPoseObservationFromNative({
        'timestamp_ms': 100,
        'inference_ms': 20,
        'input_width': 720,
        'input_height': 1280,
        'poses': const <Object?>[],
      });

      expect(observation.inputWidth, 720);
      expect(observation.inputHeight, 1280);
    },
  );

  test(
    'waits for the native model-ready event before start completes',
    () async {
      const methodChannel = MethodChannel('motion-pose-ready-test');
      final events = StreamController<Object?>.broadcast(sync: true);
      var nativeStartCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            if (call.method == 'start') nativeStartCalls += 1;
            return null;
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, null);
        await events.close();
      });
      final platform = NativeMotionPosePlatform(
        methodChannel: methodChannel,
        nativeEvents: events.stream,
      );

      var completed = false;
      final start = platform.start().whenComplete(() => completed = true);
      await _flush();

      expect(nativeStartCalls, 1);
      expect(completed, isFalse);

      events.add(const {'event': 'model_ready'});
      await start;

      expect(completed, isTrue);
    },
  );

  test('does not expose model-ready events as empty pose frames', () async {
    final events = StreamController<Object?>.broadcast(sync: true);
    addTearDown(events.close);
    final platform = NativeMotionPosePlatform(nativeEvents: events.stream);
    final firstObservation = platform.observations.first;

    events.add(const {'event': 'model_ready'});
    events.add({
      'event': 'observation',
      'timestamp_ms': 100,
      'inference_ms': 20,
      'input_width': 720,
      'input_height': 1280,
      'poses': const <Object?>[],
    });

    expect(
      (await firstObservation).timestamp,
      const Duration(milliseconds: 100),
    );
  });

  test(
    'captures a bounded JPEG key frame through the native channel',
    () async {
      const methodChannel = MethodChannel('motion-pose-key-frame-test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            expect(call.method, 'captureKeyFrame');
            expect(call.arguments, {
              'max_width': 448,
              'jpeg_quality': 60,
              'max_bytes': 122880,
            });
            return {
              'id': 'frame-123',
              'bytes': Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xd9]),
              'mime_type': 'image/jpeg',
              'captured_at_ms': 123,
              'width': 448,
              'height': 252,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, null);
      });
      final platform = NativeMotionPosePlatform(methodChannel: methodChannel);

      final frame = await platform.captureKeyFrame();

      expect(frame.id, 'frame-123');
      expect(frame.mimeType, 'image/jpeg');
      expect(frame.bytes, Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xd9]));
      expect(frame.width, 448);
      expect(frame.height, 252);
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
