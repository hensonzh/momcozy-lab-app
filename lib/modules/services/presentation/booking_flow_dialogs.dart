import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../application/booking_controller.dart';
import 'mom_appointment_widgets.dart';

Widget _stack(List<Widget> children, {double gap = 14}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);

class BookingNotice extends StatelessWidget {
  const BookingNotice({super.key, required this.title, this.body, this.action});
  final String title;
  final String? body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      color: MomCozyColors.amberSoft,
      children: [
        Text(
          title,
          style: MomHomeTokens.text(
            14,
            weight: FontWeight.w700,
            color: MomCozyColors.amber,
          ),
        ),
        if (body != null)
          Text(
            body!,
            style: MomHomeTokens.text(
              13,
              height: 1.55,
              color: MomCozyColors.amber,
            ),
          ),
        ?action,
      ],
    ),
  );
}

class BookingPrecheckDialog extends StatefulWidget {
  const BookingPrecheckDialog({super.key, required this.controller});
  final BookingController controller;
  @override
  State<BookingPrecheckDialog> createState() => _BookingPrecheckDialogState();
}

class _BookingPrecheckDialogState extends State<BookingPrecheckDialog> {
  BookingController get controller => widget.controller;
  bool _waiting = false;

  Widget _group(String title, Widget child) => MomSettingsCard(
    children: [
      Text(title, style: MomHomeTokens.text(16, weight: FontWeight.w700)),
      child,
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = controller;
      return PopScope(
        canPop: !c.busy && !_waiting,
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: 'Before booking',
            closeLabel: 'Close booking check',
            maxHeight: 680,
            onClose: c.busy || _waiting ? null : () => Navigator.pop(context),
            child: _stack([
              const Text(
                'Current state',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              DropdownButtonFormField<String>(
                initialValue: c.region,
                isExpanded: true,
                itemHeight: null,
                hint: const Text('Select your current state'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                items:
                    {
                          'CA',
                          'NY',
                          'TX',
                          ...?c.data?.providers.expand((p) => p.regions),
                        }
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(switch (value) {
                              'CA' => 'California (CA)',
                              'NY' => 'New York (NY)',
                              'TX' => 'Texas (TX)',
                              _ => value,
                            }),
                          ),
                        )
                        .toList(),
                onChanged: c.canEdit && !_waiting ? c.setRegion : null,
              ),
              if (c.region != null && !c.regionSupported)
                const BookingNotice(title: 'This service is not available in your state yet, so you cannot book right now.'),
              _group(
                'Is this service right for you?',
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: MomHomeTokens.rose,
                  title: const Text(
                    'I need IBCLC support with lactation or feeding.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  value: c.serviceSuitable,
                  onChanged: c.canEdit && !_waiting
                      ? (v) => c.setSuitable(v ?? false)
                      : null,
                ),
              ),
              _group(
                'Emergency check',
                _stack([
                  const Text(
                    'If you or your baby has trouble breathing, cannot be awakened, has heavy bleeding, or has another emergency, seek urgent medical help first.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                  RadioGroup<EmergencyStatus>(
                    groupValue: c.emergencyStatus,
                    onChanged: c.setEmergency,
                    child: _stack([
                      for (final item in {
                        EmergencyStatus.clear: 'None of these apply right now',
                        EmergencyStatus.needsHelp: 'Yes, or I am not sure',
                      }.entries)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: MomHomeTokens.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: RadioListTile<EmergencyStatus>(
                            value: item.key,
                            enabled: c.canEdit && !_waiting,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            activeColor: MomHomeTokens.rose,
                            title: Text(
                              item.value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ], gap: 9),
                  ),
                ], gap: 9),
              ),
              if (c.emergencyStatus == EmergencyStatus.needsHelp)
                const BookingNotice(
                  title: 'Seek emergency help first',
                  body: 'Contact local emergency services first. An IBCLC appointment is not a substitute for emergency care.',
                ),
              if (c.failure != null || c.message != null)
                BookingNotice(title: c.message ?? 'Could not confirm. Check your connection and try again.'),
              FilledButton(
                onPressed: c.canPrecheck && !_waiting
                    ? () async {
                        setState(() => _waiting = true);
                        try {
                          await c.precheck();
                          if (context.mounted && c.precheckReady) {
                            Navigator.pop(context, true);
                          }
                        } finally {
                          if (mounted) setState(() => _waiting = false);
                        }
                      }
                    : null,
                child: Text(c.busy || _waiting ? 'Confirming…' : 'Continue to time selection'),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

class BookingSelectionDialog extends StatelessWidget {
  const BookingSelectionDialog({
    super.key,
    required this.controller,
    required this.appointment,
    required this.reminder,
    required this.onReminderChanged,
  });
  final BookingController controller;
  final CareAppointment appointment;
  final bool reminder;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = controller;
      final current = c.activeAppointment;
      final valid =
          current?.id == appointment.id &&
          current?.status == AppointmentStatus.held;
      final confirmed =
          current?.id == appointment.id &&
          current?.status == AppointmentStatus.confirmed;
      final seconds = appointment.holdExpiresAt
          .difference(c.now)
          .inSeconds
          .clamp(0, 600);
      Future<void> confirm({bool retry = false}) async {
        if (retry) {
          await c.retry();
        } else {
          await c.confirm();
        }
        if (context.mounted &&
            c.activeAppointment?.status == AppointmentStatus.confirmed) {
          Navigator.pop(context, true);
        } else if (context.mounted &&
            c.activeAppointment == null &&
            !c.unresolvedMutation &&
            c.failure == null) {
          Navigator.pop(context, false);
        }
      }

      return PopScope(
        canPop: !c.busy,
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: 'Confirm appointment time',
            closeLabel: 'Close time confirmation',
            maxHeight: 620,
            onClose: c.busy ? null : () => Navigator.pop(context),
            child: _stack([
              MomAppointmentSummary(appointment: appointment, title: 'This consultation'),
              if (valid) ...[
                const Text(
                  'Your selected time is on hold',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                Text(
                  'Confirm within ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reminder,
                  title: const Text(
                    'Remind me 15 minutes before',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'We will check notification permissions before turning this on.',
                    style: TextStyle(fontSize: 13),
                  ),
                  onChanged: c.canEdit
                      ? (v) => onReminderChanged(v ?? false)
                      : null,
                ),
              ] else if (confirmed)
                const Text(
                  'Appointment confirmed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: MomHomeTokens.teal),
                )
              else if (!c.unresolvedMutation)
                const BookingNotice(title: 'Your selected time is no longer on hold. Choose another time.'),
              if (c.failure != null || c.message != null)
                BookingNotice(
                  title: c.message ?? 'Could not confirm your appointment. Check your connection and try again.',
                  action: !c.unresolvedMutation && !c.busy
                      ? TextButton(
                          onPressed: c.loading ? null : c.load,
                          child: const Text('Check latest appointment'),
                        )
                      : null,
                ),
              if (confirmed)
                FilledButton(
                  onPressed: c.canEdit
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Continue intake form'),
                )
              else if (c.unresolvedMutation)
                FilledButton(
                  onPressed: c.busy ? null : () => confirm(retry: true),
                  child: Text(c.busy ? 'Confirming…' : 'Retry last submission'),
                )
              else if (valid)
                FilledButton(
                  onPressed: c.canEdit ? confirm : null,
                  child: Text(c.busy ? 'Confirming…' : 'Confirm appointment'),
                ),
              if (!confirmed)
                TextButton(
                  onPressed: c.canEdit
                      ? () async {
                          if (valid) await c.cancel();
                          if (context.mounted &&
                              c.activeAppointment == null &&
                              !c.unresolvedMutation) {
                            Navigator.pop(context);
                          }
                        }
                      : null,
                  child: const Text('Choose another time'),
                ),
            ]),
          ),
        ),
      );
    },
  );
}
