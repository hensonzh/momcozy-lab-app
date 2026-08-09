import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_controller.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_preview_transform.dart';

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
                IgnorePointer(
                  child: CustomPaint(
                    painter: _MotionSkeletonPainter(controller.observation),
                  ),
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
                    const SizedBox(width: 6),
                    Text(
                      _voiceLabel(),
                      style: const TextStyle(
                        color: Colors.white,
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
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.72,
        heightFactor: 0.68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(120),
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
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '视频与人体关键点仅在本机实时处理',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Text(
                  '${controller.personCount} 人',
                  style: TextStyle(
                    color: controller.personCount > 1
                        ? Colors.orangeAccent
                        : Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
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
              Text(
                '当前画面参考角度 ${result.valueDegrees.toStringAsFixed(1)}°',
                style: const TextStyle(
                  color: Color(0xffffc9dc),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
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
    return switch (controller.voicePhase.name) {
      'speaking' => '正在指导',
      'listening' => '正在聆听',
      'failed' => '语音未连接',
      'closed' => '语音已关闭',
      _ => '连接语音…',
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

class _MotionSkeletonPainter extends CustomPainter {
  const _MotionSkeletonPainter(this.observation);

  final MotionPoseObservation? observation;

  static const _connections =
      <(MotionPoseLandmarkType, MotionPoseLandmarkType)>[
        (
          MotionPoseLandmarkType.leftShoulder,
          MotionPoseLandmarkType.rightShoulder,
        ),
        (MotionPoseLandmarkType.leftShoulder, MotionPoseLandmarkType.leftElbow),
        (MotionPoseLandmarkType.leftElbow, MotionPoseLandmarkType.leftWrist),
        (
          MotionPoseLandmarkType.rightShoulder,
          MotionPoseLandmarkType.rightElbow,
        ),
        (MotionPoseLandmarkType.rightElbow, MotionPoseLandmarkType.rightWrist),
        (MotionPoseLandmarkType.leftShoulder, MotionPoseLandmarkType.leftHip),
        (MotionPoseLandmarkType.rightShoulder, MotionPoseLandmarkType.rightHip),
        (MotionPoseLandmarkType.leftHip, MotionPoseLandmarkType.rightHip),
        (MotionPoseLandmarkType.leftHip, MotionPoseLandmarkType.leftKnee),
        (MotionPoseLandmarkType.leftKnee, MotionPoseLandmarkType.leftAnkle),
        (MotionPoseLandmarkType.rightHip, MotionPoseLandmarkType.rightKnee),
        (MotionPoseLandmarkType.rightKnee, MotionPoseLandmarkType.rightAnkle),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final poses = observation?.poses ?? const <MotionPose>[];
    final frame = observation;
    final transform = MotionPreviewTransform.aspectFill(
      inputWidth: frame?.inputWidth ?? 1,
      inputHeight: frame?.inputHeight ?? 1,
      viewport: size,
    );
    final line = Paint()
      ..color = poses.length > 1
          ? Colors.orangeAccent.withValues(alpha: 0.9)
          : const Color(0xffff8eb7).withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final point = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (final pose in poses) {
      for (final connection in _connections) {
        final start = pose.landmark(connection.$1);
        final end = pose.landmark(connection.$2);
        if (start == null ||
            end == null ||
            !start.isReliable() ||
            !end.isReliable()) {
          continue;
        }
        canvas.drawLine(
          transform.project(Offset(start.x, start.y)),
          transform.project(Offset(end.x, end.y)),
          line,
        );
      }
      for (final landmark in pose.landmarks.values) {
        if (!landmark.isReliable()) continue;
        canvas.drawCircle(
          transform.project(Offset(landmark.x, landmark.y)),
          3.5,
          point,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MotionSkeletonPainter oldDelegate) {
    return oldDelegate.observation != observation;
  }
}
