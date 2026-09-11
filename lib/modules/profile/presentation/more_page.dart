import '../../../features/notifications/presentation/notification_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/momcozy_api_runtime.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';

/// The fifth tab is an account and service surface.  Health records belong in
/// Me, Baby, or the service episode; More must not become another clinical
/// profile store.
class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final runtime = MomCozyRuntimeScope.of(context);
    final session = runtime.currentSession;
    return ColoredBox(
      key: const ValueKey('route-page-/more'),
      color: MomCozyColors.background,
      child: ListView(
        padding: MomCozyInsets.page,
        children: [
          const MomCozyPageHeader(title: 'More'),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Account settings',
            detail: 'Sign-in methods and account deletion',
            onTap: () => context.push('/account'),
          ),
          _AccountCard(userId: session.userId, locale: session.locale),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.notifications_none_rounded,
            title: '通知',
            detail:
                (NotificationScope.maybeOf(context)?.inbox?.state.unreadCount ??
                        0) >
                    0
                ? '${NotificationScope.maybeOf(context)!.inbox!.state.unreadCount} unread'
                : '查看预约、任务和服务提醒',
            onTap: () => context.push('/notifications?from=/more'),
          ),
          _ActionCard(
            icon: Icons.support_agent_rounded,
            title: '专家支持',
            detail: '浏览 IBCLC 服务包和当前服务',
            onTap: () => context.push('/services'),
          ),
          _ActionCard(
            icon: Icons.lock_outline_rounded,
            title: '隐私与授权',
            detail: '管理记录、AI 和视频咨询的使用范围',
            onTap: () => _showPrivacy(context),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            key: const ValueKey('more-logout'),
            onPressed: onLogout == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await onLogout!();
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sign-out could not finish. Reconnect and try again.',
                          ),
                        ),
                      );
                    }
                    if (context.mounted) context.go('/login');
                  },
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('隐私与授权'),
        content: const Text(
          '你主动填写的妈妈、宝宝和服务记录只会在对应的账号与服务范围内使用。进入视频咨询和让 Cozymate 使用记录前，App 会分别请求授权。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.userId, required this.locale});

  final String userId;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final initial = userId.trim().isEmpty
        ? '?'
        : userId.trim()[0].toUpperCase();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: MomCozyInsets.card,
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: MomCozyColors.violetSoft,
              child: Text(
                initial,
                style: const TextStyle(
                  color: MomCozyColors.violet,
                  fontWeight: FontWeight.w800,
                  fontSize: MomCozyTypography.headingSize,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('账号', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    userId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '语言：$locale',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: MomCozyColors.violet),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
