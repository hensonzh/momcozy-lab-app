import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../application/room_controller.dart';

Widget _notice(
  String text, {
  Widget? action,
  IconData icon = Icons.info_outline,
}) => MomSettingsCard(
  color: MomCozyColors.amberSoft,
  children: [
    Align(
      alignment: Alignment.centerLeft,
      child: Icon(icon, size: 20, color: MomCozyColors.amber),
    ),
    Text(text, style: MomHomeTokens.text(13, height: 1.55)),
    ?action,
  ],
);

class ConsultationStartDialog extends StatefulWidget {
  const ConsultationStartDialog({
    super.key,
    required this.controller,
    required this.onIntake,
  });
  final ConsultationRoomController controller;
  final Future<void> Function() onIntake;
  @override
  State<ConsultationStartDialog> createState() =>
      _ConsultationStartDialogState();
}

class _ConsultationStartDialogState extends State<ConsultationStartDialog> {
  late String _region =
      widget.controller.data!.location?.region ??
      widget.controller.data!.appointment.region;
  bool _submitting = false,
      _closing = false,
      _returning = false,
      _rejected = false;
  String? _attemptedRegion;
  ConsultationRoomController get controller => widget.controller;
  bool get _busy => _submitting || _closing || controller.busy;
  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted || !controller.inRoom || _returning || _closing) return;
    _returning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _close() async {
    if (_busy) return;
    setState(() => _closing = true);
    if (controller.wantsToJoin) await controller.leave();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _enter() async {
    if (_busy || _rejected || controller.wantsToJoin) return;
    setState(() {
      _submitting = true;
      _attemptedRegion = _region;
    });
    try {
      await controller.checkLocation(_region);
      if (!mounted) return;
      final location = controller.data?.location;
      if (controller.failure != null) return;
      if (location?.region != _region ||
          !(location?.validAt(controller.now) ?? false)) {
        setState(
          () => _rejected =
              location?.region == _region && location?.passed == false,
        );
        return;
      }
      if (controller.canEnter) await controller.enter();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _restoreConsent() async {
    if (_busy) return;
    await showDialog<void>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (_) => ConsultationVideoConsentDialog(controller: controller),
    );
    if (mounted) setState(() {});
  }

  Future<void> _intake() async {
    if (_busy) return;
    setState(() => _submitting = true);
    try {
      await widget.onIntake();
      await controller.load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.data!;
      final open = data.windowOpen(controller.now);
      final ready =
          data.intakeReady &&
          data.caseConsent &&
          data.videoConsent &&
          open &&
          data.videoProvider != VideoProvider.disabled;
      final message = _attemptedRegion == _region ? controller.message : null;
      return PopScope(
        canPop: !_busy && !controller.wantsToJoin,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_busy) _close();
        },
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: 'Start video consultation',
            closeLabel: 'Close consultation confirmation',
            maxHeight: 720,
            onClose: _busy ? null : _close,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Confirm your current location before joining.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                const SizedBox(height: 14),
                MomSettingsCard(
                  color: MomHomeTokens.mint,
                  children: [
                    const Text(
                      'Current state',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('consult-location'),
                      initialValue: _region,
                      isExpanded: true,
                      isDense: MediaQuery.textScalerOf(context).scale(1) <= 1.4,
                      itemHeight: null,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                      items: {'CA', 'NY', 'TX', _region}
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(switch (value) {
                                'CA' => 'California (CA)',
                                'NY' => 'New York (NY)',
                                'TX' => 'Texas (TX)',
                                _ => value,
                              }),
                            ),
                          )
                          .toList(),
                      onChanged: _busy || controller.wantsToJoin
                          ? null
                          : (value) => setState(() {
                              _region = value!;
                              _rejected = false;
                              _attemptedRegion = null;
                            }),
                    ),
                  ],
                ),
                if (_rejected) ...[
                  const SizedBox(height: 14),
                  _notice(
                    'Your consultant does not currently support the selected state. Check your location or return to booking to reschedule.',
                    icon: Icons.shield_outlined,
                  ),
                ],
                if (!data.videoConsent) ...[
                  const SizedBox(height: 14),
                  _notice(
                    'Video consultation consent is required for this service',
                    icon: Icons.lock_outline,
                    action: TextButton(
                      onPressed: _busy ? null : _restoreConsent,
                      child: const Text('Review consent'),
                    ),
                  ),
                ],
                if (!data.intakeReady || !data.caseConsent) ...[
                  const SizedBox(height: 14),
                  _notice(
                    'Complete the intake form and confirm that your IBCLC may view it.',
                    action: TextButton(
                      onPressed: _busy ? null : _intake,
                      child: const Text('View intake form'),
                    ),
                  ),
                ],
                if (!open || data.videoProvider == VideoProvider.disabled) ...[
                  const SizedBox(height: 14),
                  _notice(
                    data.videoProvider == VideoProvider.disabled
                        ? 'Video consultations are not available yet. Try again later.'
                        : controller.now.isBefore(data.opensAt)
                        ? 'The consultation room opens 10 minutes before your appointment.'
                        : 'The join window for this appointment has closed. Go back to reschedule.',
                  ),
                ],
                if (message != null && !_rejected) ...[
                  const SizedBox(height: 14),
                  _notice(message),
                ],
                if (controller.wantsToJoin && !controller.inRoom) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'The consultation room is getting ready. Closing this dialog will cancel this join attempt.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed:
                      ready && !_busy && !_rejected && !controller.wantsToJoin
                      ? _enter
                      : null,
                  child: Text(
                    _busy || controller.wantsToJoin ? 'Joining…' : 'Confirm and join',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Explicit consent for this care episode only; no global consent is changed.
class ConsultationVideoConsentDialog extends StatefulWidget {
  const ConsultationVideoConsentDialog({super.key, required this.controller});
  final ConsultationRoomController controller;
  @override
  State<ConsultationVideoConsentDialog> createState() =>
      _ConsultationVideoConsentDialogState();
}

class _ConsultationVideoConsentDialogState
    extends State<ConsultationVideoConsentDialog> {
  bool _accepted = false, _saving = false, _attempted = false;
  Future<void> _save() async {
    if (!_accepted || _saving || widget.controller.busy) return;
    setState(() {
      _saving = true;
      _attempted = true;
    });
    await widget.controller.grantVideoConsent();
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.controller.data?.videoConsent == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final busy = _saving || widget.controller.busy;
      return PopScope(
        canPop: !busy,
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: 'Video consultation consent',
            closeLabel: 'Close video consent',
            maxHeight: 720,
            onClose: busy ? null : () => Navigator.pop(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Turning this on lets you have a live audio and video consultation with your assigned IBCLC.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                const SizedBox(height: 14),
                MomSettingsCard(
                  color: MomHomeTokens.mint,
                  children: [
                    CheckboxListTile(
                      key: const ValueKey('room-video-consent'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _accepted,
                      onChanged: busy
                          ? null
                          : (value) =>
                                setState(() => _accepted = value ?? false),
                      title: const Text(
                        'I consent to video consultations for this service',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
                if (_attempted && widget.controller.message != null) ...[
                  const SizedBox(height: 14),
                  _notice(widget.controller.message!),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _accepted && !busy ? _save : null,
                  child: Text(busy ? 'Confirming…' : 'Confirm video consent'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
