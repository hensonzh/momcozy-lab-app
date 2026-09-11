import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/product_feedback.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/care/appointment.dart';
import '../../../features/notifications/presentation/appointment_reminder_tile.dart';
import 'appointment_summary.dart';

class AppointmentDetailPage extends StatefulWidget {
  const AppointmentDetailPage({
    super.key,
    required this.repository,
    required this.appointmentId,
  });
  final AppointmentRepository repository;
  final String appointmentId;
  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage>
    with WidgetsBindingObserver {
  CareAppointment? _appointment;
  bool _loading = true, _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.read(widget.appointmentId);
      if (mounted) {
        setState(() {
          _appointment = value;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _appointment = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _appointment;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment details'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/notifications'),
        ),
      ),
      body: MomCozyPageBody(
        child: _loading
            ? const ProductLoadingView()
            : _failed || value == null
            ? Center(
                child: ProductEmptyView(
                  title: 'This appointment could not be opened.',
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: MomCozyInsets.page,
                  children: [
                    AppointmentSummary(
                      appointment: value,
                      title: switch (value.status) {
                        AppointmentStatus.confirmed => 'Confirmed',
                        AppointmentStatus.inProgress => 'In progress',
                        AppointmentStatus.completed => 'Completed',
                        AppointmentStatus.cancelled => 'Cancelled',
                        AppointmentStatus.expired => 'Expired',
                        AppointmentStatus.held => 'Awaiting confirmation',
                      },
                    ),
                    const SizedBox(height: 16),
                    if (value.status == AppointmentStatus.confirmed)
                      AppointmentReminderTile(
                        key: ValueKey('${value.id}-${value.version}'),
                        appointmentId: value.id,
                      ),
                    if ({
                      AppointmentStatus.confirmed,
                      AppointmentStatus.inProgress,
                    }.contains(value.status)) ...[
                      FilledButton(
                        onPressed: () => context.push(
                          '/services/appointments/${value.id}/intake',
                        ),
                        child: const Text('Appointment preparation'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push(
                          '/services/appointments/${value.id}/room',
                        ),
                        child: const Text('Consultation room'),
                      ),
                    ],
                    if (value.status == AppointmentStatus.completed)
                      FilledButton(
                        onPressed: () => context.push(
                          '/services/appointments/${value.id}/summary',
                        ),
                        child: const Text(
                          'Consultation summary and expert feedback',
                        ),
                      ),
                    TextButton(
                      onPressed: () =>
                          context.push('/services/episodes/${value.episodeId}'),
                      child: const Text('Service details'),
                    ),
                    if (value.status == AppointmentStatus.confirmed)
                      TextButton(
                        onPressed: () => context.push(
                          '/services/episodes/${value.episodeId}/booking',
                        ),
                        child: const Text('Manage appointment'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
