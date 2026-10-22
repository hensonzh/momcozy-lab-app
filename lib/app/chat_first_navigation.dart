import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const chatFirstNotFoundTitle = '页面不存在';
const chatFirstNotFoundSummary = '页面可能已移动，或链接已失效。';
const chatFirstBackToConversation = '返回对话';

/// Only three destinations are primary; account and schedule stay accessible
/// through section controls and their existing deep links.
class ChatFirstDrawer extends StatelessWidget {
  const ChatFirstDrawer({super.key});

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: const Color(0xFFFFFDFA),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Momcozy AI',
                    style: TextStyle(
                      color: Color(0xFF382F33),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭侧边栏',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _destination(
                  context,
                  'drawer-mother',
                  '妈妈',
                  Icons.favorite_border_rounded,
                  '/me',
                ),
                _destination(
                  context,
                  'drawer-baby',
                  '宝宝',
                  Icons.child_care_outlined,
                  '/baby',
                ),
                _destination(
                  context,
                  'drawer-devices',
                  '设备',
                  Icons.devices_other_outlined,
                  '/devices',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _destination(
    BuildContext context,
    String id,
    String title,
    IconData icon,
    String path,
  ) => ListTile(
    key: ValueKey(id),
    leading: Icon(icon, size: 21),
    title: Text(title),
    minTileHeight: 56,
    onTap: () {
      Navigator.of(context).pop();
      context.go(path);
    },
  );
}

class ChatFirstSectionHeader extends StatelessWidget {
  const ChatFirstSectionHeader({
    super.key,
    required this.location,
    this.backPath = '/',
  });

  final String location;
  final String backPath;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('section-back-chat'),
          tooltip: backPath == '/' ? '返回对话' : '返回宝宝概览',
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        Text(switch (location) {
          '/baby' => '宝宝',
          '/me' => '妈妈',
          '/devices' => '设备',
          '/schedule' => '日程',
          '/more' => '更多',
          _ => '',
        }, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const Spacer(),
        PopupMenuButton<String>(
          key: const ValueKey('section-more-services'),
          tooltip: '更多服务',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (path) => context.go(path),
          itemBuilder: (context) => const [
            PopupMenuItem(value: '/schedule', child: Text('日程')),
            PopupMenuItem(value: '/more', child: Text('账号与设置')),
            PopupMenuItem(value: '/notifications', child: Text('通知')),
          ],
        ),
      ],
    ),
  );
}
