import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/intake.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../services/application/care_overview_controller.dart';
import '../application/privacy_controller.dart';

const privacyScopeCopy =
    <CareConsentScope, ({String title, String description, String impact})>{
      CareConsentScope.ibclcCase: (
        title: 'Share with your assigned IBCLC',
        description: 'Only your assigned IBCLC can view the intake form and consent records for this service.',
        impact: 'If turned off, the form can no longer be viewed and you cannot join this consultation. Records already viewed or legally retained will not be deleted.',
      ),
      CareConsentScope.video: (
        title: 'Join video consultation',
        description: 'Allows you to join your booked video session. Audio and video are not recorded by default.',
        impact: 'If turned off, you cannot rejoin this video consultation.',
      ),
      CareConsentScope.aiContext: (
        title: 'Allow Momcozy AI to use selected records',
        description: 'Use selected records to provide context within the scope of this service.',
        impact: 'You can still use general chat if this is turned off. Existing records will remain.',
      ),
      CareConsentScope.notifications: (
        title: 'Receive service reminders',
        description: 'For appointments, tasks, and follow-ups related to this service.',
        impact: 'If turned off, you will no longer receive these reminders. Your schedule will still be available in the app.',
      ),
    };

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({
    super.key,
    required this.care,
    required this.consents,
    required this.onBack,
    required this.onNotifications,
    this.initialEpisodeId,
  });
  final CareRepository care;
  final IntakeRepository consents;
  final VoidCallback onBack;
  final VoidCallback onNotifications;
  final String? initialEpisodeId;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late final overview = CareOverviewController(widget.care);
  PrivacyController? _consent;
  String? _selected;
  int _pickerRevision = 0;
  bool _allowPop = false, _requestedMissing = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await overview.load();
    if (!mounted || overview.overview == null) return;
    final episodes = overview.overview!.episodes;
    if (_selected == null &&
        widget.initialEpisodeId != null &&
        !episodes.any((e) => e.id == widget.initialEpisodeId)) {
      setState(() => _requestedMissing = true);
      return;
    }

    if (_requestedMissing) setState(() => _requestedMissing = false);
    final id =
        episodes
            .where((e) => e.id == (_selected ?? widget.initialEpisodeId))
            .firstOrNull
            ?.id ??
        episodes.firstOrNull?.id;
    if (id != null && _consent == null) await _select(id);
  }

  Future<void> _select(String id) async {
    if (_consent?.busy == true) return;
    if ((_consent?.dirty == true || _consent?.uncertain == true) &&
        !await _discard()) {
      if (mounted) setState(() => _pickerRevision++);
      return;
    }
    if (!mounted) return;
    _consent?.dispose();
    final c = PrivacyController(repository: widget.consents, episodeId: id);
    setState(() {
      _selected = id;
      _consent = c;
    });
    await c.load();
  }

  Future<bool> _discard() async =>
      await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (context) => MomSettingsDialog(
          closeLabel: 'Close',
          title: 'Leave consent settings?',
          onCancel: () => Navigator.pop(context, false),
          cancelLabel: 'Keep reviewing',
          content: Text(
            _consent?.uncertain == true
                ? 'Your save has not been confirmed. Reload your consent settings when you return.'
                : 'Your unsaved consent changes will be lost.',
          ),
          primaryAction: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard and leave'),
          ),
        ),
      ) ??
      false;
  Future<void> _back() async {
    if (_consent?.busy == true) return;
    if ((_consent?.dirty == true || _consent?.uncertain == true) &&
        !await _discard()) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBack();
    });
  }

  Future<void> _save() async {
    final c = _consent!;
    if (c.revokedRequired.isNotEmpty && !c.uncertain) {
      final confirmed = await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (context) => MomSettingsDialog(
          closeLabel: 'Close',
          title: 'Turn off service access?',
          onCancel: () => Navigator.pop(context, false),
          cancelLabel: 'Keep access',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text(
                'Turning this off will prevent further form access or video entry. A video session in progress may also end. Records already viewed or legally required to be kept will remain.',
              ),
              for (final s in c.revokedRequired)
                Text('• ${privacyScopeCopy[s]!.title}'),
            ],
          ),
          primaryAction: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MomCozyColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Turn off access'),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await c.save();
  }

  @override
  void dispose() {
    _consent?.dispose();
    overview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: AnimatedBuilder(
      animation: Listenable.merge([overview, ?_consent]),
      builder: (context, _) {
        final c = _consent;
        return PopScope(
          canPop:
              _allowPop ||
              (c?.busy != true && c?.dirty != true && c?.uncertain != true),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_back());
          },
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: MomHomeTokens.gap,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: c?.busy == true ? null : _back,
                        child: const Text('Back'),
                      ),
                    ),
                    Text(
                      'Privacy & data',
                      style: MomHomeTokens.text(22, weight: FontWeight.w700),
                    ),
                    const _Paragraph('Choose who can use your information and for what purpose.'),
                    MomSettingsCard(
                      gradient: MomHomeTokens.milk,
                      children: [
                        Text(
                          'Account records',
                          style: MomHomeTokens.text(
                            16,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const _Paragraph('Profiles and records you enter for yourself and your baby are saved to this account.'),
                        Text(
                          'Keep my records',
                          style: MomHomeTokens.text(
                            13,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const _Paragraph('Changing service consent here will not delete your account records. Manage your account details in Account Settings.'),
                      ],
                    ),
                    if (overview.failure case final failure?)
                      ProductErrorView(failure: failure, onRetry: _load)
                    else if (overview.overview == null)
                      const _Loading()
                    else if (_requestedMissing)
                      const _Empty('No consent found for this service', 'Return to the service page and try again.')
                    else if (overview.overview!.episodes.isEmpty)
                      const _Empty('No service consent to manage yet', 'After purchasing a service, you can review and change its consent settings here.')
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selected,
                        key: ValueKey('$_selected:$_pickerRevision'),
                        isExpanded: true,
                        itemHeight: null,
                        dropdownColor: MomHomeTokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        decoration: const InputDecoration(labelText: 'Select a service'),
                        items: [
                          for (final e in overview.overview!.episodes)
                            DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                _episodeLabel(e),
                                style: MomHomeTokens.text(13),
                              ),
                            ),
                        ],
                        onChanged: c?.busy == true || c?.uncertain == true
                            ? null
                            : (id) {
                                if (id != null) unawaited(_select(id));
                              },
                      ),
                      const _Paragraph('These changes apply only to the selected service. Each permission is saved separately and will not change other services.'),
                      if (c == null || c.loading)
                        const _Loading()
                      else if (c.draft.isEmpty && c.failure != null)
                        ProductErrorView(failure: c.failure!, onRetry: c.load)
                      else ...[
                        const _Heading('Required for service', 'Permissions needed for expert support and video sessions. Turning them off will not delete past records.'),
                        ..._scopes(c, [
                          CareConsentScope.ibclcCase,
                          CareConsentScope.video,
                        ]),
                        const _Heading('Optional permissions', 'These do not affect basic record keeping and can be changed anytime.'),
                        ..._scopes(c, [
                          CareConsentScope.aiContext,
                          CareConsentScope.notifications,
                        ]),
                        if (c.failure != null) ...[
                          ProductErrorView(
                            failure: c.failure!,
                            onRetry: c.uncertain ? _save : c.load,
                          ),
                          if (c.uncertain)
                            const _Paragraph(
                              'Your save has not been confirmed. Try again to continue the same change, or reload to discard the unconfirmed draft and use the server version.',
                            ),
                          TextButton(
                            onPressed: c.busy ? null : c.load,
                            child: const Text('Reload consent'),
                          ),
                        ],
                        if (c.saved)
                          Semantics(
                            liveRegion: true,
                            child: MomSettingsCard(
                              color: MomHomeTokens.mint,
                              children: [
                                Text(
                                  'Privacy settings saved',
                                  style: MomHomeTokens.text(
                                    13,
                                    color: MomHomeTokens.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (c.dirty || c.uncertain)
                          FilledButton(
                            onPressed: c.busy || c.needsReload ? null : _save,
                            child: Text(
                              c.busy
                                  ? 'Saving…'
                                  : c.uncertain
                                  ? 'Try saving again'
                                  : 'Save changes',
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  String _episodeLabel(CareEpisode e) {
    final name =
        overview.catalog?.packages
            .where((p) => p.id == e.packageId)
            .firstOrNull
            ?.name ??
        'Expert support service';
    final date = e.startsAt?.toLocal();
    return '$name${date == null ? '' : ' · ${date.year}/${date.month}/${date.day}'}';
  }

  List<Widget> _scopes(PrivacyController c, List<CareConsentScope> scopes) => [
    for (final scope in scopes)
      if (scope == CareConsentScope.notifications)
        MomSettingsCard(
          children: [
            Text(
              'Receive service reminders',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            const _Paragraph('Manage appointment, task, and follow-up reminders in Notification Settings.'),
            TextButton(
              onPressed: c.busy ? null : widget.onNotifications,
              child: const Text('Manage notifications & reminders'),
            ),
          ],
        )
      else
        _ScopeRow(
          scope: scope,
          value: c.draft[scope] ?? false,
          enabled: c.canEdit,
          onChanged: (v) => c.toggle(scope, v),
        ),
  ];
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: MomHomeTokens.text(12, color: MomHomeTokens.secondary, height: 1.55),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.description);
  final String title, description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Text(title, style: MomHomeTokens.text(18, weight: FontWeight.w700)),
      _Paragraph(description),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.description);
  final String title, description;
  @override
  Widget build(BuildContext context) => MomSettingsCard(
    children: [
      Text(title, style: MomHomeTokens.text(16, weight: FontWeight.w700)),
      _Paragraph(description),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => MomSettingsCard(
    children: [
      Text('Loading…', style: MomHomeTokens.text(16, weight: FontWeight.w700)),
      const LinearProgressIndicator(),
    ],
  );
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.scope,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final CareConsentScope scope;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final copy = privacyScopeCopy[scope]!;
    final title = Text(
      copy.title,
      style: MomHomeTokens.text(16, weight: FontWeight.w700),
    );
    final control = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: copy.title,
          child: Switch(
            key: ValueKey(scope),
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        Text(
          enabled ? (value ? 'On' : 'Off') : 'Cannot change right now',
          style: MomHomeTokens.text(10, color: MomHomeTokens.secondary),
        ),
      ],
    );
    return MomSettingsCard(
      children: [
        MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  title,
                  Align(alignment: Alignment.centerRight, child: control),
                ],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 14),
                  control,
                ],
              ),
        _Paragraph(copy.description),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MomHomeTokens.neutralSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            copy.impact,
            style: MomHomeTokens.text(
              11,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
