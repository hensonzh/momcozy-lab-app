import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/month_selector.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../../../shared/zoned_time.dart';
import '../../appointments/application/appointment_presentation.dart';
import '../../appointments/presentation/appointments_page.dart';
import '../../shared/workbench_widgets.dart';
import '../application/calendar_controller.dart';
import '../application/calendar_timeline.dart';

class WorkbenchCalendarPage extends StatefulWidget {
  const WorkbenchCalendarPage({
    super.key,
    required this.createController,
    required this.onOpen,
    required this.onClient,
  });
  final WorkbenchCalendarController Function() createController;
  final Future<void> Function(
    WorkbenchAppointment item,
    WorkbenchAppointmentAction action,
  )
  onOpen;
  final Future<void> Function(String patientRef) onClient;
  @override
  State<WorkbenchCalendarPage> createState() => _WorkbenchCalendarPageState();
}

class _WorkbenchCalendarPageState extends State<WorkbenchCalendarPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  final horizontal = ScrollController();
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
    horizontal.dispose();
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
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final date = controller.selectedDate, start = controller.weekStart;
        final wide =
            constraints.maxWidth >= 800 &&
            MediaQuery.textScalerOf(context).scale(14) < 20;
        final timeline = start == null
            ? null
            : CalendarTimeline(
                appointments: controller.items,
                weekStart: start,
                timezone: controller.timezone!,
              );
        return WorkbenchPageBody(
          children: [
            WorkbenchHeading(
              title: 'My schedule',
              subtitle:
                  'See your scheduled client consultations on the calendar',
              actions: [
                TextButton(
                  onPressed: controller.currentWeek,
                  child: const Text('This week'),
                ),
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: date == null
                      ? null
                      : () => controller.shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: date == null
                      ? null
                      : () => controller.shiftWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                IconButton(
                  tooltip: 'Refresh schedule',
                  onPressed: controller.loading ? null : controller.load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (controller.loading)
              const LinearProgressIndicator(semanticsLabel: 'Loading schedule'),
            if (controller.failure != null)
              ProductErrorView(
                failure: controller.failure!,
                onRetry: controller.load,
              ),
            if (date != null && timeline != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${timeline.weekStart} — ${timeline.weekStart.addDays(6)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.timezone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (wide && !timeline.clockChangeWeek)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 230,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  MonthSelector(
                                    selected: date,
                                    onSelect: controller.select,
                                    today: controller.today,
                                    weekStart: timeline.weekStart,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Selected week · ${controller.items.length} appointments',
                                    style: const TextStyle(
                                      color: MomCozyColors.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, available) => Scrollbar(
                                  controller: horizontal,
                                  thumbVisibility: true,
                                  scrollbarOrientation:
                                      ScrollbarOrientation.top,
                                  notificationPredicate: (notification) =>
                                      notification.depth == 0,
                                  child: SingleChildScrollView(
                                    controller: horizontal,
                                    scrollDirection: Axis.horizontal,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: _WeekTimeline(
                                        data: timeline,
                                        columnWidth:
                                            ((available.maxWidth - 52) / 7)
                                                .clamp(88, 110),
                                        selected: date,
                                        today: controller.today,
                                        onSelect: controller.select,
                                        onOpen: (item) => _open(
                                          item,
                                          WorkbenchAppointmentPresentation.forAppointment(
                                            item,
                                            controller.serverTime!,
                                          ).action,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 280,
                            child: MonthSelector(
                              selected: date,
                              onSelect: controller.select,
                              today: controller.today,
                              weekStart: timeline.weekStart,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (timeline.clockChangeWeek)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              'Clocks change this week. Times below use each appointment\'s local time zone.',
                              style: TextStyle(
                                color: MomCozyColors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Text(
                          '$date · Daily schedule',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (controller.onDate(date).isEmpty)
                          const ProductEmptyView(
                            title: 'No appointments this day',
                          )
                        else
                          WorkbenchAppointmentList(
                            items: controller.onDate(date),
                            now: controller.serverTime!,
                            onOpen: _open,
                            onClient: widget.onClient,
                          ),
                      ],
                      if (wide && controller.items.isEmpty)
                        const ProductEmptyView(
                          title: 'No appointments this week',
                          description:
                              'Choose another date to see scheduled consultations.',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.data,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onOpen,
    required this.columnWidth,
  });
  final CalendarTimeline data;
  final LocalDate selected;
  final LocalDate? today;
  final ValueChanged<LocalDate> onSelect;
  final ValueChanged<WorkbenchAppointment> onOpen;
  final double columnWidth;
  static const hourHeight = 56.0, headingHeight = 62.0;
  @override
  Widget build(BuildContext context) {
    final height = (data.endHour - data.startHour) * hourHeight;
    return SizedBox(
      width: 52 + columnWidth * 7,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                const SizedBox(height: headingHeight),
                SizedBox(
                  height: height + 16,
                  child: Stack(
                    children: [
                      for (
                        var hour = data.startHour;
                        hour <= data.endHour;
                        hour++
                      )
                        Positioned(
                          top: (hour - data.startHour) * hourHeight,
                          left: 0,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 10,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < 7; index++)
            _day(data.weekStart.addDays(index), height),
        ],
      ),
    );
  }

  Widget _day(LocalDate day, double height) {
    final events = data.onDay(day);
    return SizedBox(
      width: columnWidth,
      child: Column(
        children: [
          SizedBox(
            height: headingHeight,
            child: TextButton(
              onPressed: () => onSelect(day),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ][day.weekday - 1],
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: day == today
                          ? MomCozyColors.primary
                          : MomCozyColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: day == selected
                  ? MomCozyColors.roseSoft.withValues(alpha: .35)
                  : MomCozyColors.card,
              border: const Border(
                left: BorderSide(color: MomCozyColors.border),
              ),
            ),
            child: Stack(
              children: [
                for (var hour = data.startHour; hour <= data.endHour; hour++)
                  Positioned(
                    top: (hour - data.startHour) * hourHeight,
                    left: 0,
                    right: 0,
                    child: const Divider(),
                  ),
                for (final event in events)
                  Positioned(
                    top:
                        (event.startMinute - data.startHour * 60) /
                        60 *
                        hourHeight,
                    height:
                        ((event.endMinute - event.startMinute) /
                                    60 *
                                    hourHeight -
                                2)
                            .clamp(18, height),
                    left: 3,
                    right: 3,
                    child: _CalendarEvent(
                      event: event,
                      timezone: data.timezone,
                      onOpen: onOpen,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEvent extends StatelessWidget {
  const _CalendarEvent({
    required this.event,
    required this.timezone,
    required this.onOpen,
  });
  final CalendarSegment event;
  final String timezone;
  final ValueChanged<WorkbenchAppointment> onOpen;
  @override
  Widget build(BuildContext context) {
    final item = event.item, appointment = event.item.appointment;
    final time = zonedRange(appointment.startsAt, appointment.endsAt, timezone);
    return Semantics(
      label: '$time, ${item.displayName}, ${item.package.publicName}',
      button: item.caseConsent,
      onTap: item.caseConsent ? () => onOpen(item) : null,
      child: ExcludeSemantics(
        child: Tooltip(
          message: '$time\n${item.displayName} · ${item.package.publicName}',
          child: Material(
            color: MomCozyColors.careSoft,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: item.caseConsent ? () => onOpen(item) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: LayoutBuilder(
                  builder: (context, constraints) => constraints.maxHeight < 38
                      ? Text(
                          '${zonedClock(appointment.startsAt, timezone)} ${item.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: MomCozyColors.care,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${zonedClock(appointment.startsAt, timezone)}–${zonedClock(appointment.endsAt, timezone)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: MomCozyColors.care,
                              ),
                            ),
                            Text(
                              item.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              item.package.publicName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: MomCozyColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
