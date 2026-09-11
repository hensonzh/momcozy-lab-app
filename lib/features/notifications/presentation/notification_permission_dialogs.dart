import 'package:flutter/material.dart';

Future<bool> explainNotifications(BuildContext context) => _dialog(
  context,
  'Receive reminders?',
  'Momcozy can remind you before appointments and let you know when service updates are ready. You can change this in system settings at any time.',
  'Continue',
);
Future<bool> offerNotificationSettings(BuildContext context) => _dialog(
  context,
  'Notifications are off',
  'Enable notifications in system settings to receive background reminders. Your appointment is still saved.',
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
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;
