import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_voice_signaling.dart';

void main() {
  test(
    'visual context is fail-closed unless the session header enables it',
    () {
      expect(motionVisualContextEnabledFromHeader(' enabled '), isTrue);
      expect(motionVisualContextEnabledFromHeader('disabled'), isFalse);
      expect(motionVisualContextEnabledFromHeader(null), isFalse);
    },
  );
}
