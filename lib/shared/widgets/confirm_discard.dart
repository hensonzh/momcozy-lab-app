import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';

Future<bool> confirmDiscard(
  BuildContext context, {
  bool uncertainSave = false,
  String confirmLabel = 'Leave',
  ThemeData? theme,
}) async =>
    await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) {
        final dialog = AlertDialog(
          scrollable: true,
          title: const Text('Leave this record?'),
          content: Text(
            uncertainSave
                ? 'Your save has not been confirmed. Refresh your records before trying again to avoid duplicates.'
                : 'Your unsaved changes will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
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
