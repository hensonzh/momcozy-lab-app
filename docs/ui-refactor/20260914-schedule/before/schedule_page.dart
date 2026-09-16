import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/care_episode.dart';
import '../application/schedule_controller.dart';
import '../data/schedule_api_repository.dart';
import '../domain/schedule.dart';
import 'personal_schedule_editor.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.repository,
    required this.timezoneProvider,
    required this.catalogLoader,
    this.onOpenAppointment,
    this.onOpenPlan,
    this.now = DateTime.now,
  });
  final ScheduleRepository repository;
  final Future<String> Function() timezoneProvider;
  final Future<ServiceCatalog> Function() catalogLoader;
  final ValueChanged<CareAppointment>? onOpenAppointment;
  final ValueChanged<String>? onOpenPlan;
  final DateTime Function() now;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  String? _focusedServiceId;
  bool _taskBusy = false;
  ProductFailure? _taskFailure;
  late final ScheduleController controller = ScheduleController(
    repository: widget.repository,
    timezoneProvider: widget.timezoneProvider,
    catalogLoader: widget.catalogLoader,
    now: widget.now,
  );
  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('route-page-/schedule'),
      color: MomCozyColors.background,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final state = controller.state;
          if (state.phase == SchedulePhase.failure && state.page == null) {
            return ProductErrorView(
              failure: state.error!,
              onRetry: controller.load,
            );
          }
          if (state.page == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final services = state.page!.episodes
              .where(
                (episode) =>
                    episode.status == CareEpisodeStatus.active &&
                    episode.startsAt != null &&
                    episode.endsAt != null,
              )
              .toList();
          final focused = services
              .where((episode) => episode.id == _focusedServiceId)
              .firstOrNull;
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 27, 8, 88),
                  children: [
                    _Header(
                      month: state.month,
                      onPrevious: () => controller.shiftMonth(-1),
                      onNext: () => controller.shiftMonth(1),
                      onToday: () => controller.select(_today()),
                    ),
                    const SizedBox(height: 10),
                    _MonthGrid(
                      state: state,
                      today: _today(),
                      services: focused == null ? services : [focused],
                      onSelect: controller.select,
                    ),
                    if (services.isNotEmpty)
                      _ServicePeriods(
                        services: services,
                        state: state,
                        focused: focused,
                        onSelect: (id) =>
                            setState(() => _focusedServiceId = id),
                      ),
                    const SizedBox(height: 13),
                    const Divider(height: 1),
                    _DayAgenda(
                      state: state,
                      onOpenAppointment: widget.onOpenAppointment,
                      onOpenPlan: widget.onOpenPlan,
                      onTaskStatus: _taskBusy ? null : _updateTask,
                      onEditPersonal: (entry) => _editPersonal(existing: entry),
                      onDeletePersonal: _deletePersonal,
                    ),
                    if (_taskFailure != null)
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: MomCozyColors.amberSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '暂时无法确认任务状态，请刷新日程后核对。',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await controller.load();
                                  if (mounted &&
                                      controller.state.error == null) {
                                    setState(() => _taskFailure = null);
                                  }
                                },
                                child: const Text('刷新日程'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final plan in state.page!.plans)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _CurrentPlanSummary(
                          plan: plan,
                          onOpen: widget.onOpenPlan == null
                              ? null
                              : () => widget.onOpenPlan!(plan.episodeId),
                        ),
                      ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      ProductErrorView(
                        failure: state.error!,
                        onRetry: controller.load,
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 10,
                bottom: 22,
                child: IconButton.filled(
                  tooltip: '添加日程',
                  onPressed: () => _editPersonal(),
                  style: IconButton.styleFrom(
                    backgroundColor: MomCozyColors.primary,
                    fixedSize: const Size.square(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 24, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  LocalDate _today() {
    final now = widget.now();
    return LocalDate(now.year, now.month, now.day);
  }

  Future<void> _updateTask(
    ScheduledPlan plan,
    PublishedCareTask task,
    CareTaskStatus status,
  ) async {
    if (_taskBusy) return;
    setState(() {
      _taskBusy = true;
      _taskFailure = null;
    });
    try {
      await controller.updateTask(plan, task, status);
    } catch (error) {
      if (mounted) {
        setState(
          () => _taskFailure = error is ProductFailure
              ? error
              : const ProductFailure(ProductFailureKind.unavailable),
        );
      }
    } finally {
      if (mounted) setState(() => _taskBusy = false);
    }
  }

  Future<void> _editPersonal({PersonalScheduleEntry? existing}) async {
    await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (_) => PersonalScheduleEditor(
        controller: controller,
        existing: existing,
        now: widget.now,
      ),
    );
  }

  Future<void> _deletePersonal(PersonalScheduleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => PersonalScheduleDeleteDialog(entry: entry),
    );
    if (confirmed != true || !mounted) return;
    try {
      await controller.deletePersonal(entry);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法确认删除结果。请刷新日程后核对。')));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });
  final LocalDate month;
  final VoidCallback onPrevious, onNext, onToday;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: '上个月',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Semantics(
          button: true,
          label: '返回今天',
          child: InkWell(
            onTap: onToday,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Text(
                    '${month.year}年${month.month}月',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '查看每天的日程安排',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: '下个月',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.state,
    required this.today,
    required this.onSelect,
    required this.services,
  });
  final ScheduleState state;
  final LocalDate today;
  final ValueChanged<LocalDate> onSelect;
  final List<CareEpisode> services;

  @override
  Widget build(BuildContext context) {
    final first = state.month;
    final start = first.addDays(-(first.weekday - 1));
    final rows = (first.weekday - 1 + first.daysInMonth + 6) ~/ 7;
    final eventDates = state.page!.datesWithEvents().toSet();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  _day(context, start.addDays(row * 7 + column), eventDates),
              ],
            ),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, LocalDate date, Set<LocalDate> eventDates) {
    final selected = date == state.selected;
    final inMonth = date.month == state.month.month;
    final isToday = date == today;
    final marked = eventDates.contains(date);
    final inService = services.any(
      (episode) =>
          date.compareTo(LocalDate.fromDateTime(episode.startsAt!.toLocal())) >=
              0 &&
          date.compareTo(LocalDate.fromDateTime(episode.endsAt!.toLocal())) <=
              0,
    );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Semantics(
          button: true,
          excludeSemantics: true,
          onTap: () => onSelect(date),
          selected: selected,
          label:
              '${date.month}月${date.day}日${marked ? '，有安排' : ''}${inService ? '，服务期内' : ''}',
          child: InkWell(
            onTap: () => onSelect(date),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              constraints: const BoxConstraints(minHeight: 45),
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: selected ? MomCozyColors.primary : null,
                borderRadius: BorderRadius.circular(13),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x33b65365),
                          blurRadius: 13,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    alignment: Alignment.center,
                    decoration: inService && !selected
                        ? BoxDecoration(
                            color: MomCozyColors.servicePeriodSurface,
                            border: Border.all(
                              color: MomCozyColors.servicePeriodBorder,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          )
                        : null,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: selected || isToday
                            ? FontWeight.w800
                            : inService
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : inService
                            ? MomCozyColors.servicePeriodInk
                            : isToday
                            ? MomCozyColors.primaryDark
                            : inMonth
                            ? MomCozyColors.foreground
                            : MomCozyColors.mutedForeground,
                      ),
                    ),
                  ),
                  if (marked || isToday) ...[
                    const SizedBox(height: 3),
                    Container(
                      width: 10,
                      height: 3,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : MomCozyColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServicePeriods extends StatelessWidget {
  const _ServicePeriods({
    required this.services,
    required this.state,
    required this.focused,
    required this.onSelect,
  });
  final List<CareEpisode> services;
  final ScheduleState state;
  final CareEpisode? focused;
  final ValueChanged<String?> onSelect;
  String _name(CareEpisode episode) =>
      packageForEpisode(episode, state.catalog)?.name ?? '专家服务';

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(13, 8, 13, 0),
    padding: const EdgeInsets.only(top: 8),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: MomCozyColors.servicePeriodBorder)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        const Text(
          '浅绿色为服务期',
          style: TextStyle(fontSize: 10, color: MomCozyColors.servicePeriodInk),
        ),
        if (services.length == 1)
          Text(
            '${_name(services.first)} · 余 ${services.first.remainingSessions} 次',
            style: const TextStyle(
              fontSize: 10,
              color: MomCozyColors.servicePeriodInk,
            ),
          )
        else
          PopupMenuButton<String>(
            tooltip: '切换日历显示的服务包',
            onSelected: (id) => onSelect(id.isEmpty ? null : id),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('全部服务')),
              for (final episode in services)
                PopupMenuItem(
                  value: episode.id,
                  child: Text(
                    '${_name(episode)} · 余 ${episode.remainingSessions} 次',
                  ),
                ),
            ],
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: MomCozyColors.servicePeriodSurface,
                border: Border.all(color: MomCozyColors.servicePeriodBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                focused == null
                    ? '全部服务 · ${services.length} 项'
                    : _name(focused!),
                style: const TextStyle(
                  fontSize: 10,
                  color: MomCozyColors.servicePeriodInk,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DayAgenda extends StatelessWidget {
  const _DayAgenda({
    required this.state,
    required this.onOpenAppointment,
    required this.onOpenPlan,
    required this.onTaskStatus,
    required this.onEditPersonal,
    required this.onDeletePersonal,
  });
  final ScheduleState state;
  final ValueChanged<CareAppointment>? onOpenAppointment;
  final ValueChanged<String>? onOpenPlan;
  final void Function(ScheduledPlan, PublishedCareTask, CareTaskStatus)?
  onTaskStatus;
  final ValueChanged<PersonalScheduleEntry> onEditPersonal;
  final ValueChanged<PersonalScheduleEntry> onDeletePersonal;
  @override
  Widget build(BuildContext context) {
    final date = state.selected;
    final page = state.page!;
    final personal = page.personal.where((item) => item.date == date).toList();
    final appointments = page.appointments
        .where(
          (item) => LocalDate.fromDateTime(item.startsAt.toLocal()) == date,
        )
        .toList();
    final taskEntries = <ScheduleTaskEntry>[];
    for (final plan in page.plans) {
      for (final task in plan.publication.tasks) {
        if (task.content.scheduledDate == date ||
            (task.content.scheduledDate == null &&
                plan.publication.publishedAt.toLocal().year == date.year &&
                plan.publication.publishedAt.toLocal().month == date.month &&
                plan.publication.publishedAt.toLocal().day == date.day)) {
          taskEntries.add(ScheduleTaskEntry(plan: plan, task: task));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (personal.isEmpty && appointments.isEmpty && taskEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                _AgendaIcon(
                  personal: true,
                  icon: Padding(
                    padding: EdgeInsets.all(11),
                    child: MomCozyLineIcon(
                      MomCozyLineGlyph.calendar,
                      size: 20,
                      color: MomCozyColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '这一天没有安排',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '你添加的日程、IBCLC 咨询和服务任务会显示在这里。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final item in appointments)
          _AppointmentCard(
            item: item,
            onTap: () => onOpenAppointment?.call(item),
          ),
        for (final entry in taskEntries)
          _TaskCard(
            entry: entry,
            onStatus: onTaskStatus == null
                ? null
                : (status) => onTaskStatus!(entry.plan, entry.task, status),
            onTap: onOpenPlan == null
                ? null
                : () => onOpenPlan!(entry.plan.episodeId),
          ),
        for (final item in personal)
          _PersonalCard(
            item: item,
            onEdit: () => onEditPersonal(item),
            onDelete: () => onDeletePersonal(item),
          ),
      ],
    );
  }
}

class _CurrentPlanSummary extends StatelessWidget {
  const _CurrentPlanSummary({required this.plan, required this.onOpen});
  final ScheduledPlan plan;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final publication = plan.publication;
    final completed = publication.tasks
        .where((task) => task.status == CareTaskStatus.completed)
        .length;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: MomCozyColors.border),
    );
    return ExpansionTile(
      key: PageStorageKey('schedule-plan-${publication.id}'),
      shape: shape,
      collapsedShape: shape,
      backgroundColor: MomCozyColors.card,
      collapsedBackgroundColor: MomCozyColors.card,
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      minTileHeight: 72,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: MomCozyColors.careSoft,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: const MomCozyLineIcon(
          MomCozyLineGlyph.plan,
          size: 22,
          color: MomCozyColors.care,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前照护方案',
                  style: TextStyle(
                    fontSize: 10,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  publication.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MomCozyColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$completed/${publication.tasks.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: MomCozyColors.care,
            ),
          ),
        ],
      ),
      children: [
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            MomCozyBadge(
              'v${publication.revision} · 已发布',
              compact: true,
              color: MomCozyColors.care,
              background: MomCozyColors.careSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$completed 项已完成',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 10,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: publication.tasks.isEmpty
              ? 0
              : completed / publication.tasks.length,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: MomCozyColors.care,
          backgroundColor: MomCozyColors.careSoft,
          semanticsLabel:
              '照护方案完成进度，$completed 项已完成，共 ${publication.tasks.length} 项',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            publication.summary,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: MomCozyColors.mutedForeground,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onOpen, child: const Text('查看照护方案 →')),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.leading,
    required this.title,
    required this.meta,
    required this.detail,
    required this.action,
    this.badge,
    this.done = false,
  });
  final Widget leading, action;
  final Widget? badge;
  final String title, meta, detail;
  final bool done;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 84),
    padding: const EdgeInsets.fromLTRB(11, 14, 8, 14),
    decoration: BoxDecoration(
      color: done ? MomCozyColors.warmFormSurface : null,
      border: const Border(bottom: BorderSide(color: MomCozyColors.border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 44, height: 44, child: leading),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                  ?badge,
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),
        action,
      ],
    ),
  );
}

class _AgendaIcon extends StatelessWidget {
  const _AgendaIcon({required this.icon, this.personal = false});
  final Widget icon;
  final bool personal;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: personal ? MomCozyColors.amberSoft : MomCozyColors.blueSoft,
      borderRadius: BorderRadius.circular(13),
    ),
    alignment: Alignment.center,
    child: icon,
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, required this.onTap});
  final CareAppointment item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _AgendaRow(
    leading: const _AgendaIcon(
      icon: Icon(Icons.videocam_outlined, size: 20, color: MomCozyColors.blue),
    ),
    title: 'IBCLC 咨询',
    meta: '${_time(item.startsAt)}–${_time(item.endsAt)}',
    badge: MomCozyBadge(
      switch (item.status) {
        AppointmentStatus.held => '待确认',
        AppointmentStatus.confirmed => '已确认',
        AppointmentStatus.inProgress => '进行中',
        AppointmentStatus.completed => '已完成',
        AppointmentStatus.cancelled => '已取消',
        AppointmentStatus.expired => '已过期',
      },
      compact: true,
      color: switch (item.status) {
        AppointmentStatus.completed => MomCozyColors.care,
        AppointmentStatus.confirmed ||
        AppointmentStatus.inProgress => MomCozyColors.blue,
        AppointmentStatus.held => MomCozyColors.amber,
        _ => MomCozyColors.mutedForeground,
      },
      background: switch (item.status) {
        AppointmentStatus.completed => MomCozyColors.careSoft,
        AppointmentStatus.confirmed ||
        AppointmentStatus.inProgress => MomCozyColors.blueSoft,
        AppointmentStatus.held => MomCozyColors.amberSoft,
        _ => MomCozyColors.muted,
      },
    ),
    detail: '${item.providerName} · ${item.duration.inMinutes} 分钟',
    action: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(switch (item.status) {
        AppointmentStatus.completed => '总结',
        AppointmentStatus.held => '确认',
        _ => '查看',
      }),
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.entry,
    required this.onStatus,
    required this.onTap,
  });
  final ScheduleTaskEntry entry;
  final ValueChanged<CareTaskStatus>? onStatus;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _AgendaRow(
    leading: Checkbox(
      value: entry.task.status == CareTaskStatus.completed,
      onChanged: onStatus == null || entry.task.status == CareTaskStatus.skipped
          ? null
          : (_) => onStatus!(
              entry.task.status == CareTaskStatus.completed
                  ? CareTaskStatus.pending
                  : CareTaskStatus.completed,
            ),
    ),
    title: entry.task.content.title,
    meta: [
      '全天',
      entry.task.content.dueLabel,
    ].where((value) => value.isNotEmpty).join(' · '),
    badge: MomCozyBadge(
      switch (entry.task.status) {
        CareTaskStatus.pending => '待完成',
        CareTaskStatus.inProgress => '进行中',
        CareTaskStatus.completed => '已完成',
        CareTaskStatus.skipped => '已跳过',
      },
      compact: true,
      color: entry.task.status == CareTaskStatus.completed
          ? MomCozyColors.care
          : MomCozyColors.mutedForeground,
      background: entry.task.status == CareTaskStatus.completed
          ? MomCozyColors.careSoft
          : MomCozyColors.muted,
    ),
    detail: entry.task.content.description,
    done: entry.task.status == CareTaskStatus.completed,
    action: PopupMenuButton<String>(
      tooltip: '更多${entry.task.content.title}选项',
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: MomCozyColors.border),
      ),
      onSelected: (value) {
        if (value == 'plan') {
          onTap?.call();
        } else {
          onStatus?.call(
            CareTaskStatus.values.firstWhere((status) => status.name == value),
          );
        }
      },
      itemBuilder: (_) => [
        for (final action in const {
          CareTaskStatus.inProgress: '标记进行中',
          CareTaskStatus.skipped: '暂时跳过',
          CareTaskStatus.pending: '恢复待完成',
        }.entries)
          PopupMenuItem(
            value: action.key.name,
            enabled: onStatus != null && entry.task.status != action.key,
            child: Text(action.value, style: const TextStyle(fontSize: 12)),
          ),
        if (onTap != null)
          const PopupMenuItem(
            value: 'plan',
            child: Text('查看服务计划', style: TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final PersonalScheduleEntry item;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) => _AgendaRow(
    leading: const _AgendaIcon(
      personal: true,
      icon: MomCozyLineIcon(
        MomCozyLineGlyph.calendar,
        size: 20,
        color: MomCozyColors.amber,
      ),
    ),
    title: item.title,
    meta: item.startTime,
    detail: item.note,
    action: PopupMenuButton<String>(
      tooltip: '更多${item.title}选项',
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('修改')),
        PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    ),
  );
}

String _time(DateTime value) =>
    '${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';
