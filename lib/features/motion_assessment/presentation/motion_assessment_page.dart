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
            const SizedBox(width: 8),
            AnimatedContainer(
              key: const ValueKey('motion-assessment-voice-status'),
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: controller.voicePhase.name == 'failed'
                    ? Colors.orange.withValues(alpha: 0.82)
                    : const Color(0xff7c2944).withValues(alpha: 0.88),
                shape: BoxShape.circle,
              ),
              width: 40,
              height: 40,
              child: Icon(
                controller.voicePhase.name == 'speaking'
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_rounded,
                size: 20,
                color: Colors.white,
              ),
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
    final (key, alignment, widthFactor, heightFactor, radius) = switch (guide) {
      MotionAssessmentFramingGuide.forwardHead => (
        const ValueKey('motion-framing-guide-forward-head'),
        Alignment.center,
        0.64,
        0.62,
        112.0,
      ),
      MotionAssessmentFramingGuide.shoulderHeight => (
        const ValueKey('motion-framing-guide-shoulder-height'),
        Alignment.center,
        0.82,
        0.62,
        44.0,
      ),
      MotionAssessmentFramingGuide.trunkLateralLean => (
        const ValueKey('motion-framing-guide-trunk-lean'),
        const Alignment(0, -0.02),
        0.72,
        0.62,
        52.0,
      ),
      MotionAssessmentFramingGuide.frontalCombined => (
        const ValueKey('motion-framing-guide-front-combined'),
        const Alignment(0, -0.02),
        0.82,
        0.62,
        44.0,
      ),
      MotionAssessmentFramingGuide.neutral => (
        const ValueKey('motion-framing-guide-neutral'),
        const Alignment(0, -0.1),
        0.68,
        0.48,
        96.0,
      ),
    };
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        key: key,
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        child: CustomPaint(
          painter: _MotionFramingGuidePainter(guide: guide, color: color),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: color, width: blocked ? 3 : 1.5),
            ),
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
    final paint = Paint()
      ..color = color.withValues(alpha: 0.48)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    switch (guide) {
      case MotionAssessmentFramingGuide.shoulderHeight:
        final shoulderY = size.height * 0.32;
        final hipY = size.height * 0.72;
        canvas.drawLine(
          Offset(size.width * 0.18, shoulderY),
          Offset(size.width * 0.82, shoulderY),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.28, hipY),
          Offset(size.width * 0.72, hipY),
          paint,
        );
        break;
      case MotionAssessmentFramingGuide.trunkLateralLean:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.22),
          Offset(size.width * 0.5, size.height * 0.78),
          paint,
        );
        break;
      case MotionAssessmentFramingGuide.frontalCombined:
        final shoulderY = size.height * 0.32;
        final hipY = size.height * 0.72;
        canvas.drawLine(
          Offset(size.width * 0.18, shoulderY),
          Offset(size.width * 0.82, shoulderY),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.28, hipY),
          Offset(size.width * 0.72, hipY),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.2),
          Offset(size.width * 0.5, size.height * 0.82),
          paint,
        );
        break;
      case MotionAssessmentFramingGuide.forwardHead:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.18),
          Offset(size.width * 0.5, size.height * 0.82),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.34, size.height * 0.48),
          Offset(size.width * 0.66, size.height * 0.48),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.39, size.height * 0.76),
          Offset(size.width * 0.61, size.height * 0.76),
          paint,
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
