import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/zoned_time.dart';

class MomServiceExpertIdentity extends StatelessWidget {
  const MomServiceExpertIdentity({
    super.key,
    required this.name,
    required this.label,
    this.bio = '',
    this.avatarSize = 44,
  });
  final String name, label, bio;
  final double avatarSize;
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MomHomeTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  initials.isEmpty ? 'IB' : initials,
                  style: MomHomeTokens.text(
                    16,
                    weight: FontWeight.w700,
                    color: MomHomeTokens.teal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MomHomeTokens.text(
                      11,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                  Text(
                    name,
                    style: MomHomeTokens.text(14, weight: FontWeight.w700),
                  ),
                  Text(
                    'IBCLC · 哺乳顾问',
                    style: MomHomeTokens.text(
                      11,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            bio,
            style: MomHomeTokens.text(
              12,
              height: 1.55,
              color: MomHomeTokens.secondary,
            ),
          ),
        ],
      ],
    );
  }
}

class MomAppointmentSummary extends StatelessWidget {
  const MomAppointmentSummary({
    super.key,
    required this.appointment,
    this.title,
    this.action,
  });
  final CareAppointment appointment;
  final String? title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => MomSettingsCard(
    color: MomHomeTokens.mint,
    children: [
      if (title != null)
        Text(
          title!,
          style: MomHomeTokens.text(
            12,
            weight: FontWeight.w700,
            color: MomHomeTokens.teal,
          ),
        ),
      Text(
        '${appointmentDay(appointment.startsAt, appointment.timezone)} · ${zonedRange(appointment.startsAt, appointment.endsAt, appointment.timezone)}',
        style: MomHomeTokens.text(20, weight: FontWeight.w700),
      ),
      Text(
        '${appointment.duration.inMinutes} 分钟 · ${appointment.timezone}',
        style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
      ),
      MomServiceExpertIdentity(name: appointment.providerName, label: '本次咨询专家'),
      ?action,
    ],
  );
}
