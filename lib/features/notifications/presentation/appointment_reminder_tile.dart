import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/notification_delivery_repository.dart';
import 'notification_coordinator.dart';
import 'notification_scope.dart';
import 'notification_permission_dialogs.dart';

class AppointmentReminderTile extends StatefulWidget {
  const AppointmentReminderTile({super.key, required this.appointmentId});
  final String appointmentId;
  @override
  State<AppointmentReminderTile> createState() =>
      _AppointmentReminderTileState();
}

class _AppointmentReminderTileState extends State<AppointmentReminderTile> {
  NotificationCoordinator? _coordinator;
  AppointmentReminder? _reminder;
  bool _busy = true;
  bool _failed = false;
  int _request = 0;
  int _syncVersion = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = NotificationScope.maybeOf(context);
    if (!identical(coordinator, _coordinator) ||
        coordinator?.permissionSyncVersion != _syncVersion) {
      _coordinator = coordinator;
      _syncVersion = coordinator?.permissionSyncVersion ?? -1;
      unawaited(_load());
    } else if (coordinator == null && _busy) {
      _busy = false;
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final result = await _coordinator?.reminder(widget.appointmentId);
      if (mounted && request == _request) {
        setState(() {
          _reminder = result;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _set(bool value) async {
    setState(() => _busy = true);
    await _coordinator?.setReminder(
      widget.appointmentId,
      enabled: value,
      explain: () => explainNotifications(context),
      offerSettings: () => offerNotificationSettings(context),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _coordinator?.pushReady == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Appointment reminder'),
          subtitle: Text(
            _failed
                ? 'Could not load reminder status'
                : _reminder?.enabled == true && ready
                ? '15 minutes before your appointment'
                : 'Off on this device. Your appointment is saved.',
          ),
          value: _reminder?.enabled == true && ready,
          onChanged: _busy || _coordinator == null ? null : _set,
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_failed) TextButton(onPressed: _load, child: const Text('Retry')),
        TextButton(
          onPressed: () => context.push('/notifications/settings'),
          child: const Text('Notification settings'),
        ),
      ],
    );
  }
}
