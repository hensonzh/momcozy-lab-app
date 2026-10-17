import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:uuid/uuid.dart';

import 'data/chat_first_mother_repository.dart';

Future<MeObservation?> showChatFirstStatusSheet(
  BuildContext context, {
  required ChatFirstMotherRepository repository,
  required DateTime Function() now,
  required bool Function() isCurrentOwner,
}) => showModalBottomSheet<MeObservation>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => _ChatFirstStatusSheet(
    repository: repository,
    now: now,
    isCurrentOwner: isCurrentOwner,
  ),
);

class _ChatFirstStatusSheet extends StatefulWidget {
  const _ChatFirstStatusSheet({
    required this.repository,
    required this.now,
    required this.isCurrentOwner,
  });

  final ChatFirstMotherRepository repository;
  final DateTime Function() now;
  final bool Function() isCurrentOwner;

  @override
  State<_ChatFirstStatusSheet> createState() => _ChatFirstStatusSheetState();
}

class _ChatFirstStatusSheetState extends State<_ChatFirstStatusSheet> {
  final String _recordId = const Uuid().v4();
  DateTime? _occurredAt;
  MeMetric? _kind;
  String? _value;
  bool _busy = false;
  bool _attempted = false;
  bool _failed = false;
  bool _accountChanged = false;

  Future<void> _save() async {
    final kind = _kind;
    final value = _value;
    if (_busy || kind == null || value == null) return;
    if (!widget.isCurrentOwner()) {
      setState(() {
        _accountChanged = true;
        _attempted = true;
      });
      return;
    }
    _occurredAt ??= widget.now();
    setState(() {
      _busy = true;
      _attempted = true;
      _failed = false;
    });
    try {
      final saved = await widget.repository.saveWellbeing(
        id: _recordId,
        kind: kind,
        value: value,
        occurredAt: _occurredAt!,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      // A timed-out PUT may still have committed. Retrying uses the exact
      // same ID, timestamp and answer; never claim success from an exception.
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: FractionallySizedBox(
      heightFactor: 0.76,
      child: Padding(
        key: const ValueKey('mother-status-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '记录身体与状态',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const ValueKey('mother-status-close'),
                  tooltip: '关闭状态记录',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    '保存到当前账号后才会出现在最近状态中。这里只记录你的自述，不作健康判断。',
                    style: TextStyle(color: Color(0xFF786E6B)),
                  ),
                  const SizedBox(height: 20),
                  const Text('今天想记录哪一项？'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in chatFirstWellbeingChoices.keys)
                        ChoiceChip(
                          key: ValueKey('mother-status-kind-${kind.name}'),
                          label: Text(switch (kind) {
                            MeMetric.energy => '精力',
                            MeMetric.sleep => '睡眠',
                            MeMetric.mood => '心情',
                            _ => '',
                          }),
                          selected: _kind == kind,
                          onSelected: _attempted
                              ? null
                              : (_) => setState(() {
                                  _kind = kind;
                                  _value = null;
                                }),
                        ),
                    ],
                  ),
                  if (_kind case final selected?) ...[
                    const SizedBox(height: 18),
                    const Text('请选择最符合你现在情况的描述'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option
                            in chatFirstWellbeingChoices[selected]!)
                          ChoiceChip(
                            key: ValueKey('mother-status-value-$option'),
                            label: Text(option),
                            selected: _value == option,
                            onSelected: _attempted
                                ? null
                                : (_) => setState(() => _value = option),
                          ),
                      ],
                    ),
                  ],
                  if (_failed) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '尚未确认保存。可用同一记录重试；若退出，请先回看最近状态，避免重复添加。',
                      style: TextStyle(color: Color(0xFFB24054)),
                    ),
                  ],
                  if (_accountChanged) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '账号已切换，请关闭后从当前账号重新打开。当前选择未保存。',
                      style: TextStyle(color: Color(0xFFB24054)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('mother-status-save'),
                onPressed: _busy || _accountChanged || _value == null
                    ? null
                    : _save,
                child: Text(
                  _busy
                      ? '保存中…'
                      : _attempted
                      ? '重试保存'
                      : '保存状态',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
