import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/consultations/device_check.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';

enum _DeviceStatus { checking, ready, error }

class ConsultationDeviceCheckDialog extends StatefulWidget {
  const ConsultationDeviceCheckDialog({
    super.key,
    this.createCheck,
    this.onSuccess,
  });
  final ConsultationDeviceCheck Function()? createCheck;
  final VoidCallback? onSuccess;
  @override
  State<ConsultationDeviceCheckDialog> createState() =>
      _ConsultationDeviceCheckDialogState();
}

class _ConsultationDeviceCheckDialogState
    extends State<ConsultationDeviceCheckDialog> {
  late final check = widget.createCheck?.call() ?? ConsultationDeviceCheck();
  _DeviceStatus _status = _DeviceStatus.checking;
  bool _running = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  @override
  void dispose() {
    check.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;
    _running = true;
    setState(() {
      _status = _DeviceStatus.checking;
      _error = '';
    });
    var ready = false;
    var error = '无法使用摄像头或麦克风，请检查设备权限后重试。';
    try {
      await check.start();
      if (!mounted) return;
      ready = check.video != null && check.microphoneAvailable;
      if (!ready) {
        error = [
          if (check.cameraError != null) check.cameraError!,
          if (check.microphoneError != null) check.microphoneError!,
        ].join('\n');
        if (error.isEmpty) error = '无法使用摄像头或麦克风，请检查设备权限后重试。';
      }
    } catch (_) {
      // A failed probe must still release any tracks it acquired.
    } finally {
      if (mounted) await check.close();
      _running = false;
    }
    if (!mounted) return;
    setState(() {
      _status = ready ? _DeviceStatus.ready : _DeviceStatus.error;
      _error = ready ? '' : error;
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: MomSettingsFlowDialog(
      title: '检测摄像头与麦克风',
      closeLabel: '关闭设备检测',
      onClose: () => Navigator.pop(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MomHomeTokens.gap,
        children: [
          Text(
            '进入咨询室前，请先确认摄像头和麦克风可用。',
            style: MomHomeTokens.text(
              13,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
          _deviceStatus(),
          if (_error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: MomSettingsCard(
                color: MomCozyColors.amberSoft,
                children: [
                  Text(_error, style: MomHomeTokens.text(13, height: 1.55)),
                ],
              ),
            ),
          if (_status == _DeviceStatus.ready)
            FilledButton(
              onPressed: widget.onSuccess ?? () => Navigator.pop(context),
              child: Text(widget.onSuccess == null ? '完成' : '继续确认'),
            ),
        ],
      ),
    ),
  );

  Widget _deviceStatus() {
    final ready = _status == _DeviceStatus.ready,
        failed = _status == _DeviceStatus.error;
    return MomSettingsCard(
      color: ready
          ? MomHomeTokens.mint
          : failed
          ? const Color(0xFFFBECE8)
          : MomHomeTokens.neutralSurface,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            ready ? Icons.check : Icons.videocam_outlined,
            size: 24,
            color: MomHomeTokens.teal,
          ),
        ),
        Text(
          '摄像头与麦克风',
          style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
        ),
        Semantics(
          liveRegion: true,
          child: Text(switch (_status) {
            _DeviceStatus.checking => '正在请求设备权限…',
            _DeviceStatus.ready => '摄像头和麦克风均可用',
            _DeviceStatus.error => '检查未通过，请重试',
          }, style: MomHomeTokens.text(18, weight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: _status == _DeviceStatus.checking ? null : _start,
          style: ready
              ? FilledButton.styleFrom(
                  backgroundColor: MomHomeTokens.surface,
                  foregroundColor: MomHomeTokens.rose,
                  side: const BorderSide(color: MomHomeTokens.border),
                )
              : null,
          child: Text(
            _status == _DeviceStatus.checking
                ? '检查中…'
                : ready
                ? '重新检查'
                : '开始检测',
          ),
        ),
      ],
    );
  }
}
