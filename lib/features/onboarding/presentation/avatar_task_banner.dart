import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';

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
    final foreground = ready ? Colors.white : MomCozyV3Colors.ink;
    final background = switch (status) {
      AvatarTaskStatus.reviewRequired => MomCozyV3Colors.brand,
      AvatarTaskStatus.failed => const Color(0xfffff2e4),
      AvatarTaskStatus.completed => const Color(0xffe8f5ea),
      AvatarTaskStatus.queued ||
      AvatarTaskStatus.generating => MomCozyV3Colors.roseTint,
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
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Material(
              key: const ValueKey('avatar-task-banner'),
              color: background,
              borderRadius: BorderRadius.circular(18),
              elevation: ready ? 5 : 0,
              shadowColor: MomCozyV3Colors.brand.withValues(alpha: 0.3),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: actionable ? widget.onOpen : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                  child: Row(
                    children: [
                      _TaskStatusIcon(status: status, foreground: foreground),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: Column(
                            key: ValueKey(status),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ready
                                      ? Colors.white.withValues(alpha: 0.86)
                                      : MomCozyV3Colors.mutedText,
                                  fontSize: 12.5,
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
                          color: ready ? Colors.white : MomCozyV3Colors.brand,
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
        dimension: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: MomCozyV3Colors.brand,
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
          ? MomCozyV3Colors.warning
          : status == AvatarTaskStatus.completed
          ? MomCozyV3Colors.success
          : foreground,
      size: 25,
    );
  }
}
