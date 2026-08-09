import 'dart:math' as math;
import 'dart:ui';

class MotionPreviewTransform {
  MotionPreviewTransform.aspectFill({
    required int inputWidth,
    required int inputHeight,
    required Size viewport,
  }) : _scale = math.max(
         viewport.width / math.max(inputWidth, 1),
         viewport.height / math.max(inputHeight, 1),
       ),
       _inputWidth = math.max(inputWidth, 1).toDouble(),
       _inputHeight = math.max(inputHeight, 1).toDouble(),
       _viewport = viewport;

  final double _scale;
  final double _inputWidth;
  final double _inputHeight;
  final Size _viewport;

  Offset project(Offset normalized) {
    final displayedWidth = _inputWidth * _scale;
    final displayedHeight = _inputHeight * _scale;
    final cropX = (_viewport.width - displayedWidth) / 2;
    final cropY = (_viewport.height - displayedHeight) / 2;
    return Offset(
      normalized.dx * displayedWidth + cropX,
      normalized.dy * displayedHeight + cropY,
    );
  }
}
