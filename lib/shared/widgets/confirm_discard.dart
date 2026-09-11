import 'package:flutter/material.dart';

Future<bool> confirmDiscard(
  BuildContext context, {
  bool uncertainSave = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('离开这次记录？'),
        content: Text(
          uncertainSave ? '保存结果还未确认。返回后请先刷新记录，避免重复填写。' : '还未保存的修改会被放弃。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续填写'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('离开'),
          ),
        ],
      ),
    ) ??
    false;
