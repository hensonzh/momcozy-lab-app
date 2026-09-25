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
        'Video connection could not continue',
        'This was not your fault. No consultation was used. You can book another time.',
        Icons.wifi_off_outlined,
      ),
      ConsultationEndReason.userNoShow => (
        'This consultation could not start',
        'We could not start at the booked time. No consultation was used. Book again if you need support.',
        Icons.schedule_outlined,
      ),
      ConsultationEndReason.safetyEscalation => (
        'This consultation has ended',
        'Follow your consultant\'s guidance for further support. Follow-up records will appear in Service Progress.',
        Icons.health_and_safety_outlined,
      ),
      _ =>
        data.appointment.status == AppointmentStatus.cancelled
            ? ('Appointment canceled', 'You can book another consultation if you need more support.', Icons.close)
            : ('This consultation has ended', 'Your IBCLC is preparing recommendations. You can view them in Service Progress.', Icons.check),
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
              child: Text(unsuccessful ? 'Book another appointment' : 'View consultation summary'),
            ),
            if (unsuccessful)
              TextButton(onPressed: onHome, child: const Text('Back to home'))
            else if (reason != ConsultationEndReason.completed)
              TextButton(onPressed: onRebook, child: const Text('Book another appointment')),
          ],
        ),
        const SizedBox(height: 14),
        MomAppointmentSummary(appointment: data.appointment, title: 'This appointment'),
      ],
    );
  }
}
