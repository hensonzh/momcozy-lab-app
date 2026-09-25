import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../shared/care/care_labels.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../../../shared/zoned_time.dart';
import '../../appointments/application/appointment_presentation.dart';
import '../../appointments/presentation/appointments_page.dart';
import '../../shared/workbench_widgets.dart';
import '../application/clients_controller.dart';

class WorkbenchClientsPage extends StatefulWidget {
  const WorkbenchClientsPage({
    super.key,
    required this.createController,
    required this.onClient,
  });
  final WorkbenchClientsController Function() createController;
  final Future<void> Function(String patientRef) onClient;
  @override
  State<WorkbenchClientsPage> createState() => _WorkbenchClientsPageState();
}

class _WorkbenchClientsPageState extends State<WorkbenchClientsPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  final query = TextEditingController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!controller.loading) unawaited(controller.load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    query.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    await widget.onClient(id);
    if (mounted) await controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.data;
      return WorkbenchPageBody(
        children: [
          WorkbenchHeading(
            title: 'My clients',
            subtitle: 'View clients and services assigned to you',
            actions: [
              IconButton(
                tooltip: 'Refresh clients',
                onPressed: controller.loading ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: TextField(
                  controller: query,
                  onChanged: controller.search,
                  onSubmitted: (_) => controller.load(),
                  decoration: const InputDecoration(
                    labelText: 'Search by name or client ID',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in WorkbenchClientFilter.values)
                    ChoiceChip(
                      label: Text(switch (filter) {
                        WorkbenchClientFilter.all => 'All',
                        WorkbenchClientFilter.active => 'In care',
                        WorkbenchClientFilter.completed => 'Ended',
                      }),
                      selected: controller.filter == filter,
                      onSelected: (_) => controller.setFilter(filter),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading clients'),
          if (controller.failure != null)
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          if (data != null && data.items.isEmpty)
            Card(
              child: ProductEmptyView(
                title: controller.query.isEmpty
                    ? 'No clients yet'
                    : 'No matching clients',
                description: controller.query.isEmpty
                    ? 'Clients assigned to your services will appear here.'
                    : 'Adjust your filters or search by client ID.',
              ),
            ),
          if (data != null)
            for (final client in data.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 12,
                          spacing: 16,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.displayName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Client ${client.patientRef.substring(0, client.patientRef.length.clamp(0, 8))} · ${client.services.length} services',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MomCozyColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton(
                              onPressed: () => _open(client.patientRef),
                              child: const Text('View client'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final service in client.services)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  service.package.publicName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                WorkbenchBadge(
                                  episodeStatusLabels[service.episode.status]!,
                                ),
                                Text(
                                  '${careStageLabels[service.episode.stage]} · ${service.episode.remainingSessions} consultations left',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MomCozyColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          if (data != null)
            WorkbenchPagination(
              total: data.total,
              offset: data.offset,
              limit: data.limit,
              loading: controller.loading,
              onPage: controller.page,
            ),
        ],
      );
    },
  );
}

class WorkbenchClientPage extends StatefulWidget {
  const WorkbenchClientPage({
    super.key,
    required this.createController,
    required this.timezone,
    required this.onBack,
    required this.onOpen,
    required this.onReport,
  });
  final WorkbenchClientController Function() createController;
  final String timezone;
  final VoidCallback onBack;
  final ValueChanged<String> onReport;
  final Future<void> Function(
    WorkbenchAppointment item,
    WorkbenchAppointmentAction action,
  )
  onOpen;
  @override
  State<WorkbenchClientPage> createState() => _WorkbenchClientPageState();
}

class _WorkbenchClientPageState extends State<WorkbenchClientPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!controller.loading) unawaited(controller.load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _open(
    WorkbenchAppointment item,
    WorkbenchAppointmentAction action,
  ) async {
    await widget.onOpen(item, action);
    if (mounted) await controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.data;
      final client = data?.client;
      return WorkbenchPageBody(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to clients'),
            ),
          ),
          const SizedBox(height: 16),
          WorkbenchHeading(
            title: client?.displayName ?? 'Client profile',
            subtitle: client?.deliveryDate == null
                ? null
                : 'Delivery date ${client!.deliveryDate}',
            actions: [
              IconButton(
                tooltip: 'Refresh client profile',
                onPressed: controller.loading ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading client profile',
            ),
          if (controller.failure != null)
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          if (client != null && !client.hasCaseAccess)
            const Card(
              child: ProductEmptyView(
                title: 'Client has not consented to case access',
                description:
                    'Assigned appointments and services are visible. Case details require the client\'s consent.',
              ),
            ),
          if (client != null)
            for (final service in client.services)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ServiceCard(
                  service: service,
                  timezone: widget.timezone,
                  onReport: () => widget.onReport(service.episode.id),
                ),
              ),
          if (data != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Consultation history',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (data.appointments.isEmpty)
              const Card(child: ProductEmptyView(title: 'No appointments yet')),
            if (data.appointments.isNotEmpty)
              WorkbenchAppointmentList(
                items: data.appointments,
                now: data.serverTime,
                onOpen: _open,
                onClient: null,
              ),
            WorkbenchPagination(
              total: data.appointmentTotal,
              offset: data.offset,
              limit: data.limit,
              loading: controller.loading,
              onPage: controller.page,
            ),
          ],
        ],
      );
    },
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.timezone,
    required this.onReport,
  });
  final ClientCareService service;
  final String timezone;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) {
    final episode = service.episode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  service.package.publicName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                WorkbenchBadge(episodeStatusLabels[episode.status]!),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${careStageLabels[episode.stage]} · ${episode.remainingSessions} of ${episode.totalSessions} consultations left',
            ),
            const SizedBox(height: 8),
            Text(
              episode.startsAt == null || episode.endsAt == null
                  ? 'Service period starts when the care plan is published'
                  : '${dateInTimezone(episode.startsAt!, timezone)} — ${dateInTimezone(episode.endsAt!, timezone)}',
              style: const TextStyle(
                color: MomCozyColors.mutedForeground,
                fontSize: 13,
              ),
            ),
            if (!service.caseConsent)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: WorkbenchBadge('Case access awaiting consent'),
              ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('View follow-ups & reports'),
            ),
          ],
        ),
      ),
    );
  }
}
