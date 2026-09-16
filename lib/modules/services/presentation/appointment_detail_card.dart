import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/zoned_time.dart';
import 'service_expert_identity.dart';

class AppointmentDetailCard extends StatelessWidget {
  const AppointmentDetailCard({
    super.key,
    required this.appointment,
    this.title,
    this.action,
  });
  final CareAppointment appointment;
  final String? title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => MomCozySurface(
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: MomCozyColors.careSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: MomCozyColors.care,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${appointmentDay(appointment.startsAt, appointment.timezone)} · ${zonedRange(appointment.startsAt, appointment.endsAt, appointment.timezone)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${appointment.duration.inMinutes} 分钟 · ${appointment.timezone}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),
        ServiceExpertIdentity(
          name: appointment.providerName,
          label: '本次咨询专家',
          avatarSize: 42,
        ),
        if (action != null) ...[const SizedBox(height: 15), action!],
      ],
    ),
  );
}
