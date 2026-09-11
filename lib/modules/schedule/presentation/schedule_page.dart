import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../application/schedule_controller.dart';
import '../data/schedule_api_repository.dart';
import '../domain/schedule.dart';

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
    return ColoredBox(
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
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: MomCozyInsets.page,
              children: [
                _Header(
                  month: state.month,
                  onPrevious: () => controller.shiftMonth(-1),
                  onNext: () => controller.shiftMonth(1),
                  onToday: () => controller.select(_today()),
                ),
                const SizedBox(height: 16),
                _MonthGrid(
                  state: state,
                  today: _today(),
                  onSelect: controller.select,
                ),
                const SizedBox(height: 22),
                _DayAgenda(
                  state: state,
                  onOpenAppointment: widget.onOpenAppointment,
                  onOpenPlan: widget.onOpenPlan,
                  onToggleTask: (plan, task) => unawaited(
                    controller.updateTask(
                      plan,
                      task,
                      task.status == CareTaskStatus.completed
                          ? CareTaskStatus.pending
                          : CareTaskStatus.completed,
                    ),
                  ),
                  onAdd: () => _editPersonal(),
                  onEditPersonal: (entry) => _editPersonal(existing: entry),
                  onDeletePersonal: _deletePersonal,
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
          );
        },
      ),
    );
  }

  LocalDate _today() {
    final now = widget.now();
    return LocalDate(now.year, now.month, now.day);
  }

  Future<void> _editPersonal({PersonalScheduleEntry? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    var date = existing?.date ?? controller.state.selected;
    var time = existing?.startTime ?? '09:00';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? '添加日程' : '修改日程'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 40,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '日程名称',
                  hintText: '例如：宝宝体检',
                ),
              ),
              TextField(
                controller: note,
                maxLength: 120,
                decoration: const InputDecoration(labelText: '备注（选填）'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(date.year, date.month, date.day),
                        firstDate: DateTime(date.year - 2),
                        lastDate: DateTime(date.year + 2),
                      );
                      if (picked != null) {
                        setState(
                          () => date = LocalDate(
                            picked.year,
                            picked.month,
                            picked.day,
                          ),
                        );
                      }
                    },
                    child: const Text('选日期'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('开始时间 $time')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(time.substring(0, 2)),
                          minute: int.parse(time.substring(3)),
                        ),
                      );
                      if (picked != null) {
                        setState(
                          () => time =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                    child: const Text('选时间'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, title.text.trim().isNotEmpty),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await controller.savePersonal(
        existing: existing,
        title: title.text.trim(),
        date: date,
        startTime: time,
        note: note.text.trim(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
    title.dispose();
    note.dispose();
  }

  Future<void> _deletePersonal(PersonalScheduleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程？'),
        content: Text('删除“${entry.title}”后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await controller.deletePersonal(entry);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
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
  Widget build(BuildContext context) => MomCozyPageHeader(
    title: 'Schedule',
    subtitle: '${month.year}年${month.month}月 · 你的日程安排',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '今天',
          onPressed: onToday,
          icon: const Icon(Icons.today_outlined),
        ),
        IconButton(
          tooltip: '上个月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.state,
    required this.today,
    required this.onSelect,
  });
  final ScheduleState state;
  final LocalDate today;
  final ValueChanged<LocalDate> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = state.month;
    final start = first.addDays(-(first.weekday - 1));
    final eventDates = state.page!.datesWithEvents().toSet();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: MomCozyTypography.captionSize,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var row = 0; row < 6; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    _day(context, start.addDays(row * 7 + column), eventDates),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _day(BuildContext context, LocalDate date, Set<LocalDate> eventDates) {
    final selected = date == state.selected;
    final inMonth = date.month == state.month.month;
    final today = date == this.today;
    final marked = eventDates.contains(date);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          button: true,
          selected: selected,
          label: '${date.month}月${date.day}日${marked ? '，有安排' : ''}',
          child: InkWell(
            onTap: () => onSelect(date),
            borderRadius: BorderRadius.circular(MomCozyRadii.control),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: MomCozyTapTargets.minimum,
              ),
              padding: const EdgeInsets.symmetric(vertical: MomCozySpacing.xs),
              decoration: BoxDecoration(
                color: selected
                    ? MomCozyColors.primary
                    : today
                    ? MomCozyColors.primary.withValues(alpha: .10)
                    : null,
                borderRadius: BorderRadius.circular(MomCozyRadii.control),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: today || selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : inMonth
                          ? MomCozyColors.foreground
                          : MomCozyColors.mutedForeground,
                    ),
                  ),
                  SizedBox(
                    height: MomCozySpacing.compact,
                    child: marked
                        ? Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: selected
                                    ? MomCozyColors.raised
                                    : MomCozyColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayAgenda extends StatelessWidget {
  const _DayAgenda({
    required this.state,
    required this.onOpenAppointment,
    required this.onOpenPlan,
    required this.onToggleTask,
    required this.onAdd,
    required this.onEditPersonal,
    required this.onDeletePersonal,
  });
  final ScheduleState state;
  final ValueChanged<CareAppointment>? onOpenAppointment;
  final ValueChanged<String>? onOpenPlan;
  final void Function(ScheduledPlan, PublishedCareTask) onToggleTask;
  final VoidCallback onAdd;
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
        Row(
          children: [
            Expanded(
              child: Text(
                '${date.month}月${date.day}日 · ${_weekday(date.weekday)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (personal.isEmpty && appointments.isEmpty && taskEntries.isEmpty)
          const ProductEmptyView(
            title: '这一天没有安排',
            description: '你添加的日程、IBCLC 咨询和服务任务会显示在这里。',
          ),
        for (final item in appointments)
          _AppointmentCard(
            item: item,
            onTap: () => onOpenAppointment?.call(item),
          ),
        for (final entry in taskEntries)
          _TaskCard(
            entry: entry,
            onToggle: () => onToggleTask(entry.plan, entry.task),
            onTap: () => onOpenPlan?.call(entry.plan.episodeId),
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

  static String _weekday(int day) =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day - 1];
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, required this.onTap});
  final CareAppointment item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.video_call_outlined)),
      title: const Text('IBCLC 咨询'),
      subtitle: Text(
        '${item.providerName} · ${_time(item.startsAt)}–${_time(item.endsAt)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.entry,
    required this.onToggle,
    required this.onTap,
  });
  final ScheduleTaskEntry entry;
  final VoidCallback onToggle, onTap;
  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.status == CareTaskStatus.completed,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.content.title,
          style: TextStyle(
            decoration: task.status == CareTaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Text(task.content.description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
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
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
      title: Text(item.title),
      subtitle: Text(
        '${item.startTime}${item.note.isEmpty ? '' : ' · ${item.note}'}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('修改')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    ),
  );
}

String _time(DateTime value) =>
    '${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';
