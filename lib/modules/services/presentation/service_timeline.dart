import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/care/care_labels.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/mom_timeline_event.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../../../shared/zoned_time.dart';

class ServiceTimeline extends StatefulWidget {
  const ServiceTimeline({
    super.key,
    required this.episode,
    required this.order,
    required this.package,
    required this.appointments,
    required this.loading,
    required this.failed,
    required this.onRefresh,
    required this.onBook,
    this.onOpenAppointment,
    this.onRenew,
  });
  final CareEpisode episode;
  final CareOrder order;
  final ServicePackage package;
  final List<CareAppointment> appointments;
  final bool loading, failed;
  final Future<void> Function() onRefresh;
  final VoidCallback onBook;
  final ValueChanged<CareAppointment>? onOpenAppointment;
  final VoidCallback? onRenew;
  @override
  State<ServiceTimeline> createState() => _ServiceTimelineState();
}

class _ServiceTimelineState extends State<ServiceTimeline> {
  final _scroll = ScrollController();
  bool _away = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_position);
    _latest();
  }

  @override
  void didUpdateWidget(ServiceTimeline old) {
    super.didUpdateWidget(old);
    if (old.appointments.lastOrNull?.id != widget.appointments.lastOrNull?.id ||
        (old.loading && !widget.loading)) {
      _latest();
    }
  }

  void _latest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });
  void _position() {
    final away = _scroll.position.extentAfter > 70;
    if (away != _away) setState(() => _away = away);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final total = episode.totalSessions < 0 ? 0 : episode.totalSessions;
    final remaining = episode.remainingSessions.clamp(0, total);
    final latestExpert = widget.appointments
        .where(
          (a) =>
              a.status != AppointmentStatus.cancelled &&
              a.status != AppointmentStatus.expired,
        )
        .lastOrNull;
    final initials = latestExpert?.publicProviderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    final identity = MomSettingsCard(
      color: MomHomeTokens.mint,
      children: [
        Text(
          'My care plan',
          style: MomHomeTokens.text(11, color: MomHomeTokens.teal),
        ),
        Text(
          widget.package.publicName,
          style: MomHomeTokens.text(22, weight: FontWeight.w700),
        ),
        Text(
          episodeStatusLabels[episode.status]!,
          style: MomHomeTokens.text(
            12,
            weight: FontWeight.w700,
            color: MomHomeTokens.teal,
          ),
        ),
        Text(
          'Current stage · ${careStageLabels[episode.stage]}',
          style: MomHomeTokens.text(13, color: MomHomeTokens.teal),
        ),
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MomHomeTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: latestExpert == null
                    ? const MomCozyLineIcon(
                        MomCozyLineGlyph.users,
                        size: 24,
                        color: MomHomeTokens.teal,
                      )
                    : Text(
                        initials == null || initials.isEmpty ? 'IB' : initials,
                        style: MomHomeTokens.text(
                          18,
                          color: MomHomeTokens.teal,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                latestExpert?.publicProviderName ?? 'IBCLC team',
                style: MomHomeTokens.text(14, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Text(
          '${total - remaining} used · $remaining/$total consultations left',
          style: MomHomeTokens.text(
            14,
            weight: FontWeight.w700,
            color: MomHomeTokens.teal,
          ),
        ),
        Text(
          '${widget.order.durationDays} days of support',
          style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
        ),
      ],
    );
    final events = <_TimelineEvent>[
      _TimelineEvent(
        date: widget.order.createdAt,
        title: 'Package purchased',
        description:
            '${widget.order.durationDays} days of support · ${widget.order.totalSessions} online IBCLC consultations',
      ),
      for (final a in widget.appointments)
        _TimelineEvent(
          date: a.startsAt,
          timezone: a.timezone,
          author: a.publicProviderName,
          title: switch (a.status) {
            AppointmentStatus.completed => 'Consultation ended',
            AppointmentStatus.cancelled => 'Appointment canceled',
            AppointmentStatus.expired => 'Appointment expired',
            AppointmentStatus.inProgress => 'Consultation in progress',
            _ => 'Consultation booked',
          },
          description:
              'Appointment: ${appointmentDay(a.startsAt, a.timezone)} · ${zonedRange(a.startsAt, a.endsAt, a.timezone)}',
          actionLabel: a.status == AppointmentStatus.completed
              ? 'View consultation summary'
              : 'View appointment',
          action:
              widget.onOpenAppointment == null ||
                  [
                    AppointmentStatus.cancelled,
                    AppointmentStatus.expired,
                  ].contains(a.status)
              ? null
              : () => widget.onOpenAppointment!(a),
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return Column(
      children: [
        if (events.length > 1)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _scroll.jumpTo(0),
              child: const Text('↑ Earlier records'),
            ),
          ),
        if (widget.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 14),
                      Semantics(
                        header: true,
                        child: Text(
                          'Service history',
                          style: MomHomeTokens.text(
                            18,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < events.length; i++)
                        _EventTile(
                          event: events[i],
                          latest: i == events.length - 1,
                        ),
                      if (widget.failed)
                        MomSettingsCard(
                          children: [
                            Text(
                              'Appointment history has not refreshed. Your current service details are still here.',
                              style: MomHomeTokens.text(
                                13,
                                height: 1.55,
                                color: MomHomeTokens.secondary,
                              ),
                            ),
                            TextButton(
                              onPressed: widget.loading
                                  ? null
                                  : widget.onRefresh,
                              child: const Text('Reload appointments'),
                            ),
                          ],
                        ),
                      // Keep the existing booking path available when the server permits it.
                      if (episode.canBook)
                        FilledButton(
                          onPressed: widget.onBook,
                          child: const Text('Book consultation'),
                        ),
                      if (!episode.ongoing && widget.onRenew != null)
                        FilledButton(
                          onPressed: widget.onRenew,
                          child: const Text('Continue care'),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        'Showing current service history',
                        style: MomHomeTokens.text(
                          11,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${episodeStatusLabels[episode.status]} · Showing synced information only',
                        style: MomHomeTokens.text(
                          11,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
              if (_away && !large)
                Positioned(
                  right: 16,
                  bottom: 14,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: MomHomeTokens.surface,
                      foregroundColor: MomHomeTokens.teal,
                      side: const BorderSide(color: MomHomeTokens.border),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _latest,
                    child: const Text(
                      '↓ Back to latest records',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_away && large)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _latest,
                child: const Text('↓ Back to latest records'),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.date,
    required this.title,
    required this.description,
    this.timezone,
    this.author,
    this.actionLabel,
    this.action,
  });
  final DateTime date;
  final String title, description;
  final String? timezone, author, actionLabel;
  final VoidCallback? action;
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.latest});
  final _TimelineEvent event;
  final bool latest;
  @override
  Widget build(BuildContext context) {
    final date = event.timezone == null
        ? event.date.toLocal()
        : inTimezone(event.date, event.timezone!);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return MomTimelineEvent(
      dateLabel: '${date.month}/${date.day} · $time',
      title: event.title,
      description: event.description,
      author: event.author,
      actionLabel: event.actionLabel,
      onAction: event.action,
      latest: latest,
    );
  }
}
