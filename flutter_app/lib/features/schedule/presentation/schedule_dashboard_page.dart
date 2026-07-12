import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_reminder.dart';
import 'package:momcozy_flutter_app/features/schedule/presentation/schedule_dashboard_controller.dart';

class ScheduleDashboardPage extends StatefulWidget {
  const ScheduleDashboardPage({
    super.key,
    required this.repository,
    required this.now,
    this.path = '/schedule',
    this.initialDay,
    this.routeUri,
    this.routeExtra,
    this.onOpenAgent,
    this.onRecognizeScheduleImage,
    this.reminderGateway = const UnsupportedScheduleReminderGateway(),
    this.reminderPreferenceStore =
        const DisabledScheduleReminderPreferenceStore(),
    this.milkPlanChangeStore,
  });

  final ScheduleRepository repository;
  final DateTime Function() now;
  final String path;
  final DateTime? initialDay;
  final Uri? routeUri;
  final Object? routeExtra;
  final VoidCallback? onOpenAgent;
  final Future<bool> Function()? onRecognizeScheduleImage;
  final ScheduleReminderGateway reminderGateway;
  final ScheduleReminderPreferenceStore reminderPreferenceStore;
  final MilkPlanChangeStore? milkPlanChangeStore;

  @override
  State<ScheduleDashboardPage> createState() => _ScheduleDashboardPageState();
}

class _ScheduleDashboardPageState extends State<ScheduleDashboardPage> {
  late final ScheduleDashboardController _controller;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _taskFocusKeys = <String, GlobalKey>{};
  Timer? _clockTimer;
  Timer? _highlightTimer;
  Timer? _planChangeHighlightTimer;
  late DateTime _clock;
  String? _feedback;
  String? _highlightedTaskId;
  DateTime? _highlightedDay;
  bool _reminderEnabled = false;
  bool _warmingReminderWindow = false;
  bool _reminderSyncInFlight = false;
  bool _reminderSyncQueued = false;
  String? _lastReminderFingerprint;
  int _requestSequence = 0;
  int _intentRevision = 0;
  String? _pendingFocusTaskId;
  bool _focusScheduled = false;
  int? _consumedMilkPlanRevision;
  final Set<String> _changedDayKeys = <String>{};
  final Map<String, String> _idempotencyKeysByIntent = <String, String>{};

  @override
  void initState() {
    super.initState();
    _clock = widget.now();
    final intentDay = _intentDay(widget.routeUri, widget.routeExtra);
    _controller = ScheduleDashboardController(
      repository: widget.repository,
      initialDay: widget.initialDay ?? intentDay ?? _clock,
      now: widget.now,
    );
    _controller.addListener(_onControllerReminderChange);
    _applyRouteIntent(intentDay: intentDay, notify: false, selectDay: false);
    widget.milkPlanChangeStore?.addListener(_onMilkPlanChangeStore);
    unawaited(_loadReminderPreference());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _clock = widget.now());
    });
    unawaited(_controller.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onMilkPlanChangeStore();
    });
  }

  @override
  void didUpdateWidget(covariant ScheduleDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final intentInputChanged =
        !identical(oldWidget.routeUri, widget.routeUri) ||
        !identical(oldWidget.routeExtra, widget.routeExtra) ||
        oldWidget.initialDay != widget.initialDay;
    if (intentInputChanged) {
      _applyRouteIntent(
        intentDay: _intentDay(widget.routeUri, widget.routeExtra),
        notify: true,
        selectDay: true,
      );
    }
    if (!identical(oldWidget.milkPlanChangeStore, widget.milkPlanChangeStore)) {
      oldWidget.milkPlanChangeStore?.removeListener(_onMilkPlanChangeStore);
      widget.milkPlanChangeStore?.addListener(_onMilkPlanChangeStore);
      _consumedMilkPlanRevision = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onMilkPlanChangeStore();
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _highlightTimer?.cancel();
    _planChangeHighlightTimer?.cancel();
    widget.milkPlanChangeStore?.removeListener(_onMilkPlanChangeStore);
    _controller.removeListener(_onControllerReminderChange);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Column(
          key: ValueKey('route-page-${widget.path}'),
          children: [
            _ScheduleFixedDateArea(
              today: _controller.today,
              selectedDay: state.selectedDay,
              displayAnchor: state.displayAnchor,
              highlightedDay: _highlightedDay,
              changedDayKeys: _changedDayKeys,
              onSelected: (day) => unawaited(_controller.selectDay(day)),
              onBrowseWeek: _controller.browseWeek,
              onToday: () =>
                  unawaited(_controller.selectDay(_controller.today)),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _controller.load,
                child: ListView(
                  key: const ValueKey('schedule-scroll-content'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: _content(state),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _content(ScheduleDashboardState state) {
    final snapshot = state.snapshot;
    final isToday = _sameDay(state.selectedDay, _controller.today);
    final children = <Widget>[];

    if (state.phase == ScheduleLoadPhase.loading && snapshot == null) {
      children.add(const _ScheduleLoadingCard());
      return children;
    }
    if (state.phase == ScheduleLoadPhase.error && snapshot == null) {
      children.add(
        _ScheduleErrorCard(
          message: state.loadError ?? '计划数据暂时不可用。',
          onRetry: () => unawaited(_controller.load()),
        ),
      );
      return children;
    }

    final resolved = snapshot ?? ScheduleDayPlan(day: state.selectedDay);
    final isFutureWithoutTasks =
        state.selectedDay.isAfter(_controller.today) && resolved.tasks.isEmpty;
    final planContext = isFutureWithoutTasks ? null : resolved.context;
    if (planContext == null) {
      children.add(
        isFutureWithoutTasks
            ? _ScheduleContextPlaceholder(
                title:
                    '${state.selectedDay.month}月${state.selectedDay.day}日 待规划',
                message: '当天还没有计划任务，后续安排确认后会同步到这里。',
              )
            : const _ScheduleContextPlaceholder(),
      );
    } else {
      children.add(
        _ScheduleContextCard(
          title: _contextTitle(planContext, state.selectedDay),
          stageLabel: _stageLabel(planContext, state.selectedDay),
          completed: resolved.completedTaskCount,
          total: resolved.tasks.length,
          skipped: resolved.skippedTaskCount,
          showReminder: isToday,
          reminderEnabled: _reminderEnabled,
          onReminder: () => unawaited(_toggleReminder(resolved.tasks)),
        ),
      );
      if (isToday) {
        children.addAll([
          const SizedBox(height: 16),
          _ScheduleAgentCard(
            planTitle: planContext.title,
            stageLabel: _stageLabel(planContext, state.selectedDay),
            taskCount: resolved.tasks.length,
            nextTask: state.nextPendingTask,
            reminderEnabled: _reminderEnabled,
            onReminder: () => unawaited(_toggleReminder(resolved.tasks)),
            onOpenAgent: _openAgent,
          ),
        ]);
      }
    }
    children.add(const SizedBox(height: 16));
    if (state.loadError != null) {
      children.addAll([
        _ScheduleFeedbackBanner(
          message: state.loadError ?? '刷新失败，正在显示此前同步的数据。',
          isError: true,
        ),
        const SizedBox(height: 8),
      ]);
    }
    children.add(
      _ScheduleHeroCard(
        selectedDay: state.selectedDay,
        today: _controller.today,
        snapshot: resolved,
        now: _clock,
        onComplete: isToday && state.nextPendingTask != null
            ? () => unawaited(_showTaskCompletion(state.nextPendingTask!))
            : null,
        onDelay: isToday && state.nextPendingTask != null
            ? () => unawaited(_delayTask(state.nextPendingTask!))
            : null,
        onSkip: isToday && state.nextPendingTask != null
            ? () => unawaited(
                _setTaskState(
                  state.nextPendingTask!,
                  ScheduleTaskState.skipped,
                ),
              )
            : null,
      ),
    );
    children.add(const SizedBox(height: 22));
    if (isToday) {
      children.add(
        _ScheduleToolbar(
          busy: state.isMutating,
          explanation: _taskExplanation(resolved),
          onAdd: () => unawaited(_showTaskEditor()),
          onRecognize: () => unawaited(_showScheduleRecognition()),
        ),
      );
      children.add(const SizedBox(height: 10));
      children.add(
        _ScheduleQuickActions(
          onPumping: () =>
              unawaited(_showRecordEditor(ScheduleRecordKind.pumping)),
          onFeeding: () =>
              unawaited(_showRecordEditor(ScheduleRecordKind.feeding)),
        ),
      );
    } else {
      children.add(
        Text(
          '执行记录',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: MomCozyColors.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    final error = state.mutationError;
    if (error != null) {
      children.addAll([
        const SizedBox(height: 8),
        _ScheduleFeedbackBanner(message: error, isError: true),
      ]);
    } else if (_feedback != null) {
      children.addAll([
        const SizedBox(height: 8),
        _ScheduleFeedbackBanner(message: _feedback!),
      ]);
    }
    children.add(const SizedBox(height: 8));

    if (resolved.timeline.isEmpty) {
      children.add(const _ScheduleEmptyTaskNotice());
    } else {
      final timelineRows = <Widget>[];
      for (final entry in resolved.timeline) {
        final task = entry.task;
        final record = entry.record;
        if (task != null) {
          timelineRows.add(
            KeyedSubtree(
              key: _taskFocusKeys.putIfAbsent(
                task.id,
                () => GlobalKey(debugLabel: 'schedule-focus-${task.id}'),
              ),
              child: _ScheduleTaskRow(
                task: task,
                linkedRecords: entry.linkedRecords,
                busy: state.isMutating,
                highlighted: task.id == _highlightedTaskId,
                isNext: isToday && task.id == state.nextPendingTask?.id,
                onEdit: task.state == ScheduleTaskState.pending && isToday
                    ? () => unawaited(_showTaskEditor(task: task))
                    : null,
                onDelete: () => unawaited(_deleteTask(task)),
                onDeleteLinkedRecord: (record) =>
                    unawaited(_deleteRecord(record)),
              ),
            ),
          );
        } else if (record != null) {
          timelineRows.add(
            _ScheduleRecordRow(
              record: record,
              busy: state.isMutating,
              onDelete: () => unawaited(_deleteRecord(record)),
            ),
          );
        }
      }
      children.add(Column(children: timelineRows));
    }
    _scheduleRouteFocus(state, resolved);
    return children;
  }

  void _applyRouteIntent({
    required DateTime? intentDay,
    required bool notify,
    required bool selectDay,
  }) {
    final taskId = _intentTaskId(widget.routeUri, widget.routeExtra);
    final revision = ++_intentRevision;
    _highlightTimer?.cancel();
    _focusScheduled = false;

    void apply() {
      _highlightedTaskId = taskId;
      _highlightedDay = intentDay;
      _pendingFocusTaskId = taskId;
      if (taskId != null) _feedback = null;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    if (selectDay && intentDay != null) {
      unawaited(_controller.selectDay(intentDay));
    }
    if (taskId == null && intentDay == null) return;
    _highlightTimer = Timer(const Duration(milliseconds: 6500), () {
      if (!mounted || revision != _intentRevision) return;
      setState(() {
        _highlightedTaskId = null;
        _highlightedDay = null;
        _pendingFocusTaskId = null;
      });
    });
  }

  void _scheduleRouteFocus(
    ScheduleDashboardState state,
    ScheduleDayPlan snapshot,
  ) {
    final taskId = _pendingFocusTaskId;
    if (taskId == null ||
        _focusScheduled ||
        state.phase == ScheduleLoadPhase.loading) {
      return;
    }
    final revision = _intentRevision;
    _focusScheduled = true;
    if (!snapshot.tasks.any((task) => task.id == taskId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            revision != _intentRevision ||
            _pendingFocusTaskId != taskId) {
          return;
        }
        setState(() {
          _pendingFocusTaskId = null;
          _focusScheduled = false;
          _feedback = '未找到通知关联的任务，已定位到对应日期';
        });
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToFocusedTask(taskId, revision));
    });
  }

  Future<void> _scrollToFocusedTask(String taskId, int revision) async {
    if (!mounted || revision != _intentRevision) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    var targetContext = _taskFocusKeys[taskId]?.currentContext;
    if (targetContext == null && _scrollController.hasClients) {
      final bottom = _scrollController.position.maxScrollExtent;
      if (reducedMotion) {
        _scrollController.jumpTo(bottom);
      } else {
        await _scrollController.animateTo(
          bottom,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted || revision != _intentRevision) return;
      await WidgetsBinding.instance.endOfFrame;
      targetContext = _taskFocusKeys[taskId]?.currentContext;
    }
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.42,
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted ||
        revision != _intentRevision ||
        _pendingFocusTaskId != taskId) {
      return;
    }
    setState(() {
      _pendingFocusTaskId = null;
      _focusScheduled = false;
      if (targetContext == null) {
        _feedback = '未找到通知关联的任务，已定位到对应日期';
      }
    });
  }

  void _onMilkPlanChangeStore() {
    final store = widget.milkPlanChangeStore;
    if (!mounted ||
        store == null ||
        !store.hasPageNotice ||
        _consumedMilkPlanRevision == store.revision) {
      return;
    }
    _consumedMilkPlanRevision = store.revision;
    unawaited(_consumeMilkPlanChange(store, store.revision));
  }

  Future<void> _consumeMilkPlanChange(
    MilkPlanChangeStore store,
    int revision,
  ) async {
    final today = _controller.today;
    final todayKey = _dayKey(today);
    final futureDateKeys = store.affectedDateKeys
        .where((dateKey) => dateKey.compareTo(todayKey) > 0)
        .toList(growable: false);
    final dateKeys = futureDateKeys.isNotEmpty
        ? futureDateKeys
        : [
            for (var offset = 1; offset <= 3; offset += 1)
              _dayKey(today.add(Duration(days: offset))),
          ];
    _planChangeHighlightTimer?.cancel();
    setState(() {
      _changedDayKeys
        ..clear()
        ..addAll(dateKeys);
      _feedback = null;
    });
    _planChangeHighlightTimer = Timer(const Duration(milliseconds: 6500), () {
      if (!mounted || _consumedMilkPlanRevision != revision) return;
      setState(_changedDayKeys.clear);
    });

    final preloadDays = <DateTime>[];
    final firstAffectedDay = DateTime.tryParse(dateKeys.first);
    if (firstAffectedDay != null) preloadDays.add(firstAffectedDay);
    final selectedDayKey = _dayKey(_controller.state.selectedDay);
    if (dateKeys.contains(selectedDayKey) && selectedDayKey != dateKeys.first) {
      final selectedDay = DateTime.tryParse(selectedDayKey);
      if (selectedDay != null) preloadDays.add(selectedDay);
    }
    if (preloadDays.isEmpty) {
      _consumedMilkPlanRevision = null;
      store.restoreNavigationNotice();
      return;
    }
    final refreshResults = await Future.wait(
      preloadDays.map(_controller.refreshDay),
    );
    if (!mounted || _consumedMilkPlanRevision != revision) return;
    if (refreshResults.any((succeeded) => !succeeded)) {
      _consumedMilkPlanRevision = null;
      store.restoreNavigationNotice();
      setState(() => _feedback = '稳奶计划更新已收到，但权威数据刷新失败');
      return;
    }
    store.clearPageNotice();
    _queueReminderSync();
    setState(() => _feedback = '稳奶计划已按最新权威数据刷新');
  }

  String _contextTitle(SchedulePlanContext plan, DateTime selectedDay) {
    final planTitle = plan.title.trim();
    if (_sameDay(selectedDay, _controller.today)) return '$planTitle执行中';
    if (selectedDay.isAfter(_controller.today)) {
      return '${selectedDay.month}月${selectedDay.day}日 $planTitle';
    }
    return planTitle;
  }

  String _stageLabel(SchedulePlanContext context, [DateTime? selectedDay]) {
    final explicit =
        context.payload['stage_label'] ?? context.payload['stageLabel'];
    if (explicit is String && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final rawWeek =
        context.payload['postpartum_week'] ?? context.payload['postpartumWeek'];
    final baseWeek = rawWeek is num
        ? rawWeek.round()
        : int.tryParse(rawWeek?.toString() ?? '');
    if (baseWeek != null && selectedDay != null) {
      final weekOffset =
          _calendarDay(selectedDay).difference(_controller.today).inDays ~/ 7;
      final week = (baseWeek + weekOffset).clamp(0, 520);
      final phase =
          context.payload['phase'] ??
          context.payload['stage'] ??
          context.payload['care_phase'];
      final phaseLabel = phase is String ? phase.trim() : '';
      return phaseLabel.isEmpty ? '产后第$week周' : '产后第$week周（$phaseLabel）';
    }
    final value = context.stageLabel.trim();
    return value.isEmpty ? '计划阶段待同步' : value;
  }

  String _taskExplanation(ScheduleDayPlan snapshot) {
    final plan = snapshot.context;
    final basis = plan == null
        ? '当前服务器计划'
        : '${plan.title}的${_stageLabel(plan, snapshot.day)}';
    return '今日任务依据$basis、已同步的 ${snapshot.records.length} 条奶量与喂养记录，'
        '以及原任务节奏展示。稳奶以保持规律为主；追奶会适度增加频次，减奶会逐步拉长间隔。'
        '当前完成 ${snapshot.completedTaskCount} 项、跳过 ${snapshot.skippedTaskCount} 项。';
  }

  void _openAgent() {
    final callback = widget.onOpenAgent;
    if (callback != null) {
      callback();
      return;
    }
    context.go('/', extra: const {'agentPrefill': '我想调整今天的吸乳排期'});
  }

  Future<void> _toggleReminder(List<ScheduleTask> tasks) async {
    final next = !_reminderEnabled;
    if (!next) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('schedule-reminder-confirm-dialog'),
          title: const Text('关闭计划提醒？'),
          content: const Text('关闭后，系统将取消当前计划的本地提醒。'),
          actions: [
            TextButton(
              key: const ValueKey('schedule-reminder-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('schedule-reminder-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认关闭'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    var reminderTasks = tasks;
    var warmed = true;
    if (next) {
      _warmingReminderWindow = true;
      warmed = await _controller.warmReminderWindow();
      _warmingReminderWindow = false;
      reminderTasks = _controller.reminderTasks;
    }
    final synced = await widget.reminderGateway.setEnabled(
      enabled: next,
      tasks: reminderTasks,
    );
    if (!mounted) return;
    if (!synced) {
      setState(() => _feedback = '当前设备尚未接入系统计划提醒，未修改提醒状态');
      return;
    }
    try {
      await widget.reminderPreferenceStore.writeEnabled(next);
    } catch (_) {
      await widget.reminderGateway.setEnabled(
        enabled: _reminderEnabled,
        tasks: tasks,
      );
      if (!mounted) return;
      setState(() => _feedback = '提醒偏好保存失败，未修改提醒状态');
      return;
    }
    setState(() {
      _reminderEnabled = next;
      _lastReminderFingerprint = _reminderFingerprint(next, reminderTasks);
      _feedback = next
          ? warmed
                ? '系统提醒已同步'
                : '部分未来日程暂未加载，已同步当前可用提醒'
          : '系统提醒已关闭';
    });
  }

  Future<void> _loadReminderPreference() async {
    if (!widget.reminderGateway.isSupported) {
      if (mounted) setState(() => _reminderEnabled = false);
      return;
    }
    try {
      final enabled = await widget.reminderPreferenceStore.readEnabled();
      if (!mounted) return;
      setState(() => _reminderEnabled = enabled);
      if (!enabled) return;
      _warmingReminderWindow = true;
      final warmed = await _controller.warmReminderWindow();
      _warmingReminderWindow = false;
      final synced = await _syncReminderTasks(force: true);
      if (!mounted) return;
      if (!synced) {
        setState(() {
          _reminderEnabled = false;
          _feedback = '系统提醒恢复失败，已保持关闭';
        });
        try {
          await widget.reminderPreferenceStore.writeEnabled(false);
        } catch (_) {
          // The visible state remains honest even if preference repair fails.
        }
      } else if (!warmed) {
        setState(() => _feedback = '部分未来日程暂未加载，已同步当前可用提醒');
      }
    } catch (_) {
      if (mounted) setState(() => _reminderEnabled = false);
    }
  }

  void _onControllerReminderChange() {
    if (!_reminderEnabled || _warmingReminderWindow) return;
    _queueReminderSync();
  }

  void _queueReminderSync() {
    if (!_reminderEnabled || !widget.reminderGateway.isSupported) return;
    if (_reminderSyncInFlight) {
      _reminderSyncQueued = true;
      return;
    }
    unawaited(_syncReminderTasks());
  }

  Future<bool> _syncReminderTasks({bool force = false}) async {
    if (!_reminderEnabled || !widget.reminderGateway.isSupported) return false;
    final tasks = _controller.reminderTasks;
    final fingerprint = _reminderFingerprint(true, tasks);
    if (!force && fingerprint == _lastReminderFingerprint) return true;
    if (_reminderSyncInFlight) {
      _reminderSyncQueued = true;
      return true;
    }
    _reminderSyncInFlight = true;
    var synced = false;
    try {
      synced = await widget.reminderGateway.setEnabled(
        enabled: true,
        tasks: tasks,
      );
      if (synced) {
        _lastReminderFingerprint = fingerprint;
      } else if (mounted) {
        setState(() => _feedback = '日程已更新，但系统提醒重同步失败');
      }
      return synced;
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = '日程已更新，但系统提醒重同步失败');
      }
      return false;
    } finally {
      _reminderSyncInFlight = false;
      if (_reminderSyncQueued) {
        _reminderSyncQueued = false;
        _queueReminderSync();
      }
    }
  }

  Future<void> _showScheduleRecognition() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('schedule-adjust-upload-dialog'),
        title: const Text('识别日程截图'),
        content: Text(
          widget.onRecognizeScheduleImage == null
              ? '当前版本尚未接入日程截图识别。你可以前往智能体对话发送截图。'
              : '选择日程截图后，识别结果会先展示给你确认，再写入计划。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('schedule-adjust-submit'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.onRecognizeScheduleImage == null ? '前往对话' : '选择截图',
            ),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    final recognize = widget.onRecognizeScheduleImage;
    if (recognize == null) {
      _openAgent();
      return;
    }
    final accepted = await recognize();
    if (!mounted) return;
    setState(() {
      _feedback = accepted ? '截图日程已确认同步' : '未同步截图日程';
    });
  }

  Future<void> _showTaskEditor({ScheduleTask? task}) async {
    final drafts = await showDialog<List<_TaskDraft>>(
      context: context,
      builder: (context) => _ScheduleTaskDialog(task: task),
    );
    if (drafts == null || drafts.isEmpty) return;
    _controller.clearMutationError();
    if (task != null) {
      final draft = drafts.single;
      final updated = await _controller.updateTask(
        taskId: task.id,
        time: draft.time,
        title: draft.title,
        description: draft.description,
      );
      if (!mounted || updated == null) return;
      setState(() => _feedback = '任务已更新');
      return;
    }

    var created = 0;
    final intentKeys = <String>[];
    for (var index = 0; index < drafts.length; index += 1) {
      final draft = drafts[index];
      final intent = <Object?>[
        _dayKey(_controller.state.selectedDay),
        _controller.state.snapshot?.context?.id,
        draft.time,
        draft.title,
        draft.description,
        draft.kind.wireValue,
        drafts.length,
        index,
      ].join('\u001f');
      intentKeys.add(intent);
      final result = await _controller.createTask(
        planId: _controller.state.snapshot?.context?.id,
        time: draft.time,
        title: draft.title,
        description: draft.description,
        kind: draft.kind,
        idempotencyKey: _idempotencyKeyFor('task', intent),
      );
      if (result == null) break;
      created += 1;
    }
    if (created == drafts.length) {
      for (final intent in intentKeys) {
        _idempotencyKeysByIntent.remove('task\u001f$intent');
      }
    }
    if (!mounted || created == 0) return;
    setState(() => _feedback = created == 1 ? '任务已添加' : '已添加 $created 个任务');
  }

  Future<void> _showTaskCompletion(ScheduleTask task) async {
    if (task.kind == ScheduleTaskKind.other) {
      await _setTaskState(
        task,
        ScheduleTaskState.completed,
        message: '执行记录已完成',
      );
      return;
    }
    final action = await showDialog<_CompletionAction>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('schedule-record-entry-dialog'),
        title: const Text('记录执行数据'),
        content: Text('${task.title}完成后，可同时保存本次执行数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (task.kind == ScheduleTaskKind.pumping)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _CompletionAction.pumping),
              child: const Text('吸奶补录'),
            ),
          if (task.kind == ScheduleTaskKind.feeding)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _CompletionAction.feeding),
              child: const Text('喂养记录'),
            ),
        ],
      ),
    );
    switch (action) {
      case _CompletionAction.pumping:
        await _showRecordEditor(ScheduleRecordKind.pumping, linkedTask: task);
      case _CompletionAction.feeding:
        await _showRecordEditor(ScheduleRecordKind.feeding, linkedTask: task);
      case null:
        return;
    }
  }

  Future<void> _showRecordEditor(
    ScheduleRecordKind kind, {
    ScheduleTask? linkedTask,
  }) async {
    final draft = await showDialog<_RecordDraft>(
      context: context,
      builder: (context) => _ScheduleRecordDialog(
        kind: kind,
        initialTime: linkedTask?.remindAt == null
            ? _time(_clock)
            : _time(linkedTask!.remindAt),
      ),
    );
    if (draft == null) return;
    _controller.clearMutationError();
    final occurredAt = _recordDateTime(
      _controller.state.selectedDay,
      draft.time,
    );
    final scope = kind == ScheduleRecordKind.pumping ? 'pumping' : 'feeding';
    final intent = <Object?>[
      _dayKey(_controller.state.selectedDay),
      draft.time,
      draft.amountMl,
      draft.durationSeconds,
      draft.feedType,
      linkedTask?.id,
    ].join('\u001f');
    final idempotencyKey = _idempotencyKeyFor(scope, intent);
    final record = kind == ScheduleRecordKind.pumping
        ? await _controller.createPumpingRecord(
            occurredAt: occurredAt,
            amountMl: draft.amountMl!,
            durationSeconds: draft.durationSeconds,
            linkedTaskId: linkedTask?.id,
            idempotencyKey: idempotencyKey,
          )
        : await _controller.createFeedingRecord(
            occurredAt: occurredAt,
            amountMl: draft.amountMl,
            durationSeconds: draft.durationSeconds,
            feedType: draft.feedType,
            linkedTaskId: linkedTask?.id,
            idempotencyKey: idempotencyKey,
          );
    if (!mounted || record == null) return;
    _idempotencyKeysByIntent.remove('$scope\u001f$intent');
    setState(
      () => _feedback = kind == ScheduleRecordKind.pumping
          ? '吸奶记录已保存'
          : '喂养记录已保存',
    );
  }

  Future<void> _delayTask(ScheduleTask task) async {
    final remindAt = task.remindAt;
    if (remindAt == null) {
      setState(() => _feedback = '该任务没有可顺延的时间');
      return;
    }
    final delayed = remindAt.add(const Duration(minutes: 30));
    final result = await _controller.updateTask(
      taskId: task.id,
      time: _time(delayed),
      title: task.title,
      description: task.description,
    );
    if (!mounted || result == null) return;
    setState(() => _feedback = '顺延半小时已更新');
  }

  Future<void> _setTaskState(
    ScheduleTask task,
    ScheduleTaskState state, {
    String? message,
  }) async {
    _controller.clearMutationError();
    final updated = await _controller.setTaskState(task.id, state);
    if (!mounted || updated == null) return;
    setState(() {
      _feedback =
          message ??
          switch (state) {
            ScheduleTaskState.completed => '任务已完成',
            ScheduleTaskState.pending => '任务已恢复',
            ScheduleTaskState.skipped => '已跳过',
          };
    });
  }

  Future<void> _deleteTask(ScheduleTask task) async {
    _controller.clearMutationError();
    final deleted = await _controller.deleteTask(task.id);
    if (!mounted || !deleted) return;
    setState(() => _feedback = '任务已删除');
  }

  Future<void> _deleteRecord(ScheduleRecord record) async {
    _controller.clearMutationError();
    final deleted = await _controller.deleteRecord(record);
    if (!mounted || !deleted) return;
    setState(() => _feedback = '记录已删除');
  }

  String _idempotencyKeyFor(String scope, String intent) {
    final intentKey = '$scope\u001f$intent';
    return _idempotencyKeysByIntent.putIfAbsent(intentKey, () {
      _requestSequence += 1;
      return 'schedule-$scope-${widget.now().microsecondsSinceEpoch}-$_requestSequence';
    });
  }
}

class _ScheduleFixedDateArea extends StatelessWidget {
  const _ScheduleFixedDateArea({
    required this.today,
    required this.selectedDay,
    required this.displayAnchor,
    required this.highlightedDay,
    required this.changedDayKeys,
    required this.onSelected,
    required this.onBrowseWeek,
    required this.onToday,
  });

  final DateTime today;
  final DateTime selectedDay;
  final DateTime displayAnchor;
  final DateTime? highlightedDay;
  final Set<String> changedDayKeys;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onBrowseWeek;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('schedule-fixed-date-area'),
      color: MomCozyColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: RepaintBoundary(
            key: const ValueKey('schedule-date-strip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${displayAnchor.year}年${displayAnchor.month}月',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: MomCozyColors.mutedForeground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!_sameDay(selectedDay, today) ||
                        !_sameWeekWindow(displayAnchor, today))
                      TextButton(
                        key: const ValueKey('schedule-back-to-today-button'),
                        onPressed: onToday,
                        child: const Text('今天'),
                      ),
                  ],
                ),
                DecoratedBox(
                  decoration: MomCozyDecorations.card(
                    color: MomCozyColors.card,
                    borderColor: MomCozyColors.border,
                    radius: 16,
                    shadows: MomCozyShadows.soft,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('schedule-week-prev-button'),
                        tooltip: '上一周',
                        onPressed: () => onBrowseWeek(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var offset = -3; offset <= 3; offset += 1)
                                _ScheduleDatePill(
                                  date: displayAnchor.add(
                                    Duration(days: offset),
                                  ),
                                  today: today,
                                  selected: _sameDay(
                                    displayAnchor.add(Duration(days: offset)),
                                    selectedDay,
                                  ),
                                  highlighted:
                                      changedDayKeys.contains(
                                        _dayKey(
                                          displayAnchor.add(
                                            Duration(days: offset),
                                          ),
                                        ),
                                      ) ||
                                      (highlightedDay != null &&
                                          _sameDay(
                                            displayAnchor.add(
                                              Duration(days: offset),
                                            ),
                                            highlightedDay!,
                                          )),
                                  onSelected: onSelected,
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('schedule-week-next-button'),
                        tooltip: '下一周',
                        onPressed: () => onBrowseWeek(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleDatePill extends StatelessWidget {
  const _ScheduleDatePill({
    required this.date,
    required this.today,
    required this.selected,
    required this.highlighted,
    required this.onSelected,
  });

  final DateTime date;
  final DateTime today;
  final bool selected;
  final bool highlighted;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final todayLabel = _sameDay(date, today) ? '，今天' : '';
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${date.year}年${date.month}月${date.day}日$todayLabel${selected ? '，已选择' : ''}',
      child: InkWell(
        key: ValueKey('schedule-date-${_dayKey(date)}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(date),
        child: SizedBox(
          width: 44,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              key: highlighted
                  ? ValueKey('schedule-highlighted-date-${_dayKey(date)}')
                  : null,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              width: 28,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? MomCozyColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: highlighted && !selected
                    ? Border.all(color: MomCozyColors.primary, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _sameDay(date, today) ? '今' : _weekday(date),
                    style: TextStyle(
                      color: selected
                          ? Colors.white70
                          : MomCozyColors.mutedForeground,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected ? Colors.white : MomCozyColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
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

class _ScheduleContextCard extends StatelessWidget {
  const _ScheduleContextCard({
    required this.title,
    required this.stageLabel,
    required this.completed,
    required this.total,
    required this.skipped,
    required this.showReminder,
    required this.reminderEnabled,
    required this.onReminder,
  });

  final String title;
  final String stageLabel;
  final int completed;
  final int total;
  final int skipped;
  final bool showReminder;
  final bool reminderEnabled;
  final VoidCallback onReminder;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MomCozyColors.card,
            MomCozyColors.roseSoft.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MomCozyColors.primary.withValues(alpha: 0.16),
        ),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Stack(
        children: [
          if (showReminder)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton.filledTonal(
                key: const ValueKey('schedule-context-reminder-button'),
                tooltip: reminderEnabled ? '关闭计划提醒' : '开启计划提醒',
                onPressed: onReminder,
                icon: Icon(
                  reminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: showReminder ? 56 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stageLabel,
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showReminder) ...[
                      const SizedBox(height: 4),
                      Text(
                        reminderEnabled ? '系统提醒已开启' : '系统提醒未开启',
                        style: TextStyle(
                          color: reminderEnabled
                              ? MomCozyColors.primary
                              : MomCozyColors.mutedForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    showReminder ? '今日任务' : '当天任务',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (skipped > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '已跳过 $skipped',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '$completed/$total',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                child: LinearProgressIndicator(
                  key: const ValueKey('schedule-context-progress'),
                  value: progress.clamp(0, 1),
                  minHeight: 9,
                  color: MomCozyColors.primary,
                  backgroundColor: MomCozyColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleContextPlaceholder extends StatelessWidget {
  const _ScheduleContextPlaceholder({
    this.title = '计划待同步',
    this.message = '当前没有可确认的稳奶计划上下文。任务和记录仍按服务器数据展示。',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('schedule-context-placeholder'),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.muted,
        borderColor: MomCozyColors.border,
        radius: 18,
        shadows: const [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.sync_rounded,
              color: MomCozyColors.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleAgentCard extends StatelessWidget {
  const _ScheduleAgentCard({
    required this.planTitle,
    required this.stageLabel,
    required this.taskCount,
    required this.nextTask,
    required this.reminderEnabled,
    required this.onReminder,
    required this.onOpenAgent,
  });

  final String planTitle;
  final String stageLabel;
  final int taskCount;
  final ScheduleTask? nextTask;
  final bool reminderEnabled;
  final VoidCallback onReminder;
  final VoidCallback onOpenAgent;

  @override
  Widget build(BuildContext context) {
    final task = nextTask;
    final contextMessage = task == null
        ? '$planTitle · $stageLabel。今天已同步 $taskCount 项任务，可以继续和我调整执行节奏。'
        : '$planTitle · $stageLabel。下一项是 ${_time(task.remindAt)} ${task.title}，可以调整提醒或继续和我讨论。';
    return Container(
      key: const ValueKey('schedule-agent-card'),
      padding: const EdgeInsets.all(14),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.82),
        borderColor: MomCozyColors.primary.withValues(alpha: 0.16),
        radius: 24,
        shadows: MomCozyShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(
              MomCozyAssets.agentAvatar,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const CircleAvatar(
                backgroundColor: MomCozyColors.primary,
                child: Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contextMessage,
                  style: const TextStyle(
                    color: MomCozyColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('schedule-agent-reminder-button'),
                        onPressed: onReminder,
                        icon: Icon(
                          reminderEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          size: 16,
                        ),
                        label: const Text('提醒'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('schedule-agent-chat-button'),
                        onPressed: onOpenAgent,
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('对话'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleHeroCard extends StatelessWidget {
  const _ScheduleHeroCard({
    required this.selectedDay,
    required this.today,
    required this.snapshot,
    required this.now,
    required this.onComplete,
    required this.onDelay,
    required this.onSkip,
  });

  final DateTime selectedDay;
  final DateTime today;
  final ScheduleDayPlan snapshot;
  final DateTime now;
  final VoidCallback? onComplete;
  final VoidCallback? onDelay;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDay(selectedDay, today);
    final isPast = selectedDay.isBefore(today) && !isToday;
    final pending =
        snapshot.tasks
            .where((task) => task.state == ScheduleTaskState.pending)
            .toList(growable: false)
          ..sort((left, right) {
            if (left.remindAt == null) return 1;
            if (right.remindAt == null) return -1;
            return left.remindAt!.compareTo(right.remindAt!);
          });
    final next = pending.isEmpty ? null : pending.first;
    final allCompleted =
        snapshot.tasks.isNotEmpty &&
        snapshot.completedTaskCount == snapshot.tasks.length;
    final allSkipped =
        snapshot.tasks.isNotEmpty &&
        snapshot.skippedTaskCount == snapshot.tasks.length;
    final pumpingAmountMl = snapshot.records
        .where((record) => record.kind == ScheduleRecordKind.pumping)
        .map((record) => record.amountMl ?? 0)
        .fold<int>(0, (total, amount) => total + amount);
    final title = isPast
        ? snapshot.tasks.isEmpty
              ? '这天没有计划任务'
              : '这天的计划已结束'
        : !isToday
        ? '未来的计划'
        : next != null
        ? '待执行任务'
        : snapshot.tasks.isEmpty
        ? '今天还没有计划任务'
        : allSkipped
        ? '今天的任务均已跳过'
        : allCompleted
        ? '今天任务已完成'
        : '今天的计划尚未全部完成哦';
    final detail = isPast
        ? snapshot.tasks.isEmpty
              ? pumpingAmountMl > 0
                    ? '当天母乳产出 $pumpingAmountMl ml。'
                    : '当天没有可执行的计划任务。'
              : '共完成 ${snapshot.completedTaskCount} 项，母乳产出 $pumpingAmountMl ml。'
        : !isToday
        ? next == null
              ? snapshot.tasks.isNotEmpty
                    ? '当天任务已全部标记处理。'
                    : snapshot.records.isNotEmpty
                    ? '当天已有 ${snapshot.records.length} 条执行记录。'
                    : '当天暂无任务或执行记录。'
              : '首项 ${_time(next.remindAt)} ${next.title}'
        : next != null
        ? '${_time(next.remindAt)} ${next.title} · ${_countdown(next.remindAt, now)}'
        : snapshot.tasks.isEmpty
        ? '你可以新增任务，或补录吸奶和喂养数据。'
        : '完成 ${snapshot.completedTaskCount} 项，跳过 ${snapshot.skippedTaskCount} 项。';

    if (next == null) {
      return Container(
        key: const ValueKey('schedule-empty-task-card'),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.secondary.withValues(alpha: 0.32),
          borderColor: MomCozyColors.border,
          radius: 24,
          shadows: const [],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: MomCozyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 30,
                color: MomCozyColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: MomCozyColors.mutedForeground,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final overdue = next.remindAt != null && !next.remindAt!.isAfter(now);
    return Container(
      key: const ValueKey('schedule-next-task-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MomCozyColors.primary.withValues(alpha: 0.16),
            MomCozyColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MomCozyColors.primary.withValues(alpha: 0.2)),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MomCozyColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MomCozyColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _taskIcon(next.kind),
                  color: MomCozyColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _time(next.remindAt),
                      key: const ValueKey('schedule-next-task-time'),
                      style: const TextStyle(
                        color: MomCozyColors.foreground,
                        fontSize: 32,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      next.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Container(
                  key: const ValueKey('schedule-next-countdown-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: overdue
                        ? const Color(0xffffe8e5)
                        : MomCozyColors.amberSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: overdue
                          ? Colors.redAccent.withValues(alpha: 0.28)
                          : MomCozyColors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _countdown(next.remindAt, now),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: overdue
                          ? Colors.red.shade700
                          : const Color(0xff7d5730),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isToday) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('schedule-next-complete-button'),
                onPressed: onComplete,
                icon: const Icon(Icons.check_rounded),
                label: const Text('手动完成并记录数据'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('schedule-next-delay-button'),
                    onPressed: onDelay,
                    child: const Text('顺延半小时'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('schedule-next-skip-button'),
                    onPressed: onSkip,
                    child: const Text('跳过这次任务'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.busy,
    required this.explanation,
    required this.onAdd,
    required this.onRecognize,
  });

  final bool busy;
  final String explanation;
  final VoidCallback onAdd;
  final VoidCallback onRecognize;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('schedule-list-toolbar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '今日任务',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            IconButton(
              key: const ValueKey('schedule-task-help-button'),
              tooltip: '今日任务说明',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  key: const ValueKey('schedule-task-explanation-dialog'),
                  title: const Text('今日任务说明'),
                  content: Text(explanation),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('schedule-adjust-button'),
                onPressed: busy ? null : onRecognize,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('调整日程'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('schedule-add-task-button'),
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加任务'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScheduleTaskRow extends StatelessWidget {
  const _ScheduleTaskRow({
    required this.task,
    required this.linkedRecords,
    required this.busy,
    required this.highlighted,
    required this.isNext,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteLinkedRecord,
  });

  final ScheduleTask task;
  final List<ScheduleRecord> linkedRecords;
  final bool busy;
  final bool highlighted;
  final bool isNext;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ScheduleRecord> onDeleteLinkedRecord;

  @override
  Widget build(BuildContext context) {
    final completed = task.state == ScheduleTaskState.completed;
    final skipped = task.state == ScheduleTaskState.skipped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        label:
            '${_time(task.remindAt)} ${task.title}，${_taskStateLabel(task.state)}'
            '${isNext ? '，下一项' : ''}'
            '${linkedRecords.isEmpty ? '' : '，${linkedRecords.map(_linkedRecordSummary).join('，')}'}',
        button: onEdit != null,
        child: DecoratedBox(
          key: ValueKey('schedule-timeline-task-${task.id}'),
          decoration: MomCozyDecorations.card(
            color: completed ? const Color(0xfff0f7ee) : MomCozyColors.card,
            borderColor: highlighted
                ? MomCozyColors.primary
                : isNext
                ? MomCozyColors.care
                : MomCozyColors.border,
            radius: 16,
            shadows: highlighted || isNext ? MomCozyShadows.soft : const [],
          ),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      _time(task.remindAt),
                      style: const TextStyle(
                        color: MomCozyColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    _taskIcon(task.kind),
                    size: 18,
                    color: MomCozyColors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  decoration: skipped
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (isNext)
                              Container(
                                key: ValueKey(
                                  'schedule-next-task-badge-${task.id}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MomCozyColors.careSoft,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: MomCozyColors.care),
                                ),
                                child: const Text(
                                  '下一项',
                                  style: TextStyle(
                                    color: MomCozyColors.foreground,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (task.description.isNotEmpty)
                          Text(
                            task.description,
                            style: const TextStyle(
                              color: MomCozyColors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        if (linkedRecords.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final record in linkedRecords)
                                InputChip(
                                  key: ValueKey(
                                    'schedule-linked-record-${record.id}',
                                  ),
                                  label: Text(
                                    _linkedRecordSummary(record),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  avatar: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                  ),
                                  onDeleted: busy
                                      ? null
                                      : () => onDeleteLinkedRecord(record),
                                  deleteButtonTooltipMessage: '删除关联记录',
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (skipped) const _StatusBadge(label: '已跳过'),
                  if (completed) const _StatusBadge(label: '已完成'),
                  IconButton(
                    tooltip: linkedRecords.isEmpty ? '删除任务' : '已有执行记录，请先删除关联记录',
                    onPressed: busy || linkedRecords.isNotEmpty
                        ? null
                        : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
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

class _ScheduleRecordRow extends StatelessWidget {
  const _ScheduleRecordRow({
    required this.record,
    required this.busy,
    required this.onDelete,
  });

  final ScheduleRecord record;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pumping = record.kind == ScheduleRecordKind.pumping;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        label:
            '${_time(record.occurredAt)} ${record.displayTitle}'
            '${record.amountMl == null ? '' : '，${record.amountMl}毫升'}'
            '${record.linkedTaskId == null ? '' : '，已关联任务'}',
        child: DecoratedBox(
          key: ValueKey('schedule-timeline-record-${record.id}'),
          decoration: MomCozyDecorations.card(
            color: pumping ? MomCozyColors.careSoft : MomCozyColors.amberSoft,
            borderColor: pumping ? MomCozyColors.care : MomCozyColors.amber,
            radius: 16,
            shadows: const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    _time(record.occurredAt),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(
                  pumping
                      ? Icons.water_drop_outlined
                      : Icons.child_care_rounded,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        [
                          if (record.amountMl != null) '${record.amountMl} ml',
                          if (record.durationSeconds != null)
                            '${(record.durationSeconds! / 60).round()} 分钟',
                        ].join(' · '),
                        style: const TextStyle(
                          color: MomCozyColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (record.linkedTaskId != null)
                  const _StatusBadge(label: '已关联任务'),
                IconButton(
                  tooltip: '删除记录',
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ScheduleQuickActions extends StatelessWidget {
  const _ScheduleQuickActions({
    required this.onPumping,
    required this.onFeeding,
  });

  final VoidCallback onPumping;
  final VoidCallback onFeeding;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('schedule-quick-actions'),
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPumping,
            child: const Text('吸奶补录'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: onFeeding,
            child: const Text('喂养记录'),
          ),
        ),
      ],
    );
  }
}

class _ScheduleEmptyTaskNotice extends StatelessWidget {
  const _ScheduleEmptyTaskNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('schedule-empty-timeline-notice'),
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(child: Text('当天暂无执行内容')),
    );
  }
}

class _ScheduleFeedbackBanner extends StatelessWidget {
  const _ScheduleFeedbackBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('schedule-feedback-banner'),
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(
          color: isError ? const Color(0xffffecec) : MomCozyColors.roseSoft,
          borderColor: isError ? Colors.red.shade200 : MomCozyColors.primary,
          radius: 14,
          shadows: const [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleLoadingCard extends StatelessWidget {
  const _ScheduleLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(28),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('计划待同步'),
          ],
        ),
      ),
    );
  }
}

class _ScheduleErrorCard extends StatelessWidget {
  const _ScheduleErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: const Color(0xfffff2f2),
        borderColor: Colors.red.shade200,
        radius: 18,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
            const SizedBox(height: 8),
            const Text('计划同步失败', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('schedule-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTaskDialog extends StatefulWidget {
  const _ScheduleTaskDialog({this.task});

  final ScheduleTask? task;

  @override
  State<_ScheduleTaskDialog> createState() => _ScheduleTaskDialogState();
}

class _ScheduleTaskDialogState extends State<_ScheduleTaskDialog> {
  late final List<_TaskDraftEditor> _rows = [
    _TaskDraftEditor(
      title: widget.task?.title ?? _defaultTaskTitle(ScheduleTaskKind.pumping),
      time: _timeText(widget.task?.remindAt),
      description: widget.task?.description ?? '',
      kind: widget.task?.kind ?? ScheduleTaskKind.pumping,
    ),
  ];
  String? _error;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('schedule-add-task-dialog'),
      title: Text(widget.task == null ? '添加任务' : '编辑任务'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _rows.length; index += 1) ...[
              if (index > 0) const Divider(height: 24),
              _buildTaskRow(index),
            ],
            if (widget.task == null && _rows.length < 6) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('schedule-add-task-row-button'),
                onPressed: _addRow,
                icon: const Icon(Icons.add_rounded),
                label: const Text('继续添加一项'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('schedule-task-edit-cancel-button'),
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: widget.task == null
              ? const ValueKey('schedule-add-task-submit')
              : const ValueKey('schedule-task-edit-save-button'),
          onPressed: _submit,
          child: Text(widget.task == null ? '添加' : '保存'),
        ),
      ],
    );
  }

  Widget _buildTaskRow(int index) {
    final row = _rows[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.task == null ? '任务 ${index + 1}' : '任务内容',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (widget.task == null && _rows.length > 1)
              IconButton(
                key: ValueKey('schedule-remove-task-row-$index'),
                tooltip: '删除这一项',
                onPressed: () => _removeRow(index),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
          ],
        ),
        SegmentedButton<ScheduleTaskKind>(
          key: ValueKey('schedule-task-kind-$index'),
          segments: const [
            ButtonSegment(value: ScheduleTaskKind.pumping, label: Text('吸奶')),
            ButtonSegment(value: ScheduleTaskKind.feeding, label: Text('喂养')),
            ButtonSegment(value: ScheduleTaskKind.other, label: Text('其他')),
          ],
          selected: {row.kind},
          onSelectionChanged: widget.task == null
              ? (value) => _changeTaskKind(row, value.single)
              : null,
        ),
        const SizedBox(height: 10),
        TextField(
          key: index == 0
              ? const ValueKey('schedule-add-task-title-input')
              : ValueKey('schedule-add-task-title-input-$index'),
          controller: row.title,
          decoration: const InputDecoration(labelText: '任务名称'),
        ),
        const SizedBox(height: 10),
        TextField(
          key: index == 0
              ? const ValueKey('schedule-task-edit-time-input')
              : ValueKey('schedule-task-time-input-$index'),
          controller: row.time,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(labelText: '时间', hintText: '21:30'),
        ),
        const SizedBox(height: 10),
        TextField(
          key: ValueKey('schedule-task-description-input-$index'),
          controller: row.description,
          decoration: const InputDecoration(labelText: '说明（可选）'),
        ),
      ],
    );
  }

  void _addRow() {
    final nextTime = _shiftTime(_rows.last.time.text, 15) ?? '21:45';
    setState(() {
      _rows.add(
        _TaskDraftEditor(
          title: _defaultTaskTitle(ScheduleTaskKind.pumping),
          time: nextTime,
          description: '',
          kind: ScheduleTaskKind.pumping,
        ),
      );
    });
  }

  void _removeRow(int index) {
    final removed = _rows.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _changeTaskKind(_TaskDraftEditor row, ScheduleTaskKind nextKind) {
    final titleWasDefault = row.title.text == _defaultTaskTitle(row.kind);
    setState(() {
      row.kind = nextKind;
      if (titleWasDefault) {
        row.title.text = _defaultTaskTitle(nextKind);
      }
    });
  }

  void _submit() {
    final drafts = <_TaskDraft>[];
    for (var index = 0; index < _rows.length; index += 1) {
      final row = _rows[index];
      final title = row.title.text.trim();
      final time = _normalizedTime(row.time.text);
      if (title.isEmpty || time == null) {
        setState(() {
          _error = title.isEmpty
              ? '请填写第 ${index + 1} 项任务名称'
              : '第 ${index + 1} 项请输入 HH:mm 格式时间';
        });
        return;
      }
      drafts.add(
        _TaskDraft(
          title: title,
          time: time,
          description: row.description.text.trim(),
          kind: row.kind,
        ),
      );
    }
    Navigator.pop(context, drafts);
  }
}

class _TaskDraftEditor {
  _TaskDraftEditor({
    required String title,
    required String time,
    required String description,
    required this.kind,
  }) : title = TextEditingController(text: title),
       time = TextEditingController(text: time),
       description = TextEditingController(text: description);

  final TextEditingController title;
  final TextEditingController time;
  final TextEditingController description;
  ScheduleTaskKind kind;

  void dispose() {
    title.dispose();
    time.dispose();
    description.dispose();
  }
}

class _ScheduleRecordDialog extends StatefulWidget {
  const _ScheduleRecordDialog({required this.kind, this.initialTime});

  final ScheduleRecordKind kind;
  final String? initialTime;

  @override
  State<_ScheduleRecordDialog> createState() => _ScheduleRecordDialogState();
}

class _ScheduleRecordDialogState extends State<_ScheduleRecordDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  late final TextEditingController _time = TextEditingController(
    text: widget.initialTime ?? '14:00',
  );
  String _feedType = 'bottle';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _duration.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pumping = widget.kind == ScheduleRecordKind.pumping;
    return AlertDialog(
      key: ValueKey(
        pumping
            ? 'schedule-pumping-record-dialog'
            : 'schedule-feeding-record-dialog',
      ),
      title: Text(pumping ? '吸奶补录' : '喂养记录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!pumping)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bottle', label: Text('瓶喂')),
                ButtonSegment(value: 'breast', label: Text('亲喂')),
                ButtonSegment(value: 'formula', label: Text('配方')),
              ],
              selected: {_feedType},
              onSelectionChanged: (selection) {
                setState(() {
                  _feedType = selection.single;
                  if (_feedType == 'breast') _amount.clear();
                });
              },
            ),
          TextField(
            key: const ValueKey('schedule-record-time-input'),
            controller: _time,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: '时间'),
          ),
          TextField(
            key: const ValueKey('schedule-record-amount-input'),
            controller: _amount,
            keyboardType: TextInputType.number,
            enabled: pumping || _feedType != 'breast',
            decoration: InputDecoration(
              labelText: _feedType == 'breast' ? '亲喂无需填写奶量' : '奶量（ml）',
            ),
          ),
          TextField(
            key: const ValueKey('schedule-record-duration-input'),
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '时长（分钟）'),
          ),
          if (_error != null)
            Semantics(
              key: const ValueKey('schedule-form-error'),
              liveRegion: true,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('schedule-record-submit'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim());
    final durationMinutes = int.tryParse(_duration.text.trim());
    final time = _normalizedTime(_time.text);
    final pumping = widget.kind == ScheduleRecordKind.pumping;
    final requiresAmount = pumping || _feedType != 'breast';
    final validAmount = amount != null && amount > 0;
    final validDuration = durationMinutes != null && durationMinutes > 0;
    if (time == null || (requiresAmount && !validAmount)) {
      setState(() => _error = requiresAmount ? '请填写有效的时间和奶量' : '请填写有效的时间');
      return;
    }
    Navigator.pop(
      context,
      _RecordDraft(
        amountMl: validAmount ? amount : null,
        durationSeconds: validDuration ? durationMinutes * 60 : null,
        time: time,
        feedType: _feedType,
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.time,
    required this.description,
    required this.kind,
  });

  final String title;
  final String time;
  final String description;
  final ScheduleTaskKind kind;
}

class _RecordDraft {
  const _RecordDraft({
    required this.amountMl,
    required this.durationSeconds,
    required this.time,
    required this.feedType,
  });

  final int? amountMl;
  final int? durationSeconds;
  final String time;
  final String feedType;
}

enum _CompletionAction { pumping, feeding }

IconData _taskIcon(ScheduleTaskKind kind) => switch (kind) {
  ScheduleTaskKind.pumping => Icons.water_drop_outlined,
  ScheduleTaskKind.feeding => Icons.child_care_rounded,
  ScheduleTaskKind.other => Icons.event_note_rounded,
};

String _defaultTaskTitle(ScheduleTaskKind kind) => switch (kind) {
  ScheduleTaskKind.pumping => '吸奶',
  ScheduleTaskKind.feeding => '喂养',
  ScheduleTaskKind.other => '',
};

String _taskStateLabel(ScheduleTaskState state) => switch (state) {
  ScheduleTaskState.pending => '待执行',
  ScheduleTaskState.completed => '已完成',
  ScheduleTaskState.skipped => '已跳过',
};

String _linkedRecordSummary(ScheduleRecord record) {
  final amount = record.amountMl == null ? '' : '${record.amountMl} ml · ';
  return '$amount${_time(record.occurredAt)} 完成';
}

String _reminderFingerprint(bool enabled, List<ScheduleTask> tasks) {
  final entries =
      tasks
          .map(
            (task) =>
                '${task.id}:${task.state.name}:${task.remindAt?.millisecondsSinceEpoch ?? 0}',
          )
          .toList(growable: false)
        ..sort();
  return '${enabled ? 1 : 0}|${entries.join('|')}';
}

String _countdown(DateTime? at, DateTime now) {
  if (at == null) return '未设置时间';
  final difference = at.difference(now);
  if (difference.isNegative || difference == Duration.zero) {
    final overdue = now.difference(at);
    final hours = overdue.inHours;
    final minutes = overdue.inMinutes.remainder(60);
    final seconds = overdue.inSeconds.remainder(60);
    if (hours > 0) return '超时 $hours小时$minutes分$seconds秒';
    return '超时 $minutes分$seconds秒';
  }
  final days = difference.inDays;
  final hours = difference.inHours.remainder(24);
  final minutes = difference.inMinutes.remainder(60);
  final seconds = difference.inSeconds.remainder(60);
  if (days > 0) return '还有 $days天$hours小时$minutes分$seconds秒';
  if (difference.inHours > 0) {
    return '还有 ${difference.inHours}小时$minutes分$seconds秒';
  }
  return '还有 $minutes 分 $seconds 秒';
}

String _time(DateTime? value) {
  if (value == null) return '--:--';
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _timeText(DateTime? value) => value == null ? '21:30' : _time(value);

String? _normalizedTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String? _shiftTime(String value, int minutes) {
  final normalized = _normalizedTime(value);
  if (normalized == null) return null;
  final parts = normalized.split(':');
  final totalMinutes =
      (int.parse(parts[0]) * 60 + int.parse(parts[1]) + minutes) % (24 * 60);
  final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final minute = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime _recordDateTime(DateTime day, String time) {
  final parts = time.split(':');
  if (day.isUtc) {
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

String _dayKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _weekday(DateTime date) =>
    const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1];

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

DateTime _calendarDay(DateTime value) => value.isUtc
    ? DateTime.utc(value.year, value.month, value.day)
    : DateTime(value.year, value.month, value.day);

bool _sameWeekWindow(DateTime anchor, DateTime date) =>
    date.difference(anchor).inDays.abs() <= 3;

String? _intentTaskId(Uri? routeUri, Object? routeExtra) {
  final queryId =
      routeUri?.queryParameters['taskId'] ??
      routeUri?.queryParameters['task_id'];
  if (queryId?.trim().isNotEmpty == true) return queryId!.trim();
  if (routeExtra is Map) {
    final value = routeExtra['taskId'] ?? routeExtra['task_id'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

DateTime? _intentDay(Uri? routeUri, Object? routeExtra) {
  final queryDate =
      routeUri?.queryParameters['date'] ??
      routeUri?.queryParameters['task_date'] ??
      routeUri?.queryParameters['plan_date'];
  final queryParsed = queryDate == null ? null : DateTime.tryParse(queryDate);
  if (queryParsed != null) return queryParsed;
  if (routeExtra is Map) {
    final value =
        routeExtra['date'] ??
        routeExtra['task_date'] ??
        routeExtra['plan_date'];
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
  }
  return null;
}
