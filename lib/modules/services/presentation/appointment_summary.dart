import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/zoned_time.dart';

class AppointmentSummary extends StatelessWidget {
  const AppointmentSummary({super.key, required this.appointment, this.title});
  final CareAppointment appointment;
  final String? title;
  @override
  Widget build(BuildContext context) => MomCozySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(
              color: MomCozyColors.mutedForeground,
              fontSize: MomCozyTypography.captionSize,
            ),
          ),
          const SizedBox(height: MomCozySpacing.statusGap),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: MomCozyColors.care,
              size: 22,
            ),
            const SizedBox(width: MomCozySpacing.content),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointmentDay(appointment.startsAt, appointment.timezone),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: MomCozyTypography.sectionSize,
                    ),
                  ),
                  Text(
                    zonedRange(
                      appointment.startsAt,
                      appointment.endsAt,
                      appointment.timezone,
                    ),
                    style: const TextStyle(
                      fontSize: MomCozyTypography.bodyLargeSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${appointment.duration.inMinutes} 分钟 · ${appointment.timezone}',
                    style: const TextStyle(
                      fontSize: MomCozyTypography.labelSize,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(),
        ),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: MomCozyColors.careSoft,
              foregroundColor: MomCozyColors.care,
              child: Icon(Icons.person_outline_rounded),
            ),
            const SizedBox(width: MomCozySpacing.content),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.providerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'IBCLC · 哺乳顾问',
                    style: TextStyle(
                      color: MomCozyColors.mutedForeground,
                      fontSize: MomCozyTypography.captionSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
