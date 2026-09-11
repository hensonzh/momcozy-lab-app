import '../../shared/widgets/momcozy_wordmark.dart';
import 'package:flutter/material.dart';
import '../../domain/ibclc/workbench.dart';
import '../../shared/design_system/momcozy_design_system.dart';
import '../../shared/zoned_time.dart';

final class WorkbenchDestination {
  const WorkbenchDestination(this.path, this.label, this.icon);
  final String path, label;
  final IconData icon;
}

class WorkbenchShell extends StatelessWidget {
  const WorkbenchShell({
    super.key,
    required this.identity,
    required this.destinations,
    required this.location,
    required this.onNavigate,
    required this.onLogout,
    required this.child,
  });
  final WorkbenchIdentity identity;
  final List<WorkbenchDestination> destinations;
  final String location;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final Widget child;

  String get _breadcrumb {
    if (location.endsWith('/intake')) return '今日预约 / 咨询前资料';
    if (location.startsWith('/ibclc/clients/')) return '我的客户 / 客户资料';
    if (location.startsWith('/ibclc/followups/')) return '今日跟进 / 专业复核';
    return destinations
            .where((value) => location.startsWith(value.path))
            .firstOrNull
            ?.label ??
        '工作台';
  }

  Future<void> _account(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('工作账号'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              identity.provider.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectionArea(child: Text(identity.email)),
            const SizedBox(height: 18),
            Text('工作时区：${identity.provider.timezone}'),
            const SizedBox(height: 8),
            Text('服务地区：${identity.provider.regions.join('、')}'),
            const SizedBox(height: 8),
            Text('服务语言：${identity.provider.languages.join('、')}'),
            const SizedBox(height: 18),
            Text(
              '两步验证有效至 ${dateInTimezone(identity.mfaExpiresAt, identity.provider.timezone)} ${zonedClock(identity.mfaExpiresAt, identity.provider.timezone)}',
              style: const TextStyle(
                fontSize: 12,
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onLogout();
          },
          child: const Text('退出登录'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  Widget _sidebar(BuildContext context, {bool drawer = false}) => SafeArea(
    child: Material(
      color: MomCozyColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MomCozyWordmark(),
                  const SizedBox(height: 8),
                  const Text(
                    'IBCLC 工作台',
                    style: TextStyle(
                      fontSize: 11,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final destination in destinations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        selected: location.startsWith(destination.path),
                        selectedTileColor: MomCozyColors.roseSoft,
                        selectedColor: MomCozyColors.primary,
                        leading: Icon(destination.icon, size: 19),
                        minLeadingWidth: 20,
                        horizontalTitleGap: 10,
                        title: Text(
                          destination.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          if (drawer) Navigator.pop(context);
                          onNavigate(destination.path);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _account(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: MomCozyColors.roseSoft,
                      foregroundColor: MomCozyColors.primary,
                      child: Text(
                        identity.provider.displayName.characters.firstOrNull ??
                            'I',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            identity.provider.displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            identity.provider.timezone,
                            style: const TextStyle(
                              fontSize: 10,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          constraints.maxWidth >= 900 &&
          MediaQuery.textScalerOf(context).scale(14) <= 22;
      return Scaffold(
        drawer: desktop
            ? null
            : Drawer(width: 264, child: _sidebar(context, drawer: true)),
        // Paint persistent controls after the nested Navigator so its route
        // does not remove the sidebar/header from the accessibility tree.
        body: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                verticalDirection: VerticalDirection.up,
                children: [
                  Expanded(child: child),
                  Container(
                    decoration: const BoxDecoration(
                      color: MomCozyColors.card,
                      border: Border(
                        bottom: BorderSide(color: MomCozyColors.border),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: desktop ? 30 : 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (!desktop)
                              Builder(
                                builder: (context) => IconButton(
                                  tooltip: '打开工作台导航',
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const Icon(Icons.menu_rounded),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                desktop
                                    ? 'IBCLC 工作台  /  $_breadcrumb'
                                    : _breadcrumb,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MomCozyColors.mutedForeground,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '工作账号',
                              onPressed: () => _account(context),
                              icon: const Icon(
                                Icons.account_circle_outlined,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (desktop) ...[
              const VerticalDivider(width: 1),
              SizedBox(width: 216, child: _sidebar(context)),
            ],
          ],
        ),
      );
    },
  );
}
