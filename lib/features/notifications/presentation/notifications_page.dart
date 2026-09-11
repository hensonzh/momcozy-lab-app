import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/product_feedback.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_controller.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.repository,
    required this.onBack,
    this.controller,
    this.onOpen,
    this.onSettings,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final NotificationsRepository repository;
  final NotificationsController? controller;
  final Future<void> Function(String)? onOpen;
  final VoidCallback? onSettings;
  final VoidCallback onBack;
  final DateTime Function() now;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsController _controller =
      widget.controller ??
      NotificationsController(repository: widget.repository);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomCozyColors.background,
      child: MomCozyPageBody(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final state = _controller.state;
            return RefreshIndicator(
              color: MomCozyColors.primary,
              onRefresh: _controller.load,
              child: ListView(
                key: const ValueKey('route-page-/notifications'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: MomCozyInsets.page,
                children: [
                  _NotificationsHeader(
                    unreadCount: state.unreadCount,
                    loading: state.phase == NotificationsPhase.loading,
                    onBack: widget.onBack,
                    onRefresh: () => unawaited(_controller.load()),
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: MomCozySpacing.compact,
                    children: [
                      TextButton(
                        onPressed:
                            state.unreadCount == 0 || state.busyIds.isNotEmpty
                            ? null
                            : () => unawaited(_controller.markAllRead()),
                        child: const Text('Mark all read'),
                      ),
                      if (widget.onSettings != null)
                        IconButton(
                          tooltip: 'Notification settings',
                          onPressed: widget.onSettings,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: MomCozySpacing.card),
                  if (state.error != null) ...[
                    _NotificationsErrorBanner(
                      onRetry: () => unawaited(_controller.load()),
                    ),
                    const SizedBox(height: MomCozySpacing.headingGap),
                  ],
                  if (state.phase == NotificationsPhase.loading &&
                      state.notifications.isEmpty)
                    const ProductLoadingView()
                  else if (state.notifications.isEmpty)
                    const ProductEmptyView(
                      title: 'No notifications yet',
                      description:
                          'Confirmed reminders and updates will appear here.',
                      icon: Icons.notifications_none_rounded,
                    )
                  else
                    for (
                      var index = 0;
                      index < state.notifications.length;
                      index += 1
                    ) ...[
                      _NotificationCard(
                        notification: state.notifications[index],
                        timestamp: _notificationTimestamp(
                          context,
                          state.notifications[index].createdAt,
                          widget.now(),
                        ),
                        busy: state.busyIds.contains(
                          state.notifications[index].id,
                        ),
                        onOpen: () => unawaited(
                          widget.onOpen?.call(state.notifications[index].id) ??
                              _controller.markRead(
                                state.notifications[index].id,
                              ),
                        ),
                        onArchive: () => unawaited(
                          _controller.archive(state.notifications[index].id),
                        ),
                      ),
                      if (index < state.notifications.length - 1)
                        const SizedBox(height: MomCozySpacing.content),
                    ],
                  if (state.nextCursor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton(
                        onPressed: state.loadingMore
                            ? null
                            : () => unawaited(_controller.loadMore()),
                        child: Text(
                          state.loadingMore ? 'Loading…' : 'Load more',
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.loading,
    required this.onBack,
    required this.onRefresh,
  });

  final int unreadCount;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('notifications-back'),
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: MomCozySpacing.xs),
            Expanded(
              child: Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('notifications-refresh'),
              tooltip: 'Refresh notifications',
              onPressed: loading ? null : onRefresh,
              icon: loading
                  ? const SizedBox.square(
                      dimension: MomCozyIconSizes.medium,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 52, top: 2),
          child: Text(
            unreadCount == 0 ? 'All caught up' : '$unreadCount unread',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.timestamp,
    required this.busy,
    required this.onOpen,
    required this.onArchive,
  });

  final MomCozyNotification notification;
  final String timestamp;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    return MomCozySurface(
      key: ValueKey('notification-item-${notification.id}'),
      color: unread ? MomCozyColors.roseSoft : MomCozyColors.raised,
      padding: MomCozyInsets.compactCard,
      onTap: busy ? null : onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: MomCozyTapTargets.minimum,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MomCozyColors.raised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _notificationIcon(notification.type),
                color: MomCozyColors.primary,
                size: MomCozyIconSizes.standard,
              ),
            ),
          ),
          const SizedBox(width: MomCozySpacing.content),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (unread) ...[
                      const SizedBox.square(
                        dimension: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: MomCozyColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: MomCozySpacing.compact),
                    ],
                    Expanded(
                      child: Text(
                        notification.title.isEmpty
                            ? 'Momcozy update'
                            : notification.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: MomCozySpacing.xs),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      height: 1.35,
                    ),
                  ),
                ],
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: MomCozySpacing.compact),
                  Text(
                    timestamp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: MomCozyIconSizes.medium,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  key: ValueKey('notification-archive-${notification.id}'),
                  tooltip: 'Archive notification',
                  onPressed: onArchive,
                  icon: const Icon(
                    Icons.archive_outlined,
                    size: MomCozyIconSizes.medium,
                  ),
                ),
        ],
      ),
    );
  }
}

class _NotificationsErrorBanner extends StatelessWidget {
  const _NotificationsErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MomCozySurface(
      color: MomCozyColors.amberSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couldn’t refresh notifications',
            style: MomCozyTypography.title,
          ),
          const SizedBox(height: MomCozySpacing.compact),
          const Text('Previously loaded updates remain visible.'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

IconData _notificationIcon(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('feed')) return Icons.restaurant_rounded;
  if (normalized.contains('pump') || normalized.contains('milk')) {
    return Icons.water_drop_rounded;
  }
  if (normalized.contains('plan')) return Icons.event_note_rounded;
  return Icons.notifications_active_outlined;
}

String _notificationTimestamp(
  BuildContext context,
  DateTime? createdAt,
  DateTime now,
) {
  if (createdAt == null) return '';
  final localCreated = createdAt.toLocal();
  final localNow = now.toLocal();
  final createdDate = DateTime(
    localCreated.year,
    localCreated.month,
    localCreated.day,
  );
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final difference = today.difference(createdDate).inDays;
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(localCreated),
  );
  if (difference == 0) return 'Today · $time';
  if (difference == 1) return 'Yesterday · $time';
  return '${localizations.formatMediumDate(localCreated)} · $time';
}
