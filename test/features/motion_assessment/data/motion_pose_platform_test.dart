import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';

void main() {
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
}
