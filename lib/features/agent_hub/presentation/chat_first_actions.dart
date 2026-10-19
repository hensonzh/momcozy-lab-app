import 'package:flutter/material.dart';

import 'chat_first_demo_icon.dart';

const chatFirstRecordUnavailableMessage = '记录暂不可用，请稍后重试。';

enum ChatFirstRecordKind {
  nursing('亲喂', Icons.favorite_border_rounded),
  formula('配方奶', Icons.local_drink_outlined),
  expressed('瓶喂母乳', Icons.local_drink_outlined),
  diaper('换尿布', Icons.child_care_outlined),
  pumping('吸奶', Icons.water_drop_outlined),
  sleep('睡眠', Icons.bedtime_outlined),
  growth('生长', Icons.trending_up_rounded);

  const ChatFirstRecordKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ChatFirstQuickActions extends StatelessWidget {
  const ChatFirstQuickActions({
    super.key,
    required this.onRecord,
    required this.onCry,
    required this.onPoop,
  });

  final VoidCallback onRecord;
  final VoidCallback onCry;
  final VoidCallback onPoop;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _action('chat-first-action-record', '记录', 'baby', onRecord, false),
        _action('chat-first-action-cry', '听哭闹', 'sound-wave', onCry, false),
        _action('chat-first-action-poop', '看便便', 'diaper', onPoop, false),
      ],
    ),
  );

  Widget _action(
    String key,
    String label,
    String icon,
    VoidCallback onPressed,
    bool selected,
  ) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: OutlinedButton.icon(
      key: ValueKey(key),
      onPressed: onPressed,
      icon: ChatFirstDemoIcon(icon, size: 16, color: const Color(0xFF975771)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFFF6E9EC)
            : const Color(0xFFFFFDFA),
        foregroundColor: selected
            ? const Color(0xFF844B62)
            : const Color(0xFF655758),
        side: BorderSide(
          color: selected ? const Color(0xFFE9CED9) : const Color(0xFFEEE5E1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

class ChatFirstRecordPicker extends StatelessWidget {
  const ChatFirstRecordPicker({
    super.key,
    required this.onClose,
    required this.onSelected,
  });

  final VoidCallback onClose;
  final ValueChanged<ChatFirstRecordKind> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('chat-first-record-picker'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 18),
            child: Text(
              '选择记录类型',
              style: TextStyle(
                color: Color(0xFF382F33),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey('chat-first-record-close'),
            tooltip: '关闭记录类型',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      SizedBox(
        height: 91,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final kind in ChatFirstRecordKind.values)
              SizedBox(
                width: 82,
                child: TextButton(
                  key: ValueKey('record-type-${kind.name}'),
                  onPressed: () => onSelected(kind),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(kind.icon, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        kind.label,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
