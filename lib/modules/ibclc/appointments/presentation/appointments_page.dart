import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/care/care_labels.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../../../shared/zoned_time.dart';
import '../../shared/workbench_widgets.dart';
import '../application/appointment_presentation.dart';
import '../application/appointments_controller.dart';

class WorkbenchAppointmentsPage extends StatefulWidget {
  const WorkbenchAppointmentsPage({
    super.key,
    required this.createController,
    required this.onOpen,
    required this.onClient,
  });
  final WorkbenchAppointmentsController Function() createController;
  final Future<void> Function(
    WorkbenchAppointment item,
    WorkbenchAppointmentAction action,
  )
  onOpen;
  final Future<void> Function(String patientRef) onClient;
  @override
  State<WorkbenchAppointmentsPage> createState() =>
      _WorkbenchAppointmentsPageState();
}

class _WorkbenchAppointmentsPageState extends State<WorkbenchAppointmentsPage>
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
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final current =
        controller.date ??
        controller.data?.date ??
        LocalDate.fromDateTime(controller.now);
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Choose appointment date',
    );
    if (mounted && selected != null) {
      await controller.selectDate(LocalDate.fromDateTime(selected));
    }
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
      return WorkbenchPageBody(
        children: [
          WorkbenchHeading(
            title: controller.date == null
                ? 'Today\'s appointments'
                : 'Appointments',
            subtitle: data == null ? null : '${data.date} · ${data.timezone}',
            actions: [
              OutlinedButton.icon(
                onPressed: _date,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('Choose date'),
              ),
              if (controller.date != null)
                TextButton(
                  onPressed: () => controller.selectDate(null),
                  child: const Text('Today'),
                ),
              IconButton(
                tooltip: 'Refresh appointment',
                onPressed: controller.loading ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading appointments',
            ),
          if (controller.failure != null)
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          if (data != null && data.items.isEmpty)
            const Card(
              child: ProductEmptyView(
                title: 'No appointments for this day',
                description: 'Confirmed consultations will appear here.',
              ),
            ),
          if (data != null && data.items.isNotEmpty)
            WorkbenchAppointmentList(
              items: data.items,
              now: controller.now,
              onOpen: _open,
              onClient: widget.onClient,
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

class WorkbenchAppointmentList extends StatelessWidget {
  const WorkbenchAppointmentList({
    super.key,
    required this.items,
    required this.now,
    required this.onOpen,
    required this.onClient,
  });
  final List<WorkbenchAppointment> items;
  final DateTime now;
  final void Function(
    WorkbenchAppointment item,
    WorkbenchAppointmentAction action,
  )
  onOpen;
  final void Function(String patientRef)? onClient;
  static const _flex = [15, 11, 6, 16, 10, 12, 14];
  Widget _row(List<Widget> cells) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var index = 0; index < cells.length; index++)
        Expanded(
          flex: _flex[index],
          child: Padding(
            padding: EdgeInsets.only(right: index == cells.length - 1 ? 0 : 12),
            child: cells[index],
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final table =
          constraints.maxWidth >= 720 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (table)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                color: MomCozyColors.muted.withValues(alpha: .5),
                child: _row([
                  for (final label in [
                    'Time',
                    'Client',
                    'State',
                    'Service package',
                    'Service stage',
                    'Status',
                    'Action',
                  ])
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ]),
              ),
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0 || table) const Divider(),
              _item(items[index], table),
            ],
          ],
        ),
      );
    },
  );

  Widget _item(WorkbenchAppointment item, bool table) {
    final appointment = item.appointment;
    final view = WorkbenchAppointmentPresentation.forAppointment(item, now);
    final badge = WorkbenchBadge(
      view.status,
      color: view.tone == WorkbenchStatusTone.care
          ? MomCozyColors.care
          : view.tone == WorkbenchStatusTone.attention
          ? MomCozyColors.primary
          : MomCozyColors.mutedForeground,
      background: view.tone == WorkbenchStatusTone.care
          ? MomCozyColors.careSoft
          : view.tone == WorkbenchStatusTone.attention
          ? MomCozyColors.roseSoft
          : MomCozyColors.muted,
    );
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appointmentDay(appointment.startsAt, appointment.timezone),
          style: const TextStyle(
            color: MomCozyColors.mutedForeground,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${zonedClock(appointment.startsAt, appointment.timezone)}–${zonedClock(appointment.endsAt, appointment.timezone)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          '${appointment.duration.inMinutes} min',
          style: const TextStyle(
            fontSize: 11,
            color: MomCozyColors.mutedForeground,
          ),
        ),
      ],
    );
    final client = onClient == null
        ? Text(
            item.displayName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          )
        : TextButton(
            onPressed: () => onClient!(item.patientRef),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            child: Text(item.displayName, style: const TextStyle(fontSize: 13)),
          );
    final primaryAction = FilledButton(
      onPressed: item.caseConsent ? () => onOpen(item, view.action) : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      ),
      child: Text(
        item.caseConsent ? view.actionLabel : 'Awaiting consent',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primaryAction,
        if (item.caseConsent &&
            appointment.intakeVersion > 0 &&
            view.action != WorkbenchAppointmentAction.prepare)
          TextButton(
            onPressed: () => onOpen(item, WorkbenchAppointmentAction.prepare),
            child: const Text('Intake details', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
    final package = Text(
      item.package.publicName,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    final stage = Text(
      careStageLabels[item.episode.stage]!,
      style: const TextStyle(fontSize: 12),
    );
    return Padding(
      padding: const EdgeInsets.all(18),
      child: table
          ? _row([
              time,
              client,
              Text(appointment.region, style: const TextStyle(fontSize: 12)),
              package,
              stage,
              Align(alignment: Alignment.centerLeft, child: badge),
              action,
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [time, badge],
                ),
                const SizedBox(height: 8),
                client,
                package,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [Text('State: ${appointment.region}'), stage],
                ),
                const SizedBox(height: 14),
                action,
              ],
            ),
    );
  }
}
