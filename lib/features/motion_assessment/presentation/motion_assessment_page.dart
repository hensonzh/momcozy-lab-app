import 'dart:async';

import 'package:flutter/foundation.dart';
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
                _topBar(context),
                _framingGuide(),
                _bottomPanel(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: const ValueKey('motion-assessment-close'),
              onPressed: () => unawaited(_close(context)),
              icon: const Icon(Icons.close_rounded),
              tooltip: '退出评估',
            ),
            const SizedBox(width: 8),
            const Text(
              '动态姿态评估',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      controller.voicePhase.name == 'speaking'
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_rounded,
                      size: 17,
                      color: controller.voicePhase.name == 'failed'
                          ? Colors.orangeAccent
                          : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _voiceLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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

  Widget _bottomPanel(BuildContext context) {
    final result = controller.forwardHeadResult;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff20171c).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _statusIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.guidance,
                    key: const ValueKey('motion-assessment-guidance'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (controller.voiceStatusMessage case final message?) ...[
              const SizedBox(height: 10),
              Row(
                key: const ValueKey('motion-assessment-voice-status'),
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (controller.phase == MotionAssessmentPagePhase.failed &&
                controller.poseDiagnosticMessage != null &&
                kDebugMode) ...[
              const SizedBox(height: 8),
              SelectableText(
                '诊断信息：${controller.poseDiagnosticMessage!}',
                key: const ValueKey('motion-assessment-pose-diagnostic'),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            if (controller.phase == MotionAssessmentPagePhase.assessing &&
                result == null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const ValueKey('motion-assessment-sampling-progress'),
                  value: controller.samplingProgress,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  color: const Color(0xff51e1d2),
                ),
              ),
            ],
            if (controller.phase ==
                MotionAssessmentPagePhase.targetChanged) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(controller.confirmRecalibration()),
                child: const Text('确认是我，重新校准'),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(_complete(context)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('完成评估'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusIcon() {
    final icon = switch (controller.phase) {
      MotionAssessmentPagePhase.pausedMultiplePeople => Icons.groups_rounded,
      MotionAssessmentPagePhase.targetChanged => Icons.person_search_rounded,
      MotionAssessmentPagePhase.assessing => Icons.accessibility_new_rounded,
      MotionAssessmentPagePhase.failed => Icons.error_outline_rounded,
      _ => Icons.center_focus_strong_rounded,
    };
    return Icon(icon, color: Colors.white, size: 28);
  }

  String _voiceLabel() {
    if (controller.voicePhase.name == 'reconnecting') return '重新连接…';
    if (controller.voiceStatusMessage != null) return '语音未连接';
    final provider = controller.voiceProviderName == 'openai_realtime'
        ? 'OpenAI · '
        : '';
    return switch (controller.voicePhase.name) {
      'speaking' when !controller.hasRemoteVoiceAudio => '音频连接中…',
      'speaking' => '$provider指导中',
      'listening' => '$provider聆听中',
      'failed' => '语音未连接',
      'closed' => '语音已关闭',
      'reconnecting' => '重新连接…',
      _ => '连接实时语音…',
    };
  }

  Future<void> _close(BuildContext context) async {
    await controller.finish();
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go('/');
  }

  Future<void> _complete(BuildContext context) async {
    await controller.finish(completed: true);
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go('/');
  }
}
