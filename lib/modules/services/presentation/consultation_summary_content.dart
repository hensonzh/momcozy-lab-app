import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../domain/care/documentation.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/zoned_time.dart';
import 'mom_appointment_widgets.dart';

class ConsultationSummaryContent extends StatelessWidget {
  const ConsultationSummaryContent({
    super.key,
    required this.data,
    required this.onTask,
    required this.onProgress,
    this.onPlan,
  });
  final PatientCareSummary data;
  final ValueChanged<String> onTask;
  final VoidCallback onProgress;
  final VoidCallback? onPlan;

  Text _text(
    String text,
    double size, {
    Color color = MomHomeTokens.ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.55,
  }) => Text(
    text,
    style: MomHomeTokens.text(
      size,
      color: color,
      weight: weight,
      height: height,
    ),
  );
  Widget _heading(String title, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _text(title, 18, weight: FontWeight.w700, height: 1.4),
      const SizedBox(height: 6),
      _text(hint, 12, color: MomHomeTokens.secondary),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final plan = data.publication;
    if (plan == null) {
      final failed = [
        ConsultationStatus.failed,
        ConsultationStatus.noShow,
        ConsultationStatus.cancelled,
      ].contains(data.consultation?.status);
      final ended = data.appointment.status == AppointmentStatus.completed;
      return SummaryStateCard(
        title: failed
            ? 'This consultation was not completed'
            : ended
            ? '${data.appointment.publicProviderName} is preparing your recommendations'
            : 'No summary available yet',
        description: failed
            ? 'Return to Service Progress to see what comes next.'
            : ended
            ? 'Once your consultant publishes it, you will see recommended actions, what to watch for, and next steps here.'
            : 'After your consultation, recommendations confirmed by your IBCLC will appear here.',
        pending: ended && !failed,
        action: OutlinedButton(
          onPressed: onProgress,
          child: const Text('View service progress'),
        ),
      );
    }
    final publisherName = englishCareExpertName(
      plan.publisherName,
      providerId: data.appointment.providerId,
    );
    final primary =
        plan.tasks
            .where(
              (task) =>
                  task.status == CareTaskStatus.pending ||
                  task.status == CareTaskStatus.inProgress,
            )
            .firstOrNull ??
        plan.tasks.firstOrNull;
    final next = plan.tasks.where((task) => task != primary).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MomSettingsCard(
          gradient: MomHomeTokens.plan,
          children: [
            MomServiceExpertIdentity(
              name: publisherName,
              label: 'Your consultation summary',
            ),
            _text(plan.title, 20, weight: FontWeight.w700, height: 1.4),
            _text(plan.summary, 14),
            _text(
              'Confirmed ${appointmentDay(plan.publishedAt, data.appointment.timezone)}',
              11,
              color: MomHomeTokens.secondary,
            ),
          ],
        ),
        if (primary != null) ...[
          const SizedBox(height: 14),
          MomSettingsCard(
            color: MomHomeTokens.milk.colors.first,
            children: [
              _text(
                'One thing to try today',
                12,
                weight: FontWeight.w700,
                color: MomHomeTokens.rose,
              ),
              _text(
                primary.content.title,
                20,
                weight: FontWeight.w700,
                height: 1.4,
              ),
              _text(
                primary.content.description,
                14,
                color: MomHomeTokens.secondary,
              ),
              FilledButton(
                onPressed: () => onTask(primary.content.sourceKey),
                child: const Text('See how'),
              ),
            ],
          ),
        ],
        if (next.isNotEmpty) ...[
          const SizedBox(height: 14),
          _heading('Over the next few days', 'One small step at a time'),
          for (final task in next) ...[
            const SizedBox(height: 10),
            Semantics(
              button: true,
              child: InkWell(
                onTap: () => onTask(task.content.sourceKey),
                borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
                child: MomSettingsCard(
                  children: [
                    _text(
                      task.content.displayDueLabel,
                      12,
                      color: MomHomeTokens.rose,
                    ),
                    _text(task.content.title, 14, weight: FontWeight.w700),
                    _text(
                      task.content.description,
                      13,
                      color: MomHomeTokens.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 14),
        _heading('Changes to notice', 'Notice what you can'),
        const SizedBox(height: 10),
        _text(
          'Notice how the next feeding feels and whether it brings you closer to the goal you agreed on together.',
          13,
          color: MomHomeTokens.secondary,
        ),
        for (final goal in plan.goals)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: MomHomeTokens.mint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: MomHomeTokens.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _text(goal, 13)),
              ],
            ),
          ),
        if (onPlan != null)
          TextButton(
            onPressed: onPlan,
            child: const Text('View full care plan →'),
          ),
        const SizedBox(height: 14),
        MomSettingsCard(
          color: MomHomeTokens.mint,
          children: [
            _text(
              'If you need more help',
              14,
              weight: FontWeight.w700,
              color: MomHomeTokens.teal,
            ),
            _text(
              'If you still feel uncomfortable or have new concerns, note any changes and tell $publisherName at your next follow-up. For emergencies, contact local emergency services.',
              13,
              color: MomHomeTokens.secondary,
            ),
          ],
        ),
        const SizedBox(height: 14),
        MomSettingsCard(
          padding: EdgeInsets.zero,
          children: [
            ExpansionTile(
              tilePadding: const EdgeInsets.all(16),
              shape: const Border(),
              collapsedShape: const Border(),
              title: _text(
                'Consultation & service details',
                14,
                weight: FontWeight.w700,
              ),
              subtitle: _text(
                '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · $publisherName',
                12,
                color: MomHomeTokens.secondary,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Divider(height: 1),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cells = [
                      (
                        'This consultation',
                        zonedRange(
                          data.appointment.startsAt,
                          data.appointment.endsAt,
                          data.appointment.timezone,
                        ),
                      ),
                      (
                        'Service period',
                        data.episode.endsAt == null
                            ? 'Awaiting confirmation'
                            : 'Until ${appointmentDay(data.episode.endsAt!, data.appointment.timezone)}',
                      ),
                      (
                        'Consultations left',
                        '${data.episode.remainingSessions}',
                      ),
                      (
                        'Published by',
                        appointmentDay(
                          plan.publishedAt,
                          data.appointment.timezone,
                        ),
                      ),
                    ];
                    final columns =
                        MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 1 : 2;
                    return Wrap(
                      children: [
                        for (final (label, value) in cells)
                          SizedBox(
                            width: constraints.maxWidth / columns,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 14, 8, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _text(
                                    label,
                                    12,
                                    color: MomHomeTokens.secondary,
                                  ),
                                  const SizedBox(height: 4),
                                  _text(value, 14, weight: FontWeight.w700),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onProgress,
                    child: const Text('View service progress'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class SummaryStateCard extends StatelessWidget {
  const SummaryStateCard({
    super.key,
    required this.title,
    required this.description,
    this.pending = false,
    this.loading = false,
    this.action,
  });
  final String title, description;
  final bool pending, loading;
  final Widget? action;
  @override
  Widget build(BuildContext context) => MomSettingsCard(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: ExcludeSemantics(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MomHomeTokens.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              pending || loading
                  ? Icons.schedule_outlined
                  : Icons.description_outlined,
              size: 24,
              color: MomHomeTokens.teal,
            ),
          ),
        ),
      ),
      if (pending)
        Text(
          'Summary in progress',
          style: MomHomeTokens.text(
            12,
            weight: FontWeight.w700,
            color: MomHomeTokens.teal,
          ),
        ),
      Text(title, style: MomHomeTokens.text(20, weight: FontWeight.w700)),
      Text(
        description,
        style: MomHomeTokens.text(
          13,
          height: 1.55,
          color: MomHomeTokens.secondary,
        ),
      ),
      if (loading) const LinearProgressIndicator(),
      ?action,
    ],
  );
}
