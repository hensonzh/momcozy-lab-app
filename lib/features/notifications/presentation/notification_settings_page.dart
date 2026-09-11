import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../domain/notification_permission.dart';
import 'notification_coordinator.dart';
import 'notification_permission_dialogs.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, required this.coordinator});
  final NotificationCoordinator? coordinator;
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  Map<String, bool>? _preferences;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.coordinator?.refresh();
      final preferences = await widget.coordinator?.preferences();
      if (mounted) {
        setState(() {
          _preferences = preferences;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load your preferences. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _set(String category, bool enabled) async {
    final coordinator = widget.coordinator;
    if (coordinator == null || _busy) return;
    setState(() => _busy = true);
    final changed = await coordinator.setPreference(
      category,
      enabled: enabled,
      explain: () => explainNotifications(context),
      offerSettings: () => offerNotificationSettings(context),
    );
    if (!mounted) return;
    if (changed) {
      await _load();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = widget.coordinator;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: MomCozyPageBody(
        child: coordinator == null
            ? const SingleChildScrollView(
                child: ProductEmptyView(
                  title:
                      'Background notifications are unavailable on this device.',
                  icon: Icons.notifications_off_outlined,
                ),
              )
            : AnimatedBuilder(
                animation: coordinator,
                builder: (context, _) {
                  final permission = coordinator.permission.permission;
                  final label = switch (permission) {
                    NotificationPermission.notDetermined => 'Not requested',
                    NotificationPermission.authorized => 'Allowed',
                    NotificationPermission.provisional =>
                      'Quiet notifications allowed',
                    NotificationPermission.denied => 'Off in system settings',
                    NotificationPermission.unavailable =>
                      'Unavailable on this device',
                  };
                  return ListView(
                    padding: MomCozyInsets.page,
                    children: [
                      MomCozySurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'System permission',
                              style: MomCozyTypography.title,
                            ),
                            Text(label),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => coordinator.openSettings(),
                                child: const Text('Settings'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.section),
                      if (coordinator.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(coordinator.error!),
                        ),
                      if (_error != null) Text(_error!),
                      if (_busy) const LinearProgressIndicator(),
                      for (final entry in const {
                        'appointments': 'Appointments',
                        'consultations': 'Consultations',
                        'expert_feedback': 'Expert feedback',
                        'service_updates': 'Service updates',
                      }.entries)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value),
                          subtitle: Text(
                            permission.canNotify && coordinator.pushReady
                                ? 'Service notifications'
                                : 'Background delivery unavailable',
                          ),
                          value: _preferences?[entry.key] ?? false,
                          onChanged: _busy || _preferences == null
                              ? null
                              : (value) => _set(entry.key, value),
                        ),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Marketing'),
                        subtitle: Text(
                          'Not enabled. Service preferences do not opt you into marketing.',
                        ),
                      ),
                      const Text(
                        'Only future reminders you previously enabled can resume when permission is restored. Past reminders are not sent later.',
                      ),
                      const SizedBox(height: MomCozySpacing.page),
                      OutlinedButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Refresh status'),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
