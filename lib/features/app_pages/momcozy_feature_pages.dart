import '../notifications/presentation/notification_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/momcozy_api_runtime.dart';
import '../../features/media/presentation/media_viewer_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../modules/schedule/presentation/schedule_page.dart';
import '../../modules/profile/presentation/more_page.dart';
import '../../shared/design_system/momcozy_design_system.dart';

/// Compatibility-free page dispatcher for the current user product routes.
/// Domain pages live in their module; this class only adapts route state.
class MomCozyFeaturePage extends StatelessWidget {
  const MomCozyFeaturePage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
    this.routeUri,
    this.routeExtra,
    this.onLogout,
    this.onDeleteAccount,
    this.onBabySelected,
    this.extendedProductResourcesEnabled = false,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;
  final Uri? routeUri;
  final Object? routeExtra;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onDeleteAccount;
  final Future<void> Function(String babyId)? onBabySelected;
  final bool extendedProductResourcesEnabled;

  @override
  Widget build(BuildContext context) {
    switch (path) {
      case '/schedule':
        final runtime = MomCozyRuntimeScope.of(context);
        return SchedulePage(
          key: ValueKey('schedule-page-${runtime.currentSession.userId}'),
          repository: runtime.scheduleRepository,
          timezoneProvider: runtime.timezoneProvider,
          now: runtime.now,
        );
      case '/more':
        return MorePage(onLogout: onLogout, onDeleteAccount: onDeleteAccount);
      case '/media-viewer':
        return MediaViewerPage(
          path: path,
          title: title,
          summary: summary,
          icon: icon,
          accent: accent,
          routeUri: routeUri,
          routeExtra: routeExtra,
        );
      case '/notifications':
        final coordinator = NotificationScope.maybeOf(context);
        final runtime = MomCozyRuntimeScope.of(context);
        return NotificationsPage(
          key: ValueKey(
            'notifications-${runtime.currentSession.userId}-${identityHashCode(coordinator?.inbox)}',
          ),
          controller: coordinator?.inbox,
          onOpen: coordinator?.openInboxNotification,
          onSettings: () => context.push('/notifications/settings'),
          repository: runtime.notificationsRepository,
          now: runtime.now,
          onBack: () {
            final from = routeUri?.queryParameters['from'];
            context.go(from == '/me' ? '/me' : '/more');
          },
        );
      default:
        return _UnsupportedRoutePage(path: path, title: title);
    }
  }
}

class _UnsupportedRoutePage extends StatelessWidget {
  const _UnsupportedRoutePage({required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: MomCozyColors.mutedForeground,
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'This entry is no longer available in this version.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Momcozy AI'),
            ),
          ],
        ),
      ),
    );
  }
}
