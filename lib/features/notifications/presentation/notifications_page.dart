import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/momcozy_text_roles.dart';
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final state = _controller.state;
      final initialLoading =
          state.phase == NotificationsPhase.loading &&
          state.notifications.isEmpty;
      final count = initialLoading
          ? 'Loading updates'
          : state.error != null && state.notifications.isEmpty
          ? 'Your updates'
          : state.unreadCount == 0
          ? 'All caught up'
          : '${state.unreadCount} unread';
      final readAll = TextButton(
        onPressed: state.unreadCount == 0 || state.busyIds.isNotEmpty
            ? null
            : () => unawaited(_controller.markAllRead()),
        child: const Text('Mark all read'),
      );
      return Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 136
                : 56,
            title: const Text('Notifications', maxLines: 2),
            leading: IconButton(
              key: const ValueKey('notifications-back'),
              tooltip: 'Back',
              onPressed: widget.onBack,
              icon: SvgPicture.asset(
                'assets/images/me_baby_overview/icons/back-button.svg',
                width: 36,
                height: 32,
              ),
            ),
          ),
          body: ClipRect(
            child: MomCozyPageBody(
              child: RefreshIndicator(
                color: MomHomeTokens.rose,
                onRefresh: _controller.load,
                child: ListView(
                  key: const ValueKey('route-page-/notifications'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Stay close to every update.',
                            style: MomHomeTokens.text(
                              12,
                              color: MomHomeTokens.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: MomHomeTokens.gap),
                        IconButton(
                          key: const ValueKey('notifications-refresh'),
                          tooltip: 'Refresh notifications',
                          onPressed: state.phase == NotificationsPhase.loading
                              ? null
                              : () => unawaited(_controller.load()),
                          color: MomHomeTokens.secondary,
                          icon: state.phase == NotificationsPhase.loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                        if (widget.onSettings != null) ...[
                          const SizedBox(width: MomHomeTokens.gap),
                          IconButton(
                            tooltip: 'Notification settings',
                            onPressed: widget.onSettings,
                            color: MomHomeTokens.secondary,
                            icon: const Icon(Icons.settings_outlined),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: MomHomeTokens.gap),
                    MomSettingsCard(
                      gradient: MomHomeTokens.milk,
                      border: false,
                      children: [
                        MediaQuery.textScalerOf(context).scale(1) > 1.3
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: MomHomeTokens.gap,
                                children: [
                                  Text(
                                    count,
                                    style: MomHomeTokens.text(
                                      18,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  readAll,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      count,
                                      style: MomHomeTokens.text(
                                        18,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: MomHomeTokens.gap),
                                  readAll,
                                ],
                              ),
                      ],
                    ),
                    const SizedBox(height: MomHomeTokens.gap),
                    if (state.error != null) ...[
                      _NotificationsErrorBanner(
                        onRetry: () => unawaited(_controller.load()),
                        hasContent: state.notifications.isNotEmpty,
                      ),
                      const SizedBox(height: MomHomeTokens.gap),
                    ],
                    if (initialLoading)
                      MomSettingsCard(
                        children: [
                          Text(
                            'Loading notifications…',
                            style: MomHomeTokens.text(
                              18,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Your updates will appear here.',
                            style: MomHomeTokens.text(
                              13,
                              color: MomHomeTokens.secondary,
                            ),
                          ),
                          const LinearProgressIndicator(
                            semanticsLabel: 'Loading notifications',
                          ),
                        ],
                      )
                    else if (state.notifications.isEmpty && state.error == null)
                      MomSettingsCard(
                        children: [
                          Text(
                            'No notifications yet',
                            style: MomHomeTokens.text(
                              18,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Confirmed reminders and updates will appear here.',
                            style: MomHomeTokens.text(
                              13,
                              color: MomHomeTokens.secondary,
                              height: 1.55,
                            ),
                          ),
                        ],
                      )
                    else
                      for (final notification in state.notifications) ...[
                        _NotificationCard(
                          notification: notification,
                          timestamp: _notificationTimestamp(
                            context,
                            notification.createdAt,
                            widget.now(),
                          ),
                          busy: state.busyIds.contains(notification.id),
                          onOpen: () => unawaited(
                            widget.onOpen?.call(notification.id) ??
                                _controller.markRead(notification.id),
                          ),
                          onArchive: () =>
                              unawaited(_controller.archive(notification.id)),
                        ),
                        const SizedBox(height: MomHomeTokens.gap),
                      ],
                    if (state.nextCursor != null)
                      OutlinedButton(
                        onPressed: state.loadingMore
                            ? null
                            : () => unawaited(_controller.loadMore()),
                        child: Text(
                          state.loadingMore ? 'Loading…' : 'Load more',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
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
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MomHomeTokens.milk.colors.first,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _notificationIcon(notification.type),
              color: MomHomeTokens.secondary,
              size: 20,
            ),
          ),
        ),
        if (unread) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MomHomeTokens.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'New',
              style: MomHomeTokens.text(
                11,
                weight: FontWeight.w700,
                color: MomHomeTokens.teal,
              ),
            ),
          ),
        ],
      ],
    );
    final time = Text(
      timestamp,
      style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
    );
    return MomHomeSurface(
      key: ValueKey('notification-item-${notification.id}'),
      gradient: const LinearGradient(
        colors: [MomHomeTokens.surface, MomHomeTokens.surface],
      ),
      border: MomHomeTokens.border,
      onTap: busy ? null : onOpen,
      child: Padding(
        padding: const EdgeInsets.all(MomHomeTokens.inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MomHomeTokens.gap,
          children: [
            MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [identity, if (timestamp.isNotEmpty) time],
                  )
                : Row(
                    children: [
                      identity,
                      const SizedBox(width: 8),
                      if (timestamp.isNotEmpty)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: time,
                          ),
                        ),
                    ],
                  ),
            Text(
              notification.displayTitle,
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            if (notification.displayBody.isNotEmpty)
              Text(
                notification.displayBody,
                style: MomHomeTokens.text(
                  13,
                  color: MomHomeTokens.secondary,
                  height: 1.55,
                ).merge(MomCozyTextRoles.paragraphOf(context)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: busy
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Updating notification',
                          ),
                        ),
                      ),
                    )
                  : Tooltip(
                      message: 'Archive notification',
                      child: TextButton.icon(
                        key: ValueKey(
                          'notification-archive-${notification.id}',
                        ),
                        onPressed: onArchive,
                        style: TextButton.styleFrom(
                          foregroundColor: MomHomeTokens.secondary,
                        ),
                        icon: const Icon(Icons.archive_outlined, size: 16),
                        label: const Text('Archive'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsErrorBanner extends StatelessWidget {
  const _NotificationsErrorBanner({
    required this.onRetry,
    required this.hasContent,
  });
  final bool hasContent;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      gradient: MomHomeTokens.body,
      children: [
        Text(
          'Couldn\'t refresh notifications',
          style: MomHomeTokens.text(18, weight: FontWeight.w700),
        ),
        Text(
          hasContent
              ? 'Previously loaded updates remain visible.'
              : 'Please try again to load your updates.',
          style: MomHomeTokens.text(
            13,
            color: MomHomeTokens.secondary,
            height: 1.55,
          ),
        ),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
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
