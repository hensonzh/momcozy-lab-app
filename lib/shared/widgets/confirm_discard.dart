import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';

Future<bool> confirmDiscard(
  BuildContext context, {
  bool uncertainSave = false,
  String confirmLabel = '离开',
  ThemeData? theme,
}) async =>
    await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) {
        final dialog = AlertDialog(
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
              child: Text(confirmLabel),
            ),
          ],
        );
        return theme == null ? dialog : Theme(data: theme, child: dialog);
      },
    ) ??
    false;
