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
        ? 'You can join early'
        : past
        ? 'Join window has closed'
        : started
        ? 'Started'
        : seconds >= 86400
        ? '${seconds ~/ 86400} days ${two(seconds ~/ 3600 % 24)}:${two(seconds ~/ 60 % 60)}'
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
                          ? 'Test mode'
                          : past
                          ? 'Consultation status'
                          : started
                          ? 'Consultation started'
                          : 'Time until consultation',
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
          Text('Before you join', style: MomHomeTokens.text(18, weight: FontWeight.w700)),
          Text(
            'Confirm your current state and make sure your camera and microphone work before joining.',
            style: MomHomeTokens.text(
              13,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
          if (!data.intakeReady || !data.caseConsent)
            _note(
              data.intakeReady
                  ? 'Confirm that your IBCLC may view the information for this consultation.'
                  : 'Complete your intake form first so your IBCLC can understand your feeding situation.',
              action: TextButton(
                onPressed: widget.busy ? null : widget.onIntake,
                child: const Text('View intake form'),
              ),
            ),
          if (data.videoProvider == VideoProvider.disabled)
            _note('Video consultations are not available yet. Try again later.'),
          if (past)
            _note(
              'The join window for this appointment has closed. You can reschedule.',
              action: TextButton(
                onPressed: widget.busy ? null : widget.onRebook,
                child: const Text('Book another appointment'),
              ),
            ),
          FilledButton(
            onPressed: ready ? widget.onStart : null,
            child: Text(
              widget.busy
                  ? 'Please wait…'
                  : data.active
                  ? 'Rejoin consultation room'
                  : 'Start consultation',
            ),
          ),
          if (widget.onCancel != null)
            OutlinedButton(
              onPressed: widget.busy ? null : widget.onCancel,
              child: const Text('Cancel appointment'),
            ),
          if (!open && now.isBefore(data.opensAt))
            Text(
              'The consultation room opens ${appointmentDay(data.opensAt, appointment.timezone)} at ${zonedClock(data.opensAt, appointment.timezone)}',
              style: MomHomeTokens.text(
                12,
                color: MomHomeTokens.secondary,
                height: 1.5,
              ),
            ),
          if (data.videoProvider == VideoProvider.sandbox || demo)
            Text(
              data.videoProvider == VideoProvider.sandbox
                  ? 'This is a simulated consultation. Remote audio and video are not transmitted.'
                  : 'Test mode lets you join early.',
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
