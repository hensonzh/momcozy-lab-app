import '../../../shared/design_system/mom_home_tokens.dart';
import '../../mom/presentation/mom_home_sections.dart';
import '../../../core/observability/momcozy_observability.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../../../shared/zoned_time.dart';
import '../../../shared/care/care_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';

class ExpertSupportSection extends StatefulWidget {
  const ExpertSupportSection({
    super.key,
    required this.repository,
    required this.onCatalog,
    required this.onProgress,
    required this.onBook,
    this.appointmentRepository,
    this.observability,
    this.portraitForProvider,
    this.onAppointment,
    this.onIntake,
    this.onJoin,
    this.now = DateTime.now,
  });
  final AppointmentRepository? appointmentRepository;
  final MomCozyObservability? observability;
  final ImageProvider? Function(String providerId)? portraitForProvider;
  final Future<void> Function(CareAppointment)? onAppointment, onIntake, onJoin;
  final DateTime Function() now;
  final CareRepository repository;
  final Future<void> Function() onCatalog;
  final Future<void> Function(CareEpisode) onProgress, onBook;
  @override
  State<ExpertSupportSection> createState() => _ExpertSupportSectionState();
}

class _ExpertSupportSectionState extends State<ExpertSupportSection> {
  late final controller = CareOverviewController(
    widget.repository,
    appointmentRepository: widget.appointmentRepository,
    now: widget.now,
  );
  Timer? _clock;
  bool _navigating = false;

  Future<void> _open(Future<void> Function() navigate) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await navigate();
      if (mounted) await controller.load();
    } finally {
      _navigating = false;
    }
  }

  VoidCallback? _appointmentAction(
    String episodeId,
    Future<void> Function(CareAppointment)? action,
  ) {
    if (action == null) return null;
    return () {
      final appointment = controller.nextAppointment(episodeId);
      if (appointment != null) unawaited(_open(() => action(appointment)));
    };
  }

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && controller.bookingContexts.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.overview;
      final activeCount =
          data?.episodes
              .where(
                (episode) =>
                    episode.status == CareEpisodeStatus.active &&
                    (episode.endsAt == null ||
                        episode.endsAt!.isAfter(widget.now())),
              )
              .length ??
          0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MomHomeSectionHeader(title: 'Expert care plans'),
          const SizedBox(height: 7),
          MomExpertPlanEntry(
            onTap: () {
              widget.observability?.recordFeatureEvent(
                'mom_home',
                'mom_home_expert_plan_click',
              );
              unawaited(_open(widget.onCatalog));
            },
          ),
          if (controller.loading && data == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: ProductLoadingView(),
            )
          else if (controller.failure case final failure?)
            ProductErrorView(failure: failure, onRetry: controller.load),
          if (data?.episodes.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  'My care plan',
                  style: MomHomeTokens.text(
                    14,
                    weight: FontWeight.w700,
                    color: const Color(0xffa57d7d),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff3e8ee),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeCount active service${activeCount == 1 ? '' : 's'}',
                    style: MomHomeTokens.text(11, color: MomHomeTokens.rose),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          for (final episode in data?.episodes ?? <CareEpisode>[])
            if (controller.catalog!.packages
                    .where((item) => item.id == episode.packageId)
                    .firstOrNull
                case final package?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpertServiceCard(
                  portrait: episode.assignedIbclcId == null
                      ? null
                      : widget.portraitForProvider?.call(
                          episode.assignedIbclcId!,
                        ),
                  episode: episode,
                  package: package,
                  appointment: controller.nextAppointment(episode.id),
                  appointmentLoading: controller.bookingLoading,
                  appointmentFailed: controller.bookingFailures.contains(
                    episode.id,
                  ),
                  now: widget.now(),
                  onAppointment: _appointmentAction(
                    episode.id,
                    widget.onAppointment,
                  ),
                  onIntake: _appointmentAction(episode.id, widget.onIntake),
                  onJoin: _appointmentAction(episode.id, widget.onJoin),
                  provider: controller.catalog!.providers
                      .where((item) => item.id == episode.assignedIbclcId)
                      .firstOrNull,
                  onProgress: () {
                    widget.observability?.recordFeatureEvent(
                      'mom_home',
                      'mom_home_service_progress_click',
                    );
                    unawaited(_open(() => widget.onProgress(episode)));
                  },
                  onBook: () {
                    widget.observability?.recordFeatureEvent(
                      'mom_home',
                      'mom_home_consultation_book_click',
                    );
                    unawaited(_open(() => widget.onBook(episode)));
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MomHomeSurface(
                  gradient: MomHomeTokens.plan,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Purchased plan details could not load'),
                        TextButton(
                          onPressed: () {
                            widget.observability?.recordFeatureEvent(
                              'mom_home',
                              'mom_home_service_progress_click',
                            );
                            unawaited(_open(() => widget.onProgress(episode)));
                          },
                          child: const Text('Service progress ›'),
                        ),
                        TextButton(
                          onPressed: controller.load,
                          child: const Text('Reload plan details'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class ExpertServiceCard extends StatelessWidget {
  const ExpertServiceCard({
    super.key,
    required this.episode,
    required this.package,
    required this.onProgress,
    required this.onBook,
    this.provider,
    this.portrait,
    this.credential,
    this.appointment,
    this.appointmentLoading = false,
    this.appointmentFailed = false,
    this.onAppointment,
    this.onIntake,
    this.onJoin,
    this.now,
  });
  final CareAppointment? appointment;
  final bool appointmentLoading, appointmentFailed;
  final VoidCallback? onAppointment, onIntake, onJoin;
  final DateTime? now;
  final CareEpisode episode;
  final ServicePackage package;
  final CareProvider? provider;
  final ImageProvider? portrait;
  final String? credential;
  final VoidCallback onProgress, onBook;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final stackDetails = largeText || MediaQuery.sizeOf(context).width <= 360;
    final instant = now ?? DateTime.now();
    final expired = episode.endsAt != null && !episode.endsAt!.isAfter(instant);
    final days = episode.endsAt == null
        ? package.durationDays
        : (episode.endsAt!.difference(instant).inSeconds /
                  Duration.secondsPerDay)
              .ceil()
              .clamp(0, package.durationDays);
    final supportLabel = '$days day${days == 1 ? '' : 's'} of support';
    final remaining = episode.remainingSessions;
    final sessionsLabel =
        '$remaining consultation${remaining == 1 ? '' : 's'} left';
    final fallback = ColoredBox(
      color: MomHomeTokens.mint,
      child: Center(
        child: Icon(Icons.person_outline, color: MomHomeTokens.teal, size: 24),
      ),
    );
    final name =
        appointment?.publicProviderName ??
        provider?.publicName ??
        'Consultant not assigned yet';
    return MomHomeSurface(
      gradient: MomHomeTokens.plan,
      radius: 23,
      border: MomHomeTokens.border,
      child: Stack(
        children: [
          Positioned(
            right: -31,
            top: -35,
            child: momDecoration('imgDecorationServiceMintGlow', 104, 104),
          ),
          Positioned(
            right: 15,
            top: 4,
            child: momDecoration('imgDecorationServiceLeaf', 46, 54),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 4, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (largeText) ...[
                  Text(
                    package.publicName,
                    style: MomHomeTokens.text(
                      16,
                      weight: FontWeight.w700,
                      color: const Color(0xff836262),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _progressButton(),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.publicName,
                          style: MomHomeTokens.text(
                            16,
                            weight: FontWeight.w700,
                            color: const Color(0xff836262),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _progressButton(),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: 44,
                        child: portrait == null
                            ? fallback
                            : Image(
                                image: portrait!,
                                fit: BoxFit.cover,
                                alignment: Alignment.bottomCenter,
                                frameBuilder: (context, child, frame, sync) =>
                                    frame == null ? fallback : child,
                                errorBuilder: (context, error, stack) =>
                                    fallback,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: MomHomeTokens.text(
                              15,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            credential ??
                                (provider == null && appointment == null
                                    ? 'Confirm your consultant when booking'
                                    : 'IBCLC'),
                            style: MomHomeTokens.text(
                              10,
                              color: const Color(0xff7f7873),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (stackDetails) ...[
                  _benefit(MomCozyLineGlyph.calendar, supportLabel, false),
                  const SizedBox(height: 8),
                  _benefit(MomCozyLineGlyph.consultation, sessionsLabel, false),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _benefit(
                          MomCozyLineGlyph.calendar,
                          supportLabel,
                          false,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _benefit(
                          MomCozyLineGlyph.consultation,
                          sessionsLabel,
                          false,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: MomHomeTokens.border),
                if (appointment != null ||
                    appointmentLoading ||
                    appointmentFailed ||
                    !episode.canBook ||
                    expired) ...[
                  const SizedBox(height: 10),
                  if (expired)
                    Text(
                      'Service expired',
                      style: MomHomeTokens.text(
                        12,
                        color: MomHomeTokens.secondary,
                      ),
                    )
                  else
                    _appointmentDetails(stackDetails),
                ],
                const SizedBox(height: 8),
                _footer(stackDetails, expired),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(bool stacked, bool expired) {
    final status = Text(
      expired ? 'Service expired' : episodeStatusLabels[episode.status]!,
      style: MomHomeTokens.text(10, color: MomHomeTokens.teal),
    );
    final action = FilledButton(
      onPressed: appointmentLoading || appointmentFailed
          ? null
          : appointment != null
          ? _appointmentAction
          : episode.canBook && !expired
          ? onBook
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: MomHomeTokens.expertAction,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: MomHomeTokens.text(12, weight: FontWeight.w600),
      ),
      child: Text(
        appointment == null ? 'Book a consultation' : _appointmentActionLabel,
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [status, const SizedBox(height: 8), action],
      );
    }
    return Row(
      children: [
        Expanded(child: status),
        const SizedBox(width: 8),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: action),
        ),
      ],
    );
  }

  Widget _progressButton() => TextButton(
    onPressed: onProgress,
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xff799888),
      minimumSize: const Size(96, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: MomHomeTokens.text(12, weight: FontWeight.w700),
    ),
    child: const Text('Service progress ›'),
  );

  bool get _needsIntake =>
      appointment?.status == AppointmentStatus.confirmed &&
      appointment!.intakeVersion == 0 &&
      onIntake != null;
  bool get _canJoin =>
      appointment?.status == AppointmentStatus.inProgress && onJoin != null;
  VoidCallback? get _appointmentAction => _needsIntake
      ? onIntake
      : _canJoin
      ? onJoin
      : onAppointment;
  String get _appointmentActionLabel => _needsIntake
      ? 'Complete intake'
      : _canJoin
      ? 'Join consultation'
      : appointment!.status == AppointmentStatus.held
      ? 'Confirm appointment'
      : 'View appointment';

  Widget _appointmentDetails(bool largeText) {
    final value = appointment;
    final showAppointment =
        value != null && !appointmentLoading && !appointmentFailed;
    final copy = appointmentLoading
        ? 'Loading appointment…'
        : appointmentFailed
        ? 'Appointment could not load. Check Service Progress.'
        : value != null
        ? '${appointmentDay(value.startsAt, value.timezone)} · ${zonedRange(value.startsAt, value.endsAt, value.timezone)}'
        : episode.canBook
        ? 'Your next consultation is ready to book'
        : episode.remainingSessions == 0
        ? 'All consultations in this package have been used'
        : episodeStatusLabels[episode.status]!;
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showAppointment ? 'Next consultation' : 'Continue',
          style: const TextStyle(
            fontSize: MomCozyTypography.labelSize,
            height: 1.5,
            color: MomCozyColors.expertMuted,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          copy,
          style: const TextStyle(
            fontSize: MomCozyTypography.captionSize,
            height: 1.6,
            color: MomCozyColors.expertInk,
          ),
        ),
      ],
    );
    if (!showAppointment) return detail;
    final state = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: MomCozyColors.expertCountdownSurface,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _countdown(value),
        style: const TextStyle(
          fontSize: 10,
          height: 1.4,
          color: MomCozyColors.expertMuted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [detail, const SizedBox(height: 8), state],
      );
    }
    return Row(
      children: [
        Expanded(child: detail),
        const SizedBox(width: 8),
        state,
      ],
    );
  }

  String _countdown(CareAppointment value) {
    if (value.status == AppointmentStatus.inProgress) return 'In consultation';
    if (value.status == AppointmentStatus.held) return 'Awaiting confirmation';
    final instant = now ?? DateTime.now();
    if (!instant.isBefore(value.endsAt)) return 'Time passed';
    if (!instant.isBefore(value.startsAt)) return 'Time to join';
    final seconds = value.startsAt.difference(instant).inSeconds;
    String two(int v) => v.toString().padLeft(2, '0');
    final clock = '${two(seconds ~/ 3600 % 24)}:${two(seconds ~/ 60 % 60)}';
    return seconds >= 86400
        ? '${seconds ~/ 86400} days $clock'
        : '$clock:${two(seconds % 60)}';
  }

  Widget _benefit(MomCozyLineGlyph icon, String label, bool narrow) =>
      Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: icon == MomCozyLineGlyph.calendar
              ? const Color(0xfff5f0e8)
              : const Color(0xfff2edf4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: MomHomeTokens.mint,
                shape: BoxShape.circle,
              ),
              child: momDecoration(
                icon == MomCozyLineGlyph.calendar
                    ? 'imgIconCalendar'
                    : 'imgIconConsultation',
                16,
                16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: MomHomeTokens.text(12, color: const Color(0xff3f3b38)),
              ),
            ),
          ],
        ),
      );
}
