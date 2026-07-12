import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_image_recognition.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_postpartum_stage.dart';
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
    this.deliveryDateLoader,
    this.imageRecognitionGateway,
    this.reminderGateway = const UnsupportedScheduleReminderGateway(),
    this.reminderPreferenceStore =
        const DisabledScheduleReminderPreferenceStore(),
    this.milkPlanChangeStore,
    this.volumeUnitPreferenceStore,
  });

  final ScheduleRepository repository;
  final DateTime Function() now;
  final String path;
  final DateTime? initialDay;
  final Uri? routeUri;
  final Object? routeExtra;
  final VoidCallback? onOpenAgent;
  final Future<DateTime?> Function()? deliveryDateLoader;
  final ScheduleImageRecognitionGateway? imageRecognitionGateway;
  final ScheduleReminderGateway reminderGateway;
  final ScheduleReminderPreferenceStore reminderPreferenceStore;
  final MilkPlanChangeStore? milkPlanChangeStore;
  final VolumeUnitPreferenceStore? volumeUnitPreferenceStore;

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
  MomCozyVolumeUnit _volumeUnit = MomCozyVolumeUnit.milliliters;
  bool _recognitionInFlight = false;
  String? _lastReminderFingerprint;
  int _volumeUnitLoadRevision = 0;
  int _requestSequence = 0;
  int _intentRevision = 0;
  String? _pendingFocusTaskId;
  bool _focusScheduled = false;
  int? _consumedMilkPlanRevision;
  DateTime? _deliveryDate;
  int _deliveryDateLoadGeneration = 0;
  String? _editingTaskId;
  TextEditingController? _editingTaskTitleController;
  String? _editingTaskTime;
  bool _savingTaskEdit = false;
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
    unawaited(_loadVolumeUnitPreference());
    unawaited(_loadReminderPreference());
    unawaited(_loadDeliveryDate());
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
    if (!identical(oldWidget.deliveryDateLoader, widget.deliveryDateLoader)) {
      unawaited(_loadDeliveryDate());
    }
    if (!identical(
      oldWidget.volumeUnitPreferenceStore,
      widget.volumeUnitPreferenceStore,
    )) {
      unawaited(_loadVolumeUnitPreference());
    }
  }

  @override
  void dispose() {
    _volumeUnitLoadRevision += 1;
    _clockTimer?.cancel();
    _highlightTimer?.cancel();
    _planChangeHighlightTimer?.cancel();
    widget.milkPlanChangeStore?.removeListener(_onMilkPlanChangeStore);
    _controller.removeListener(_onControllerReminderChange);
    _editingTaskTitleController?.dispose();
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
        final showBackToToday =
            !_sameDay(state.selectedDay, _controller.today) ||
            !_sameWeekWindow(state.displayAnchor, _controller.today);
        final motionDuration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200);
        return Stack(
          key: ValueKey('route-page-${widget.path}'),
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                _ScheduleFixedDateArea(
                  today: _controller.today,
                  selectedDay: state.selectedDay,
                  displayAnchor: state.displayAnchor,
                  highlightedDay: _highlightedDay,
                  changedDayKeys: _changedDayKeys,
                  onSelected: _selectDay,
                  onBrowseWeek: _controller.browseWeek,
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
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 82,
              right: 20,
              child: AnimatedSwitcher(
                duration: motionDuration,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.96,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: showBackToToday
                    ? FilledButton(
                        key: const ValueKey('schedule-back-to-today-button'),
                        onPressed: () =>
                            unawaited(_controller.selectDay(_controller.today)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('今天'),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('schedule-back-to-today-hidden'),
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
          reminderEnabled: _reminderEnabled,
          onReminder: () => unawaited(_toggleReminder(resolved.tasks)),
        ),
      );
      if (isToday) {
        children.addAll([
          const SizedBox(height: 16),
          _ScheduleAgentCard(
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
        volumeUnit: _volumeUnit,
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
          busy: state.isMutating || _recognitionInFlight,
          explanation: _taskExplanation(resolved),
          onAdd: () => unawaited(_showTaskEditor()),
          onRecognize: () => unawaited(_showScheduleRecognition()),
        ),
      );
      children.add(const SizedBox(height: 10));
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
                provenance: _taskProvenance(task, resolved.context),
                linkedRecords: entry.linkedRecords,
                volumeUnit: _volumeUnit,
                busy: state.isMutating,
                highlighted: task.id == _highlightedTaskId,
                isNext: isToday && task.id == state.nextPendingTask?.id,
                editing: task.id == _editingTaskId,
                editTitleController: task.id == _editingTaskId
                    ? _editingTaskTitleController
                    : null,
                editTime: task.id == _editingTaskId ? _editingTaskTime : null,
                editSaving: task.id == _editingTaskId && _savingTaskEdit,
                onEdit: task.state == ScheduleTaskState.pending && isToday
                    ? () => _startInlineTaskEdit(task)
                    : null,
                onEditTime: () => unawaited(_pickInlineTaskTime()),
                onSaveEdit: () => unawaited(_saveInlineTaskEdit(task)),
                onCancelEdit: _cancelInlineTaskEdit,
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
              volumeUnit: _volumeUnit,
              busy: state.isMutating,
              onDelete: () => unawaited(_deleteRecord(record)),
            ),
          );
        }
      }
      children.add(Column(children: timelineRows));
    }
    if (isToday) {
      children.add(const SizedBox(height: 12));
      children.add(
        _ScheduleQuickActions(
          onPumping: () =>
              unawaited(_showRecordEditor(ScheduleRecordKind.pumping)),
          onFeeding: () =>
              unawaited(_showRecordEditor(ScheduleRecordKind.feeding)),
        ),
      );
    }
    _scheduleRouteFocus(state, resolved);
    return children;
  }

  void _selectDay(DateTime day) {
    if (!_sameDay(day, _controller.state.selectedDay)) {
      _cancelInlineTaskEdit();
    }
    unawaited(_controller.selectDay(day));
  }

  void _startInlineTaskEdit(ScheduleTask task) {
    if (_controller.state.isMutating) return;
    final previous = _editingTaskTitleController;
    setState(() {
      _editingTaskId = task.id;
      _editingTaskTitleController = TextEditingController(text: task.title);
      _editingTaskTime = _time(task.remindAt);
      _savingTaskEdit = false;
      _feedback = null;
    });
    previous?.dispose();
  }

  void _cancelInlineTaskEdit() {
    if (_editingTaskId == null) return;
    FocusScope.of(context).unfocus();
    final previous = _editingTaskTitleController;
    setState(_resetInlineTaskEditState);
    previous?.dispose();
  }

  void _resetInlineTaskEditState() {
    _editingTaskId = null;
    _editingTaskTitleController = null;
    _editingTaskTime = null;
    _savingTaskEdit = false;
  }

  Future<void> _pickInlineTaskTime() async {
    final initialTime = _editingTaskTime;
    if (initialTime == null || _savingTaskEdit) return;
    final selected = await _showScheduleTimePicker(
      context,
      title: '设置任务时间',
      initialTime: initialTime,
    );
    if (!mounted || selected == null || _editingTaskId == null) return;
    setState(() => _editingTaskTime = selected);
  }

  Future<void> _saveInlineTaskEdit(ScheduleTask task) async {
    if (_savingTaskEdit || _editingTaskId != task.id) return;
    final title = _editingTaskTitleController?.text.trim() ?? '';
    final time = _normalizedTime(_editingTaskTime ?? '');
    if (title.isEmpty || time == null) {
      setState(() => _feedback = '请填写有效的任务名称和时间');
      return;
    }
    FocusScope.of(context).unfocus();
    _controller.clearMutationError();
    setState(() => _savingTaskEdit = true);
    final updated = await _controller.updateTask(
      taskId: task.id,
      time: time,
      title: title,
      description: task.description,
    );
    if (!mounted || _editingTaskId != task.id) return;
    if (updated == null) {
      setState(() => _savingTaskEdit = false);
      return;
    }
    final previous = _editingTaskTitleController;
    setState(() {
      _resetInlineTaskEditState();
      _feedback = '任务已更新';
    });
    previous?.dispose();
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
    final abandonedEditController = notify ? _editingTaskTitleController : null;

    void apply() {
      if (notify) _resetInlineTaskEditState();
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
    abandonedEditController?.dispose();
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
    final deliveryDate = _deliveryDate;
    if (deliveryDate != null && selectedDay != null) {
      return schedulePostpartumStageLabel(
        deliveryDate: deliveryDate,
        selectedDay: selectedDay,
      );
    }
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

  Future<void> _loadDeliveryDate() async {
    final generation = ++_deliveryDateLoadGeneration;
    final loader = widget.deliveryDateLoader;
    if (loader == null) {
      if (mounted && _deliveryDate != null) {
        setState(() => _deliveryDate = null);
      }
      return;
    }
    try {
      final value = await loader();
      if (!mounted || generation != _deliveryDateLoadGeneration) return;
      final normalized = value == null
          ? null
          : _calendarDay(value.isUtc ? value.toLocal() : value);
      if (_deliveryDate == normalized) return;
      setState(() => _deliveryDate = normalized);
    } catch (_) {
      // Keep the last known date and fall back to the plan payload on first load.
    }
  }

  String _taskExplanation(ScheduleDayPlan snapshot) {
    final actionTasks = snapshot.tasks
        .where((task) => !task.id.startsWith('blocked-'))
        .toList(growable: false);
    final completed = actionTasks
        .where((task) => task.state == ScheduleTaskState.completed)
        .length;
    final skipped = actionTasks
        .where((task) => task.state == ScheduleTaskState.skipped)
        .length;
    final taskProgress = actionTasks.isEmpty
        ? '暂无任务进度'
        : '完成$completed/${actionTasks.length}项${skipped > 0 ? '，跳过$skipped项' : ''}';
    final recordFeedback = snapshot.records.isEmpty
        ? '暂无新增记录反馈'
        : '新增记录只用于看执行反馈';
    final planKind = _explanationPlanKind(snapshot.context);
    final planLabel = _explanationPlanLabel(planKind, snapshot.context);
    return '$planLabel依据上次制定前读取到的产后阶段、奶量/喂养记录和原有任务节奏。'
        '今天$taskProgress，$recordFeedback；${_explanationMethod(planKind, planLabel)}';
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
        barrierColor: MomCozyColors.foreground.withValues(alpha: 0.3),
        builder: (context) => const _ScheduleReminderWarningDialog(),
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

  Future<void> _loadVolumeUnitPreference() async {
    final revision = ++_volumeUnitLoadRevision;
    var unit = MomCozyVolumeUnit.milliliters;
    try {
      unit = await widget.volumeUnitPreferenceStore?.read() ?? unit;
    } catch (_) {
      // The default mL unit keeps this non-sensitive display preference usable.
    }
    if (!mounted || revision != _volumeUnitLoadRevision) return;
    setState(() => _volumeUnit = unit);
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
    if (_recognitionInFlight) return;
    final gateway = widget.imageRecognitionGateway;
    if (gateway == null) {
      setState(() => _feedback = '登录后可选择截图并识别日程');
      return;
    }
    setState(() {
      _recognitionInFlight = true;
      _feedback = '正在识别截图，结果不会自动写入计划…';
    });
    ScheduleImageRecognitionResult result;
    try {
      result = await gateway.pickAndRecognize();
    } on ScheduleImageRecognitionException catch (error) {
      if (!mounted) return;
      setState(() {
        _recognitionInFlight = false;
        _feedback = error.userMessage;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recognitionInFlight = false;
        _feedback = '截图识别暂时不可用，请稍后重试';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _recognitionInFlight = false);
    if (result.cancelled) {
      setState(() => _feedback = '已取消选择截图');
      return;
    }
    if (result.tasks.isEmpty) {
      setState(() => _feedback = '未识别到带有明确时间的日程任务');
      return;
    }
    final drafts = await _showTaskDraftSheet(
      initialTasks: result.tasks,
      dialogTitle: '确认识别结果',
      submitLabel: '确认添加',
    );
    if (!mounted) return;
    if (drafts == null || drafts.isEmpty) {
      setState(() => _feedback = '识别结果未保存');
      return;
    }
    await _createTasks(drafts);
  }

  Future<List<_TaskDraft>?> _showTaskDraftSheet({
    ScheduleTask? task,
    List<ScheduleImageTaskPreview> initialTasks =
        const <ScheduleImageTaskPreview>[],
    String? dialogTitle,
    String? submitLabel,
  }) {
    return showModalBottomSheet<List<_TaskDraft>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: MomCozyColors.foreground.withValues(alpha: 0.2),
      builder: (context) => _ScheduleTaskSheet(
        task: task,
        initialTasks: initialTasks,
        dialogTitle: dialogTitle,
        submitLabel: submitLabel,
        defaultTime: _time(_clock.add(const Duration(minutes: 15))),
      ),
    );
  }

  Future<void> _showTaskEditor({ScheduleTask? task}) async {
    final drafts = await _showTaskDraftSheet(task: task);
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

    await _createTasks(drafts);
  }

  Future<void> _createTasks(List<_TaskDraft> drafts) async {
    _controller.clearMutationError();
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
    setState(() {
      _feedback = created == drafts.length
          ? created == 1
                ? '任务已添加'
                : '已添加 $created 个任务'
          : '已添加 $created/${drafts.length} 个任务，其余未保存，请检查后重试';
    });
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
    if (task.kind == ScheduleTaskKind.pumping) {
      await _showRecordEditor(ScheduleRecordKind.pumping, linkedTask: task);
      return;
    }
    await _showRecordEditor(ScheduleRecordKind.feeding, linkedTask: task);
  }

  Future<void> _showRecordEditor(
    ScheduleRecordKind kind, {
    ScheduleTask? linkedTask,
  }) async {
    final draft = await showModalBottomSheet<_RecordDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: MomCozyColors.foreground.withValues(alpha: 0.2),
      builder: (context) => _ScheduleRecordSheet(
        kind: kind,
        volumeUnit: _volumeUnit,
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
  });

  final DateTime today;
  final DateTime selectedDay;
  final DateTime displayAnchor;
  final DateTime? highlightedDay;
  final Set<String> changedDayKeys;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onBrowseWeek;

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
                Text(
                  '${displayAnchor.year}年${displayAnchor.month}月',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: MomCozyDecorations.card(
                      color: MomCozyColors.card,
                      borderColor: MomCozyColors.border,
                      radius: 16,
                      shadows: MomCozyShadows.soft,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            height: 48,
                            child: IconButton(
                              key: const ValueKey('schedule-week-prev-button'),
                              tooltip: '上一周',
                              padding: EdgeInsets.zero,
                              onPressed: () => onBrowseWeek(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                for (var offset = -3; offset <= 3; offset += 1)
                                  Expanded(
                                    child: _ScheduleDatePill(
                                      date: displayAnchor.add(
                                        Duration(days: offset),
                                      ),
                                      today: today,
                                      selected: _sameDay(
                                        displayAnchor.add(
                                          Duration(days: offset),
                                        ),
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
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 48,
                            child: IconButton(
                              key: const ValueKey('schedule-week-next-button'),
                              tooltip: '下一周',
                              padding: EdgeInsets.zero,
                              onPressed: () => onBrowseWeek(1),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
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
          height: 48,
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1.05 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: AnimatedContainer(
                key: highlighted
                    ? ValueKey('schedule-highlighted-date-${_dayKey(date)}')
                    : null,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                width: 36,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? MomCozyColors.primary
                      : highlighted
                      ? MomCozyColors.careSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: highlighted && !selected
                      ? Border.all(
                          color: MomCozyColors.care.withValues(alpha: 0.5),
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: MomCozyColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Center(
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
                              color: selected
                                  ? Colors.white
                                  : highlighted
                                  ? MomCozyColors.care
                                  : MomCozyColors.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (highlighted && !selected)
                      const Positioned(
                        right: 2,
                        top: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: MomCozyColors.care,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 6, height: 6),
                        ),
                      ),
                  ],
                ),
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
    required this.reminderEnabled,
    required this.onReminder,
  });

  final String title;
  final String stageLabel;
  final int completed;
  final int total;
  final bool reminderEnabled;
  final VoidCallback onReminder;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      key: const ValueKey('schedule-context-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MomCozyColors.primary.withValues(alpha: 0.05),
            MomCozyColors.card.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.4)),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                key: const ValueKey('schedule-context-reminder-button'),
                tooltip: reminderEnabled ? '关闭计划提醒' : '开启计划提醒',
                onPressed: onReminder,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: MomCozyColors.card.withValues(alpha: 0.9),
                  side: BorderSide(
                    color: MomCozyColors.border.withValues(alpha: 0.5),
                  ),
                ),
                icon: Icon(
                  reminderEnabled
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_off_outlined,
                  size: 18,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 1),
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MomCozyColors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stageLabel,
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    '今日任务',
                    style: TextStyle(
                      color: MomCozyColors.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completed/$total',
                    style: const TextStyle(
                      color: MomCozyColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
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
    required this.reminderEnabled,
    required this.onReminder,
    required this.onOpenAgent,
  });

  final bool reminderEnabled;
  final VoidCallback onReminder;
  final VoidCallback onOpenAgent;

  @override
  Widget build(BuildContext context) {
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
              width: 36,
              height: 36,
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
                const Text(
                  '已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我',
                  style: TextStyle(
                    color: MomCozyColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('schedule-agent-reminder-button'),
                      onPressed: onReminder,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: MomCozyColors.foreground,
                      ),
                      icon: Icon(
                        reminderEnabled
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_off_outlined,
                        size: 16,
                      ),
                      label: const Text('提醒开关', style: TextStyle(fontSize: 12)),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('schedule-agent-chat-button'),
                      onPressed: onOpenAgent,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                      ),
                      label: const Text('对话', style: TextStyle(fontSize: 12)),
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
    required this.volumeUnit,
    required this.onComplete,
    required this.onDelay,
    required this.onSkip,
  });

  final DateTime selectedDay;
  final DateTime today;
  final ScheduleDayPlan snapshot;
  final DateTime now;
  final MomCozyVolumeUnit volumeUnit;
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
    final pumpingAmountMl = snapshot.records
        .where((record) => record.kind == ScheduleRecordKind.pumping)
        .map((record) => record.amountMl ?? 0)
        .fold<int>(0, (total, amount) => total + amount);
    final pumpingAmount = _formatVolume(volumeUnit, pumpingAmountMl);
    final title = isPast
        ? snapshot.tasks.isEmpty
              ? '这天没有计划任务'
              : '这天的计划已结束'
        : !isToday
        ? snapshot.tasks.isEmpty
              ? '这天还没有计划'
              : '未来的计划'
        : next != null
        ? '待执行任务'
        : snapshot.tasks.isEmpty
        ? '今天还没有计划任务'
        : snapshot.skippedTaskCount > 0
        ? '今天的计划尚未全部完成哦'
        : '今天的计划已全部完成';
    final detail = isPast
        ? snapshot.tasks.isEmpty
              ? '没有看到当天的计划任务。'
              : '共完成 ${snapshot.completedTaskCount} 项任务，母乳产出 $pumpingAmount'
        : !isToday
        ? snapshot.tasks.isEmpty
              ? null
              : '系统已为你提前规划了当天的吸乳和喂养日程'
        : next != null
        ? '${_time(next.remindAt)} ${next.title} · ${_countdown(next.remindAt, now)}'
        : snapshot.tasks.isEmpty
        ? '可以先从对话里生成计划并同步到日历，或手动添加任务。'
        : snapshot.skippedTaskCount > 0
        ? '顺利完成${snapshot.completedTaskCount}个任务，有${snapshot.skippedTaskCount}个任务被跳过'
        : '任务很棒地完成了，继续保持节奏就好。';

    if (!isToday || next == null) {
      return Container(
        key: const ValueKey('schedule-empty-task-card'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.secondary.withValues(alpha: 0.32),
          borderColor: MomCozyColors.border,
          radius: 28,
          shadows: const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MomCozyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPast || (isToday && snapshot.tasks.isNotEmpty)
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
                size: 32,
                color: MomCozyColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MomCozyColors.mutedForeground,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final overdue = next.remindAt != null && !next.remindAt!.isAfter(now);
    final severelyOverdue =
        overdue && now.difference(next.remindAt!).inMinutes > 90;
    return Container(
      key: const ValueKey('schedule-next-task-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: severelyOverdue
              ? [
                  MomCozyColors.secondary.withValues(alpha: 0.5),
                  MomCozyColors.secondary.withValues(alpha: 0.3),
                ]
              : [
                  MomCozyColors.primary.withValues(alpha: 0.15),
                  MomCozyColors.primary.withValues(alpha: 0.05),
                  MomCozyColors.card,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: severelyOverdue
              ? MomCozyColors.border.withValues(alpha: 0.6)
              : MomCozyColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MomCozyColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _taskIcon(next.kind),
                          color: MomCozyColors.primary,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            next.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MomCozyColors.foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        overdue ? '已超时' : '距离开始还剩',
                        maxLines: 1,
                        style: TextStyle(
                          color: overdue
                              ? Colors.red.shade700
                              : const Color(0xff7d5730),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 18,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _countdownValue(next.remindAt, now),
                            maxLines: 1,
                            style: TextStyle(
                              color: overdue
                                  ? Colors.red.shade700
                                  : const Color(0xff7d5730),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              key: const ValueKey('schedule-next-complete-button'),
              onPressed: onComplete,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                '手动完成并记录数据',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('schedule-next-delay-button'),
                    onPressed: onDelay,
                    icon: const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: MomCozyColors.mutedForeground,
                    ),
                    label: const Text('顺延半小时', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: MomCozyColors.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('schedule-next-skip-button'),
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: MomCozyColors.mutedForeground,
                    ),
                    child: const Text('跳过这次任务', style: TextStyle(fontSize: 12)),
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
    final compactButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
      foregroundColor: MomCozyColors.foreground,
    );
    return Row(
      key: const ValueKey('schedule-list-toolbar'),
      children: [
        Text(
          '今日任务',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            key: const ValueKey('schedule-task-help-button'),
            tooltip: '今日任务说明',
            padding: EdgeInsets.zero,
            onPressed: () => showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.35),
              builder: (context) =>
                  _ScheduleTaskExplanationDialog(explanation: explanation),
            ),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          key: const ValueKey('schedule-adjust-button'),
          onPressed: busy ? null : onRecognize,
          style: compactButtonStyle,
          icon: const Icon(Icons.image_outlined, size: 15),
          label: const Text(
            '调整日程',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          key: const ValueKey('schedule-add-task-button'),
          onPressed: busy ? null : onAdd,
          style: compactButtonStyle,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: const Text(
            '添加任务',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ScheduleTaskExplanationDialog extends StatelessWidget {
  const _ScheduleTaskExplanationDialog({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('schedule-task-explanation-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: MomCozyColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey('schedule-task-explanation-close'),
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: MomCozyColors.muted.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  explanation,
                  style: const TextStyle(
                    color: MomCozyColors.foreground,
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleReminderWarningDialog extends StatelessWidget {
  const _ScheduleReminderWarningDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('schedule-reminder-confirm-dialog'),
      insetPadding: EdgeInsets.zero,
      backgroundColor: MomCozyColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: MomCozyColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.85,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 21,
                      color: MomCozyColors.warm,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '关闭提醒？',
                      style: TextStyle(
                        color: MomCozyColors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: '关闭后，将停止'),
                      TextSpan(
                        text: '系统级后台提醒',
                        style: TextStyle(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: '（含锁屏/全屏提醒与悬浮窗相关能力），Mai 也无法再为你提供'),
                      TextSpan(
                        text: '个性化排期优化',
                        style: TextStyle(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: '与'),
                      TextSpan(
                        text: '智能防冲突',
                        style: TextStyle(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: '。确定要关闭吗？'),
                    ],
                  ),
                  style: const TextStyle(
                    color: MomCozyColors.mutedForeground,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('schedule-reminder-cancel'),
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('保持开启'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('schedule-reminder-confirm'),
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: const Color(0xffc8465c),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('仍要关闭'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleTaskRow extends StatelessWidget {
  const _ScheduleTaskRow({
    required this.task,
    required this.provenance,
    required this.linkedRecords,
    required this.volumeUnit,
    required this.busy,
    required this.highlighted,
    required this.isNext,
    required this.editing,
    required this.editTitleController,
    required this.editTime,
    required this.editSaving,
    required this.onEdit,
    required this.onEditTime,
    required this.onSaveEdit,
    required this.onCancelEdit,
    required this.onDelete,
    required this.onDeleteLinkedRecord,
  });

  final ScheduleTask task;
  final _ScheduleTaskProvenance provenance;
  final List<ScheduleRecord> linkedRecords;
  final MomCozyVolumeUnit volumeUnit;
  final bool busy;
  final bool highlighted;
  final bool isNext;
  final bool editing;
  final TextEditingController? editTitleController;
  final String? editTime;
  final bool editSaving;
  final VoidCallback? onEdit;
  final VoidCallback onEditTime;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onDelete;
  final ValueChanged<ScheduleRecord> onDeleteLinkedRecord;

  @override
  Widget build(BuildContext context) {
    final completed = task.state == ScheduleTaskState.completed;
    final skipped = task.state == ScheduleTaskState.skipped;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 5),
      child: Semantics(
        label:
            '${_time(task.remindAt)} ${task.title}，${_taskStateLabel(task.state)}'
            '，${provenance.label}'
            '${isNext ? '，下一项' : ''}'
            '${linkedRecords.isEmpty ? '' : '，${linkedRecords.map((record) => _linkedRecordSummary(record, volumeUnit)).join('，')}'}',
        button: !editing && onEdit != null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              key: ValueKey('schedule-timeline-task-${task.id}'),
              decoration: BoxDecoration(
                color: skipped
                    ? const Color(0xffefedec)
                    : completed
                    ? const Color(0xfff0f7ee)
                    : MomCozyColors.card,
                borderRadius: BorderRadius.circular(16),
                border: skipped
                    ? null
                    : Border.all(
                        color: editing
                            ? MomCozyColors.primary
                            : highlighted
                            ? MomCozyColors.primary.withValues(alpha: 0.72)
                            : isNext
                            ? MomCozyColors.primary.withValues(alpha: 0.5)
                            : completed
                            ? const Color(0xffd4e3d1)
                            : MomCozyColors.border.withValues(alpha: 0.6),
                        width: editing || highlighted ? 2 : 1,
                      ),
                boxShadow: editing || highlighted || isNext
                    ? MomCozyShadows.soft
                    : const [],
              ),
              child: InkWell(
                onTap: editing ? null : onEdit,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.only(left: editing ? 6 : 12, right: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: editing
                        ? _ScheduleInlineTaskEditor(
                            taskId: task.id,
                            titleController: editTitleController!,
                            time: editTime ?? _time(task.remindAt),
                            saving: editSaving,
                            onEditTime: onEditTime,
                            onSave: onSaveEdit,
                            onCancel: onCancelEdit,
                          )
                        : Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  _time(task.remindAt),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: skipped
                                        ? MomCozyColors.mutedForeground
                                        : completed
                                        ? MomCozyColors.primary.withValues(
                                            alpha: 0.7,
                                          )
                                        : MomCozyColors.mutedForeground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    decoration: skipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: skipped
                                        ? MomCozyColors.mutedForeground
                                        : MomCozyColors.foreground.withValues(
                                            alpha: completed ? 0.8 : 0.9,
                                          ),
                                    fontSize: 15,
                                    fontWeight: completed || skipped
                                        ? FontWeight.w800
                                        : FontWeight.w900,
                                    decoration: skipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (linkedRecords.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                _CompactLinkedRecordBadge(
                                  record: linkedRecords.first,
                                  volumeUnit: volumeUnit,
                                  extraCount: linkedRecords.length - 1,
                                  onDeleted: busy
                                      ? null
                                      : () => onDeleteLinkedRecord(
                                          linkedRecords.first,
                                        ),
                                ),
                              ],
                              if (skipped) const _StatusBadge(label: '已跳过'),
                              if (completed) const _StatusBadge(label: '已完成'),
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: IconButton(
                                  tooltip: linkedRecords.isEmpty
                                      ? '删除任务'
                                      : '已有执行记录，请先删除关联记录',
                                  padding: EdgeInsets.zero,
                                  onPressed: busy || linkedRecords.isNotEmpty
                                      ? null
                                      : onDelete,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            if (!editing)
              Positioned(
                left: 0,
                top: -4,
                child: _TaskSourceBadge(
                  taskId: task.id,
                  provenance: provenance,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleInlineTaskEditor extends StatelessWidget {
  const _ScheduleInlineTaskEditor({
    required this.taskId,
    required this.titleController,
    required this.time,
    required this.saving,
    required this.onEditTime,
    required this.onSave,
    required this.onCancel,
  });

  final String taskId;
  final TextEditingController titleController;
  final String time;
  final bool saving;
  final VoidCallback onEditTime;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          height: 38,
          child: OutlinedButton(
            key: ValueKey('schedule-inline-task-time-$taskId'),
            onPressed: saving ? null : onEditTime,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                color: MomCozyColors.primary.withValues(alpha: 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(time),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              key: ValueKey('schedule-inline-task-title-$taskId'),
              controller: titleController,
              autofocus: true,
              enabled: !saving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!saving) onSave();
              },
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: MomCozyColors.border.withValues(alpha: 0.8),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: MomCozyColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          height: 40,
          child: IconButton(
            key: ValueKey('schedule-inline-task-save-$taskId'),
            tooltip: '保存',
            padding: EdgeInsets.zero,
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
          ),
        ),
        SizedBox(
          width: 36,
          height: 40,
          child: IconButton(
            key: ValueKey('schedule-inline-task-cancel-$taskId'),
            tooltip: '取消',
            padding: EdgeInsets.zero,
            onPressed: saving ? null : onCancel,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ),
      ],
    );
  }
}

class _ScheduleRecordRow extends StatelessWidget {
  const _ScheduleRecordRow({
    required this.record,
    required this.volumeUnit,
    required this.busy,
    required this.onDelete,
  });

  final ScheduleRecord record;
  final MomCozyVolumeUnit volumeUnit;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final value = record.amountMl != null
        ? _formatVolume(volumeUnit, record.amountMl!)
        : record.durationSeconds != null
        ? '${(record.durationSeconds! / 60).round()} min'
        : null;
    final manualSupplement = record.displayTitle.contains('补录');
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 5),
      child: Semantics(
        label:
            '${_time(record.occurredAt)} ${record.displayTitle}'
            '${record.amountMl == null ? '' : '，${_formatVolume(volumeUnit, record.amountMl!)}'}'
            '${record.linkedTaskId == null ? '' : '，已关联任务'}，已完成',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              key: ValueKey('schedule-timeline-record-${record.id}'),
              decoration: BoxDecoration(
                color: const Color(0xfff0f7ee),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffd4e3d1)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          _time(record.occurredAt),
                          maxLines: 1,
                          style: TextStyle(
                            color: MomCozyColors.primary.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          record.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MomCozyColors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (value != null) _TimelineValueBadge(label: value),
                      _StatusBadge(label: _time(record.occurredAt)),
                      const _StatusBadge(label: '已完成'),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          tooltip: '删除记录',
                          padding: EdgeInsets.zero,
                          onPressed: busy ? null : onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (manualSupplement)
              const Positioned(
                left: 0,
                top: -4,
                child: _TimelineCornerBadge(label: '手动添加'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactLinkedRecordBadge extends StatelessWidget {
  const _CompactLinkedRecordBadge({
    required this.record,
    required this.volumeUnit,
    required this.extraCount,
    required this.onDeleted,
  });

  final ScheduleRecord record;
  final MomCozyVolumeUnit volumeUnit;
  final int extraCount;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('schedule-linked-record-${record.id}'),
      height: 24,
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xffc7dbc4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _linkedRecordSummary(record, volumeUnit),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MomCozyColors.foreground,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (extraCount > 0)
            Text(
              ' +$extraCount',
              style: const TextStyle(
                color: MomCozyColors.mutedForeground,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (onDeleted != null)
            Tooltip(
              message: '删除关联记录',
              child: Semantics(
                button: true,
                label: '删除关联记录',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDeleted,
                    borderRadius: BorderRadius.circular(6),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(Icons.close_rounded, size: 14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineValueBadge extends StatelessWidget {
  const _TimelineValueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      constraints: const BoxConstraints(maxWidth: 88),
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TimelineCornerBadge extends StatelessWidget {
  const _TimelineCornerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MomCozyColors.muted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MomCozyColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MomCozyColors.mutedForeground,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
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
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TaskSourceBadge extends StatelessWidget {
  const _TaskSourceBadge({required this.taskId, required this.provenance});

  final String taskId;
  final _ScheduleTaskProvenance provenance;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('schedule-task-source-$taskId'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: provenance.agentGenerated
            ? MomCozyColors.roseSoft
            : MomCozyColors.muted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: provenance.agentGenerated
              ? MomCozyColors.primary.withValues(alpha: 0.35)
              : MomCozyColors.border,
        ),
      ),
      child: Text(
        provenance.label,
        style: TextStyle(
          color: provenance.agentGenerated
              ? MomCozyColors.primary
              : MomCozyColors.mutedForeground,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
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
    return SizedBox(
      key: const ValueKey('schedule-quick-actions'),
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPumping,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: MomCozyColors.raised,
                foregroundColor: MomCozyColors.foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                '吸奶补录',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onFeeding,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: MomCozyColors.raised,
                foregroundColor: MomCozyColors.foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                '喂养记录',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
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

Future<String?> _showScheduleTimePicker(
  BuildContext context, {
  required String title,
  required String initialTime,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: MomCozyColors.foreground.withValues(alpha: 0.3),
    builder: (context) =>
        _ScheduleTimePickerSheet(title: title, initialTime: initialTime),
  );
}

class _ScheduleTimePickerSheet extends StatefulWidget {
  const _ScheduleTimePickerSheet({
    required this.title,
    required this.initialTime,
  });

  final String title;
  final String initialTime;

  @override
  State<_ScheduleTimePickerSheet> createState() =>
      _ScheduleTimePickerSheetState();
}

class _ScheduleTimePickerSheetState extends State<_ScheduleTimePickerSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final normalized = _normalizedTime(widget.initialTime) ?? '00:00';
    final parts = normalized.split(':');
    _hour = int.parse(parts[0]);
    _minute = int.parse(parts[1]);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey('schedule-time-picker-sheet'),
      child: Material(
        color: MomCozyColors.card,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: MomCozyColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: MomCozyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MomCozyColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '当前调节时间',
                        style: TextStyle(
                          color: MomCozyColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                        key: const ValueKey('schedule-time-picker-current'),
                        style: const TextStyle(
                          color: MomCozyColors.primary,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 176,
                  child: Row(
                    children: [
                      Expanded(
                        child: _timeWheel(
                          key: const ValueKey('schedule-time-hour-wheel'),
                          controller: _hourController,
                          count: 24,
                          selected: _hour,
                          onSelected: (value) => setState(() => _hour = value),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: MomCozyColors.mutedForeground,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _timeWheel(
                          key: const ValueKey('schedule-time-minute-wheel'),
                          controller: _minuteController,
                          count: 60,
                          selected: _minute,
                          onSelected: (value) =>
                              setState(() => _minute = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        key: const ValueKey('schedule-time-picker-cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('schedule-time-picker-confirm'),
                        onPressed: () => Navigator.pop(
                          context,
                          '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                        ),
                        child: const Text('确认'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeWheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.secondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListWheelScrollView.useDelegate(
          key: key,
          controller: controller,
          itemExtent: 36,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.35,
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) {
              final active = index == selected;
              return ColoredBox(
                color: active
                    ? MomCozyColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                child: Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: active
                          ? MomCozyColors.primary
                          : MomCozyColors.mutedForeground,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScheduleTaskSheet extends StatefulWidget {
  const _ScheduleTaskSheet({
    this.task,
    this.initialTasks = const <ScheduleImageTaskPreview>[],
    this.dialogTitle,
    this.submitLabel,
    required this.defaultTime,
  });

  final ScheduleTask? task;
  final List<ScheduleImageTaskPreview> initialTasks;
  final String? dialogTitle;
  final String? submitLabel;
  final String defaultTime;

  @override
  State<_ScheduleTaskSheet> createState() => _ScheduleTaskSheetState();
}

class _ScheduleTaskSheetState extends State<_ScheduleTaskSheet> {
  late final List<_TaskDraftEditor> _rows;
  String? _error;

  int get _maxRows => widget.initialTasks.isEmpty ? 6 : 32;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _rows = [
        _TaskDraftEditor(
          title: task.title,
          time: _timeText(task.remindAt),
          description: task.description,
          kind: task.kind,
        ),
      ];
      return;
    }
    if (widget.initialTasks.isNotEmpty) {
      _rows = widget.initialTasks
          .map(
            (preview) => _TaskDraftEditor(
              title: preview.title,
              time: preview.time,
              description: '',
              kind: _scheduleTaskKind(preview.kind),
            ),
          )
          .toList(growable: true);
      return;
    }
    _rows = [
      _TaskDraftEditor(
        title: _defaultTaskTitle(ScheduleTaskKind.pumping),
        time: widget.defaultTime,
        description: '',
        kind: ScheduleTaskKind.pumping,
      ),
    ];
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _isValid => _rows.every(
    (row) =>
        row.title.text.trim().isNotEmpty &&
        _normalizedTime(row.time.text) != null,
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: RepaintBoundary(
          key: const ValueKey('schedule-add-task-sheet'),
          child: Material(
            color: MomCozyColors.card,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.dialogTitle ??
                              (widget.task == null ? '添加任务' : '编辑任务'),
                          style: const TextStyle(
                            color: MomCozyColors.foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('schedule-task-sheet-close'),
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    children: [
                      if (widget.initialTasks.isNotEmpty) ...[
                        Container(
                          key: const ValueKey(
                            'schedule-recognition-preview-notice',
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MomCozyColors.primary.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: MomCozyColors.primary.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                          child: const Text(
                            '以下内容仅为识别预览，请核对时间和任务名称；确认后才会写入计划。',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (var index = 0; index < _rows.length; index += 1) ...[
                        if (index > 0) const SizedBox(height: 12),
                        _buildTaskRow(index),
                      ],
                      if (widget.task == null && _rows.length < _maxRows) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const ValueKey('schedule-add-task-row-button'),
                          onPressed: _addRow,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(
                              color: MomCozyColors.border,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('手动添加一项'),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: MomCozyColors.card,
                    border: Border(
                      top: BorderSide(color: MomCozyColors.border),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: widget.task == null
                          ? const ValueKey('schedule-add-task-submit')
                          : const ValueKey('schedule-task-edit-save-button'),
                      onPressed: _isValid ? _submit : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        widget.submitLabel ??
                            (widget.task == null
                                ? '确认添加 (${_rows.length}项)'
                                : '保存'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(int index) {
    final row = _rows[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MomCozyColors.secondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MomCozyColors.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MomCozyColors.border),
                ),
                child: Text(
                  widget.task == null ? '任务 ${index + 1}' : '任务内容',
                  style: const TextStyle(
                    color: MomCozyColors.mutedForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.task == null && _rows.length > 1)
                IconButton(
                  key: ValueKey('schedule-remove-task-row-$index'),
                  tooltip: '删除这一项',
                  onPressed: () => _removeRow(index),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ScheduleTaskKind>(
              key: ValueKey('schedule-task-kind-$index'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ScheduleTaskKind.pumping,
                  icon: Icon(Icons.water_drop_outlined, size: 16),
                  label: Text('吸奶'),
                ),
                ButtonSegment(
                  value: ScheduleTaskKind.feeding,
                  icon: Icon(Icons.child_care_rounded, size: 16),
                  label: Text('喂养'),
                ),
                ButtonSegment(
                  value: ScheduleTaskKind.other,
                  icon: Icon(Icons.star_outline_rounded, size: 16),
                  label: Text('其他'),
                ),
              ],
              selected: {row.kind},
              onSelectionChanged: widget.task == null
                  ? (value) => _changeTaskKind(row, value.single)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: index == 0
                ? const ValueKey('schedule-add-task-title-input')
                : ValueKey('schedule-add-task-title-input-$index'),
            controller: row.title,
            onChanged: (_) => setState(() => _error = null),
            decoration: const InputDecoration(
              labelText: '任务名称',
              hintText: '例如：带娃打疫苗、哄睡',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 62,
                child: Text(
                  '计划时间',
                  style: TextStyle(
                    color: MomCozyColors.mutedForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  key: index == 0
                      ? const ValueKey('schedule-task-time-input')
                      : ValueKey('schedule-task-time-input-$index'),
                  onPressed: () => _pickTime(row),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    alignment: Alignment.centerLeft,
                    backgroundColor: MomCozyColors.card,
                    foregroundColor: MomCozyColors.foreground,
                  ),
                  child: Text(
                    row.time.text,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(_TaskDraftEditor row) async {
    final selected = await _showScheduleTimePicker(
      context,
      title: '设置计划时间',
      initialTime: row.time.text,
    );
    if (!mounted || selected == null) return;
    setState(() {
      row.time.text = selected;
      _error = null;
    });
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

class _ScheduleRecordSheet extends StatefulWidget {
  const _ScheduleRecordSheet({
    required this.kind,
    required this.volumeUnit,
    this.initialTime,
  });

  final ScheduleRecordKind kind;
  final MomCozyVolumeUnit volumeUnit;
  final String? initialTime;

  @override
  State<_ScheduleRecordSheet> createState() => _ScheduleRecordSheetState();
}

class _ScheduleRecordSheetState extends State<_ScheduleRecordSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _leftAmount = TextEditingController();
  final TextEditingController _rightAmount = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  late final TextEditingController _time = TextEditingController(
    text: widget.initialTime ?? '14:00',
  );
  String _feedType = 'formula';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _leftAmount.dispose();
    _rightAmount.dispose();
    _duration.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pumping = widget.kind == ScheduleRecordKind.pumping;
    final pumpingTotalMl = pumping ? _pumpingTotalMilliliters() : null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: RepaintBoundary(
          key: ValueKey(
            pumping
                ? 'schedule-pumping-record-sheet'
                : 'schedule-feeding-record-sheet',
          ),
          child: Material(
            color: MomCozyColors.card,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 10, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pumping ? '🤱 吸奶补录' : '+ 喂养记录',
                            style: const TextStyle(
                              color: MomCozyColors.foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('schedule-record-sheet-close'),
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                      children: [
                        if (pumping)
                          ..._buildPumpingFields(pumpingTotalMl)
                        else
                          ..._buildFeedingFields(),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            key: const ValueKey('schedule-form-error'),
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: MomCozyColors.card,
                      border: Border(
                        top: BorderSide(color: MomCozyColors.border),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('schedule-record-submit'),
                        onPressed: _canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '添加记录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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

  List<Widget> _buildPumpingFields(int? pumpingTotalMl) => [
    Container(
      key: const ValueKey('schedule-pumping-record-description'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MomCozyColors.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: '📝 吸奶补录是指'),
            TextSpan(
              text: '吸奶器未连接APP时或者通过其他方式',
              style: TextStyle(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: '获取的母乳，通过手动录入的方式计入可用母乳库存。'),
          ],
        ),
        style: const TextStyle(
          color: MomCozyColors.mutedForeground,
          fontSize: 11,
          height: 1.45,
        ),
      ),
    ),
    const SizedBox(height: 14),
    const _ScheduleRecordFieldLabel('开始吸奶时间'),
    const SizedBox(height: 5),
    TextField(
      key: const ValueKey('schedule-record-time-input'),
      controller: _time,
      keyboardType: TextInputType.datetime,
      onChanged: (_) => setState(() => _error = null),
      decoration: _fieldDecoration(hintText: '14:00'),
    ),
    const SizedBox(height: 12),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ScheduleRecordFieldLabel('吸奶量（左侧）'),
              const SizedBox(height: 5),
              _measurementInput(
                key: const ValueKey('schedule-record-left-amount-input'),
                controller: _leftAmount,
                autofocus: true,
                hintText: '0',
                unit: widget.volumeUnit.storageValue,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ScheduleRecordFieldLabel('吸奶量（右侧）'),
              const SizedBox(height: 5),
              _measurementInput(
                key: const ValueKey('schedule-record-right-amount-input'),
                controller: _rightAmount,
                hintText: '0',
                unit: widget.volumeUnit.storageValue,
              ),
            ],
          ),
        ),
      ],
    ),
    AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      child: pumpingTotalMl != null && pumpingTotalMl > 0
          ? Container(
              key: const ValueKey('schedule-record-pumping-total'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: MomCozyColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MomCozyColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                '总奶量：${_formatVolume(widget.volumeUnit, pumpingTotalMl)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MomCozyColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : const SizedBox.shrink(),
    ),
    const SizedBox(height: 12),
    const _ScheduleRecordFieldLabel('吸奶时长（选填）'),
    const SizedBox(height: 5),
    Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 170,
        child: _measurementInput(
          key: const ValueKey('schedule-record-duration-input'),
          controller: _duration,
          hintText: '例如 15',
          unit: 'min',
          decimal: false,
        ),
      ),
    ),
  ];

  List<Widget> _buildFeedingFields() => [
    Row(
      children: [
        _feedTypeButton(
          value: 'formula',
          label: '🧪 配方奶',
          accent: MomCozyColors.warm,
        ),
        const SizedBox(width: 8),
        _feedTypeButton(
          value: 'breast',
          label: '🤱 亲喂',
          accent: MomCozyColors.care,
        ),
        const SizedBox(width: 8),
        _feedTypeButton(
          value: 'bottle',
          label: '🍼 瓶喂母乳',
          accent: MomCozyColors.primary,
        ),
      ],
    ),
    const SizedBox(height: 14),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ScheduleRecordFieldLabel('喂养时间', compact: true),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('schedule-record-time-input'),
                controller: _time,
                keyboardType: TextInputType.datetime,
                onChanged: (_) => setState(() => _error = null),
                decoration: _fieldDecoration(hintText: '14:00', compact: true),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScheduleRecordFieldLabel(
                _feedType == 'breast'
                    ? '时长 (选填)'
                    : '${_feedType == 'formula' ? '配方奶量' : '瓶喂奶量'} (${widget.volumeUnit.storageValue})',
                compact: true,
              ),
              const SizedBox(height: 4),
              if (_feedType == 'breast')
                _measurementInput(
                  key: const ValueKey('schedule-record-duration-input'),
                  controller: _duration,
                  hintText: '15',
                  unit: 'min',
                  compact: true,
                )
              else
                TextField(
                  key: const ValueKey('schedule-record-amount-input'),
                  controller: _amount,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: _fieldDecoration(
                    hintText: widget.volumeUnit == MomCozyVolumeUnit.ounces
                        ? '3.5'
                        : '100',
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    if (_feedType == 'breast') ...[
      const SizedBox(height: 8),
      const Text(
        '🤱 亲喂时长可用于粗略估算奶量，不作为精确依据',
        style: TextStyle(
          color: MomCozyColors.mutedForeground,
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  ];

  Widget _feedTypeButton({
    required String value,
    required String label,
    required Color accent,
  }) {
    final selected = _feedType == value;
    return Expanded(
      child: SizedBox(
        height: 42,
        child: OutlinedButton(
          key: ValueKey('schedule-feed-type-$value'),
          onPressed: () {
            if (selected) return;
            setState(() {
              _feedType = value;
              _amount.clear();
              _duration.clear();
              _error = null;
            });
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: selected
                ? MomCozyColors.foreground
                : MomCozyColors.mutedForeground,
            backgroundColor: selected
                ? accent.withValues(alpha: 0.14)
                : MomCozyColors.muted.withValues(alpha: 0.5),
            side: BorderSide(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : MomCozyColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    );
  }

  Widget _measurementInput({
    required Key key,
    required TextEditingController controller,
    required String hintText,
    required String unit,
    bool autofocus = false,
    bool decimal = true,
    bool compact = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: key,
            controller: controller,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            onChanged: (_) => setState(() => _error = null),
            decoration: _fieldDecoration(hintText: hintText, compact: compact),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 24,
          child: Text(
            unit,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MomCozyColors.mutedForeground,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    bool compact = false,
  }) => InputDecoration(
    isDense: true,
    hintText: hintText,
    filled: true,
    fillColor: MomCozyColors.muted.withValues(alpha: 0.6),
    contentPadding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 12,
      vertical: compact ? 10 : 12,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: MomCozyColors.border.withValues(alpha: 0.5),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: MomCozyColors.primary.withValues(alpha: 0.5),
      ),
    ),
  );

  bool get _canSubmit {
    if (_normalizedTime(_time.text) == null) return false;
    if (widget.kind == ScheduleRecordKind.pumping) {
      final amountMl = _pumpingTotalMilliliters();
      return amountMl != null && amountMl > 0;
    }
    if (_feedType == 'breast') return true;
    final amountMl = _canonicalRequiredVolume(_amount.text);
    return amountMl != null && amountMl > 0;
  }

  void _submit() {
    final time = _normalizedTime(_time.text);
    final pumping = widget.kind == ScheduleRecordKind.pumping;
    final durationSeconds = pumping
        ? switch (int.tryParse(_duration.text.trim())) {
            final minutes? when minutes > 0 => minutes * 60,
            _ => null,
          }
        : switch (double.tryParse(_duration.text.trim())) {
            final minutes? when minutes > 0 => (minutes * 60).round(),
            _ => null,
          };
    final amountMl = pumping
        ? _pumpingTotalMilliliters()
        : _feedType == 'breast'
        ? null
        : _canonicalRequiredVolume(_amount.text);
    final requiresAmount = pumping || _feedType != 'breast';
    final validAmount = amountMl != null && amountMl > 0;
    if (time == null || (requiresAmount && !validAmount)) {
      setState(() => _error = requiresAmount ? '请填写有效的时间和奶量' : '请填写有效的时间');
      return;
    }
    Navigator.pop(
      context,
      _RecordDraft(
        amountMl: validAmount ? amountMl : null,
        durationSeconds: durationSeconds,
        time: time,
        feedType: _feedType,
      ),
    );
  }

  int? _pumpingTotalMilliliters() {
    final left = _canonicalOptionalVolume(_leftAmount.text);
    final right = _canonicalOptionalVolume(_rightAmount.text);
    if (left == null || right == null) return null;
    return left + right;
  }

  int? _canonicalOptionalVolume(String raw) {
    if (raw.trim().isEmpty) return 0;
    return _canonicalRequiredVolume(raw);
  }

  int? _canonicalRequiredVolume(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null) return null;
    return widget.volumeUnit.toCanonicalMilliliters(value);
  }
}

class _ScheduleRecordFieldLabel extends StatelessWidget {
  const _ScheduleRecordFieldLabel(this.label, {this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: compact ? 2 : 1,
      style: TextStyle(
        color: MomCozyColors.mutedForeground,
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w700,
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

class _ScheduleTaskProvenance {
  const _ScheduleTaskProvenance({
    required this.label,
    required this.agentGenerated,
  });

  final String label;
  final bool agentGenerated;
}

String _explanationPlanKind(SchedulePlanContext? context) {
  if (context == null) return 'unknown';
  final candidates = <Object?>[
    context.planType,
    context.payload['care_plan_type'],
    context.payload['carePlanType'],
    context.payload['goal_type'],
    context.payload['goalType'],
    context.payload['mode'],
    context.payload['strategy'],
    context.title,
  ];
  for (final candidate in candidates) {
    final value = candidate?.toString().trim().toLowerCase() ?? '';
    if (value == 'none' || value.contains('稳奶')) return 'none';
    if (value == 'maintain' || value.contains('维持')) return 'maintain';
    if (value == 'chase' || value.contains('追奶')) return 'chase';
    if (value == 'wean' || value.contains('减奶') || value.contains('离乳')) {
      return 'wean';
    }
    if (value == 'fertility' || value.contains('待产')) return 'fertility';
    if (value == 'work' || value.contains('返工')) return 'work';
  }
  return 'unknown';
}

String _explanationPlanLabel(String planKind, SchedulePlanContext? context) =>
    switch (planKind) {
      'none' => '稳奶计划',
      'maintain' => '维持奶量计划',
      'chase' => '追奶计划',
      'wean' => '温和离乳计划',
      'fertility' => '待产计划',
      'work' => '返工计划',
      _ =>
        _normalizedPlanBadgeLabel(context?.title ?? '').isEmpty
            ? '呵护计划'
            : _normalizedPlanBadgeLabel(context?.title ?? ''),
    };

String _explanationMethod(String planKind, String planLabel) =>
    switch (planKind) {
      'chase' => '追奶重点是增加有效移出机会，放在更容易坚持的时段。',
      'wean' => '减奶重点是循序减少频次或时长，避免突然停吸带来胀痛。',
      'none' || 'maintain' => '稳奶重点是稳定关键排乳窗口，避免过度加任务或过早减少。',
      'work' => '返工重点是保留关键排乳窗口，并适配通勤和工作空档。',
      'fertility' => '待产重点是按阶段排优先级，先处理必须确认的事项。',
      _ => '$planLabel重点是结合阶段、记录和执行负担，保证任务能执行。',
    };

_ScheduleTaskProvenance _taskProvenance(
  ScheduleTask task,
  SchedulePlanContext? context,
) {
  final source = (task.payload['source']?.toString() ?? '')
      .trim()
      .toLowerCase();
  final actionId = (task.payload['agent_action_id']?.toString() ?? '').trim();
  final agentGenerated =
      actionId.isNotEmpty ||
      source == 'agent_action' ||
      source == 'agent' ||
      source == 'mai' ||
      source == 'system';
  if (!agentGenerated) {
    return const _ScheduleTaskProvenance(label: '手动添加', agentGenerated: false);
  }
  final label = _normalizedPlanBadgeLabel(context?.title ?? '');
  return _ScheduleTaskProvenance(
    label: label.isEmpty ? '智能计划' : label,
    agentGenerated: true,
  );
}

String _normalizedPlanBadgeLabel(String value) {
  final label = value.trim();
  if (label.isEmpty) return '';
  if (label.contains('追奶')) return '追奶计划';
  if (label.contains('减奶') || label.contains('离乳')) return '减奶计划';
  if (label.contains('稳奶') || label.contains('维持')) return '稳奶计划';
  if (label.contains('待产')) return '待产计划';
  if (label.contains('返工')) return '返工计划';
  return label.endsWith('计划') ? label : '$label计划';
}

ScheduleTaskKind _scheduleTaskKind(ScheduleImageTaskKind kind) =>
    switch (kind) {
      ScheduleImageTaskKind.pumping => ScheduleTaskKind.pumping,
      ScheduleImageTaskKind.feeding => ScheduleTaskKind.feeding,
      ScheduleImageTaskKind.other => ScheduleTaskKind.other,
    };

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

String _linkedRecordSummary(
  ScheduleRecord record,
  MomCozyVolumeUnit volumeUnit,
) {
  final amount = record.amountMl == null
      ? ''
      : '${_formatVolume(volumeUnit, record.amountMl!)} · ';
  return '$amount${_time(record.occurredAt)} 完成';
}

String _formatVolume(MomCozyVolumeUnit unit, int milliliters) {
  return '${unit.formatMilliliters(milliliters.toDouble())} ${unit.storageValue}';
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
  final prefix = difference.isNegative || difference == Duration.zero
      ? '超时'
      : '还有';
  return '$prefix ${_countdownValue(at, now)}';
}

String _countdownValue(DateTime? at, DateTime now) {
  if (at == null) return '--';
  final difference = at.difference(now);
  final absolute = difference.isNegative || difference == Duration.zero
      ? now.difference(at)
      : difference;
  final days = absolute.inDays;
  final hours = absolute.inHours.remainder(24);
  final minutes = absolute.inMinutes.remainder(60);
  final seconds = absolute.inSeconds.remainder(60);
  if (days > 0) return '$days天$hours小时$minutes分$seconds秒';
  if (absolute.inHours > 0) {
    return '${absolute.inHours}小时$minutes分$seconds秒';
  }
  return '$minutes分$seconds秒';
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
