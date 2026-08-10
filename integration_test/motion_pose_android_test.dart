import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_pose_overlay.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const requireDetectedPerson = bool.fromEnvironment(
    'MOTION_POSE_REQUIRE_PERSON',
  );

  testWidgets(
    'Android native pose engine starts and emits a camera observation',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);
      final platform = NativeMotionPosePlatform();
      final observations = <MotionPoseObservation>[];
      final observationBatch = Completer<List<MotionPoseObservation>>();
      const requiredObservationCount = 3;
      final latestObservation = ValueNotifier<MotionPoseObservation?>(null);
      final subscription = platform.observations.listen(
        (observation) {
          latestObservation.value = observation;
          if (observationBatch.isCompleted ||
              (requireDetectedPerson && observation.poses.isEmpty)) {
            return;
          }
          observations.add(observation);
          if (observations.length == requiredObservationCount) {
            observationBatch.complete(List.unmodifiable(observations));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!observationBatch.isCompleted) {
            observationBatch.completeError(error, stackTrace);
          }
        },
      );
      addTearDown(() async {
        await platform.stop();
        await subscription.cancel();
        latestObservation.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                MotionPosePreview(
                  cameraFacing: requireDetectedPerson
                      ? MotionPoseCameraFacing.back
                      : MotionPoseCameraFacing.front,
                ),
                ValueListenableBuilder<MotionPoseObservation?>(
                  valueListenable: latestObservation,
                  builder: (context, observation, _) {
                    return MotionPoseOverlay(observation: observation);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final cameraGranted = await platform.requestCameraPermission().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TestFailure(
          'Camera permission dialog was not handled. Pre-grant CAMERA to the '
          'selected flavor package before running this device test.',
        ),
      );
      expect(cameraGranted, isTrue);
      await platform.start();
      final captured = await observationBatch.future.timeout(
        const Duration(seconds: 20),
      );
      final observation = captured.last;
      await tester.pump();

      expect(observation.inputWidth, greaterThan(0));
      expect(observation.inputHeight, greaterThan(0));
      expect(observation.inferenceTime, greaterThanOrEqualTo(Duration.zero));
      expect(captured.map((frame) => frame.timestamp).toSet(), hasLength(3));
      if (requireDetectedPerson) {
        expect(observation.poses, isNotEmpty);
        expect(
          observation.poses.first.landmarks,
          hasLength(MotionPoseLandmarkType.values.length),
        );
        final overlay = tester.widget<MotionPoseOverlay>(
          find.byType(MotionPoseOverlay),
        );
        expect(overlay.observation?.poses.first.landmarks, hasLength(33));
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
