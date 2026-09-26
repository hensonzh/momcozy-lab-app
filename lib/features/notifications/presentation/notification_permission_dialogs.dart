import 'package:flutter/material.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';

Future<bool> explainNotifications(BuildContext context) => _dialog(
  context,
  'Receive reminders?',
  'Momcozy can let you know when your conversation has an update. You can change this in system settings at any time.',
  'Continue',
);
Future<bool> offerNotificationSettings(BuildContext context) => _dialog(
  context,
  'Notifications are off',
  'Enable notifications in system settings to receive conversation updates.',
  'Open settings',
);
Future<bool> _dialog(
  BuildContext context,
  String title,
  String message,
  String confirm,
) async =>
    await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => MomSettingsDialog(
        title: title,
        content: Text(message),
        cancelLabel: 'Not now',
        onCancel: () => Navigator.pop(context, false),
        primaryAction: FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm, textAlign: TextAlign.center),
        ),
      ),
    ) ??
    false;
