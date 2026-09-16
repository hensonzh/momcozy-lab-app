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
            title: '开始视频咨询',
            closeLabel: '关闭咨询确认',
            maxHeight: 720,
            onClose: _busy ? null : _close,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '开始前请确认你当前所在的位置。',
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
                      '当前所在州',
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
                    '当前专家暂不支持你选择的州，请确认实际所在地，或返回预约页重新安排。',
                    icon: Icons.shield_outlined,
                  ),
                ],
                if (!data.videoConsent) ...[
                  const SizedBox(height: 14),
                  _notice(
                    '需要开启本次服务的视频咨询授权',
                    icon: Icons.lock_outline,
                    action: TextButton(
                      onPressed: _busy ? null : _restoreConsent,
                      child: const Text('去授权'),
                    ),
                  ),
                ],
                if (!data.intakeReady || !data.caseConsent) ...[
                  const SizedBox(height: 14),
                  _notice(
                    '请先完善信息采集表，并确认向本次 IBCLC 共享资料。',
                    action: TextButton(
                      onPressed: _busy ? null : _intake,
                      child: const Text('查看信息采集表'),
                    ),
                  ),
                ],
                if (!open || data.videoProvider == VideoProvider.disabled) ...[
                  const SizedBox(height: 14),
                  _notice(
                    data.videoProvider == VideoProvider.disabled
                        ? '视频咨询暂未开放，请稍后再试。'
                        : controller.now.isBefore(data.opensAt)
                        ? '咨询室会在预约开始前 10 分钟开放。'
                        : '本次预约的进入时间已过，请返回重新安排。',
                  ),
                ],
                if (message != null && !_rejected) ...[
                  const SizedBox(height: 14),
                  _notice(message),
                ],
                if (controller.wantsToJoin && !controller.inRoom) ...[
                  const SizedBox(height: 14),
                  const Text(
                    '咨询室正在准备，请稍候。关闭将取消本次进入。',
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
                    _busy || controller.wantsToJoin ? '正在进入…' : '确认并进入咨询室',
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
            title: '视频咨询授权',
            closeLabel: '关闭视频授权',
            maxHeight: 720,
            onClose: busy ? null : () => Navigator.pop(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '开启后，可以与本次负责的 IBCLC 进行实时音视频咨询。',
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
                        '我同意开启本次服务的视频咨询',
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
                  child: Text(busy ? '正在确认…' : '确认视频授权'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
