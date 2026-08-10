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
      final assessmentId = controller.completedAssessmentId;
      if (controller.completedSuccessfully && assessmentId != null) {
        context.go(
          '/',
          extra: {
            'agentAutoRun': {
              'requestMessage':
                  '[系统流程触发] 用户刚完成体态评估。请调用 '
                  'motion_assessment_result.read 读取最新权威聚合结果，'
                  '用简短、易懂、非诊断的中文主动反馈结果，并给出一到两个安全建议。'
                  '评估 ID：$assessmentId',
              'idempotencyKey': 'motion-assessment-feedback:$assessmentId',
              'metadata': {
                'source': 'motion_assessment_completion',
                'assessment_id': assessmentId,
              },
            },
          },
        );
        return;
      }
      context.canPop() ? context.pop() : context.go('/');
    });
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
                if (controller.phase == MotionAssessmentPagePhase.assessing &&
                    controller.forwardHeadResult == null)
                  _samplingProgress(),
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
            const Text(
              '动态姿态评估',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
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
}
