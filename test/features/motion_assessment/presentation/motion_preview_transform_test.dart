import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_preview_transform.dart';

void main() {
  test(
    'matches an aspect-fill preview crop instead of stretching landmarks',
    () {
      final transform = MotionPreviewTransform.aspectFill(
        inputWidth: 400,
        inputHeight: 300,
        viewport: Size(900, 1600),
      );

      expect(transform.project(const Offset(0.5, 0.5)), const Offset(450, 800));
      expect(transform.project(const Offset(0, 0)).dx, closeTo(-616.67, 0.1));
      expect(transform.project(const Offset(1, 1)).dx, closeTo(1516.67, 0.1));
    },
  );

  test('keeps coordinates unchanged when input and viewport ratios match', () {
    final transform = MotionPreviewTransform.aspectFill(
      inputWidth: 900,
      inputHeight: 1600,
      viewport: Size(900, 1600),
    );

    expect(
      transform.project(const Offset(0.25, 0.75)),
      const Offset(225, 1200),
    );
  });
}
