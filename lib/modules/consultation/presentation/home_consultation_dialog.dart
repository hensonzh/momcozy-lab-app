import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/appointment.dart';
import '../../../services/consultations/device_check.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../services/presentation/appointment_cancel_dialog.dart';
import '../application/room_controller.dart';
import 'room_page.dart';

enum HomeConsultationDestination { intake, rebook, summary }

/// The same room controller owns preparation, preflight and the live session.
/// Navigation out of the dialog is returned to the home route after dismissal.
Future<HomeConsultationDestination?> showHomeConsultationDialog(
  BuildContext context, {
  required ConsultationRoomController Function() createController,
  required AppointmentRepository appointments,
  ConsultationDeviceCheck Function()? createDeviceCheck,
}) => showDialog<HomeConsultationDestination>(
  context: context,
  animationStyle: MomCozyMotion.animationStyle(context),
  barrierDismissible: false,
  barrierColor: MomCozyColors.expertDialogBarrier,
  useSafeArea: false,
  builder: (dialogContext) {
    final route = ModalRoute.of(dialogContext)!;
    void finish([HomeConsultationDestination? destination]) {
      if (!dialogContext.mounted || !route.isActive) return;
      final navigator = Navigator.of(dialogContext);
      navigator.popUntil((candidate) => candidate == route);
      navigator.pop(destination);
    }

    return ConsultationRoomPage(
      overHome: true,
      createController: createController,
      createDeviceCheck: createDeviceCheck,
      onBack: finish,
      onIntake: () async => finish(HomeConsultationDestination.intake),
      onProgress: (_) => finish(HomeConsultationDestination.summary),
      onRebook: (_) => finish(HomeConsultationDestination.rebook),
      onCancel: (appointment) async {
        await showAppointmentCancellation(
          dialogContext,
          repository: appointments,
          appointment: appointment,
        );
        if (dialogContext.mounted) finish();
      },
    );
  },
);
