import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:momcozy_flutter_app/features/pump_session/domain/pump_workstate.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

const _internalDeviceDebugEnabled = bool.fromEnvironment(
  'MOMCOZY_INTERNAL_BUILD',
);

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
                borderRadius: BorderRadius.circular(MomCozyRadii.control),
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
                      color: MomCozyColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: MomCozyColors.mutedForeground,
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
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
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
    return Container(
      width: 162,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: MomCozyColors.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MomCozyColors.mutedForeground,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.primary,
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
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
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
                      borderRadius: BorderRadius.circular(MomCozyRadii.control),
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                height: 1.35,
                                color: MomCozyColors.mutedForeground,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
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
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
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
  String _careStage = 'postpartum';
  bool _growthRecordAdded = false;
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
            if (isMom)
              _CareStageSelector(
                selectedStage: _careStage,
                accent: widget.accent,
                onChanged: (stage) => setState(() => _careStage = stage),
              ),
            ..._overviewChildren(snapshot, isMom),
            const SizedBox(height: 18),
            const _SectionTitle('下一步'),
            _ActionTile(
              icon: isMom
                  ? Icons.edit_note_rounded
                  : Icons.monitor_weight_outlined,
              title: isMom
                  ? '补写孕期日记'
                  : (_growthRecordAdded ? '成长记录已添加' : '记录成长事件'),
              subtitle: isMom
                  ? '保留心情、体征和 Agent 分析上下文。'
                  : (_growthRecordAdded
                        ? '本地草稿已保存，同步恢复后会写入成长记录。'
                        : '记录身高、体重、睡眠和喂养变化。'),
              accent: widget.accent,
              onTap: isMom
                  ? () => context.go('/records')
                  : () => setState(() => _growthRecordAdded = true),
              trailing: isMom
                  ? const Icon(Icons.chevron_right_rounded)
                  : _StatusChip(
                      label: _growthRecordAdded ? '已记录' : '新增',
                      icon: _growthRecordAdded
                          ? Icons.check_circle_outline_rounded
                          : Icons.add_circle_outline_rounded,
                      accent: widget.accent,
                    ),
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
    final isPregnancy = _careStage == 'pregnancy';

    return [
      _MetricTile(
        label: '阶段',
        value: isPregnancy ? '孕期' : _textOr(mom?.stage, '哺乳期'),
        icon: Icons.favorite_border_rounded,
        accent: widget.accent,
        note: isPregnancy
            ? '孕期重点：体征与日记'
            : (mom?.postpartumDay == null
                  ? null
                  : '产后第 ${mom!.postpartumDay} 天'),
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
      _MetricTile(
        label: '成长记录',
        value: _growthRecordAdded ? '已添加' : '待记录',
        icon: Icons.trending_up_rounded,
        accent: const Color(0xffb2773b),
        note: _growthRecordAdded ? '本地草稿待同步' : null,
      ),
    ];
  }
}

class _CareStageSelector extends StatelessWidget {
  const _CareStageSelector({
    required this.selectedStage,
    required this.accent,
    required this.onChanged,
  });

  final String selectedStage;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPregnancy = selectedStage == 'pregnancy';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '护理阶段',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPregnancy ? '孕期档案优先关注体征、日记和待办。' : '哺乳期档案优先关注恢复、泵奶和喂养。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            SegmentedButton<String>(
              selected: {selectedStage},
              showSelectedIcon: false,
              onSelectionChanged: (next) => onChanged(next.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.selected) ? accent : null,
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: 'pregnancy',
                  icon: Icon(Icons.pregnant_woman_rounded),
                  label: Text('孕期模式'),
                ),
                ButtonSegment(
                  value: 'postpartum',
                  icon: Icon(Icons.favorite_border_rounded),
                  label: Text('哺乳期模式'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
  final Map<String, List<ScheduleTask>> _localTasksByDay = {};
  final Set<String> _deletedTaskKeys = {};
  int _localTaskSequence = 0;
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
      _deletedTaskKeys.clear();
      _dayPlanFuture = _fetchDayPlan(runtime);
    });
  }

  void _selectDay(DateTime day) {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _selectedDay = day;
      _taskDoneOverrides.clear();
      _deletedTaskKeys.clear();
      _dayPlanFuture = _fetchDayPlan(runtime);
    });
  }

  void _toggleTask(ScheduleTask task, int index, bool? value) {
    final key = _taskScopedKey(task, index);
    setState(() {
      _taskDoneOverrides[key] = value ?? !_taskDone(task, index);
    });
  }

  void _addLocalTask() {
    final dayKey = _dayKey(_selectedDay);
    final localTasks = _localTasksByDay[dayKey] ?? const <ScheduleTask>[];
    _localTaskSequence += 1;
    final remindAt = DateTime.utc(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      21,
      30,
    );
    final task = ScheduleTask(
      id: 'local-$dayKey-$_localTaskSequence',
      title: '本地补充 ${localTasks.length + 1}',
      completed: false,
      remindAt: remindAt,
    );
    setState(() {
      _localTasksByDay[dayKey] = [...localTasks, task];
    });
  }

  void _deleteTask(ScheduleTask task, int index) {
    final key = _taskScopedKey(task, index);
    setState(() {
      _deletedTaskKeys.add(key);
      _taskDoneOverrides.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScheduleDayPlan>(
      future: _dayPlanFuture,
      builder: (context, snapshot) {
        final visibleTasks = snapshot.hasData
            ? _visibleTasks(snapshot.data!)
            : const <ScheduleTask>[];
        final taskCount = snapshot.hasData ? visibleTasks.length : null;
        final pendingTaskCount = visibleTasks
            .asMap()
            .entries
            .where((entry) => !_taskDone(entry.value, entry.key))
            .length;

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
              if (taskCount != null)
                _StatusChip(
                  label: '未完成 $pendingTaskCount',
                  icon: Icons.notification_important_outlined,
                  accent: const Color(0xff6b6da8),
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
            _ActionTile(
              icon: Icons.timer_outlined,
              title: '下一项倒计时',
              subtitle: _nextTaskSubtitle(visibleTasks),
              accent: const Color(0xff6b6da8),
              trailing: const Icon(Icons.schedule_rounded),
            ),
            _ActionTile(
              icon: Icons.add_task_rounded,
              title: '添加今日任务',
              subtitle: '先创建本地草稿；后端 create/delete 合同确认后接入同步。',
              accent: const Color(0xff43827b),
              onTap: _addLocalTask,
              trailing: const Icon(Icons.add_circle_outline_rounded),
            ),
            const SizedBox(height: 8),
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
    final tasks = plan == null ? const <ScheduleTask>[] : _visibleTasks(plan);
    if (tasks.isEmpty) {
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
      for (final entry in tasks.asMap().entries)
        _ActionTile(
          icon: _taskDone(entry.value, entry.key)
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
          title: _textOr(entry.value.title, '未命名计划'),
          subtitle: _taskSubtitle(entry.value),
          accent: _taskAccent(entry.key),
          onTap: () => _toggleTask(entry.value, entry.key, null),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: '删除任务',
                onPressed: () => _deleteTask(entry.value, entry.key),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              Checkbox(
                value: _taskDone(entry.value, entry.key),
                onChanged: (value) =>
                    _toggleTask(entry.value, entry.key, value),
              ),
            ],
          ),
        ),
    ];
  }

  bool _taskDone(ScheduleTask task, int index) {
    return _taskDoneOverrides[_taskScopedKey(task, index)] ?? task.completed;
  }

  List<ScheduleTask> _visibleTasks(ScheduleDayPlan plan) {
    final dayKey = _dayKey(_selectedDay);
    final tasks = [...plan.tasks, ...?_localTasksByDay[dayKey]];
    return tasks
        .asMap()
        .entries
        .where(
          (entry) => !_deletedTaskKeys.contains(
            _taskScopedKey(entry.value, entry.key),
          ),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  String _nextTaskSubtitle(List<ScheduleTask> tasks) {
    final runtime = _runtime;
    final now = runtime?.now().toUtc() ?? DateTime.now().toUtc();
    final next =
        tasks
            .asMap()
            .entries
            .where((entry) => !_taskDone(entry.value, entry.key))
            .map((entry) => entry.value)
            .where((task) => task.remindAt != null)
            .toList()
          ..sort((a, b) => a.remindAt!.compareTo(b.remindAt!));
    if (next.isEmpty) return '没有待提醒任务。';

    final task = next.first;
    final minutes = task.remindAt!.toUtc().difference(now).inMinutes;
    if (minutes <= 0) return '${_textOr(task.title, '下一项')} 已到提醒时间。';
    const minutesPerHour = 60;
    const minutesPerDay = 24 * minutesPerHour;
    final days = minutes ~/ minutesPerDay;
    final hours = (minutes % minutesPerDay) ~/ minutesPerHour;
    final remainingMinutes = minutes % minutesPerHour;
    if (days > 0) {
      return '${_textOr(task.title, '下一项')} 还有 $days 天 $hours 小时。';
    }
    if (hours > 0) {
      return '${_textOr(task.title, '下一项')} 还有 $hours 小时 $remainingMinutes 分钟。';
    }
    return '${_textOr(task.title, '下一项')} 还有 $remainingMinutes 分钟。';
  }

  String _taskScopedKey(ScheduleTask task, int index) {
    return '${_dayKey(_selectedDay)}:${_taskKey(task, index)}';
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? MomCozyColors.roseSoft : MomCozyColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
          side: BorderSide(
            color: selected ? MomCozyColors.primary : MomCozyColors.border,
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

String _dayKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
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
  BlePlatform? _blePlatform;
  BlePermissionState _permissionState = BlePermissionState.unknown;
  List<BleDeviceSnapshot> _connectedDevices = const [];
  List<BleDeviceSnapshot> _scanResults = const [];
  String? _bleError;
  bool _scanAttempted = false;
  String? _runtimeUserId;
  StreamSubscription<BleDeviceSnapshot>? _scanSub;
  StreamSubscription<BleScanFailure>? _scanFailureSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final ble = runtime.blePlatform;
    final previousUserId = _runtimeUserId;
    final userChanged =
        previousUserId != null && previousUserId != runtime.userId;
    _runtimeUserId = runtime.userId;
    if (!identical(ble, _blePlatform)) {
      unawaited(_scanSub?.cancel());
      unawaited(_scanFailureSub?.cancel());
      _blePlatform = ble;
      _scanSub = ble.scanResults.listen(_handleScanResult);
      _scanFailureSub = ble.scanFailures.listen(_handleScanFailure);
      unawaited(_refreshBleState());
    }
    if (userChanged) unawaited(_clearDevicesForUserSwitch());
  }

  @override
  void dispose() {
    unawaited(_scanSub?.cancel());
    unawaited(_scanFailureSub?.cancel());
    super.dispose();
  }

  Future<void> _refreshBleState() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      final permission = await ble.permissionState();
      final connected = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _permissionState = permission;
        _connectedDevices = connected;
        _bleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bleError = 'BLE 状态读取失败';
      });
    }
  }

  Future<void> _clearDevicesForUserSwitch() async {
    final ble = _blePlatform;
    if (ble == null) return;
    final devices = _connectedDevices.isEmpty
        ? await ble.getConnectedDevices()
        : _connectedDevices;
    try {
      if (_isScanning) await ble.stopScan();
      for (final device in devices.where((device) => device.connected)) {
        await ble.disconnect(device.deviceId);
      }
    } catch (_) {
      // Best-effort local isolation; native cleanup is verified in device lab.
    }
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _connectedDevices = const [];
      _scanResults = const [];
      _scanAttempted = false;
      _bleError = '检测到用户切换，已隔离上一用户设备连接。';
    });
  }

  Future<void> _toggleScan() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      if (_isScanning) {
        await ble.stopScan();
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
        return;
      }

      final permission = await ble.requestPermission();
      if (permission != BlePermissionState.granted) {
        if (!mounted) return;
        setState(() {
          _permissionState = permission;
          _bleError = _permissionDeniedMessage(permission);
        });
        return;
      }

      await ble.startScan();
      if (!mounted) return;
      setState(() {
        _permissionState = permission;
        _isScanning = true;
        _scanAttempted = true;
        _scanResults = const [];
        _bleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = 'BLE 扫描启动失败';
      });
    }
  }

  void _handleScanResult(BleDeviceSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _scanResults = [
        snapshot,
        ..._scanResults.where((item) => item.deviceId != snapshot.deviceId),
      ];
      _bleError = null;
    });
  }

  void _handleScanFailure(BleScanFailure failure) {
    if (!mounted) return;
    setState(() {
      _bleError = failure.message;
      _isScanning = false;
    });
  }

  Future<void> _connectScanResult(BleDeviceSnapshot snapshot) async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      await ble.connect(snapshot.deviceId);
      await ble.stopScan();
      await _refreshBleState();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = '${snapshot.deviceName} 已连接';
      });
    } catch (_) {
      await ble.stopScan();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = '连接 ${snapshot.deviceName} 失败，请重试。';
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    final ble = _blePlatform;
    if (ble == null) return;
    if (_permissionState == BlePermissionState.permanentlyDenied) {
      await ble.openAppSettings();
    } else {
      await ble.openBluetoothSettings();
    }
    await _refreshBleState();
  }

  @override
  Widget build(BuildContext context) {
    final leftDevice = _deviceForSide('L') ?? _deviceForSide('left');
    final rightDevice = _deviceForSide('R') ?? _deviceForSide('right');

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
            onPressed: _toggleScan,
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
          subtitle:
              _bleError ??
              (_isScanning
                  ? '正在查找附近设备；超时或空结果会显示在这里。'
                  : '权限状态 ${_permissionLabel(_permissionState)}，已恢复 ${_connectedDevices.length} 台已连接设备。'),
          accent: widget.accent,
          trailing: _isScanning
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _permissionAction(),
        ),
        const _SectionTitle('左右设备'),
        _DeviceSideTile(
          side: '左侧',
          name: leftDevice?.deviceName ?? '等待连接',
          state: leftDevice?.connected == true ? '已连接' : '未连接',
          battery: _deviceBatteryLabel(leftDevice),
          accent: widget.accent,
        ),
        _DeviceSideTile(
          side: '右侧',
          name: rightDevice?.deviceName ?? '等待连接',
          state: rightDevice?.connected == true ? '已连接' : '未连接',
          battery: _deviceBatteryLabel(rightDevice),
          accent: const Color(0xff7f6a75),
        ),
        if (_scanAttempted) ...[
          const SizedBox(height: 8),
          const _SectionTitle('扫描结果'),
          if (_scanResults.isEmpty)
            const _ActionTile(
              icon: Icons.bluetooth_disabled_rounded,
              title: '暂无扫描结果',
              subtitle: '请确认设备已开机并靠近手机后重试。',
              accent: Color(0xff7f6a75),
              trailing: Icon(Icons.refresh_rounded),
            )
          else
            for (final device in _scanResults.take(3))
              _ActionTile(
                icon: Icons.bluetooth_searching,
                title: device.deviceName,
                subtitle: _scanResultSubtitle(device),
                accent: widget.accent,
                onTap: () => _connectScanResult(device),
                trailing: const Icon(Icons.link_rounded),
              ),
        ],
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
        if (_internalDeviceDebugEnabled)
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

  Widget _permissionAction() {
    if (_permissionState == BlePermissionState.permanentlyDenied) {
      return IconButton(
        tooltip: '打开系统设置',
        onPressed: _openPermissionSettings,
        icon: const Icon(Icons.settings_rounded),
      );
    }
    if (_permissionState == BlePermissionState.denied) {
      return IconButton(
        tooltip: '打开蓝牙设置',
        onPressed: _openPermissionSettings,
        icon: const Icon(Icons.bluetooth_disabled_rounded),
      );
    }
    return const Icon(Icons.chevron_right_rounded);
  }

  BleDeviceSnapshot? _deviceForSide(String side) {
    final normalized = side.toLowerCase();
    for (final device in _connectedDevices) {
      if (device.side.toLowerCase() == normalized) return device;
    }
    return null;
  }
}

String _deviceBatteryLabel(BleDeviceSnapshot? device) {
  final battery = device?.battery;
  if (battery == null) return '--';
  return '$battery%';
}

String _scanResultSubtitle(BleDeviceSnapshot device) {
  final details = <String>[
    device.side,
    device.deviceId,
    if (device.battery != null) '电量 ${device.battery}%',
    if (device.rssi != null) 'RSSI ${device.rssi}',
  ];
  return details.join(' · ');
}

String _permissionLabel(BlePermissionState state) {
  return switch (state) {
    BlePermissionState.granted => '已授权',
    BlePermissionState.denied => '未授权',
    BlePermissionState.permanentlyDenied => '永久拒绝',
    BlePermissionState.unknown => '未请求',
  };
}

String _permissionDeniedMessage(BlePermissionState state) {
  if (state == BlePermissionState.permanentlyDenied) {
    return 'BLE 权限已永久拒绝，请从系统设置重新开启。';
  }
  return 'BLE 权限未授权';
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
  int _elapsedMinutes = 0;
  int _leftVolumeMl = 0;
  int _rightVolumeMl = 0;
  String? _sessionOwnerUserId;
  bool _completionUploadLocked = false;
  bool _duplicateCompletionBlocked = false;
  MomCozyApiRuntime? _runtime;
  PumpWorkstateReply? _lastReply;
  Object? _uploadError;
  String? _guardNotice;
  bool _isUploading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final previousRuntime = _runtime;
    if (previousRuntime != null &&
        previousRuntime.userId != runtime.userId &&
        _runState != _PumpRunState.idle) {
      _runState = _PumpRunState.idle;
      _isUploading = false;
      _elapsedMinutes = 0;
      _leftVolumeMl = 0;
      _rightVolumeMl = 0;
      _sessionOwnerUserId = null;
      _completionUploadLocked = false;
      _duplicateCompletionBlocked = false;
      _lastReply = null;
      _uploadError = null;
      _guardNotice = '检测到用户切换，已清空上一用户 session。';
    }
    _runtime = runtime;
  }

  void _changeRunState(_PumpRunState next) {
    if (next == _PumpRunState.idle && _completionUploadLocked) {
      setState(() {
        _duplicateCompletionBlocked = true;
        _guardNotice = '重复结束已拦截，本次 session 只保留一组结束上传。';
      });
      return;
    }

    setState(() {
      _applyLocalSessionTransition(next);
      _runState = next;
    });
    _uploadWorkstate(next);
  }

  void _applyLocalSessionTransition(_PumpRunState next) {
    final previous = _runState;
    if (previous == _PumpRunState.idle && next == _PumpRunState.running) {
      _sessionOwnerUserId = _runtime?.userId;
      _completionUploadLocked = false;
      _duplicateCompletionBlocked = false;
      _elapsedMinutes = 0;
      _leftVolumeMl = 0;
      _rightVolumeMl = 0;
      _guardNotice = '已绑定 ${_sessionOwnerUserId ?? '当前用户'}。';
      _advanceLocalProgress(minutes: 2);
      return;
    }

    if (previous == _PumpRunState.running && next == _PumpRunState.paused) {
      _advanceLocalProgress(minutes: 3);
      return;
    }

    if (previous == _PumpRunState.paused && next == _PumpRunState.running) {
      _advanceLocalProgress(minutes: 2);
      return;
    }

    if (next == _PumpRunState.idle && previous != _PumpRunState.idle) {
      _advanceLocalProgress(minutes: 1);
      _completionUploadLocked = true;
      _duplicateCompletionBlocked = false;
      _guardNotice = '结束上传已锁定：summary、milk record、Agent context 仅允许一次。';
    }
  }

  void _advanceLocalProgress({required int minutes}) {
    _elapsedMinutes += minutes;
    _leftVolumeMl += (_leftLevel * minutes).round();
    _rightVolumeMl += (_rightLevel * minutes * 0.8).round();
  }

  Future<void> _uploadWorkstate(_PumpRunState state) async {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final reply = await runtime.pumpWorkstateRepository.uploadWorkstate(
        userId: runtime.userId,
        left: PumpSideWorkstate(
          state: _pumpStateCode(state),
          mode: 'massage_expression',
          level: _leftLevel.round(),
        ),
        right: PumpSideWorkstate(
          state: _pumpStateCode(state),
          mode: 'expression',
          level: _rightLevel.round(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lastReply = reply;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadError = error;
        _isUploading = false;
      });
    }
  }

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
                  : () => _changeRunState(_PumpRunState.running),
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.water_drop,
              ),
              label: Text(isPaused ? '恢复' : '开始'),
            ),
            OutlinedButton.icon(
              onPressed: isRunning
                  ? () => _changeRunState(_PumpRunState.paused)
                  : null,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('暂停'),
            ),
            OutlinedButton.icon(
              onPressed: _runState == _PumpRunState.idle
                  ? null
                  : () => _changeRunState(_PumpRunState.idle),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('结束'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Session 进度'),
        _MetricWrap(
          children: [
            _MetricTile(
              label: '运行时长',
              value: '$_elapsedMinutes 分钟',
              icon: Icons.timer_outlined,
              accent: widget.accent,
              note: _sessionOwnerUserId == null
                  ? '未绑定用户'
                  : '绑定 $_sessionOwnerUserId',
            ),
            _MetricTile(
              label: '左侧进度',
              value: '$_leftVolumeMl mL',
              icon: Icons.water_drop_outlined,
              accent: widget.accent,
              note: '档位 ${_leftLevel.round()}',
            ),
            _MetricTile(
              label: '右侧进度',
              value: '$_rightVolumeMl mL',
              icon: Icons.water_drop_outlined,
              accent: const Color(0xff43827b),
              note: '档位 ${_rightLevel.round()}',
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
        const _SectionTitle('结束保护'),
        _ActionTile(
          icon: _duplicateCompletionBlocked
              ? Icons.block_rounded
              : Icons.verified_outlined,
          title: _completionGuardTitle(),
          subtitle: _guardNotice ?? '开始后绑定当前用户，结束时锁定一次性上传标记。',
          accent: _duplicateCompletionBlocked
              ? const Color(0xffb2773b)
              : const Color(0xff43827b),
          trailing: _StatusChip(
            label: _completionUploadLocked ? '1/1' : '待结束',
            icon: _completionUploadLocked
                ? Icons.lock_outline_rounded
                : Icons.hourglass_empty_rounded,
            accent: _duplicateCompletionBlocked
                ? const Color(0xffb2773b)
                : const Color(0xff43827b),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('上传状态'),
        _ActionTile(
          icon: _uploadError == null
              ? Icons.cloud_sync_outlined
              : Icons.cloud_off_outlined,
          title: _uploadStatusTitle(),
          subtitle: _uploadStatusSubtitle(),
          accent: const Color(0xff6b6da8),
          trailing: _isUploading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: '重试同步',
                  onPressed: () => _uploadWorkstate(_runState),
                  icon: const Icon(Icons.refresh_rounded),
                ),
        ),
      ],
    );
  }

  String _uploadStatusTitle() {
    if (_isUploading) return '正在同步 workstate';
    if (_uploadError != null) return 'Workstate 同步失败';
    if (_lastReply != null) return 'Workstate 已同步';
    return 'Agent context 上传';
  }

  String _uploadStatusSubtitle() {
    if (_uploadError is String) return _uploadError! as String;
    if (_uploadError != null) return '检查后端连接或 token 后重试。';
    final reply = _lastReply;
    if (reply == null) return '结束后生成摘要、奶量记录和智能体上下文；重复上传会被自动拦截。';
    if (reply.output.isNotEmpty) return reply.output;
    return reply.needReply ? '后端需要处理设备状态回复。' : '后端已接收当前左右侧状态。';
  }

  String _completionGuardTitle() {
    if (_duplicateCompletionBlocked) return '重复结束已拦截';
    if (_completionUploadLocked) return '结束同步已锁定';
    if (_sessionOwnerUserId != null) return 'Session 用户已绑定';
    return 'Session 等待开始';
  }
}

int _pumpStateCode(_PumpRunState state) {
  return switch (state) {
    _PumpRunState.running => 1,
    _PumpRunState.paused => 2,
    _PumpRunState.idle => 0,
  };
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
  BlePlatform? _blePlatform;
  List<BleDeviceSnapshot> _connectedDevices = const [];
  String? _deviceStatusError;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ble = MomCozyRuntimeScope.of(context).blePlatform;
    if (!identical(ble, _blePlatform)) {
      _blePlatform = ble;
      unawaited(_refreshCalibrationDevices());
    }
  }

  Future<void> _refreshCalibrationDevices() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      final devices = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = devices;
        _deviceStatusError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceStatusError = '设备状态同步失败，请稍后重试。';
      });
    }
  }

  void _setLeftComfort(double value) {
    setState(() {
      _leftComfort = value;
      _hasUnsavedChanges = true;
      _saveError = null;
    });
  }

  void _setRightComfort(double value) {
    setState(() {
      _rightComfort = value;
      _hasUnsavedChanges = true;
      _saveError = null;
    });
  }

  void _resetCalibrationChanges() {
    setState(() {
      _leftComfort = 4;
      _rightComfort = 4;
      _hasUnsavedChanges = false;
      _saveError = '已恢复默认校准档位，可安全退出。';
    });
  }

  Future<void> _saveAndEnterPump() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      await runtime.ensurePumpProtocolReady();
      await runtime.pumpProtocolPlatform.adjustGearForSide(
        PumpSide.left,
        _leftComfort.round(),
      );
      await runtime.pumpProtocolPlatform.adjustGearForSide(
        PumpSide.right,
        _rightComfort.round(),
      );
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = false;
      });
      context.go('/pump');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = _calibrationSaveErrorText(error);
      });
    }
  }

  void _exitCalibration() {
    if (_hasUnsavedChanges) {
      setState(() {
        _saveError = '有未保存校准更改，请先保存或恢复默认后再退出。';
      });
      return;
    }
    context.go('/device');
  }

  @override
  Widget build(BuildContext context) {
    final leftDevice = _deviceForSide('L') ?? _deviceForSide('left');
    final rightDevice = _deviceForSide('R') ?? _deviceForSide('right');

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
        const _SectionTitle('设备状态'),
        if (_deviceStatusError != null)
          _ActionTile(
            icon: Icons.bluetooth_disabled_rounded,
            title: '设备状态同步失败',
            subtitle: _deviceStatusError!,
            accent: Colors.red,
            trailing: IconButton(
              tooltip: '重试设备状态',
              onPressed: _refreshCalibrationDevices,
              icon: const Icon(Icons.refresh_rounded),
            ),
          )
        else ...[
          _CalibrationDeviceTile(
            label: '左侧',
            device: leftDevice,
            accent: widget.accent,
          ),
          _CalibrationDeviceTile(
            label: '右侧',
            device: rightDevice,
            accent: const Color(0xff43827b),
          ),
        ],
        const SizedBox(height: 8),
        const _SectionTitle('舒适档位'),
        _CalibrationSideTile(
          label: '左侧',
          value: _leftComfort,
          accent: widget.accent,
          onChanged: _setLeftComfort,
        ),
        _CalibrationSideTile(
          label: '右侧',
          value: _rightComfort,
          accent: const Color(0xff43827b),
          onChanged: _setRightComfort,
        ),
        const SizedBox(height: 8),
        const _SectionTitle('保存规则'),
        _ActionTile(
          icon: Icons.verified_user_outlined,
          title: '校准结果保存检查',
          subtitle: _saveError ?? '保存前会检查左右设备状态，并处理历史校准数据。',
          accent: _saveError == null ? const Color(0xff7f6a75) : Colors.red,
          trailing: _isSaving
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(
                  _saveError == null
                      ? Icons.rule_rounded
                      : Icons.error_outline_rounded,
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveAndEnterPump,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isSaving ? '保存中' : '保存并进入泵奶'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _exitCalibration,
              icon: const Icon(Icons.close_rounded),
              label: const Text('退出校准'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetCalibrationChanges,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('恢复默认'),
            ),
          ],
        ),
      ],
    );
  }

  BleDeviceSnapshot? _deviceForSide(String side) {
    final normalized = side.toLowerCase();
    for (final device in _connectedDevices) {
      if (device.side.toLowerCase() == normalized) return device;
    }
    return null;
  }

  String _calibrationSaveErrorText(Object error) {
    final text = '$error';
    if (text.contains('No BLE device') ||
        text.contains('No pump protocol state')) {
      return '未检测到左右设备连接，请先在设备页连接后再保存。';
    }
    if (text.contains('BLE permission')) {
      return '蓝牙权限未开启，请授权后重试。';
    }
    return '校准保存失败，请稍后重试。';
  }
}

class _CalibrationDeviceTile extends StatelessWidget {
  const _CalibrationDeviceTile({
    required this.label,
    required this.device,
    required this.accent,
  });

  final String label;
  final BleDeviceSnapshot? device;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final connected = device != null;
    return _ActionTile(
      icon: connected
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      title: '$label设备${connected ? '已连接' : '未连接'}',
      subtitle: connected
          ? '${device!.deviceName} · 电量 ${_deviceBatteryLabel(device)}'
          : '未检测到连接设备，保存时会提示重试。',
      accent: connected ? accent : const Color(0xff7f6a75),
      trailing: Icon(
        connected ? Icons.check_circle_outline_rounded : Icons.info_outline,
      ),
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
  String _volumeUnit = 'mL';
  final List<PumpMilkRecord> _localPumpRecords = [];
  final Map<String, PumpMilkRecord> _editedPumpRecords = {};
  final Set<String> _deletedPumpRecordIds = {};
  int _localPumpRecordSequence = 0;
  MomCozyApiRuntime? _runtime;
  late DateTime _recordsDay;
  late Future<_RecordsOverview> _recordsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _recordsDay = runtime.now();
      _recordsFuture = _fetchRecords(runtime);
    }
  }

  Future<_RecordsOverview> _fetchRecords(MomCozyApiRuntime runtime) async {
    final repository = runtime.recordsRepository;
    final pump = await repository.fetchPumpMilkRecords(
      userId: runtime.userId,
      date: _recordsDay,
    );
    final feeding = await repository.fetchFeedingRecords(
      userId: runtime.userId,
      date: _recordsDay,
    );
    final growth = await repository.fetchGrowthRecords(
      userId: runtime.userId,
      babyId: runtime.babyId,
    );
    return _RecordsOverview(pump: pump, feeding: feeding, growth: growth);
  }

  void _reloadRecords() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _recordsFuture = _fetchRecords(runtime);
    });
  }

  void _addManualPumpRecord() {
    _localPumpRecordSequence += 1;
    final occurredAt = DateTime.utc(
      _recordsDay.year,
      _recordsDay.month,
      _recordsDay.day,
      21,
      45,
    );
    final record = PumpMilkRecord(
      id: 'local-pump-$_localPumpRecordSequence',
      title: '手动补录 $_localPumpRecordSequence',
      pumpSource: 9,
      amountMl: 90,
      occurredAt: occurredAt,
    );
    setState(() {
      _filter = 'pump';
      _localPumpRecords.insert(0, record);
    });
  }

  void _editPumpRecord(PumpMilkRecord record) {
    final edited = PumpMilkRecord(
      id: record.id,
      title: '已编辑 ${_textOr(record.title, '泵奶记录')}',
      pumpType: record.pumpType,
      pumpSource: record.pumpSource,
      amountMl: (record.amountMl ?? 0) + 10,
      occurredAt: record.occurredAt,
    );
    setState(() {
      _editedPumpRecords[record.id] = edited;
    });
  }

  void _deletePumpRecord(PumpMilkRecord record) {
    setState(() {
      _deletedPumpRecordIds.add(record.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RecordsOverview>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        final overview = snapshot.data == null
            ? null
            : _applyLocalRecordEdits(snapshot.data!);

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
              SegmentedButton<String>(
                key: const ValueKey('records-filter-segment'),
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (next) =>
                    setState(() => _filter = next.first),
                segments: const [
                  ButtonSegment(value: 'pump', label: Text('泵奶')),
                  ButtonSegment(value: 'feed', label: Text('喂养')),
                  ButtonSegment(value: 'growth', label: Text('成长')),
                ],
              ),
              SegmentedButton<String>(
                key: const ValueKey('records-unit-segment'),
                selected: {_volumeUnit},
                showSelectedIcon: false,
                onSelectionChanged: (next) =>
                    setState(() => _volumeUnit = next.first),
                segments: const [
                  ButtonSegment(value: 'mL', label: Text('mL')),
                  ButtonSegment(value: 'oz', label: Text('oz')),
                ],
              ),
            ],
          ),
          children: [
            const _SectionTitle('本周概览'),
            ..._recordsSummaryChildren(snapshot, overview),
            if (overview != null && !snapshot.hasError) ...[
              const SizedBox(height: 18),
              const _SectionTitle('趋势'),
              ..._trendChildren(overview),
              const SizedBox(height: 18),
              const _SectionTitle('最近记录'),
              ..._recordChildren(overview),
            ],
            _ActionTile(
              icon: Icons.add_circle_outline_rounded,
              title: '手动补录',
              subtitle: '支持 mL/oz、左右侧、时间和备注。',
              accent: const Color(0xff43827b),
              onTap: _addManualPumpRecord,
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _recordsSummaryChildren(
    AsyncSnapshot<_RecordsOverview> snapshot,
    _RecordsOverview? visibleOverview,
  ) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const [
        _ActionTile(
          icon: Icons.sync_rounded,
          title: '正在同步记录',
          subtitle: '正在读取泵奶、喂养和成长记录。',
          accent: Color(0xff6b6da8),
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
          title: '记录同步失败',
          subtitle: '弱网/离线时保留本地筛选，可点击重试。',
          accent: widget.accent,
          trailing: IconButton(
            tooltip: '重试',
            onPressed: _reloadRecords,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ];
    }

    final overview = visibleOverview ?? _RecordsOverview.empty;
    return [
      _MetricWrap(
        children: [
          _MetricTile(
            label: '总奶量',
            value: _amountLabel(overview.totalMilkMl, unit: _volumeUnit),
            icon: Icons.water_drop_outlined,
            accent: widget.accent,
            note: '泵奶 + 喂养',
          ),
          _MetricTile(
            label: '记录数',
            value: overview.recordCount.toString(),
            icon: Icons.receipt_long_outlined,
            accent: const Color(0xff43827b),
          ),
          _MetricTile(
            label: '最近记录',
            value: _dateTimeLabel(overview.latestAt),
            icon: Icons.schedule_rounded,
            accent: const Color(0xffb2773b),
          ),
        ],
      ),
    ];
  }

  List<Widget> _trendChildren(_RecordsOverview overview) {
    final points = overview.milkTrendPoints;
    if (points.isEmpty) {
      return const [
        _ActionTile(
          icon: Icons.insights_rounded,
          title: '暂无奶量趋势',
          subtitle: '泵奶或喂养记录同步后会显示趋势。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.show_chart_rounded),
        ),
      ];
    }

    final maxAmount = points
        .map((point) => point.amountMl)
        .reduce((a, b) => a > b ? a : b);
    return [
      for (final point in points.take(3))
        _TrendBar(
          label: point.label,
          value: maxAmount <= 0 ? 0 : point.amountMl / maxAmount,
          valueLabel: _amountLabel(point.amountMl, unit: _volumeUnit),
        ),
    ];
  }

  List<Widget> _recordChildren(_RecordsOverview overview) {
    return switch (_filter) {
      'feed' => _feedingRecordChildren(overview.feeding),
      'growth' => _growthRecordChildren(overview.growth),
      _ => _pumpRecordChildren(overview.pump),
    };
  }

  List<Widget> _pumpRecordChildren(List<PumpMilkRecord> records) {
    if (records.isEmpty) return [_emptyRecordTile('暂无泵奶记录')];
    return [
      for (final record in records)
        _ActionTile(
          icon: Icons.water_drop_rounded,
          title:
              '${_dateTimeLabel(record.occurredAt)} ${_textOr(record.title, '泵奶记录')}',
          subtitle:
              '${_amountLabel(record.amountMl, unit: _volumeUnit)} · 来源 ${record.pumpSource ?? '--'}${_crossDaySuffix(record.occurredAt)}',
          accent: widget.accent,
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: '编辑记录',
                onPressed: () => _editPumpRecord(record),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '删除记录',
                onPressed: () => _deletePumpRecord(record),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _feedingRecordChildren(List<FeedingRecord> records) {
    if (records.isEmpty) return [_emptyRecordTile('暂无喂养记录')];
    return [
      for (final record in records)
        _ActionTile(
          icon: Icons.child_friendly_rounded,
          title: '${_dateTimeLabel(record.occurredAt)} 喂养',
          subtitle:
              '${_amountLabel(record.amountMl, unit: _volumeUnit)} · ${_textOr(record.type, '未分类')}',
          accent: const Color(0xff43827b),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
    ];
  }

  List<Widget> _growthRecordChildren(List<GrowthRecord> records) {
    if (records.isEmpty) return [_emptyRecordTile('暂无成长记录')];
    return [
      for (final record in records)
        _ActionTile(
          icon: Icons.monitor_weight_outlined,
          title: '${_dateLabel(record.measuredAt)} 成长记录',
          subtitle:
              '${_weightLabel(record.weightGram)} · ${_heightLabel(record.heightCm)}',
          accent: const Color(0xff6b6da8),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
    ];
  }

  Widget _emptyRecordTile(String title) {
    return _ActionTile(
      icon: Icons.info_outline_rounded,
      title: title,
      subtitle: '同步完成后仍没有对应记录。',
      accent: const Color(0xff7f6a75),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  _RecordsOverview _applyLocalRecordEdits(_RecordsOverview overview) {
    final pump = <PumpMilkRecord>[..._localPumpRecords, ...overview.pump]
        .where((record) => !_deletedPumpRecordIds.contains(record.id))
        .map((record) => _editedPumpRecords[record.id] ?? record)
        .toList(growable: false);
    return _RecordsOverview(
      pump: pump,
      feeding: overview.feeding,
      growth: overview.growth,
    );
  }

  String _crossDaySuffix(DateTime? occurredAt) {
    if (occurredAt == null) return '';
    final day = DateTime.utc(
      _recordsDay.year,
      _recordsDay.month,
      _recordsDay.day,
    );
    final recordDay = DateTime.utc(
      occurredAt.toUtc().year,
      occurredAt.toUtc().month,
      occurredAt.toUtc().day,
    );
    return recordDay == day ? '' : ' · 跨天记录';
  }
}

class _RecordsOverview {
  const _RecordsOverview({
    required this.pump,
    required this.feeding,
    required this.growth,
  });

  static const empty = _RecordsOverview(
    pump: <PumpMilkRecord>[],
    feeding: <FeedingRecord>[],
    growth: <GrowthRecord>[],
  );

  final List<PumpMilkRecord> pump;
  final List<FeedingRecord> feeding;
  final List<GrowthRecord> growth;

  int get totalMilkMl {
    final pumpTotal = pump.fold<int>(
      0,
      (total, record) => total + (record.amountMl ?? 0),
    );
    final feedingTotal = feeding.fold<int>(
      0,
      (total, record) => total + (record.amountMl ?? 0),
    );
    return pumpTotal + feedingTotal;
  }

  int get recordCount => pump.length + feeding.length + growth.length;

  DateTime? get latestAt {
    final dates = <DateTime>[
      for (final record in pump)
        if (record.occurredAt != null) record.occurredAt!,
      for (final record in feeding)
        if (record.occurredAt != null) record.occurredAt!,
      for (final record in growth)
        if (record.measuredAt != null) record.measuredAt!,
    ]..sort((a, b) => b.compareTo(a));
    return dates.isEmpty ? null : dates.first;
  }

  List<_MilkTrendPoint> get milkTrendPoints {
    final points = <_MilkTrendPoint>[
      for (final record in pump)
        if (record.amountMl != null)
          _MilkTrendPoint(
            label: _dateTimeLabel(record.occurredAt),
            amountMl: record.amountMl!,
          ),
      for (final record in feeding)
        if (record.amountMl != null)
          _MilkTrendPoint(
            label: _dateTimeLabel(record.occurredAt),
            amountMl: record.amountMl!,
          ),
    ];
    return points;
  }
}

class _MilkTrendPoint {
  const _MilkTrendPoint({required this.label, required this.amountMl});

  final String label;
  final int amountMl;
}

String _amountLabel(int? amountMl, {String unit = 'mL'}) {
  if (amountMl == null) return '--';
  if (unit == 'oz') {
    return '${(amountMl / 29.5735).toStringAsFixed(1)} oz';
  }
  return '$amountMl mL';
}

String _weightLabel(int? weightGram) {
  if (weightGram == null) return '--';
  return '${(weightGram / 1000).toStringAsFixed(1)} kg';
}

String _heightLabel(double? heightCm) {
  return heightCm == null ? '--' : '${heightCm.toStringAsFixed(1)} cm';
}

String _dateTimeLabel(DateTime? value) {
  if (value == null) return '--';
  return _timeLabel(value);
}

String _dateLabel(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day';
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.label, required this.value, this.valueLabel});

  final String label;
  final double value;
  final String? valueLabel;

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
              value: value.clamp(0, 1),
              minHeight: 10,
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
            ),
          ),
          const SizedBox(width: 10),
          Text(valueLabel ?? '${(value * 500).round()} mL'),
        ],
      ),
    );
  }
}

class _CommunityPage extends StatefulWidget {
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
  State<_CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<_CommunityPage> {
  String? _lastActionStatus;
  String? _postingKey;

  Future<void> _openCommunityItem(String key, String label) async {
    if (_postingKey != null) return;
    setState(() {
      _postingKey = key;
      _lastActionStatus = null;
    });

    final sent = await _postFeatureClientEvent(
      context,
      eventType: 'community_item_opened',
      label: '打开社区内容：$label',
      metadata: {'item_key': key, 'source': 'community'},
    );
    if (!mounted) return;
    setState(() {
      _postingKey = null;
      _lastActionStatus = sent ? '已记录 $label。' : '本地已打开，稍后重试同步。';
    });
  }

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
      children: [
        const _SectionTitle('关注话题'),
        _ActionTile(
          icon: Icons.forum_outlined,
          title: '泵奶节奏调整',
          subtitle: '来自相同月龄妈妈的经验和已收藏讨论。',
          accent: const Color(0xff6b6da8),
          onTap: () => _openCommunityItem('pump_rhythm', '泵奶节奏调整'),
          trailing: _communityTrailing('pump_rhythm'),
        ),
        _ActionTile(
          icon: Icons.favorite_border_rounded,
          title: '产后恢复',
          subtitle: '查看收藏内容、精选讨论和恢复建议。',
          accent: const Color(0xff9f6378),
          onTap: () => _openCommunityItem('postpartum_recovery', '产后恢复'),
          trailing: _communityTrailing('postpartum_recovery'),
        ),
        const _SectionTitle('最新动态'),
        _ActionTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: '妈妈小组更新',
          subtitle: '3 条新回复，打开后会更新已读状态。',
          accent: const Color(0xff43827b),
          onTap: () => _openCommunityItem('group_updates', '妈妈小组更新'),
          trailing: _communityTrailing('group_updates'),
        ),
        if (_lastActionStatus != null)
          _ActionTile(
            icon: Icons.done_all_rounded,
            title: '社区状态',
            subtitle: _lastActionStatus!,
            accent: const Color(0xff43827b),
            trailing: const Icon(Icons.check_circle_outline_rounded),
          ),
      ],
    );
  }

  Widget _communityTrailing(String key) {
    if (_postingKey != key) return const Icon(Icons.chevron_right_rounded);
    return const SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}

class _DeviceManagePage extends StatefulWidget {
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
  State<_DeviceManagePage> createState() => _DeviceManagePageState();
}

class _DeviceManagePageState extends State<_DeviceManagePage> {
  List<BleDeviceSnapshot> _connectedDevices = const [];
  bool _isRefreshing = false;
  String? _syncStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_refreshDevices());
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _isRefreshing = true;
      _syncStatus = null;
    });
    try {
      final devices = await MomCozyRuntimeScope.of(
        context,
      ).blePlatform.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = devices;
        _isRefreshing = false;
        _syncStatus = devices.isEmpty
            ? '当前没有已连接设备。'
            : '已同步 ${devices.length} 台设备。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _syncStatus = '设备状态同步失败，请稍后重试。';
      });
    }
  }

  Future<void> _disconnectAll() async {
    setState(() {
      _isRefreshing = true;
      _syncStatus = null;
    });
    try {
      final ble = MomCozyRuntimeScope.of(context).blePlatform;
      final devices = await ble.getConnectedDevices();
      for (final device in devices) {
        await ble.disconnect(device.deviceId);
      }
      final next = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = next;
        _isRefreshing = false;
        _syncStatus = '已解绑 ${devices.length} 台设备。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _syncStatus = '解绑失败，请确认 session 已结束后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedSummary = _connectedDevices.isEmpty
        ? '暂无已连接设备'
        : _connectedDevices
              .map((device) => '${device.side} ${device.deviceName}')
              .join('、');

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      children: [
        const _SectionTitle('设备操作'),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: '固件和序列号',
          subtitle: connectedSummary,
          accent: widget.accent,
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.notifications_active_outlined,
          title: '设备提醒通道',
          subtitle: '管理设备消息、提醒声音和后台接收状态。',
          accent: Color(0xffb2773b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        _ActionTile(
          icon: Icons.refresh_rounded,
          title: '重新同步设备状态',
          subtitle: _syncStatus ?? '刷新左右设备连接、电量和运行快照。',
          accent: const Color(0xff43827b),
          onTap: _isRefreshing ? null : _refreshDevices,
          trailing: _isRefreshing
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.sync_rounded),
        ),
        _ActionTile(
          icon: Icons.link_off_rounded,
          title: '解绑设备',
          subtitle: '解绑前需要确认后台 session 已结束。',
          accent: const Color(0xff9f6378),
          onTap: _connectedDevices.isEmpty || _isRefreshing
              ? null
              : _disconnectAll,
          trailing: const Icon(Icons.chevron_right_rounded),
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
    final runtime = MomCozyRuntimeScope.of(context);
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
          subtitle:
              '${runtime.userId} · baby ${runtime.babyId} · ${runtime.locale}',
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

class _W1Page extends StatefulWidget {
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
  State<_W1Page> createState() => _W1PageState();
}

class _W1PageState extends State<_W1Page> {
  bool _openingTutorial = false;

  Future<void> _openTutorial() async {
    if (_openingTutorial) return;
    setState(() => _openingTutorial = true);
    await _postFeatureClientEvent(
      context,
      eventType: 'w1_tutorial_opened',
      label: '打开 W1 使用教程',
      metadata: const {'source': 'w1', 'target': 'media-viewer'},
    );
    if (!mounted) return;
    context.go('/media-viewer');
  }

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
          accent: const Color(0xff6b6da8),
          onTap: _openTutorial,
          trailing: _openingTutorial
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

Future<bool> _postFeatureClientEvent(
  BuildContext context, {
  required String eventType,
  required String label,
  required Map<String, Object?> metadata,
}) async {
  try {
    final runtime = MomCozyRuntimeScope.of(context);
    final result = await runtime.clientEventClient.post(
      AgentStreamClientEventRequest(
        threadId: 'thread-${runtime.userId}',
        userId: runtime.userId,
        eventType: eventType,
        label: label,
        occurredAt: runtime.now().toIso8601String(),
        locale: runtime.locale,
        metadata: metadata,
      ),
    );
    return result.sent;
  } catch (_) {
    return false;
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
  bool _isSyncing = false;
  String? _syncStatus;
  final Set<String> _removedItemIds = {};

  void _setPacked(String id, bool value) {
    setState(() {
      switch (id) {
        case 'pump':
          _pumpPacked = value;
          break;
        case 'pads':
          _padsPacked = value;
          break;
        case 'baby_clothes':
          _babyClothesPacked = value;
          break;
      }
    });
    unawaited(_syncCart());
  }

  void _resetCart() {
    setState(() {
      _pumpPacked = true;
      _padsPacked = false;
      _babyClothesPacked = false;
      _removedItemIds.clear();
    });
    unawaited(_syncCart());
  }

  void _deleteItem(String id) {
    setState(() {
      _removedItemIds.add(id);
      switch (id) {
        case 'pump':
          _pumpPacked = false;
          break;
        case 'pads':
          _padsPacked = false;
          break;
        case 'baby_clothes':
          _babyClothesPacked = false;
          break;
      }
    });
    unawaited(_syncCart());
  }

  Future<void> _syncCart() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final result = await runtime.hospitalBagCartRepository.syncCart(
        userId: runtime.userId,
        items: _hospitalBagItems(),
      );
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = result.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = '本地清单已更新，稍后重试同步。';
      });
    }
  }

  List<HospitalBagPackedItem> _hospitalBagItems() {
    return [
      HospitalBagPackedItem(id: 'pump', title: '吸奶器和配件', packed: _pumpPacked),
      HospitalBagPackedItem(id: 'pads', title: '产后护理用品', packed: _padsPacked),
      HospitalBagPackedItem(
        id: 'baby_clothes',
        title: '宝宝衣物',
        packed: _babyClothesPacked,
      ),
    ].where((item) => !_removedItemIds.contains(item.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _hospitalBagItems();
    final packed = items.where((item) => item.packed).length;

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      priority: widget.priority,
      trailing: _StatusChip(
        label: '$packed/${items.length} 已准备',
        icon: Icons.inventory_2_outlined,
        accent: widget.accent,
      ),
      children: [
        const _SectionTitle('清单'),
        if (!_removedItemIds.contains('pump'))
          _ChecklistTile(
            title: '吸奶器和配件',
            subtitle: '主机、阀门、储奶袋、充电线。',
            value: _pumpPacked,
            accent: widget.accent,
            onChanged: (value) => _setPacked('pump', value),
            onDelete: () => _deleteItem('pump'),
          ),
        if (!_removedItemIds.contains('pads'))
          _ChecklistTile(
            title: '产后护理用品',
            subtitle: '护理垫、湿巾、一次性用品。',
            value: _padsPacked,
            accent: const Color(0xff43827b),
            onChanged: (value) => _setPacked('pads', value),
            onDelete: () => _deleteItem('pads'),
          ),
        if (!_removedItemIds.contains('baby_clothes'))
          _ChecklistTile(
            title: '宝宝衣物',
            subtitle: '连体衣、包巾、帽子和备用衣物。',
            value: _babyClothesPacked,
            accent: const Color(0xff6b6da8),
            onChanged: (value) => _setPacked('baby_clothes', value),
            onDelete: () => _deleteItem('baby_clothes'),
          ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: _isSyncing ? Icons.sync_rounded : Icons.cloud_done_outlined,
          title: '购物车同步',
          subtitle: _syncStatus ?? '勾选变化会同步到待产包购物车状态。',
          accent: const Color(0xff43827b),
          trailing: _isSyncing
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.check_circle_outline_rounded),
        ),
        _ActionTile(
          icon: Icons.restore_rounded,
          title: '恢复默认清单',
          subtitle: '把待产包恢复为推荐清单，并同步购物车状态。',
          accent: const Color(0xff7f6a75),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _resetCart,
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
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
      title: title,
      subtitle: subtitle,
      accent: accent,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (next) => onChanged(next ?? false)),
          if (onDelete != null)
            IconButton(
              tooltip: '删除$title',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
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
  bool _isStarting = false;
  String? _syncStatus;
  static const String _returnToPath = '/status';

  Future<void> _startConsult() async {
    if (!_accepted || _consultStarted || _isStarting) return;
    setState(() {
      _isStarting = true;
      _syncStatus = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final result = await runtime.clientEventClient.post(
        AgentStreamClientEventRequest(
          threadId: 'thread-${runtime.userId}',
          userId: runtime.userId,
          eventType: 'ibclc_consult_started',
          label: '用户进入 IBCLC 在线咨询队列',
          occurredAt: runtime.now().toIso8601String(),
          locale: runtime.locale,
          metadata: const {
            'consult_id': 'ibclc-flutter-default',
            'source': 'ibclc-chat',
            'handoff': 'vendor_h5_native',
            'return_to': _returnToPath,
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _consultStarted = true;
        _isStarting = false;
        _syncStatus = result.sent ? '咨询事件已同步。' : '本地已进入队列，稍后重试同步。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consultStarted = true;
        _isStarting = false;
        _syncStatus = '本地已进入队列，稍后重试同步。';
      });
    }
  }

  void _returnToStatus() {
    context.go(_returnToPath);
  }

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
          _ActionTile(
            icon: Icons.support_agent_rounded,
            title: '顾问流程已打开',
            subtitle: _syncStatus ?? '正在保留本次咨询上下文，稍后可以继续查看。',
            accent: const Color(0xff43827b),
            trailing: IconButton(
              key: const ValueKey('ibclc-return-status-button'),
              tooltip: '返回状态页',
              onPressed: _returnToStatus,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        FilledButton.icon(
          onPressed: _accepted && !_consultStarted && !_isStarting
              ? _startConsult
              : null,
          icon: const Icon(Icons.chat_rounded),
          label: Text(
            _consultStarted
                ? '已进入咨询队列'
                : _isStarting
                ? '进入中'
                : '进入 IBCLC 咨询',
          ),
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
  bool _isUploading = false;
  UploadedMediaFile? _uploadedFile;
  String? _uploadError;
  String _cacheStatus = '离线资料已缓存，网络不稳定时可继续查看并失败重试。';

  Future<void> _uploadSampleMedia() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final uploaded = await runtime.mediaRepository.uploadFile(
        userId: runtime.userId,
        file: _sampleMediaFile,
      );
      if (!mounted) return;
      setState(() {
        _uploadedFile = uploaded;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadError = _mediaUploadErrorText(error);
      });
    }
  }

  void _clearOfflineCache() {
    setState(() {
      _uploadedFile = null;
      _uploadError = null;
      _cacheStatus = '已清理离线缓存和临时上传结果。';
    });
  }

  void _returnFromMediaViewer() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

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
          subtitle: _cacheStatus,
          accent: widget.accent,
          trailing: IconButton(
            key: const ValueKey('media-clear-cache-button'),
            tooltip: '清理缓存',
            onPressed: _clearOfflineCache,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ),
        _ActionTile(
          icon: Icons.cloud_upload_outlined,
          title: _uploadedFile == null
              ? '上传示例资料'
              : '已上传 ${_uploadedFile!.name}',
          subtitle:
              _uploadError ??
              (_uploadedFile == null
                  ? '通过 /v1/files/upload 验证媒体上传合同。'
                  : '文件 ID ${_uploadedFile!.id}，${_uploadedFile!.sizeBytes} bytes。'),
          accent: _uploadError == null ? const Color(0xff846bd8) : Colors.red,
          trailing: _isUploading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : IconButton(
                  tooltip: '上传',
                  onPressed: _uploadSampleMedia,
                  icon: const Icon(Icons.cloud_upload_outlined),
                ),
        ),
        _ActionTile(
          icon: Icons.ios_share_rounded,
          title: '分享或返回',
          subtitle: '从 Agent artifact、IBCLC 和 W1 内容跳入时保留返回意图。',
          accent: const Color(0xff43827b),
          trailing: IconButton(
            key: const ValueKey('media-return-button'),
            tooltip: '返回上一页',
            onPressed: _returnFromMediaViewer,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ],
    );
  }

  String _mediaUploadErrorText(Object error) {
    if (error is ApiRequestCancelledException) return '上传已取消，预览内容已保留。';
    if (error is ApiRequestTimeoutException) return '上传超时，请稍后重试。';
    if (error is ApiHttpException) return '媒体服务暂不可用，请稍后重试。';
    return '上传失败，请稍后重试。';
  }
}

const _sampleMediaFile = ApiUploadFile(
  name: 'pump-display-fixture.png',
  mimeType: 'image/png',
  sizeBytes: 68,
  bytes: <int>[137, 80, 78, 71, 13, 10, 26, 10],
);

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
      decoration: MomCozyDecorations.card(),
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
