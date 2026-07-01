import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';

class MomCozyFeaturePage extends StatelessWidget {
  const MomCozyFeaturePage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return switch (path) {
      '/calibration' => _CalibrationPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/pump' => _PumpPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/records' => _RecordsPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/schedule' => _SchedulePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/status' => _StatusPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/community' => _CommunityPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/device' => _DevicePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/device/manage' => _DeviceManagePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/device/user' => _DeviceUserPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/w1' => _W1Page(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/hospital-bag-cart' => _HospitalBagCartPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/ibclc-chat.html' => _IbclcPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      '/media-viewer' => _MediaViewerPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
      _ => _NotFoundPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        priority: priority,
      ),
    };
  }
}

class _FeaturePageFrame extends StatelessWidget {
  const _FeaturePageFrame({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
    required this.children,
    this.trailing,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      key: ValueKey('route-page-$path'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PriorityBadge(priority: priority, accent: accent),
          ],
        ),
        if (trailing != null) ...[const SizedBox(height: 16), trailing!],
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority, required this.accent});

  final String priority;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 162,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = accent ?? colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: foreground, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPage extends StatefulWidget {
  const _StatusPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<_StatusPage> {
  String _view = 'mom';
  MomCozyApiRuntime? _runtime;
  late Future<StatusOverview> _overviewFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _overviewFuture = runtime.statusRepository.fetchOverview(
        userId: runtime.userId,
      );
    }
  }

  void _reloadOverview() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _overviewFuture = runtime.statusRepository.fetchOverview(
        userId: runtime.userId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMom = _view == 'mom';

    return FutureBuilder<StatusOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        return _FeaturePageFrame(
          path: widget.path,
          title: widget.title,
          summary: widget.summary,
          icon: widget.icon,
          accent: widget.accent,
          priority: widget.priority,
          trailing: SegmentedButton<String>(
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (next) => setState(() => _view = next.first),
            segments: const [
              ButtonSegment(
                value: 'mom',
                icon: Icon(Icons.person_outline_rounded),
                label: Text('妈妈'),
              ),
              ButtonSegment(
                value: 'baby',
                icon: Icon(Icons.child_care_rounded),
                label: Text('宝宝'),
              ),
            ],
          ),
          children: [
            const _SectionTitle('今日状态'),
            ..._overviewChildren(snapshot, isMom),
            const SizedBox(height: 18),
            const _SectionTitle('下一步'),
            _ActionTile(
              icon: Icons.edit_note_rounded,
              title: isMom ? '补写孕期日记' : '记录成长事件',
              subtitle: isMom ? '保留心情、体征和 Agent 分析上下文。' : '记录身高、体重、睡眠和喂养变化。',
              accent: widget.accent,
              onTap: () => context.go('/records'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
            _ActionTile(
              icon: Icons.fact_check_outlined,
              title: '今日待办',
              subtitle: '2 项待确认，提醒和 Agent 建议会在这里汇总。',
              accent: const Color(0xffb2773b),
              onTap: () => context.go('/schedule'),
              trailing: const _StatusChip(
                label: '2',
                icon: Icons.notifications_active_outlined,
                accent: Color(0xffb2773b),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _overviewChildren(
    AsyncSnapshot<StatusOverview> snapshot,
    bool isMom,
  ) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return [
        const _ActionTile(
          icon: Icons.sync_rounded,
          title: '正在同步状态',
          subtitle: '正在读取妈妈和宝宝状态。',
          accent: Color(0xff9f6378),
          trailing: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        _ActionTile(
          icon: Icons.cloud_off_outlined,
          title: '状态同步失败',
          subtitle: '检查后端连接或 token 后重试。',
          accent: const Color(0xff9f6378),
          trailing: IconButton(
            tooltip: '重试',
            onPressed: _reloadOverview,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ];
    }

    final overview = snapshot.data;
    if (overview == null || overview.isEmpty) {
      return const [
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: '暂无状态数据',
          subtitle: '完成妈妈/宝宝资料后这里会显示当前状态。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ];
    }

    return [
      _MetricWrap(
        children: isMom
            ? _momOverviewMetrics(overview.mom)
            : _babyOverviewMetrics(overview.baby),
      ),
    ];
  }

  List<Widget> _momOverviewMetrics(MomStatus? mom) {
    return [
      _MetricTile(
        label: '阶段',
        value: _textOr(mom?.stage, '未设置'),
        icon: Icons.favorite_border_rounded,
        accent: widget.accent,
        note: mom?.postpartumDay == null ? null : '产后第 ${mom!.postpartumDay} 天',
      ),
      _MetricTile(
        label: '默认用户',
        value: _textOr(_runtime?.userId, '--'),
        icon: Icons.person_outline_rounded,
        accent: const Color(0xff43827b),
      ),
      const _MetricTile(
        label: '同步状态',
        value: '已连接',
        icon: Icons.cloud_done_outlined,
        accent: Color(0xff6b6da8),
      ),
    ];
  }

  List<Widget> _babyOverviewMetrics(BabyStatus? baby) {
    return [
      _MetricTile(
        label: '宝宝',
        value: _textOr(baby?.nickname, '未设置'),
        icon: Icons.child_care_rounded,
        accent: widget.accent,
        note: baby?.ageDays == null ? null : '${baby!.ageDays} 天',
      ),
      _MetricTile(
        label: '默认宝宝',
        value: _textOr(_runtime?.babyId, '--'),
        icon: Icons.badge_outlined,
        accent: const Color(0xff43827b),
      ),
      const _MetricTile(
        label: '同步状态',
        value: '已连接',
        icon: Icons.cloud_done_outlined,
        accent: Color(0xff6b6da8),
      ),
    ];
  }
}

String _textOr(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

class _SchedulePage extends StatefulWidget {
  const _SchedulePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  bool _pumpReminderEnabled = true;
  bool _dailySummaryEnabled = true;
  final Map<String, bool> _taskDoneOverrides = {};
  MomCozyApiRuntime? _runtime;
  late DateTime _selectedDay;
  late Future<ScheduleDayPlan> _dayPlanFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _selectedDay = runtime.now();
      _dayPlanFuture = _fetchDayPlan(runtime);
    }
  }

  Future<ScheduleDayPlan> _fetchDayPlan(MomCozyApiRuntime runtime) {
    return runtime.scheduleRepository.fetchDayPlan(
      userId: runtime.userId,
      day: _selectedDay,
    );
  }

  void _reloadDayPlan() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _taskDoneOverrides.clear();
      _dayPlanFuture = _fetchDayPlan(runtime);
    });
  }

  void _selectDay(DateTime day) {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _selectedDay = day;
      _taskDoneOverrides.clear();
      _dayPlanFuture = _fetchDayPlan(runtime);
    });
  }

  void _toggleTask(ScheduleTask task, int index, bool? value) {
    final key = _taskKey(task, index);
    setState(() {
      _taskDoneOverrides[key] = value ?? !_taskDone(task, index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScheduleDayPlan>(
      future: _dayPlanFuture,
      builder: (context, snapshot) {
        final taskCount = snapshot.data?.tasks.length;

        return _FeaturePageFrame(
          path: widget.path,
          title: widget.title,
          summary: widget.summary,
          icon: widget.icon,
          accent: widget.accent,
          priority: widget.priority,
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _StatusChip(
                label: '今天',
                icon: Icons.today_outlined,
                accent: Color(0xffb2773b),
              ),
              _StatusChip(
                label: taskCount == null ? '同步中' : '$taskCount 项计划',
                icon: Icons.alarm_rounded,
                accent: const Color(0xff43827b),
              ),
            ],
          ),
          children: [
            const _SectionTitle('日期'),
            _ScheduleDateStrip(
              selectedDay: _selectedDay,
              onSelected: _selectDay,
            ),
            const SizedBox(height: 18),
            const _SectionTitle('计划'),
            ..._dayPlanChildren(snapshot),
            const SizedBox(height: 8),
            const _SectionTitle('提醒'),
            _ActionTile(
              icon: Icons.alarm_on_rounded,
              title: '泵奶提醒',
              subtitle: '需要 Android 通知权限和精确闹钟能力。',
              accent: widget.accent,
              trailing: Switch(
                value: _pumpReminderEnabled,
                onChanged: (value) =>
                    setState(() => _pumpReminderEnabled = value),
              ),
            ),
            _ActionTile(
              icon: Icons.summarize_outlined,
              title: '每日摘要',
              subtitle: '跨天时汇总计划、记录和 Agent 建议。',
              accent: const Color(0xff43827b),
              trailing: Switch(
                value: _dailySummaryEnabled,
                onChanged: (value) =>
                    setState(() => _dailySummaryEnabled = value),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _dayPlanChildren(AsyncSnapshot<ScheduleDayPlan> snapshot) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const [
        _ActionTile(
          icon: Icons.sync_rounded,
          title: '正在同步计划',
          subtitle: '正在读取当天任务和提醒。',
          accent: Color(0xffb2773b),
          trailing: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        _ActionTile(
          icon: Icons.cloud_off_outlined,
          title: '计划同步失败',
          subtitle: '检查后端连接或 token 后重试。',
          accent: widget.accent,
          trailing: IconButton(
            tooltip: '重试',
            onPressed: _reloadDayPlan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ];
    }

    final plan = snapshot.data;
    if (plan == null || plan.isEmpty) {
      return const [
        _ActionTile(
          icon: Icons.event_available_outlined,
          title: '暂无计划',
          subtitle: '当天没有计划任务，可以从 Agent 或记录页创建。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.add_circle_outline_rounded),
        ),
      ];
    }

    return [
      for (final entry in plan.tasks.asMap().entries)
        _ActionTile(
          icon: _taskDone(entry.value, entry.key)
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
          title: _textOr(entry.value.title, '未命名计划'),
          subtitle: _taskSubtitle(entry.value),
          accent: _taskAccent(entry.key),
          onTap: () => _toggleTask(entry.value, entry.key, null),
          trailing: Checkbox(
            value: _taskDone(entry.value, entry.key),
            onChanged: (value) => _toggleTask(entry.value, entry.key, value),
          ),
        ),
    ];
  }

  bool _taskDone(ScheduleTask task, int index) {
    return _taskDoneOverrides[_taskKey(task, index)] ?? task.completed;
  }

  String _taskKey(ScheduleTask task, int index) {
    return task.id.isEmpty ? 'task-$index' : task.id;
  }
}

class _ScheduleDateStrip extends StatelessWidget {
  const _ScheduleDateStrip({
    required this.selectedDay,
    required this.onSelected,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var offset = -2; offset <= 2; offset += 1)
            _DatePill(
              day: _weekdayLabel(selectedDate.add(Duration(days: offset))),
              date: selectedDate
                  .add(Duration(days: offset))
                  .day
                  .toString()
                  .padLeft(2, '0'),
              selected: offset == 0,
              onTap: () => onSelected(selectedDate.add(Duration(days: offset))),
            ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.day,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String day;
  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? colorScheme.primaryContainer : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(day, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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

String _taskSubtitle(ScheduleTask task) {
  final remindAt = task.remindAt;
  if (remindAt == null) return '暂无提醒时间，可稍后补充。';
  return '提醒 ${_timeLabel(remindAt)} · 可从通知直接进入相关页面。';
}

Color _taskAccent(int index) {
  return switch (index % 3) {
    0 => const Color(0xffb2773b),
    1 => const Color(0xff43827b),
    _ => const Color(0xff6b6da8),
  };
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _weekdayLabel(DateTime value) {
  return switch (value.weekday) {
    DateTime.monday => '一',
    DateTime.tuesday => '二',
    DateTime.wednesday => '三',
    DateTime.thursday => '四',
    DateTime.friday => '五',
    DateTime.saturday => '六',
    _ => '日',
  };
}

class _DevicePage extends StatefulWidget {
  const _DevicePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<_DevicePage> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => setState(() => _isScanning = !_isScanning),
            icon: Icon(_isScanning ? Icons.stop_rounded : Icons.search_rounded),
            label: Text(_isScanning ? '停止扫描' : '扫描'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/device/manage'),
            icon: const Icon(Icons.settings_remote_rounded),
            label: const Text('管理'),
          ),
        ],
      ),
      children: [
        _ActionTile(
          icon: _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
          title: _isScanning ? '正在扫描附近设备' : 'BLE 权限和扫描',
          subtitle: _isScanning
              ? '正在查找附近设备；超时或空结果会显示在这里。'
              : 'Android 12+ 需要蓝牙权限，Android 13+ 还需要通知权限。',
          accent: widget.accent,
          trailing: _isScanning
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
        ),
        const _SectionTitle('左右设备'),
        _DeviceSideTile(
          side: '左侧',
          name: 'S12 Pro L',
          state: '已连接',
          battery: '82%',
          accent: widget.accent,
        ),
        _DeviceSideTile(
          side: '右侧',
          name: '等待连接',
          state: '未连接',
          battery: '--',
          accent: const Color(0xff7f6a75),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('设备入口'),
        _ActionTile(
          icon: Icons.tune_rounded,
          title: '进入舒适校准',
          subtitle: '复用左右设备状态，保存后进入泵奶参数。',
          accent: const Color(0xff9b6b2f),
          onTap: () => context.go('/calibration'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        _ActionTile(
          icon: Icons.bug_report_outlined,
          title: '内部调试参数',
          subtitle: '仅用于 QA/dev，正式包需要 feature flag 控制。',
          accent: const Color(0xff7f6a75),
          onTap: () => context.go('/device/user'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DeviceSideTile extends StatelessWidget {
  const _DeviceSideTile({
    required this.side,
    required this.name,
    required this.state,
    required this.battery,
    required this.accent,
  });

  final String side;
  final String name;
  final String state;
  final String battery;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: state == '已连接'
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      title: '$side $name',
      subtitle: '状态 $state · 电量 $battery',
      accent: accent,
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: state == '已连接' ? '校准' : '连接',
            onPressed: () => state == '已连接'
                ? context.go('/calibration')
                : context.go('/device/manage'),
            icon: Icon(
              state == '已连接' ? Icons.tune_rounded : Icons.link_rounded,
            ),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () => context.go('/device/manage'),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }
}

enum _PumpRunState { idle, running, paused }

class _PumpPage extends StatefulWidget {
  const _PumpPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<_PumpPage> {
  _PumpRunState _runState = _PumpRunState.idle;
  double _leftLevel = 5;
  double _rightLevel = 5;

  @override
  Widget build(BuildContext context) {
    final isRunning = _runState == _PumpRunState.running;
    final isPaused = _runState == _PumpRunState.paused;

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusChip(
            label: isRunning
                ? '进行中'
                : isPaused
                ? '已暂停'
                : '待开始',
            icon: isRunning
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            accent: widget.accent,
          ),
          const _StatusChip(
            label: '前台服务待验证',
            icon: Icons.notifications_active_outlined,
            accent: Color(0xffb2773b),
          ),
        ],
      ),
      children: [
        const _SectionTitle('Session 控制'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () => setState(() => _runState = _PumpRunState.running),
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.water_drop,
              ),
              label: Text(isPaused ? '恢复' : '开始'),
            ),
            OutlinedButton.icon(
              onPressed: isRunning
                  ? () => setState(() => _runState = _PumpRunState.paused)
                  : null,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('暂停'),
            ),
            OutlinedButton.icon(
              onPressed: _runState == _PumpRunState.idle
                  ? null
                  : () => setState(() => _runState = _PumpRunState.idle),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('结束'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('左右侧参数'),
        _PumpSideTile(
          label: '左侧',
          mode: '按摩 + 吸乳',
          level: _leftLevel,
          accent: widget.accent,
          onChanged: (value) => setState(() => _leftLevel = value),
        ),
        _PumpSideTile(
          label: '右侧',
          mode: '吸乳',
          level: _rightLevel,
          accent: const Color(0xff43827b),
          onChanged: (value) => setState(() => _rightLevel = value),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('上传状态'),
        const _ActionTile(
          icon: Icons.cloud_sync_outlined,
          title: 'Agent context 上传',
          subtitle: '结束后生成摘要、奶量记录和智能体上下文；重复上传会被自动拦截。',
          accent: Color(0xff6b6da8),
          trailing: Icon(Icons.pending_actions_rounded),
        ),
      ],
    );
  }
}

class _PumpSideTile extends StatelessWidget {
  const _PumpSideTile({
    required this.label,
    required this.mode,
    required this.level,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final String mode;
  final double level;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.compress_rounded,
      title: '$label · $mode',
      subtitle: '档位 ${level.round()}，调整后会同步到当前连接设备。',
      accent: accent,
      trailing: SizedBox(
        width: 136,
        child: Slider(
          value: level,
          min: 1,
          max: 9,
          divisions: 8,
          label: level.round().toString(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CalibrationPage extends StatefulWidget {
  const _CalibrationPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<_CalibrationPage> {
  double _leftComfort = 4;
  double _rightComfort = 4;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: const _StatusChip(
        label: '左右独立',
        icon: Icons.compare_arrows_rounded,
        accent: Color(0xff9b6b2f),
      ),
      children: [
        const _SectionTitle('舒适档位'),
        _CalibrationSideTile(
          label: '左侧',
          value: _leftComfort,
          accent: widget.accent,
          onChanged: (value) => setState(() => _leftComfort = value),
        ),
        _CalibrationSideTile(
          label: '右侧',
          value: _rightComfort,
          accent: const Color(0xff43827b),
          onChanged: (value) => setState(() => _rightComfort = value),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('保存规则'),
        const _ActionTile(
          icon: Icons.verified_user_outlined,
          title: '校准结果保存检查',
          subtitle: '保存前会检查左右设备状态，并处理历史校准数据。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.rule_rounded),
        ),
        FilledButton.icon(
          onPressed: () => context.go('/pump'),
          icon: const Icon(Icons.save_rounded),
          label: const Text('保存并进入泵奶'),
        ),
      ],
    );
  }
}

class _CalibrationSideTile extends StatelessWidget {
  const _CalibrationSideTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.tune_rounded,
      title: '$label 舒适档位 ${value.round()}',
      subtitle: '低档位用于找舒适点，高档位需二次确认。',
      accent: accent,
      trailing: SizedBox(
        width: 136,
        child: Slider(
          value: value,
          min: 1,
          max: 9,
          divisions: 8,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RecordsPage extends StatefulWidget {
  const _RecordsPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<_RecordsPage> {
  String _filter = 'pump';

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: SegmentedButton<String>(
        selected: {_filter},
        showSelectedIcon: false,
        onSelectionChanged: (next) => setState(() => _filter = next.first),
        segments: const [
          ButtonSegment(value: 'pump', label: Text('泵奶')),
          ButtonSegment(value: 'feed', label: Text('喂养')),
          ButtonSegment(value: 'growth', label: Text('成长')),
        ],
      ),
      children: [
        const _SectionTitle('本周概览'),
        _MetricWrap(
          children: [
            _MetricTile(
              label: '总奶量',
              value: '2.8 L',
              icon: Icons.water_drop_outlined,
              accent: widget.accent,
              note: '较上周 +8%',
            ),
            const _MetricTile(
              label: '记录数',
              value: '26',
              icon: Icons.receipt_long_outlined,
              accent: Color(0xff43827b),
            ),
            const _MetricTile(
              label: '平均间隔',
              value: '3h',
              icon: Icons.schedule_rounded,
              accent: Color(0xffb2773b),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('趋势'),
        const _TrendBar(label: '周一', value: 0.64),
        const _TrendBar(label: '周二', value: 0.72),
        const _TrendBar(label: '周三', value: 0.58),
        const SizedBox(height: 18),
        const _SectionTitle('最近记录'),
        _ActionTile(
          icon: Icons.water_drop_rounded,
          title: _filter == 'pump' ? '10:40 泵奶 120 mL' : '10:40 记录项',
          subtitle: '左 58 mL，右 62 mL；已同步 Agent context。',
          accent: widget.accent,
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.add_circle_outline_rounded,
          title: '手动补录',
          subtitle: '支持 mL/oz、左右侧、时间和备注。',
          accent: Color(0xff43827b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Text('${(value * 500).round()} mL'),
        ],
      ),
    );
  }
}

class _CommunityPage extends StatelessWidget {
  const _CommunityPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: path,
      title: title,
      summary: summary,
      icon: icon,
      accent: accent,
      priority: priority,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _StatusChip(
            label: '同城',
            icon: Icons.location_on_outlined,
            accent: Color(0xff6b6da8),
          ),
          _StatusChip(
            label: '哺乳支持',
            icon: Icons.volunteer_activism_outlined,
            accent: Color(0xff43827b),
          ),
        ],
      ),
      children: const [
        _SectionTitle('关注话题'),
        _ActionTile(
          icon: Icons.forum_outlined,
          title: '泵奶节奏调整',
          subtitle: '来自相同月龄妈妈的经验和已收藏讨论。',
          accent: Color(0xff6b6da8),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        _ActionTile(
          icon: Icons.favorite_border_rounded,
          title: '产后恢复',
          subtitle: '查看收藏内容、精选讨论和恢复建议。',
          accent: Color(0xff9f6378),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        _SectionTitle('最新动态'),
        _ActionTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: '妈妈小组更新',
          subtitle: '3 条新回复，打开后会更新已读状态。',
          accent: Color(0xff43827b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DeviceManagePage extends StatelessWidget {
  const _DeviceManagePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: path,
      title: title,
      summary: summary,
      icon: icon,
      accent: accent,
      priority: priority,
      children: [
        const _SectionTitle('设备操作'),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: '固件和序列号',
          subtitle: '展示左右设备 firmware、model、serial 和电量。',
          accent: accent,
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.notifications_active_outlined,
          title: '设备提醒通道',
          subtitle: '管理设备消息、提醒声音和后台接收状态。',
          accent: Color(0xffb2773b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.refresh_rounded,
          title: '重新同步设备状态',
          subtitle: '刷新左右设备连接、电量和运行快照。',
          accent: Color(0xff43827b),
          trailing: Icon(Icons.sync_rounded),
        ),
        const _ActionTile(
          icon: Icons.link_off_rounded,
          title: '解绑设备',
          subtitle: '解绑前需要确认后台 session 已结束。',
          accent: Color(0xff9f6378),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DeviceUserPage extends StatefulWidget {
  const _DeviceUserPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_DeviceUserPage> createState() => _DeviceUserPageState();
}

class _DeviceUserPageState extends State<_DeviceUserPage> {
  bool _debugEvents = false;
  bool _useFixtureDevice = true;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      children: [
        const _SectionTitle('内部参数'),
        _ActionTile(
          icon: Icons.person_search_outlined,
          title: '当前用户',
          subtitle: 'demo-user · 正式环境从安全会话读取。',
          accent: widget.accent,
          trailing: const Icon(Icons.lock_outline_rounded),
        ),
        _ActionTile(
          icon: Icons.science_outlined,
          title: '使用测试设备',
          subtitle: '用于无真泵时验证页面状态，不写入生产数据。',
          accent: const Color(0xff43827b),
          trailing: Switch(
            value: _useFixtureDevice,
            onChanged: (value) => setState(() => _useFixtureDevice = value),
          ),
        ),
        _ActionTile(
          icon: Icons.terminal_rounded,
          title: '显示设备调试事件',
          subtitle: '正式包应隐藏，仅 QA/dev flavor 可见。',
          accent: const Color(0xff7f6a75),
          trailing: Switch(
            value: _debugEvents,
            onChanged: (value) => setState(() => _debugEvents = value),
          ),
        ),
      ],
    );
  }
}

class _W1Page extends StatelessWidget {
  const _W1Page({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: path,
      title: title,
      summary: summary,
      icon: icon,
      accent: accent,
      priority: priority,
      trailing: const _StatusChip(
        label: '产品内容',
        icon: Icons.workspace_premium_outlined,
        accent: Color(0xffb2773b),
      ),
      children: [
        const _SectionTitle('W1'),
        const _ActionTile(
          icon: Icons.air_rounded,
          title: '穿戴体验',
          subtitle: '查看产品亮点、贴合方式和日常佩戴建议。',
          accent: Color(0xffb2773b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.battery_charging_full_rounded,
          title: '续航与清洁',
          subtitle: '了解电池、清洁、收纳和耗材维护。',
          accent: Color(0xff43827b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        _ActionTile(
          icon: Icons.play_circle_outline_rounded,
          title: '使用教程',
          subtitle: '打开视频、PDF 和图文教程。',
          accent: Color(0xff6b6da8),
          onTap: () => context.go('/media-viewer'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _HospitalBagCartPage extends StatefulWidget {
  const _HospitalBagCartPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_HospitalBagCartPage> createState() => _HospitalBagCartPageState();
}

class _HospitalBagCartPageState extends State<_HospitalBagCartPage> {
  bool _pumpPacked = true;
  bool _padsPacked = false;
  bool _babyClothesPacked = false;

  @override
  Widget build(BuildContext context) {
    final packed = [
      _pumpPacked,
      _padsPacked,
      _babyClothesPacked,
    ].where((item) => item).length;

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: _StatusChip(
        label: '$packed/3 已准备',
        icon: Icons.inventory_2_outlined,
        accent: widget.accent,
      ),
      children: [
        const _SectionTitle('清单'),
        _ChecklistTile(
          title: '吸奶器和配件',
          subtitle: '主机、阀门、储奶袋、充电线。',
          value: _pumpPacked,
          accent: widget.accent,
          onChanged: (value) => setState(() => _pumpPacked = value),
        ),
        _ChecklistTile(
          title: '产后护理用品',
          subtitle: '护理垫、湿巾、一次性用品。',
          value: _padsPacked,
          accent: const Color(0xff43827b),
          onChanged: (value) => setState(() => _padsPacked = value),
        ),
        _ChecklistTile(
          title: '宝宝衣物',
          subtitle: '连体衣、包巾、帽子和备用衣物。',
          value: _babyClothesPacked,
          accent: const Color(0xff6b6da8),
          onChanged: (value) => setState(() => _babyClothesPacked = value),
        ),
        const SizedBox(height: 8),
        const _ActionTile(
          icon: Icons.restore_rounded,
          title: '恢复默认清单',
          subtitle: '把待产包恢复为推荐清单，并同步购物车状态。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
      title: title,
      subtitle: subtitle,
      accent: accent,
      trailing: Checkbox(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
      ),
    );
  }
}

class _IbclcPage extends StatefulWidget {
  const _IbclcPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_IbclcPage> createState() => _IbclcPageState();
}

class _IbclcPageState extends State<_IbclcPage> {
  bool _accepted = false;
  bool _consultStarted = false;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: _StatusChip(
        label: _consultStarted ? '咨询准备中' : '咨询入口',
        icon: Icons.health_and_safety_outlined,
        accent: const Color(0xff43827b),
      ),
      children: [
        const _SectionTitle('开始前'),
        _ActionTile(
          icon: Icons.privacy_tip_outlined,
          title: '咨询协议',
          subtitle: '勾选后才能进入顾问流程；返回后会停在离开前的位置。',
          accent: widget.accent,
          trailing: Checkbox(
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
          ),
        ),
        const _ActionTile(
          icon: Icons.question_answer_outlined,
          title: '常见问题',
          subtitle: '含乳头疼痛、堵奶、亲喂姿势和泵奶节奏。',
          accent: Color(0xff6b6da8),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        if (_consultStarted)
          const _ActionTile(
            icon: Icons.support_agent_rounded,
            title: '咨询准备中',
            subtitle: '正在保留本次咨询上下文，稍后可以继续查看。',
            accent: Color(0xff43827b),
            trailing: Icon(Icons.check_circle_outline_rounded),
          ),
        FilledButton.icon(
          onPressed: _accepted && !_consultStarted
              ? () => setState(() => _consultStarted = true)
              : null,
          icon: const Icon(Icons.chat_rounded),
          label: Text(_consultStarted ? '已进入咨询队列' : '进入 IBCLC 咨询'),
        ),
      ],
    );
  }
}

class _MediaViewerPage extends StatefulWidget {
  const _MediaViewerPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  String _type = 'pdf';

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: SegmentedButton<String>(
        selected: {_type},
        showSelectedIcon: false,
        onSelectionChanged: (next) => setState(() => _type = next.first),
        segments: const [
          ButtonSegment(
            value: 'pdf',
            icon: Icon(Icons.picture_as_pdf_outlined),
            label: Text('PDF'),
          ),
          ButtonSegment(
            value: 'image',
            icon: Icon(Icons.image_outlined),
            label: Text('图片'),
          ),
          ButtonSegment(
            value: 'video',
            icon: Icon(Icons.play_circle_outline_rounded),
            label: Text('视频'),
          ),
        ],
      ),
      children: [
        const _SectionTitle('预览'),
        _MediaPreview(type: _type, accent: widget.accent),
        const SizedBox(height: 18),
        const _SectionTitle('操作'),
        _ActionTile(
          icon: Icons.download_for_offline_outlined,
          title: '离线缓存',
          subtitle: '网络不稳定时继续查看已缓存资料，并支持失败重试。',
          accent: widget.accent,
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.ios_share_rounded,
          title: '分享或返回',
          subtitle: '从 Agent artifact、IBCLC 和 W1 内容跳入时保留返回意图。',
          accent: Color(0xff43827b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.type, required this.accent});

  final String type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (type) {
      'image' => Icons.image_outlined,
      'video' => Icons.play_circle_outline_rounded,
      _ => Icons.picture_as_pdf_outlined,
    };
    final label = switch (type) {
      'image' => '图片预览',
      'video' => '视频预览',
      _ => 'PDF 预览',
    };

    return Container(
      height: 210,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 54, color: accent),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '选择资料后可在这里查看内容、进度和加载状态。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: path,
      title: title,
      summary: summary,
      icon: icon,
      accent: accent,
      priority: priority,
      children: const [
        _ActionTile(
          icon: Icons.home_outlined,
          title: '返回主入口',
          subtitle: '这个入口暂不可用，可以返回主入口继续使用。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
