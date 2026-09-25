import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/ibclc/workbench_followup.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../shared/workbench_widgets.dart';
import '../../reports/application/report_presentation.dart';
import '../application/followups_controller.dart';

class WorkbenchFollowupsPage extends StatefulWidget {
  const WorkbenchFollowupsPage({
    super.key,
    required this.createController,
    required this.onOpen,
    required this.onFilters,
  });
  final WorkbenchFollowupsController Function() createController;
  final Future<void> Function(String patientRef) onOpen;
  final void Function(String query, WorkbenchFollowupFilter filter) onFilters;
  @override
  State<WorkbenchFollowupsPage> createState() => _WorkbenchFollowupsPageState();
}

class _WorkbenchFollowupsPageState extends State<WorkbenchFollowupsPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  late final query = TextEditingController(text: controller.query);
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
    await widget.onOpen(id);
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
            title: 'Today\'s follow-ups',
            subtitle:
                'Review daily AI client reports and provide clinical feedback.',
            actions: [
              IconButton(
                tooltip: 'Refresh follow-ups',
                onPressed: controller.loading ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Wrap(
            spacing: 22,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in WorkbenchFollowupFilter.values)
                    ChoiceChip(
                      selected: controller.filter == filter,
                      label: Text(switch (filter) {
                        WorkbenchFollowupFilter.all =>
                          'All${data == null ? '' : ' ${data.allCount}'}',
                        WorkbenchFollowupFilter.pending =>
                          'Needs feedback${data == null ? '' : ' ${data.pendingCount}'}',
                        WorkbenchFollowupFilter.completed =>
                          'Followed up${data == null ? '' : ' ${data.completedCount}'}',
                      }),
                      onSelected: (_) {
                        unawaited(controller.setFilter(filter));
                        widget.onFilters(controller.query, filter);
                      },
                    ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: TextField(
                  controller: query,
                  onChanged: (value) {
                    controller.search(value);
                    widget.onFilters(controller.query, controller.filter);
                  },
                  onSubmitted: (_) => controller.load(),
                  decoration: const InputDecoration(
                    labelText: 'Search client or package',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (data != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${data.date} · ${data.timezone}',
                style: const TextStyle(
                  fontSize: 12,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ),
          if (controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading follow-ups'),
          if (controller.failure != null)
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          if (data != null && data.items.isEmpty)
            Card(
              child: ProductEmptyView(
                title: controller.query.isNotEmpty
                    ? 'No matching clients'
                    : switch (controller.filter) {
                        WorkbenchFollowupFilter.all =>
                          'No clients to follow up today',
                        WorkbenchFollowupFilter.pending =>
                          'No clients awaiting feedback',
                        WorkbenchFollowupFilter.completed =>
                          'No completed follow-ups',
                      },
                description:
                    'Client service and review updates will appear here.',
              ),
            ),
          if (data != null && data.items.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 700 &&
                    MediaQuery.textScalerOf(context).scale(14) < 20;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (wide)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          color: MomCozyColors.muted,
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Client name')),
                              Expanded(
                                flex: 7,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text('Service package'),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text('Service progress'),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('Follow-up status'),
                              ),
                            ],
                          ),
                        ),
                      for (
                        var index = 0;
                        index < data.items.length;
                        index++
                      ) ...[
                        if (index > 0) const Divider(height: 1),
                        _ClientRow(
                          item: data.items[index],
                          data: data,
                          wide: wide,
                          onOpen: () => _open(data.items[index].patientRef),
                        ),
                      ],
                    ],
                  ),
                );
              },
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

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.item,
    required this.data,
    required this.wide,
    required this.onOpen,
  });
  final WorkbenchFollowupClient item;
  final WorkbenchFollowups data;
  final bool wide;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final status = WorkbenchBadge(
      item.completed ? 'Followed up' : 'Needs feedback',
      color: item.completed ? MomCozyColors.care : MomCozyColors.amber,
      background: item.completed
          ? MomCozyColors.careSoft
          : MomCozyColors.amberSoft,
    );
    final services = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final value in item.services)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: Text(value.service.package.publicName),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          serviceDayLabel(
                            value.service,
                            data.date,
                            data.timezone,
                          ),
                          style: const TextStyle(
                            color: MomCozyColors.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.service.package.publicName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${serviceDayLabel(value.service, data.date, data.timezone)} · ${reportStatusLabel(value.reportState, value.reviewDecision)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
    return Semantics(
      button: true,
      label:
          '${item.displayName}, ${item.completed ? 'Followed up' : 'Needs feedback'}, view today\'s follow-up',
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: wide
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(flex: 7, child: services),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: status,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          item.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        status,
                      ],
                    ),
                    const SizedBox(height: 12),
                    services,
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
