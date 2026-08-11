import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_controller.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_pose_overlay.dart';

typedef MotionVisualConsentPrompt = Future<bool> Function(BuildContext context);

class MotionAssessmentPage extends StatefulWidget {
  const MotionAssessmentPage({
    super.key,
    required this.controllerIdentity,
    required this.controllerFactory,
    this.previewBuilder,
    this.visualConsentPrompt,
  });

  final Object controllerIdentity;
  final MotionAssessmentController Function() controllerFactory;
  final WidgetBuilder? previewBuilder;
  final MotionVisualConsentPrompt? visualConsentPrompt;

  @override
  State<MotionAssessmentPage> createState() => _MotionAssessmentPageState();
}

class _MotionAssessmentPageState extends State<MotionAssessmentPage> {
  late MotionAssessmentController _controller;
  MotionAssessmentController get controller => _controller;
  bool _voiceExitScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerFactory();
    controller.addListener(_handleControllerSignal);
    _scheduleStart();
  }

  @override
  void didUpdateWidget(covariant MotionAssessmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controllerIdentity == widget.controllerIdentity) return;
    controller.removeListener(_handleControllerSignal);
    controller.dispose();
    _controller = widget.controllerFactory();
    _voiceExitScheduled = false;
    controller.addListener(_handleControllerSignal);
    _scheduleStart();
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerSignal);
    controller.dispose();
    super.dispose();
  }

  void _scheduleStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startController());
    });
  }

  Future<void> _startController() async {
    final startingController = controller;
    var visualEnabled = startingController.supportsVisualContext;
    final visualConsentPrompt = widget.visualConsentPrompt;
    if (visualEnabled && visualConsentPrompt != null) {
      visualEnabled = await visualConsentPrompt(context);
    }
    if (!mounted || !identical(startingController, controller)) return;
    await startingController.start(keyFrameUploadEnabled: visualEnabled);
  }

  void _handleControllerSignal() {
    if (!controller.exitRequested || _voiceExitScheduled || !mounted) return;
    _voiceExitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.completedSuccessfully) {
        context.go(
          '/',
          extra: {
            'motionAssessmentFeedbackRefreshKey':
                controller.completedAssessmentId ?? '',
          },
        );
        return;
      }
      context.canPop() ? context.pop() : context.go('/');
    });
  }

  void _retryAfterFailure() {
    if (!controller.canRetry) return;
    controller.removeListener(_handleControllerSignal);
    controller.dispose();
    setState(() {
      _controller = widget.controllerFactory();
      _voiceExitScheduled = false;
      controller.addListener(_handleControllerSignal);
    });
    _scheduleStart();
  }

  Future<void> _exitAfterFailure() async {
    await controller.exitAfterFailure();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.previewBuilder?.call(context) ??
                    const MotionPosePreview(),
                MotionPoseOverlay(
                  key: const ValueKey('motion-pose-overlay'),
                  observation: controller.observation,
                ),
                _topBar(),
                _framingGuide(),
                if ((controller.phase ==
                            MotionAssessmentPagePhase.capturingSegment ||
                        controller.phase ==
                            MotionAssessmentPagePhase
                                .capturingValidationSegment) &&
                    controller.forwardHeadResult == null)
                  _samplingProgress(),
                if (controller.phase == MotionAssessmentPagePhase.failed)
                  _failureOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.target == 'posture_screen' ? '体态动态评估' : '头颈姿态动态评估',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('motion-assessment-end'),
              onPressed: controller.canEnd
                  ? () => unawaited(controller.finish())
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                backgroundColor: Colors.black.withValues(alpha: 0.36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('结束评估'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _framingGuide() {
    final blocked =
        controller.phase == MotionAssessmentPagePhase.pausedMultiplePeople ||
        controller.phase == MotionAssessmentPagePhase.targetChanged;
    final guide = controller.framingGuide;
    final color = blocked
        ? Colors.orangeAccent
        : Colors.white.withValues(alpha: 0.72);
    final key = switch (guide) {
      MotionAssessmentFramingGuide.forwardHead => const ValueKey(
        'motion-framing-guide-forward-head',
      ),
      MotionAssessmentFramingGuide.shoulderHeight => const ValueKey(
        'motion-framing-guide-shoulder-height',
      ),
      MotionAssessmentFramingGuide.trunkLateralLean => const ValueKey(
        'motion-framing-guide-trunk-lean',
      ),
      MotionAssessmentFramingGuide.frontalCombined => const ValueKey(
        'motion-framing-guide-front-combined',
      ),
      MotionAssessmentFramingGuide.neutral => const ValueKey(
        'motion-framing-guide-neutral',
      ),
    };
    return Positioned.fill(
      left: 6,
      top: 58,
      right: 6,
      bottom: 22,
      child: IgnorePointer(
        child: KeyedSubtree(
          key: key,
          child: CustomPaint(
            key: const ValueKey('motion-assessment-body-guide'),
            painter: _MotionFramingGuidePainter(guide: guide, color: color),
          ),
        ),
      ),
    );
  }

  Widget _samplingProgress() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const ValueKey('motion-assessment-sampling-progress'),
            value: controller.samplingProgress,
            minHeight: 5,
            backgroundColor: Colors.black38,
            color: const Color(0xff51e1d2),
          ),
        ),
      ),
    );
  }

  Widget _failureOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.74),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff2b2024),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xffffc2cf),
                    size: 34,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    controller.errorMessage ?? '评估暂时中断，请重试。',
                    key: const ValueKey('motion-assessment-error'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('motion-assessment-retry'),
                      onPressed: _retryAfterFailure,
                      child: const Text('重新尝试'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('motion-assessment-exit'),
                      onPressed: _exitAfterFailure,
                      child: const Text('退出评估'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionFramingGuidePainter extends CustomPainter {
  const _MotionFramingGuidePainter({required this.guide, required this.color});

  final MotionAssessmentFramingGuide guide;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;
    final cue = Paint()
      ..color = color.withValues(alpha: 0.46)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    // The outer envelope stays large and stable between assessment types so
    // the user never has to move closer just because the requested metric
    // changed. Side-view cues narrow only the painted silhouette, not the
    // available standing area.
    final horizontalScale = guide == MotionAssessmentFramingGuide.forwardHead
        ? 0.88
        : 1.0;
    double x(double normalized) =>
        size.width * (0.5 + (normalized - 0.5) * horizontalScale);
    double y(double normalized) => size.height * normalized;

    final body = Path()
      ..moveTo(x(0.43), y(0.19))
      ..cubicTo(x(0.34), y(0.20), x(0.25), y(0.22), x(0.18), y(0.27))
      ..cubicTo(x(0.12), y(0.34), x(0.10), y(0.46), x(0.12), y(0.55))
      ..cubicTo(x(0.14), y(0.61), x(0.18), y(0.61), x(0.22), y(0.55))
      ..cubicTo(x(0.26), y(0.50), x(0.28), y(0.46), x(0.30), y(0.43))
      ..cubicTo(x(0.31), y(0.53), x(0.30), y(0.60), x(0.27), y(0.66))
      ..lineTo(x(0.20), y(0.97))
      ..cubicTo(x(0.27), y(0.99), x(0.36), y(0.99), x(0.44), y(0.97))
      ..lineTo(x(0.49), y(0.69))
      ..lineTo(x(0.51), y(0.69))
      ..lineTo(x(0.56), y(0.97))
      ..cubicTo(x(0.64), y(0.99), x(0.73), y(0.99), x(0.80), y(0.97))
      ..lineTo(x(0.73), y(0.66))
      ..cubicTo(x(0.70), y(0.60), x(0.69), y(0.53), x(0.70), y(0.43))
      ..cubicTo(x(0.72), y(0.46), x(0.74), y(0.50), x(0.78), y(0.55))
      ..cubicTo(x(0.82), y(0.61), x(0.86), y(0.61), x(0.88), y(0.55))
      ..cubicTo(x(0.90), y(0.46), x(0.88), y(0.34), x(0.82), y(0.27))
      ..cubicTo(x(0.75), y(0.22), x(0.66), y(0.20), x(0.57), y(0.19));
    body.close();
    final head = Rect.fromCenter(
      center: Offset(x(0.5), y(0.105)),
      width: x(0.615) - x(0.385),
      height: size.height * 0.16,
    );
    canvas.drawPath(body, fill);
    canvas.drawOval(head, fill);
    canvas.drawPath(body, outline);
    canvas.drawOval(head, outline);

    switch (guide) {
      case MotionAssessmentFramingGuide.shoulderHeight:
        final shoulderY = y(0.27);
        canvas.drawLine(
          Offset(x(0.18), shoulderY),
          Offset(x(0.82), shoulderY),
          cue,
        );
        break;
      case MotionAssessmentFramingGuide.trunkLateralLean:
        canvas.drawLine(Offset(x(0.5), y(0.19)), Offset(x(0.5), y(0.68)), cue);
        break;
      case MotionAssessmentFramingGuide.frontalCombined:
        final shoulderY = y(0.27);
        final hipY = y(0.65);
        canvas.drawLine(
          Offset(x(0.18), shoulderY),
          Offset(x(0.82), shoulderY),
          cue,
        );
        canvas.drawLine(Offset(x(0.28), hipY), Offset(x(0.72), hipY), cue);
        canvas.drawLine(Offset(x(0.5), y(0.19)), Offset(x(0.5), y(0.68)), cue);
        break;
      case MotionAssessmentFramingGuide.forwardHead:
        canvas.drawLine(Offset(x(0.5), y(0.025)), Offset(x(0.5), y(0.68)), cue);
        canvas.drawLine(
          Offset(x(0.25), y(0.27)),
          Offset(x(0.75), y(0.27)),
          cue,
        );
        canvas.drawLine(
          Offset(x(0.31), y(0.65)),
          Offset(x(0.69), y(0.65)),
          cue,
        );
        break;
      case MotionAssessmentFramingGuide.neutral:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MotionFramingGuidePainter oldDelegate) =>
      oldDelegate.guide != guide || oldDelegate.color != color;
}
