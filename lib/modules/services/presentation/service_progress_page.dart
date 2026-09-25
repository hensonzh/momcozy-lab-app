import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/care_episode.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';
import 'service_timeline.dart';

class ServiceProgressPage extends StatefulWidget {
  const ServiceProgressPage({
    super.key,
    required this.repository,
    required this.episodeId,
    required this.onBack,
    required this.onBook,
    this.appointmentRepository,
    this.onOpenAppointment,
    this.onRenew,
  });
  final CareRepository repository;
  final String episodeId;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onBook;
  final AppointmentRepository? appointmentRepository;
  final ValueChanged<CareAppointment>? onOpenAppointment;
  final VoidCallback? onRenew;
  @override
  State<ServiceProgressPage> createState() => _ServiceProgressPageState();
}

class _ServiceProgressPageState extends State<ServiceProgressPage> {
  late final controller = CareOverviewController(widget.repository);
  List<CareAppointment> _appointments = [];
  bool _appointmentLoading = false, _appointmentFailed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _generation++;
    controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    await controller.load();
    if (!mounted || generation != _generation || controller.failure != null) {
      return;
    }
    if (!controller.overview!.episodes.any((e) => e.id == widget.episodeId)) {
      return;
    }
    final repository = widget.appointmentRepository;
    if (repository == null) return;
    setState(() {
      _appointmentLoading = true;
      _appointmentFailed = false;
    });
    try {
      final context = await repository.context(widget.episodeId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _appointments =
            context.appointments
                .where(
                  (a) =>
                      a.episodeId == widget.episodeId &&
                      a.status != AppointmentStatus.held,
                )
                .toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        _appointmentLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _appointmentFailed = true;
        _appointmentLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 96
            : 56,
        leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 88 : 72,
        title: const Text('Service progress'),
        leading: TextButton(onPressed: widget.onBack, child: const Text('Back')),
      ),
      body: ClipRect(
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (controller.failure case final failure?) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ProductErrorView(failure: failure, onRetry: _reload),
                );
              }
              if (controller.overview == null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MomSettingsCard(
                    children: [
                      Text(
                        'Loading service progress…',
                        style: MomHomeTokens.text(16, weight: FontWeight.w700),
                      ),
                      const LinearProgressIndicator(),
                    ],
                  ),
                );
              }
              final episode = controller.overview!.episodes
                  .where((e) => e.id == widget.episodeId)
                  .firstOrNull;
              final order = controller.overview!.orders
                  .where((o) => o.id == episode?.orderId)
                  .firstOrNull;
              final package = controller.catalog!.packages
                  .where((p) => p.id == episode?.packageId)
                  .firstOrNull;
              if (episode == null || order == null || package == null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MomSettingsCard(
                    children: [
                      Text(
                        'Could not find this package',
                        style: MomHomeTokens.text(16, weight: FontWeight.w700),
                      ),
                      Text(
                        'Your service details may have changed. Open it again from your home page.',
                        style: MomHomeTokens.text(
                          13,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onBack,
                        child: const Text('Back to home'),
                      ),
                    ],
                  ),
                );
              }
              return ServiceTimeline(
                episode: episode,
                order: order,
                package: package,
                appointments: _appointments,
                loading: controller.loading || _appointmentLoading,
                failed: _appointmentFailed,
                onRefresh: _reload,
                onBook: () => widget.onBook(episode),
                onOpenAppointment: widget.onOpenAppointment,
                onRenew: widget.onRenew,
              );
            },
          ),
        ),
      ),
    ),
  );
}
