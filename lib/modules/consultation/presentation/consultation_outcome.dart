import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../services/presentation/mom_appointment_widgets.dart';

class UserConsultationOutcome extends StatelessWidget {
  const UserConsultationOutcome({
    super.key,
    required this.data,
    required this.onSummary,
    required this.onRebook,
    required this.onHome,
  });

  final ConsultationRoomContext data;
  final VoidCallback onSummary, onRebook, onHome;

  @override
  Widget build(BuildContext context) {
    final reason = data.consultation?.endReason;
    final unsuccessful =
        reason == ConsultationEndReason.technicalFailure ||
        reason == ConsultationEndReason.userNoShow;
    final (title, description, icon) = switch (reason) {
      ConsultationEndReason.technicalFailure => (
        '视频连接未能继续',
        '这不是你的问题。本次未扣减咨询次数，可以重新选择合适的时间。',
        Icons.wifi_off_outlined,
      ),
      ConsultationEndReason.userNoShow => (
        '这次咨询未能开始',
        '我们没能在预约时间与你开始咨询。本次未扣减咨询次数，如需继续支持，可以重新预约。',
        Icons.schedule_outlined,
      ),
      ConsultationEndReason.safetyEscalation => (
        '本次咨询已结束',
        '请按专家的建议继续寻求支持，后续记录会出现在服务进度中。',
        Icons.health_and_safety_outlined,
      ),
      _ =>
        data.appointment.status == AppointmentStatus.cancelled
            ? ('预约已取消', '如需继续支持，可以重新安排咨询时间。', Icons.close)
            : ('本次咨询已结束', 'IBCLC 正在整理本次建议，可在服务进度中查看。', Icons.check),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MomSettingsCard(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: unsuccessful
                        ? MomHomeTokens.neutralSurface
                        : MomHomeTokens.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: MomHomeTokens.teal),
                ),
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                style: MomHomeTokens.text(22, weight: FontWeight.w700),
              ),
            ),
            Text(
              description,
              style: MomHomeTokens.text(
                13,
                height: 1.55,
                color: MomHomeTokens.secondary,
              ),
            ),
            FilledButton(
              onPressed: unsuccessful ? onRebook : onSummary,
              child: Text(unsuccessful ? '重新预约' : '查看咨询总结'),
            ),
            if (unsuccessful)
              TextButton(onPressed: onHome, child: const Text('返回妈妈主页'))
            else if (reason != ConsultationEndReason.completed)
              TextButton(onPressed: onRebook, child: const Text('重新预约')),
          ],
        ),
        const SizedBox(height: 14),
        MomAppointmentSummary(appointment: data.appointment, title: '本次预约'),
      ],
    );
  }
}
