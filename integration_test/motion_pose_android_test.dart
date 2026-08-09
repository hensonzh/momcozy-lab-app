import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android native pose engine starts and emits a camera observation',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);
      final platform = NativeMotionPosePlatform();
      final firstObservation = Completer<MotionPoseObservation>();
      final subscription = platform.observations.listen(
        (observation) {
          if (!firstObservation.isCompleted) {
            firstObservation.complete(observation);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!firstObservation.isCompleted) {
            firstObservation.completeError(error, stackTrace);
          }
        },
      );
      addTearDown(() async {
        await platform.stop();
        await subscription.cancel();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MotionPosePreview())),
      );
      await tester.pump();

      final cameraGranted = await platform.requestCameraPermission().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TestFailure(
          'Camera permission dialog was not handled. Pre-grant CAMERA to the '
          'staging package before running this device test.',
        ),
      );
      expect(cameraGranted, isTrue);
      await platform.start();
      final observation = await firstObservation.future.timeout(
        const Duration(seconds: 20),
      );

      expect(observation.inputWidth, greaterThan(0));
      expect(observation.inputHeight, greaterThan(0));
      expect(observation.inferenceTime, greaterThanOrEqualTo(Duration.zero));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
