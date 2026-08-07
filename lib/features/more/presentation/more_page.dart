import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.path, this.onLogout});

  final String path;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MomCozyV3Colors.background,
      child: ListView(
        key: ValueKey('route-page-$path'),
        padding: const EdgeInsets.fromLTRB(
          MomCozySpacing.page,
          MomCozySpacing.page,
          MomCozySpacing.page,
          112,
        ),
        children: [
          Text(
            'More',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: MomCozyV3Colors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '管理设备、服务与账户偏好',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MomCozyColors.mutedForeground,
            ),
          ),
          const SizedBox(height: MomCozySpacing.section),
          _MoreSection(
            title: '设备与服务',
            children: [
              _MoreTile(
                tileKey: const ValueKey('more-device'),
                icon: Icons.bluetooth_connected_rounded,
                title: '设备管理',
                subtitle: '连接设备并查看当前状态',
                onTap: () => context.go('/device'),
              ),
              _MoreTile(
                tileKey: const ValueKey('more-reminders'),
                icon: Icons.notifications_active_outlined,
                title: '设备提醒',
                subtitle: '管理任务提醒和奶量分析入口',
                onTap: () => context.go('/device/manage'),
              ),
              _MoreTile(
                tileKey: const ValueKey('more-community'),
                icon: Icons.groups_2_outlined,
                title: '社区',
                subtitle: '内容、经验与妈妈支持网络',
                onTap: () => context.go('/community'),
              ),
            ],
          ),
          const SizedBox(height: MomCozySpacing.section),
          _MoreSection(
            title: '账户与偏好',
            children: [
              const _MoreTile(
                tileKey: ValueKey('more-language'),
                icon: Icons.language_rounded,
                title: '语言与地区',
                subtitle: '当前跟随系统设置',
              ),
              const _MoreTile(
                tileKey: ValueKey('more-privacy'),
                icon: Icons.privacy_tip_outlined,
                title: '隐私与数据',
                subtitle: '健康与宝宝数据受隐私规则保护',
              ),
              if (onLogout != null)
                _MoreTile(
                  tileKey: const ValueKey('more-logout'),
                  icon: Icons.logout_rounded,
                  title: '退出登录',
                  subtitle: '清除本机登录状态',
                  isDestructive: true,
                  onTap: () => unawaited(onLogout!()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: MomCozyV3Colors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Material(
          color: MomCozyV3Colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: MomCozyColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foreground = isDestructive
        ? MomCozyV3Colors.danger
        : MomCozyV3Colors.ink;
    return ListTile(
      key: tileKey,
      minTileHeight: 68,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox.square(
        dimension: MomCozyTapTargets.minimum,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDestructive
                ? MomCozyV3Colors.danger.withValues(alpha: 0.08)
                : MomCozyV3Colors.roseTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: foreground),
      onTap: onTap,
    );
  }
}
