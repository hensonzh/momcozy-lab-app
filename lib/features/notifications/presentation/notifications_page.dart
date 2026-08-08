import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_controller.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.repository,
    required this.onBack,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final NotificationsRepository repository;
  final VoidCallback onBack;
  final DateTime Function() now;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsController _controller = NotificationsController(
    repository: widget.repository,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MomCozyV3Colors.background,
      child: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 112),
                children: [
                  _NotificationsHeader(
                    unreadCount: state.unreadCount,
                    loading: state.phase == NotificationsPhase.loading,
                    onBack: widget.onBack,
                    onRefresh: () => unawaited(_controller.load()),
                  ),
                  const SizedBox(height: 20),
                  if (state.error != null) ...[
                    _NotificationsErrorBanner(
                      onRetry: () => unawaited(_controller.load()),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (state.phase == NotificationsPhase.loading &&
                      state.notifications.isEmpty)
                    const _NotificationsLoadingState()
                  else if (state.notifications.isEmpty)
                    const _NotificationsEmptyState()
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
                          _controller.markRead(state.notifications[index].id),
                        ),
                        onArchive: () => unawaited(
                          _controller.archive(state.notifications[index].id),
                        ),
                      ),
                      if (index < state.notifications.length - 1)
                        const SizedBox(height: 12),
                    ],
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
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MomCozyV3Colors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('notifications-refresh'),
              tooltip: 'Refresh notifications',
              onPressed: loading ? null : onRefresh,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 20,
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
    return Material(
      color: unread ? MomCozyV3Colors.roseTint : MomCozyV3Colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('notification-item-${notification.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: busy ? null : onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: unread
                  ? MomCozyColors.primary.withValues(alpha: 0.24)
                  : MomCozyColors.border,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _notificationIcon(notification.type),
                      color: MomCozyColors.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: Text(
                              notification.title.isEmpty
                                  ? 'Momcozy update'
                                  : notification.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: MomCozyV3Colors.ink,
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          notification.body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                height: 1.35,
                              ),
                        ),
                      ],
                      if (timestamp.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          timestamp,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: MomCozyColors.mutedForeground),
                        ),
                      ],
                    ],
                  ),
                ),
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        key: ValueKey(
                          'notification-archive-${notification.id}',
                        ),
                        tooltip: 'Archive notification',
                        onPressed: onArchive,
                        icon: const Icon(Icons.archive_outlined, size: 21),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsLoadingState extends StatelessWidget {
  const _NotificationsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 72),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 46,
            color: MomCozyColors.mutedForeground,
          ),
          const SizedBox(height: 14),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: MomCozyV3Colors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirmed reminders and updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MomCozyColors.mutedForeground),
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
    return Material(
      color: MomCozyV3Colors.roseTint,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        leading: const Icon(
          Icons.cloud_off_outlined,
          color: MomCozyColors.primary,
        ),
        title: const Text('Couldn’t refresh notifications'),
        subtitle: const Text('Previously loaded updates remain visible.'),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
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
