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
            title: 'Cancel appointment',
            closeLabel: 'Close cancellation dialog',
            maxHeight: 520,
            onClose: controller.busy ? null : () => Navigator.pop(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                MomAppointmentSummary(appointment: appointment, title: 'This appointment'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                const Text(
                  'Canceling releases this time slot. If you book again, you will need to reconfirm your intake form. Your answers will be saved.',
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
                          ? 'Could not confirm cancellation. Try the same action again or check the appointment status.'
                          : 'The appointment status has changed and it can no longer be canceled here. Go back to view the latest details.',
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
                    child: const Text('Check appointment status'),
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
                              ? 'Back to appointment'
                              : 'Keep appointment',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: controller.canCancel ? _run : null,
                        style: ServiceFlowTheme.cancellationStyle(context),
                        child: Text(
                          controller.busy
                              ? 'Processing…'
                              : controller.uncertain
                              ? 'Try canceling again'
                              : 'Confirm cancellation',
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
