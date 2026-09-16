import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../application/appointment_cancellation_controller.dart';
import 'mom_appointment_widgets.dart';
import 'service_flow_theme.dart';

Future<CareAppointment?> showAppointmentCancellation(
  BuildContext context, {
  required AppointmentRepository repository,
  required CareAppointment appointment,
}) => showDialog<CareAppointment>(
  context: context,
  animationStyle: MomCozyMotion.animationStyle(context),
  barrierDismissible: false,
  builder: (_) =>
      AppointmentCancelDialog(repository: repository, appointment: appointment),
);

class AppointmentCancelDialog extends StatefulWidget {
  const AppointmentCancelDialog({
    super.key,
    required this.repository,
    required this.appointment,
  });
  final AppointmentRepository repository;
  final CareAppointment appointment;
  @override
  State<AppointmentCancelDialog> createState() =>
      _AppointmentCancelDialogState();
}

class _AppointmentCancelDialogState extends State<AppointmentCancelDialog> {
  late final controller = AppointmentCancellationController(
    repository: widget.repository,
    appointment: widget.appointment,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _run({bool refresh = false}) async {
    final result = await (refresh ? controller.refresh() : controller.cancel());
    if (mounted && result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final appointment = controller.current;
      return PopScope(
        canPop: !controller.busy,
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: '取消预约',
            closeLabel: '关闭取消预约',
            maxHeight: 520,
            onClose: controller.busy ? null : () => Navigator.pop(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                MomAppointmentSummary(appointment: appointment, title: '本次预约'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                const Text(
                  '取消后，该时段将释放。重新预约时需要再次确认信息采集表，已填写内容会保留。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                if (controller.failure != null ||
                    !controller.canCancel && !controller.busy) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      controller.failure != null
                          ? '暂时无法确认取消结果。可重试原操作，或核对预约状态。'
                          : '预约状态已变化，当前不能取消。请返回查看最新预约。',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MomCozyColors.danger,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => _run(refresh: true),
                    child: const Text('核对预约状态'),
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    final buttons = [
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          controller.uncertain ||
                                  !controller.canCancel && !controller.busy
                              ? '返回预约'
                              : '保留预约',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: controller.canCancel ? _run : null,
                        style: ServiceFlowTheme.cancellationStyle(context),
                        child: Text(
                          controller.busy
                              ? '正在处理…'
                              : controller.uncertain
                              ? '重试取消'
                              : '确认取消',
                        ),
                      ),
                    ];
                    return MediaQuery.textScalerOf(context).scale(1) > 1.4
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buttons[0],
                              const SizedBox(height: 9),
                              buttons[1],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: buttons[0]),
                              const SizedBox(width: 9),
                              Expanded(child: buttons[1]),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
