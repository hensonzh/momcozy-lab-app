import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/design_system/momcozy_text_roles.dart';
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
    return Theme(
      data: momSettingsTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? 128
              : 56,
          title: Text(
            'Notification settings',
            maxLines: 2,
            style: MomHomeTokens.text(20, weight: FontWeight.w700),
          ),
          leading: Navigator.canPop(context)
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                  icon: SvgPicture.asset(
                    'assets/images/me_baby_overview/icons/back-button.svg',
                    width: 36,
                    height: 32,
                  ),
                )
              : null,
        ),
        body: ClipRect(
          child: MomCozyPageBody(
            child: coordinator == null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: MomSettingsCard(
                      children: [
                        Text(
                          'Background notifications are unavailable on this device.',
                          style: MomHomeTokens.text(
                            18,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
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
                        NotificationPermission.denied =>
                          'Off in system settings',
                        NotificationPermission.unavailable =>
                          'Unavailable on this device',
                      };
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: MomHomeTokens.gap,
                          children: [
                            MomSettingsCard(
                              gradient: MomHomeTokens.milk,
                              border: false,
                              children: [
                                Text(
                                  'System permission',
                                  style: MomHomeTokens.text(
                                    12,
                                    color: MomHomeTokens.secondary,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: MomHomeTokens.text(
                                    20,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => coordinator.openSettings(),
                                  child: const Text('Settings'),
                                ),
                              ],
                            ),
                            if (coordinator.error != null)
                              _errorCard(context, coordinator.error!),
                            if (_error != null) _errorCard(context, _error!),
                            Semantics(
                              header: true,
                              child: Text(
                                'Service notifications',
                                style: MomHomeTokens.text(
                                  18,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_busy)
                              const LinearProgressIndicator(
                                semanticsLabel:
                                    'Updating notification preferences',
                              ),
                            MomSettingsCard(
                              padding: EdgeInsets.zero,
                              children: [
                                Column(
                                  children: [
                                    for (final entry in const {
                                      'appointments': 'Appointments',
                                      'consultations': 'Consultations',
                                      'expert_feedback': 'Expert feedback',
                                      'service_updates': 'Service updates',
                                    }.entries) ...[
                                      if (entry.key != 'appointments')
                                        const Divider(
                                          height: 1,
                                          color: MomHomeTokens.border,
                                        ),
                                      _preferenceTile(
                                        context,
                                        key: entry.key,
                                        title: entry.value,
                                        subtitle:
                                            permission.canNotify &&
                                                coordinator.pushReady
                                            ? 'Service notifications'
                                            : 'Background delivery unavailable',
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            MomSettingsCard(
                              color: MomHomeTokens.neutralSurface,
                              border: false,
                              children: [
                                Text(
                                  'Marketing',
                                  style: MomHomeTokens.text(
                                    14,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Not enabled. Service preferences do not opt you into marketing.',
                                  style: _paragraph(context, 13),
                                ),
                              ],
                            ),
                            Text(
                              'Only future reminders you previously enabled can resume when permission is restored. Past reminders are not sent later.',
                              style: _paragraph(context, 12),
                            ),
                            OutlinedButton(
                              onPressed: _busy ? null : _load,
                              child: const Text('Refresh status'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _preferenceTile(
    BuildContext context, {
    required String key,
    required String title,
    required String subtitle,
  }) {
    final value = _preferences?[key] ?? false;
    final onChanged = _busy || _preferences == null
        ? null
        : (bool enabled) => _set(key, enabled);
    final widgetKey = ValueKey('notification-preference-$key');
    final titleWidget = Text(
      title,
      style: MomHomeTokens.text(16, weight: FontWeight.w700),
    );
    final subtitleWidget = Text(
      subtitle,
      style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
    );
    if (MediaQuery.sizeOf(context).width <= 360 &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              const SizedBox(height: 4),
              subtitleWidget,
              Align(
                alignment: Alignment.centerRight,
                child: Switch(
                  key: widgetKey,
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SwitchListTile(
      key: widgetKey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: titleWidget,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: subtitleWidget,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  TextStyle _paragraph(BuildContext context, double size) => MomHomeTokens.text(
    size,
    color: MomHomeTokens.secondary,
    height: 1.55,
  ).merge(MomCozyTextRoles.paragraphOf(context));

  Widget _errorCard(BuildContext context, String message) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      gradient: MomHomeTokens.body,
      children: [Text(message, style: _paragraph(context, 13))],
    ),
  );
}
