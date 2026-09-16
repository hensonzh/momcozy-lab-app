import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/zoned_time.dart';
import '../../services/presentation/mom_appointment_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';

/// User preparation mirrors HomeConsultPreparation; server context owns entry.
class ConsultationPreparation extends StatefulWidget {
  const ConsultationPreparation({
    super.key,
    required this.data,
    required this.now,
    required this.busy,
    required this.onStart,
    required this.onIntake,
    required this.onRebook,
    this.onCancel,
  });
  final ConsultationRoomContext data;
  final DateTime Function() now;
  final bool busy;
  final VoidCallback onStart, onIntake, onRebook;
  final VoidCallback? onCancel;

  @override
  State<ConsultationPreparation> createState() =>
      _ConsultationPreparationState();
}

class _ConsultationPreparationState extends State<ConsultationPreparation> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _note(String text, {Widget? action}) => MomSettingsCard(
    color: MomCozyColors.amberSoft,
    children: [
      Text(text, style: MomHomeTokens.text(13, height: 1.55)),
      ?action,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.data, appointment = data.appointment;
    final now = widget.now();
    final remaining = appointment.startsAt.difference(now);
    final open = data.windowOpen(now);
    final past = !open && !now.isBefore(data.closesAt);
    final demo = data.demoEarlyJoin && open && now.isBefore(data.opensAt);
    final started = !now.isBefore(appointment.startsAt);
    final ready =
        open &&
        data.intakeReady &&
        data.caseConsent &&
        data.videoProvider != VideoProvider.disabled &&
        !widget.busy;
    final seconds = remaining.inSeconds.clamp(0, 999999999);
    String two(int value) => value.toString().padLeft(2, '0');
    final countdown =
        '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
    final value = demo
        ? '可提前进入'
        : past
        ? '进入时间已过'
        : started
        ? '已开始'
        : seconds >= 86400
        ? '${seconds ~/ 86400}天 ${two(seconds ~/ 3600 % 24)}:${two(seconds ~/ 60 % 60)}'
        : countdown;
    final color = past ? MomHomeTokens.secondary : MomHomeTokens.teal;
    final progress =
        (1 - remaining.inSeconds / const Duration(days: 1).inSeconds).clamp(
          0.0,
          1.0,
        );
    return Theme(
      data: momSettingsTheme(Theme.of(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MomHomeTokens.gap,
        children: [
          MomAppointmentSummary(appointment: appointment),
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: color,
                      backgroundColor: past
                          ? MomHomeTokens.neutralSurface
                          : MomHomeTokens.mint,
                    ),
                    Icon(Icons.schedule_outlined, size: 22, color: color),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      demo
                          ? '测试模式'
                          : past
                          ? '咨询状态'
                          : started
                          ? '咨询已开始'
                          : '距离咨询',
                      style: MomHomeTokens.text(
                        12,
                        color: MomHomeTokens.secondary,
                      ),
                    ),
                    Text(
                      value,
                      style:
                          MomHomeTokens.text(
                            22,
                            weight: FontWeight.w700,
                            color: color,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text('开始前准备', style: MomHomeTokens.text(18, weight: FontWeight.w700)),
          Text(
            '开始前请确认当前所在州，并确保摄像头与麦克风可用。',
            style: MomHomeTokens.text(
              13,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
          if (!data.intakeReady || !data.caseConsent)
            _note(
              data.intakeReady
                  ? '请确认向本次 IBCLC 共享资料。'
                  : '开始前请先完成信息采集，让 IBCLC 了解你的喂养情况。',
              action: TextButton(
                onPressed: widget.busy ? null : widget.onIntake,
                child: const Text('查看信息采集表'),
              ),
            ),
          if (data.videoProvider == VideoProvider.disabled)
            _note('视频咨询暂未开放，请稍后再试。'),
          if (past)
            _note(
              '本次预约的进入时间已过，可以重新安排。',
              action: TextButton(
                onPressed: widget.busy ? null : widget.onRebook,
                child: const Text('重新预约'),
              ),
            ),
          FilledButton(
            onPressed: ready ? widget.onStart : null,
            child: Text(
              widget.busy
                  ? '请稍候…'
                  : data.active
                  ? '重新进入咨询室'
                  : '开始咨询',
            ),
          ),
          if (widget.onCancel != null)
            OutlinedButton(
              onPressed: widget.busy ? null : widget.onCancel,
              child: const Text('取消预约'),
            ),
          if (!open && now.isBefore(data.opensAt))
            Text(
              '咨询室于 ${appointmentDay(data.opensAt, appointment.timezone)} ${zonedClock(data.opensAt, appointment.timezone)} 开放',
              style: MomHomeTokens.text(
                12,
                color: MomHomeTokens.secondary,
                height: 1.5,
              ),
            ),
          if (data.videoProvider == VideoProvider.sandbox || demo)
            Text(
              data.videoProvider == VideoProvider.sandbox
                  ? '当前为模拟咨询，不传输远程音视频。'
                  : '测试模式允许提前进入咨询。',
              style: MomHomeTokens.text(
                12,
                color: MomHomeTokens.secondary,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
