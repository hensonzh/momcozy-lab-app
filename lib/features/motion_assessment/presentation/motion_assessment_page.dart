import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_controller.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_pose_overlay.dart';

class MotionAssessmentPage extends StatefulWidget {
  const MotionAssessmentPage({
    super.key,
    required this.controllerIdentity,
    required this.controllerFactory,
    this.previewBuilder,
  });

  final Object controllerIdentity;
  final MotionAssessmentController Function() controllerFactory;
  final WidgetBuilder? previewBuilder;

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
      if (mounted) unawaited(controller.start());
    });
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
            const Expanded(
              child: Text(
                '头颈姿态动态评估',
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
    return Align(
      alignment: const Alignment(0, -0.1),
      child: FractionallySizedBox(
        widthFactor: 0.68,
        heightFactor: 0.48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(96),
            border: Border.all(
              color: blocked
                  ? Colors.orangeAccent
                  : Colors.white.withValues(alpha: 0.72),
              width: blocked ? 3 : 1.5,
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
