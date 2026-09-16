import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';

Widget _withSizeTransition(BuildContext context, Widget child) {
  // A zero-duration AnimatedSize can invalidate its own layout while resizing.
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return AnimatedSize(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    child: child,
  );
}

class AvatarTaskBanner extends StatefulWidget {
  const AvatarTaskBanner({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final AvatarTaskController controller;
  final VoidCallback onOpen;

  @override
  State<AvatarTaskBanner> createState() => _AvatarTaskBannerState();
}

class _AvatarTaskBannerState extends State<AvatarTaskBanner> {
  late AvatarTaskStatus _previousStatus = widget.controller.status;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant AvatarTaskBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_handleChanged);
    _previousStatus = widget.controller.status;
    widget.controller.addListener(_handleChanged);
  }

  void _handleChanged() {
    final next = widget.controller.status;
    if (_previousStatus != AvatarTaskStatus.reviewRequired &&
        next == AvatarTaskStatus.reviewRequired) {
      HapticFeedback.lightImpact();
    }
    _previousStatus = next;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.status;
    if (status == AvatarTaskStatus.hidden) return const SizedBox.shrink();

    final ready = status == AvatarTaskStatus.reviewRequired;
    final failed = status == AvatarTaskStatus.failed;
    final completed = status == AvatarTaskStatus.completed;
    final foreground = ready ? MomCozyColors.raised : MomCozyColors.foreground;
    final background = switch (status) {
      AvatarTaskStatus.reviewRequired => MomCozyColors.primaryDark,
      AvatarTaskStatus.failed => MomCozyColors.amberSoft,
      AvatarTaskStatus.completed => MomCozyColors.careSoft,
      AvatarTaskStatus.queued ||
      AvatarTaskStatus.generating => MomCozyColors.roseSoft,
      AvatarTaskStatus.hidden => Colors.transparent,
    };
    final title = switch (status) {
      AvatarTaskStatus.queued => 'Preparing your digital companion',
      AvatarTaskStatus.generating => 'Creating your digital companion',
      AvatarTaskStatus.reviewRequired => 'Your 4 companion options are ready',
      AvatarTaskStatus.failed => 'We couldn’t create your companion',
      AvatarTaskStatus.completed => 'Your digital companion is set',
      AvatarTaskStatus.hidden => '',
    };
    final subtitle = switch (status) {
      AvatarTaskStatus.queued =>
        'Waiting for a generation slot · You can keep using the app',
      AvatarTaskStatus.generating =>
        'Working on 4 options · You can keep using the app',
      AvatarTaskStatus.reviewRequired => 'Tap to choose your favorite',
      AvatarTaskStatus.failed => 'Tap to try another photo',
      AvatarTaskStatus.completed => 'Your choice is now active',
      AvatarTaskStatus.hidden => '',
    };
    final actionable = ready || failed;

    return Semantics(
      liveRegion: ready || failed || completed,
      button: actionable,
      label: '$title. $subtitle',
      child: ExcludeSemantics(
        child: _withSizeTransition(
          context,
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MomCozySpacing.pageGutter,
              MomCozySpacing.compact,
              MomCozySpacing.pageGutter,
              MomCozySpacing.xs,
            ),
            child: Material(
              key: const ValueKey('avatar-task-banner'),
              color: background,
              borderRadius: BorderRadius.circular(MomCozyRadii.card),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(MomCozyRadii.card),
                onTap: actionable ? widget.onOpen : null,
                child: Padding(
                  padding: MomCozyInsets.compactCard,
                  child: Row(
                    children: [
                      _TaskStatusIcon(status: status, foreground: foreground),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MomCozyMotion.duration(
                            context,
                            const Duration(milliseconds: 260),
                          ),
                          child: Column(
                            key: ValueKey(status),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: MomCozyTypography.bodySize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: ready
                                      ? MomCozyColors.raised.withValues(
                                          alpha: 0.86,
                                        )
                                      : MomCozyColors.mutedForeground,
                                  fontSize: MomCozyTypography.secondarySize,
                                  height: 1.25,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (actionable) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: ready
                              ? MomCozyColors.raised
                              : MomCozyColors.primaryDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskStatusIcon extends StatelessWidget {
  const _TaskStatusIcon({required this.status, required this.foreground});

  final AvatarTaskStatus status;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (status == AvatarTaskStatus.queued ||
        status == AvatarTaskStatus.generating) {
      return const SizedBox.square(
        dimension: MomCozyIconSizes.standard,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: MomCozyColors.primaryDark,
        ),
      );
    }
    return Icon(
      switch (status) {
        AvatarTaskStatus.reviewRequired => Icons.auto_awesome_rounded,
        AvatarTaskStatus.failed => Icons.refresh_rounded,
        AvatarTaskStatus.completed => Icons.check_circle_rounded,
        _ => Icons.hourglass_top_rounded,
      },
      color: status == AvatarTaskStatus.failed
          ? MomCozyColors.amber
          : status == AvatarTaskStatus.completed
          ? MomCozyColors.care
          : foreground,
      size: MomCozyIconSizes.standard,
    );
  }
}
