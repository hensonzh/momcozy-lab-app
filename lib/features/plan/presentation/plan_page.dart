import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_change_store.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/plan/presentation/plan_controller.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({
    super.key,
    required this.repository,
    this.now = DateTime.now,
    this.onCreatePlan,
    this.onOpenCalendar,
    this.onOpenAllPlans,
    this.onBackToPlans,
    this.onChat,
    this.onStartSession,
    this.onManualEdit,
    this.changeStore,
  });

  final PlanRepository repository;
  final DateTime Function() now;
  final VoidCallback? onCreatePlan;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenAllPlans;
  final VoidCallback? onBackToPlans;
  final VoidCallback? onChat;
  final VoidCallback? onStartSession;
  final VoidCallback? onManualEdit;
  final PlanChangeStore? changeStore;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late PlanController _controller;
  int _lastPlanRevision = -1;

  @override
  void initState() {
    super.initState();
    _createController();
    _attachChangeStore(widget.changeStore);
  }

  @override
  void didUpdateWidget(covariant PlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _controller.removeListener(_refresh);
      _controller.dispose();
      _createController();
    }
    if (!identical(oldWidget.changeStore, widget.changeStore)) {
      oldWidget.changeStore?.removeListener(_onPlanChange);
      _attachChangeStore(widget.changeStore);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    widget.changeStore?.removeListener(_onPlanChange);
    super.dispose();
  }

  void _createController() {
    _controller = PlanController(
      repository: widget.repository,
      initialWeek: widget.now(),
    )..addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _attachChangeStore(PlanChangeStore? store) {
    if (store == null) return;
    _lastPlanRevision = store.revision;
    store.addListener(_onPlanChange);
    unawaited(store.restore());
    store.markViewed();
  }

  void _onPlanChange() {
    final store = widget.changeStore;
    if (store == null || store.revision == _lastPlanRevision) return;
    _lastPlanRevision = store.revision;
    store.markViewed();
    unawaited(_controller.load());
  }

  Future<void> _openCalendar() async {
    final selectedDay = _controller.state.weekOf;
    final now = widget.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: 'Select plan date',
    );
    if (picked != null && mounted) {
      await _controller.selectDay(picked);
    }
  }

  void _openAllPlans() {
    final state = _controller.state;
    final plans = state.dashboard?.plans ?? const <CarePlan>[];
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: MomCozyV3Colors.background,
        showDragHandle: true,
        builder: (sheetContext) => _AllPlansSheet(
          plans: plans,
          selectedPlanId: state.selectedPlanId,
          onCreatePlan: widget.onCreatePlan,
          onSelectPlan: (planId) {
            _controller.selectPlan(planId);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  void _openManualEdit() {
    final state = _controller.state;
    final dashboard = state.dashboard;
    final plan = state.selectedPlan;
    if (dashboard == null || plan == null) return;
    final sessions = dashboard.sessionsFor(plan.id);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: MomCozyV3Colors.background,
        showDragHandle: true,
        builder: (context) => _PlanManualEditSheet(
          sessions: sessions,
          editingEnabled: _controller.canEditSessions,
          onSave:
              ({required sessionId, required title, required scheduledAt}) =>
                  _controller.updateSession(
                    sessionId: sessionId,
                    title: title,
                    scheduledAt: scheduledAt,
                  ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final dashboard = state.dashboard;
    return Material(
      key: const ValueKey('route-page-/plan'),
      color: MomCozyV3Colors.background,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: MomCozyTypography.interfaceFontFamily,
        ),
        child: switch (state.phase) {
          PlanLoadPhase.loading when dashboard == null => _PlanLoadingView(
            selectedDay: state.weekOf,
          ),
          PlanLoadPhase.error when dashboard == null => _PlanErrorView(
            onRetry: _controller.load,
          ),
          _ when dashboard != null && dashboard.isEmpty => _EmptyPlanView(
            selectedDay: state.weekOf,
            onCreatePlan: widget.onCreatePlan,
            onOpenCalendar: widget.onOpenCalendar ?? _openCalendar,
            onOpenAllPlans: widget.onOpenAllPlans ?? _openAllPlans,
            onSelectDay: _controller.selectDay,
            onChat: widget.onChat,
            onStartSession: widget.onStartSession,
          ),
          _ when dashboard != null && dashboard.isSinglePlan => _SinglePlanView(
            dashboard: dashboard,
            selectedDay: state.weekOf,
            onBackToPlans: widget.onBackToPlans ?? _openAllPlans,
            onOpenAllPlans: widget.onOpenAllPlans ?? _openAllPlans,
            onSelectDay: _controller.selectDay,
            onStartSession: widget.onStartSession,
            onAdjustWithAi: widget.onChat,
            onManualEdit: widget.onManualEdit ?? _openManualEdit,
          ),
          _ when dashboard != null => _MultiPlanView(
            dashboard: dashboard,
            selectedDay: state.weekOf,
            selectedPlan: state.selectedPlan!,
            period: state.period,
            onSelectPlan: _controller.selectPlan,
            onSelectPeriod: _controller.selectPeriod,
            onBrowseWeek: _controller.browseWeek,
            onOpenCalendar: widget.onOpenCalendar ?? _openCalendar,
            onOpenAllPlans: widget.onOpenAllPlans ?? _openAllPlans,
            onSelectDay: _controller.selectDay,
            onStartSession: widget.onStartSession,
          ),
          _ => _PlanErrorView(onRetry: _controller.load),
        },
      ),
    );
  }
}

class _PlanLoadingView extends StatelessWidget {
  const _PlanLoadingView({required this.selectedDay});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-loading-view'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
        children: [
          const _PlanHeader(),
          const SizedBox(height: 22),
          _PlanWeekStrip(selectedDay: selectedDay, compact: true),
          const SizedBox(height: 44),
          const Center(
            child: _PlanLoadingBlock(width: 140, height: 140, radius: 70),
          ),
          const SizedBox(height: 32),
          const Center(child: _PlanLoadingBlock(width: 150, height: 26)),
          const SizedBox(height: 12),
          const Center(child: _PlanLoadingBlock(width: 280, height: 14)),
          const SizedBox(height: 6),
          const Center(child: _PlanLoadingBlock(width: 220, height: 14)),
          const SizedBox(height: 24),
          const _PlanLoadingBlock(height: 48, radius: 24),
        ],
      ),
    );
  }
}

class _PlanLoadingBlock extends StatelessWidget {
  const _PlanLoadingBlock({
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff1e7e5),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _PlanErrorView extends StatelessWidget {
  const _PlanErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PlanHeader(),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: MomCozyV3Colors.brand,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Plans could not be loaded.',
                    style: _PlanText.sectionTitle,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlanView extends StatelessWidget {
  const _EmptyPlanView({
    required this.selectedDay,
    this.onCreatePlan,
    this.onOpenCalendar,
    this.onOpenAllPlans,
    this.onSelectDay,
    this.onChat,
    this.onStartSession,
  });

  final DateTime selectedDay;
  final VoidCallback? onCreatePlan;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenAllPlans;
  final ValueChanged<DateTime>? onSelectDay;
  final VoidCallback? onChat;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-empty-state'),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
        children: [
          _PlanHeader(
            calendarAsset: MomCozyAssets.planEmptyAction,
            onOpenCalendar: onOpenCalendar,
            onOpenAllPlans: onOpenAllPlans,
          ),
          const SizedBox(height: 22),
          _PlanWeekStrip(
            key: const ValueKey('plan-empty-week'),
            selectedDay: selectedDay,
            compact: true,
            onSelectDay: onSelectDay,
          ),
          const SizedBox(height: 44),
          const _EmptyPlanIllustration(
            key: ValueKey('plan-empty-illustration'),
          ),
          const SizedBox(height: 32),
          const Text(
            'No Plans Yet',
            textAlign: TextAlign.center,
            style: _PlanText.heroTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a personalized recovery plan to track your\npostpartum journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xffad938a),
              fontFamily: MomCozyTypography.interfaceFontFamily,
              fontSize: 14,
              height: 1.5,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          _PlanGradientButton(
            key: const ValueKey('plan-create-first-plan'),
            label: '+ Create Your First Plan',
            onPressed: onCreatePlan,
          ),
          const SizedBox(height: 13),
          const _ServiceHeader(),
          _ServiceCard(
            actionKey: const ValueKey('plan-service-recovery'),
            iconAsset: MomCozyAssets.planRecovery,
            title: 'Postpartum Recovery',
            subtitle: 'Postpartum recovery plan for body and mind',
            action: 'Start guide',
            height: 125,
            onTap: onCreatePlan,
          ),
          const SizedBox(height: 14),
          _ServiceCard(
            actionKey: const ValueKey('plan-service-pump'),
            iconAsset: MomCozyAssets.planPump,
            title: 'momcozy Smart Pump',
            subtitle: 'Connect your momcozy pump and track sessions',
            action: 'Check now',
            height: 125,
            onTap: onStartSession,
          ),
          const SizedBox(height: 14),
          _ServiceCard(
            actionKey: const ValueKey('plan-service-health'),
            iconAsset: MomCozyAssets.planHealth,
            title: 'Breast Health Check',
            subtitle: 'AI-powered breast health assessment',
            action: 'Check now',
            height: 111,
            onTap: onChat,
          ),
        ],
      ),
    );
  }
}

class _MultiPlanView extends StatelessWidget {
  const _MultiPlanView({
    required this.dashboard,
    required this.selectedDay,
    required this.selectedPlan,
    required this.period,
    required this.onSelectPlan,
    required this.onSelectPeriod,
    required this.onBrowseWeek,
    this.onSelectDay,
    this.onOpenCalendar,
    this.onOpenAllPlans,
    this.onStartSession,
  });

  final PlanDashboard dashboard;
  final DateTime selectedDay;
  final CarePlan selectedPlan;
  final PlanPeriod period;
  final ValueChanged<String> onSelectPlan;
  final ValueChanged<PlanPeriod> onSelectPeriod;
  final ValueChanged<int> onBrowseWeek;
  final ValueChanged<DateTime>? onSelectDay;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenAllPlans;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    final visibleSessions = dashboard.sessions
        .where((session) => _sameDay(session.scheduledAt, selectedDay))
        .toList(growable: false);
    final completed = dashboard.completedThisWeek;
    final total = math.max(1, dashboard.totalThisWeek);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-multi-category-state'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _PlanHeader(
            onOpenCalendar: onOpenCalendar,
            onOpenAllPlans: onOpenAllPlans,
          ),
          const SizedBox(height: 8),
          SizedBox(
            key: const ValueKey('plan-category-tabs'),
            height: 36,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < dashboard.plans.length;
                    index++
                  ) ...[
                    _PlanCategoryChip(
                      plan: dashboard.plans[index],
                      selected: dashboard.plans[index].id == selectedPlan.id,
                      onTap: () => onSelectPlan(dashboard.plans[index].id),
                    ),
                    if (index != dashboard.plans.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PeriodSelector(selected: period, onSelect: onSelectPeriod),
          SizedBox(key: ValueKey('plan-${period.name}-content'), height: 0),
          if (period == PlanPeriod.month) ...[
            const SizedBox(height: 12),
            _MonthlyCalendar(
              selectedDay: selectedDay,
              onSelectDay: onSelectDay,
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 4),
            _WeekRangeRow(
              selectedDay: selectedDay,
              onPrevious: () => onBrowseWeek(-1),
              onNext: () => onBrowseWeek(1),
            ),
            const SizedBox(height: 9),
            SizedBox(
              key: const ValueKey('plan-week-calendar'),
              height: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period == PlanPeriod.day ? 'Select Day' : 'This Week',
                    style: _PlanText.sectionTitle,
                  ),
                  const SizedBox(height: 5.6),
                  _PlanWeekStrip(
                    selectedDay: selectedDay,
                    onSelectDay: onSelectDay,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
          ],
          Text(
            period == PlanPeriod.month ? 'Selected Day' : 'Today',
            style: _PlanText.sectionTitle,
          ),
          const SizedBox(height: 7.6),
          if (visibleSessions.isEmpty)
            const _NoPlanSessionsCard(
              key: ValueKey('plan-no-sessions-selected-day'),
            ),
          for (var index = 0; index < visibleSessions.length; index++) ...[
            _PlanSessionCard(
              key: ValueKey('plan-session-${visibleSessions[index].id}'),
              session: visibleSessions[index],
              onStart: visibleSessions[index].status == PlanSessionStatus.next
                  ? onStartSession
                  : null,
            ),
            if (index != visibleSessions.length - 1) const SizedBox(height: 8),
          ],
          if (period == PlanPeriod.week) ...[
            const SizedBox(height: 16),
            const Text('This Week', style: _PlanText.sectionTitle),
            const SizedBox(height: 7.6),
            _WeekSummaryCard(
              completed: completed,
              total: total,
              onTap: () => _showWeekDetails(
                context,
                plan: selectedPlan,
                sessions: dashboard.sessionsFor(selectedPlan.id),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              key: ValueKey('plan-monthly-calendar-section'),
              height: 23.4,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Monthly Calendar', style: _PlanText.sectionTitle),
              ),
            ),
            const SizedBox(height: 12),
            _MonthlyCalendar(
              selectedDay: selectedDay,
              onSelectDay: onSelectDay,
            ),
          ],
        ],
      ),
    );
  }
}

class _SinglePlanView extends StatelessWidget {
  const _SinglePlanView({
    required this.dashboard,
    required this.selectedDay,
    this.onBackToPlans,
    this.onOpenAllPlans,
    this.onSelectDay,
    this.onStartSession,
    this.onAdjustWithAi,
    this.onManualEdit,
  });

  final PlanDashboard dashboard;
  final DateTime selectedDay;
  final VoidCallback? onBackToPlans;
  final VoidCallback? onOpenAllPlans;
  final ValueChanged<DateTime>? onSelectDay;
  final VoidCallback? onStartSession;
  final VoidCallback? onAdjustWithAi;
  final VoidCallback? onManualEdit;

  @override
  Widget build(BuildContext context) {
    final plan = dashboard.plans.single;
    final sessions = dashboard
        .sessionsFor(plan.id)
        .where((session) => _sameDay(session.scheduledAt, selectedDay))
        .toList(growable: false);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-single-category-state'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _SinglePlanHeader(
            title: plan.title,
            onBack: onBackToPlans,
            onEdit: onManualEdit,
            onOpenAllPlans: onOpenAllPlans,
          ),
          const SizedBox(height: 18),
          _MilestoneCard(plan: plan),
          const SizedBox(height: 16),
          _MilestoneWeekStrip(
            selectedDay: selectedDay,
            onSelectDay: onSelectDay,
          ),
          const SizedBox(height: 18),
          const Text("Today's Sessions", style: _PlanText.sectionTitle),
          const SizedBox(height: 5.6),
          if (sessions.isEmpty)
            const _NoPlanSessionsCard(
              key: ValueKey('plan-single-no-sessions-selected-day'),
            ),
          for (var index = 0; index < sessions.length; index++) ...[
            _SingleSessionCard(
              key: ValueKey('plan-single-session-${sessions[index].id}'),
              session: sessions[index],
              onStart: sessions[index].status == PlanSessionStatus.next
                  ? onStartSession
                  : null,
            ),
            if (index != sessions.length - 1)
              SizedBox(
                height: sessions[index].status == PlanSessionStatus.next
                    ? 8
                    : 10,
              ),
          ],
          const SizedBox(height: 18),
          const Text('Volume Progress', style: _PlanText.sectionTitle),
          const SizedBox(height: 7.6),
          _VolumeProgressCard(plan: plan),
          const SizedBox(height: 16),
          _PlanSettingsCard(
            plan: plan,
            onAdjustWithAi: onAdjustWithAi,
            onManualEdit: onManualEdit,
          ),
        ],
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    this.calendarAsset = MomCozyAssets.planCalendar,
    this.onOpenCalendar,
    this.onOpenAllPlans,
  });

  final String calendarAsset;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenAllPlans;

  @override
  Widget build(BuildContext context) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: 48,
      child: OverflowBox(
        minWidth: pageWidth,
        maxWidth: pageWidth,
        minHeight: 48,
        maxHeight: 48,
        alignment: Alignment.center,
        child: SizedBox(
          key: const ValueKey('plan-header'),
          width: pageWidth,
          height: 48,
          child: Stack(
            children: [
              const Positioned(
                left: 19,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text('My Plans', style: _PlanText.pageTitle),
                ),
              ),
              Positioned(
                right: 138.5,
                top: 2,
                child: _HeaderAssetButton(
                  key: const ValueKey('plan-header-calendar'),
                  asset: calendarAsset,
                  tooltip: 'Calendar',
                  onTap: onOpenCalendar,
                  width: 36,
                  height: 36,
                ),
              ),
              Positioned(
                right: 14,
                top: 2,
                child: _HeaderAssetButton(
                  key: const ValueKey('plan-header-all-plans'),
                  asset: MomCozyAssets.planAllPlans,
                  tooltip: 'All plans',
                  onTap: onOpenAllPlans,
                  width: 36,
                  height: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SinglePlanHeader extends StatelessWidget {
  const _SinglePlanHeader({
    required this.title,
    this.onBack,
    this.onEdit,
    this.onOpenAllPlans,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onOpenAllPlans;

  @override
  Widget build(BuildContext context) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      key: const ValueKey('plan-single-header'),
      height: 44,
      child: OverflowBox(
        minWidth: pageWidth,
        maxWidth: pageWidth,
        minHeight: 44,
        maxHeight: 44,
        alignment: Alignment.center,
        child: SizedBox(
          width: pageWidth,
          height: 44,
          child: Stack(
            children: [
              Positioned(
                left: 6,
                top: 0,
                child: _HeaderAssetButton(
                  key: const ValueKey('plan-single-back'),
                  asset: MomCozyAssets.planBack,
                  tooltip: 'Back to plans',
                  onTap: onBack,
                  width: 20,
                  height: 20,
                ),
              ),
              Positioned(
                left: 82,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _PlanText.headerTitle,
                  ),
                ),
              ),
              Positioned(
                left: 292,
                top: 0,
                child: _HeaderAssetButton(
                  key: const ValueKey('plan-single-edit'),
                  asset: MomCozyAssets.planEdit,
                  tooltip: 'Edit plan',
                  onTap: onEdit,
                  width: 20,
                  height: 20,
                ),
              ),
              Positioned(
                left: 332,
                top: 0,
                child: _HeaderAssetButton(
                  key: const ValueKey('plan-single-all-plans'),
                  asset: MomCozyAssets.planAllPlans,
                  tooltip: 'All plans',
                  onTap: onOpenAllPlans,
                  width: 36,
                  height: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAssetButton extends StatelessWidget {
  const _HeaderAssetButton({
    super.key,
    required this.asset,
    required this.tooltip,
    required this.width,
    required this.height,
    this.onTap,
  });

  final String asset;
  final String tooltip;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: SvgPicture.asset(asset, width: width, height: height),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanWeekStrip extends StatelessWidget {
  const _PlanWeekStrip({
    super.key,
    required this.selectedDay,
    this.compact = false,
    this.onSelectDay,
  });

  final DateTime selectedDay;
  final bool compact;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final week = _weekDays(selectedDay);
    final dayWidth = compact ? 40.0 : 44.0;
    final gap = compact ? 12.0 : 8.0;
    final stripWidth = dayWidth * 7 + gap * 6;
    return SizedBox(
      height: 51,
      child: OverflowBox(
        alignment: compact ? Alignment.centerLeft : Alignment.center,
        minWidth: stripWidth,
        maxWidth: stripWidth,
        child: SizedBox(
          width: stripWidth,
          child: Row(
            children: [
              for (var index = 0; index < week.length; index++) ...[
                SizedBox(
                  width: dayWidth,
                  child: _PlanDay(
                    day: week[index],
                    selected: _sameDay(week[index], selectedDay),
                    showDot: !compact,
                    showFullWeekday: compact,
                    onTap: onSelectDay == null
                        ? null
                        : () => onSelectDay!(week[index]),
                  ),
                ),
                if (index != week.length - 1) SizedBox(width: gap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanDay extends StatelessWidget {
  const _PlanDay({
    required this.day,
    required this.selected,
    required this.showDot,
    required this.showFullWeekday,
    this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool showDot;
  final bool showFullWeekday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : MomCozyV3Colors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_weekdayLong(day.weekday)}, ${_monthLong(day.month)} ${day.day}',
      child: GestureDetector(
        key: ValueKey('plan-week-day-${_dateKey(day)}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 51,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? null : Colors.transparent,
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xff7a2840), Color(0xffbd5178)],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Text(
                  showFullWeekday
                      ? _weekdayLong(day.weekday)
                      : _weekday(day.weekday),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xff9e8880),
                    fontFamily: MomCozyTypography.interfaceFontFamily,
                    fontSize: showFullWeekday ? 12 : 14,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 21,
                child: Text(
                  '${day.day}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontFamily: MomCozyTypography.interfaceFontFamily,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showDot)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : _dayDotColor(day),
                        shape: BoxShape.circle,
                      ),
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

class _EmptyPlanIllustration extends StatelessWidget {
  const _EmptyPlanIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: SizedBox(
          width: 170,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 2,
                top: 0,
                child: _softCircle(96, const Color(0x55d4a4b2)),
              ),
              Positioned(
                right: 18,
                top: 54,
                child: _softCircle(72, const Color(0x55d4a4b2)),
              ),
              Positioned(
                left: 45,
                bottom: 0,
                child: _softCircle(48, const Color(0x55d4a4b2)),
              ),
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xfff9ecef),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22a94d6d),
                      blurRadius: 18,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    MomCozyAssets.planSparkles,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _softCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [color.withValues(alpha: 0.78), color.withValues(alpha: 0.34)],
      ),
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(color: Color(0x18a94d6d), blurRadius: 20, spreadRadius: 4),
      ],
    ),
  );
}

class _PlanGradientButton extends StatelessWidget {
  const _PlanGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          gradient: LinearGradient(
            colors: [Color(0xff7a2840), Color(0xffbd5178)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x247a2840),
              blurRadius: 20,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(child: Text(label, style: _PlanText.primaryButton)),
          ),
        ),
      ),
    );
  }
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 101,
      child: OverflowBox(
        minHeight: 104,
        maxHeight: 104,
        alignment: Alignment.topCenter,
        child: SizedBox(
          key: const ValueKey('plan-service-header'),
          height: 104,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service', style: _PlanText.serviceTitle),
                    Text('Cozymate 1 on 1', style: _PlanText.serviceLabel),
                    Text(
                      'Your AI wellness companion',
                      style: _PlanText.caption,
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 0,
                top: 3,
                child: _PlanAvatar(
                  key: ValueKey('plan-service-avatar'),
                  radius: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.actionKey,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.height,
    this.onTap,
  });

  final Key actionKey;
  final String iconAsset;
  final String title;
  final String subtitle;
  final String action;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: actionKey,
      height: height,
      child: DecoratedBox(
        decoration: _serviceCardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xfff5ecea),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: SvgPicture.asset(iconAsset, width: 25, height: 25),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: _PlanText.cardTitle),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: title == 'Breast Health Check' ? 1 : 2,
                          softWrap: title != 'Breast Health Check',
                          overflow: TextOverflow.ellipsis,
                          style: _PlanText.cardBody.copyWith(
                            fontSize: title == 'Breast Health Check' ? 13 : 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _PlanPillButton(
                          label: action,
                          onPressed: onTap,
                          width: action.startsWith('Start guide') ? 122 : 110,
                          height: 32,
                          trailingArrow: true,
                        ),
                      ],
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

class _PlanPillButton extends StatelessWidget {
  const _PlanPillButton({
    required this.label,
    required this.onPressed,
    required this.height,
    this.width,
    this.trailingArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double? width;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: MomCozyV3Colors.ink,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width == null ? 10 : 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: _PlanText.pillButton),
                  if (trailingArrow) ...[
                    const SizedBox(width: 3),
                    SvgPicture.asset(
                      MomCozyAssets.planActionArrow,
                      width: 16,
                      height: 16,
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

class _PlanAvatar extends StatelessWidget {
  const _PlanAvatar({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xffeadbd7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26392832),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(MomCozyAssets.planCozymateAvatar, fit: BoxFit.cover),
      ),
    );
  }
}

class _PlanCategoryChip extends StatelessWidget {
  const _PlanCategoryChip({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final CarePlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: switch (plan.category) {
            PlanCategory.lactation => 84,
            PlanCategory.yoga => 58,
            PlanCategory.pelvicFloor => 97,
            PlanCategory.other => null,
          },
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? MomCozyV3Colors.brand : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: plan.category == PlanCategory.yoga
                  ? Colors.white
                  : const Color(0xffe8dcda),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              plan.category == PlanCategory.other
                  ? plan.title
                  : plan.category.label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xff9e8880),
                fontFamily: MomCozyTypography.interfaceFontFamily,
                fontSize: 13,
                height: 1.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelect});

  final PlanPeriod selected;
  final ValueChanged<PlanPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plan-period-selector'),
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xfff2e9e6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xffe4d4d0)),
      ),
      child: Row(
        children: [
          _PeriodChip(
            period: PlanPeriod.day,
            label: 'Day',
            width: 51,
            selected: selected == PlanPeriod.day,
            onTap: onSelect,
          ),
          _PeriodChip(
            period: PlanPeriod.week,
            label: 'Week',
            width: 58,
            selected: selected == PlanPeriod.week,
            onTap: onSelect,
          ),
          _PeriodChip(
            period: PlanPeriod.month,
            label: 'Month',
            width: 62,
            selected: selected == PlanPeriod.month,
            onTap: onSelect,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.period,
    required this.label,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final PlanPeriod period;
  final String label;
  final double width;
  final bool selected;
  final ValueChanged<PlanPeriod> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: ValueKey('plan-period-${period.name}'),
          onTap: () => onTap(period),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            key: selected
                ? ValueKey('plan-period-${period.name}-selected')
                : null,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? MomCozyV3Colors.brand : Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xff9d8981),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekRangeRow extends StatelessWidget {
  const _WeekRangeRow({
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final days = _weekDays(selectedDay);
    return SizedBox(
      key: const ValueKey('plan-week-range'),
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WeekArrowButton(tooltip: 'Previous week', onPressed: onPrevious),
          Text(
            '${_monthShort(days.first.month)} ${days.first.day} - ${_monthShort(days.last.month)} ${days.last.day}',
            style: _PlanText.weekRange,
          ),
          _WeekArrowButton(tooltip: 'Next week', onPressed: onNext),
        ],
      ),
    );
  }
}

class _WeekArrowButton extends StatelessWidget {
  const _WeekArrowButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 24,
          height: 32,
          child: Align(
            alignment: tooltip == 'Previous week'
                ? Alignment.centerLeft
                : Alignment.center,
            child: SvgPicture.asset(
              MomCozyAssets.planChevronRight,
              width: 16,
              height: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPlanSessionsCard extends StatelessWidget {
  const _NoPlanSessionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      alignment: Alignment.center,
      decoration: _flatCardDecoration(radius: 18, showBorder: true),
      child: const Text(
        'No sessions scheduled for this day.',
        style: _PlanText.body,
      ),
    );
  }
}

class _PlanSessionCard extends StatelessWidget {
  const _PlanSessionCard({super.key, required this.session, this.onStart});

  final PlanSession session;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final next = session.status == PlanSessionStatus.next;
    final muted = session.status == PlanSessionStatus.upcoming;
    return Opacity(
      opacity: muted ? 0.6 : 1,
      child: SizedBox(
        height: 59,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: next ? const Color(0xfff5ecea) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: next ? MomCozyV3Colors.brand : const Color(0xffe8dcda),
              width: next ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _time(session.scheduledAt),
                      style: TextStyle(
                        color: next
                            ? MomCozyV3Colors.brand
                            : MomCozyV3Colors.ink,
                        fontFamily: MomCozyTypography.interfaceFontFamily,
                        fontSize: 14,
                        height: 1.3,
                        letterSpacing: -0.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: next
                            ? MomCozyV3Colors.brand
                            : const Color(0xff9e8880),
                        fontFamily: MomCozyTypography.interfaceFontFamily,
                        fontSize: 13,
                        height: 1.3,
                        letterSpacing: -0.05,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              switch (session.status) {
                PlanSessionStatus.completed => const _StatusBadge(
                  label: 'Completed',
                  foreground: Color(0xff42b883),
                  background: Color(0xffebf9f4),
                ),
                PlanSessionStatus.next => _StartButton(onPressed: onStart),
                PlanSessionStatus.upcoming => const _StatusBadge(
                  label: 'Upcoming',
                  foreground: MomCozyV3Colors.brand,
                  background: Color(0xfff5ecea),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 26,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(52, 26),
          backgroundColor: MomCozyV3Colors.brand,
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Start',
          style: TextStyle(
            fontFamily: MomCozyTypography.interfaceFontFamily,
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: label == 'Completed' ? 86 : 81,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontFamily: MomCozyTypography.interfaceFontFamily,
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard({
    required this.completed,
    required this.total,
    this.onTap,
  });

  final int completed;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = (completed / total).clamp(0.0, 1.0);
    return SizedBox(
      key: const ValueKey('plan-week-summary'),
      height: 94,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('plan-week-details-action'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 17, 16, 0),
            decoration: _flatCardDecoration(radius: 22, showBorder: true),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$completed of $total sessions completed',
                        style: _PlanText.summaryLabel,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: MomCozyV3Colors.brand,
                        fontFamily: MomCozyTypography.interfaceFontFamily,
                        fontSize: 14,
                        height: 1.3,
                        letterSpacing: -0.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress * 0.9333333333,
                    color: MomCozyV3Colors.brand,
                    backgroundColor: const Color(0xfff5ecea),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'View week details',
                        style: _PlanText.summaryLink,
                      ),
                    ),
                    SvgPicture.asset(
                      MomCozyAssets.planChevronRight,
                      width: 16,
                      height: 16,
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

class _AllPlansSheet extends StatelessWidget {
  const _AllPlansSheet({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelectPlan,
    this.onCreatePlan,
  });

  final List<CarePlan> plans;
  final String? selectedPlanId;
  final ValueChanged<String> onSelectPlan;
  final VoidCallback? onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final height = math.min(MediaQuery.sizeOf(context).height * 0.7, 540.0);
    return SafeArea(
      child: SizedBox(
        key: const ValueKey('plan-all-plans-sheet'),
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('All Plans', style: _PlanText.sectionTitle),
              const SizedBox(height: 6),
              const Text(
                'Choose a plan to view its schedule and progress.',
                style: _PlanText.body,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: plans.isEmpty
                    ? const Center(
                        child: Text(
                          'No active plans yet.',
                          style: _PlanText.body,
                        ),
                      )
                    : ListView.separated(
                        itemCount: plans.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          final selected = plan.id == selectedPlanId;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              key: ValueKey('plan-all-plans-${plan.id}'),
                              onTap: () => onSelectPlan(plan.id),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? MomCozyV3Colors.brand
                                        : const Color(0xffe8dcda),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plan.title,
                                            style: _PlanText.cardTitle,
                                          ),
                                          if (plan.summary.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              plan.summary,
                                              style: _PlanText.body,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: MomCozyV3Colors.brand,
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xff9e8880),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (onCreatePlan != null) ...[
                const SizedBox(height: 12),
                _PlanGradientButton(
                  label: '+ Create a New Plan',
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCreatePlan!();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanManualEditSheet extends StatefulWidget {
  const _PlanManualEditSheet({
    required this.sessions,
    required this.editingEnabled,
    required this.onSave,
  });

  final List<PlanSession> sessions;
  final bool editingEnabled;
  final Future<void> Function({
    required String sessionId,
    required String title,
    required DateTime scheduledAt,
  })
  onSave;

  @override
  State<_PlanManualEditSheet> createState() => _PlanManualEditSheetState();
}

class _PlanManualEditSheetState extends State<_PlanManualEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _timeController;
  PlanSession? _selectedSession;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSession = _preferredSession(widget.sessions);
    _titleController = TextEditingController(
      text: _selectedSession?.title ?? '',
    );
    _timeController = TextEditingController(
      text: _selectedSession == null
          ? ''
          : _twentyFourHourTime(_selectedSession!.scheduledAt),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _selectSession(String? sessionId) {
    if (sessionId == null) return;
    final session = widget.sessions.firstWhere(
      (candidate) => candidate.id == sessionId,
    );
    setState(() {
      _selectedSession = session;
      _titleController.text = session.title;
      _timeController.text = _twentyFourHourTime(session.scheduledAt);
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    final session = _selectedSession;
    if (session == null ||
        !widget.editingEnabled ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final time = _parsePlanTime(_timeController.text)!;
    final scheduledAt = DateTime(
      session.scheduledAt.year,
      session.scheduledAt.month,
      session.scheduledAt.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSave(
        sessionId: session.id,
        title: _titleController.text.trim(),
        scheduledAt: scheduledAt,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Changes could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _selectedSession;
    return SafeArea(
      child: AnimatedPadding(
        key: const ValueKey('plan-manual-edit-sheet'),
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Plan Session', style: _PlanText.sectionTitle),
                const SizedBox(height: 6),
                const Text(
                  'Update one session at a time. Plan targets and frequency stay unchanged.',
                  style: _PlanText.body,
                ),
                const SizedBox(height: 18),
                if (session == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No sessions are available to edit on this day.',
                        style: _PlanText.body,
                      ),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    key: const ValueKey('plan-manual-edit-session'),
                    initialValue: session.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Session',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final option in widget.sessions)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(
                            '${option.title} · ${_time(option.scheduledAt)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving ? null : _selectSession,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('plan-manual-edit-title'),
                    controller: _titleController,
                    enabled: widget.editingEnabled && !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'Session title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a session title.'
                        : null,
                  ),
                  const SizedBox(height: 2),
                  TextFormField(
                    key: const ValueKey('plan-manual-edit-time'),
                    controller: _timeController,
                    enabled: widget.editingEnabled && !_saving,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Time (24-hour)',
                      hintText: '09:30',
                      helperText:
                          '${_monthLong(session.scheduledAt.month)} ${session.scheduledAt.day}',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => _parsePlanTime(value ?? '') == null
                        ? 'Use a valid 24-hour time, such as 09:30.'
                        : null,
                  ),
                  if (!widget.editingEnabled) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Editing is unavailable for this Plan data source.',
                      style: TextStyle(color: MomCozyV3Colors.brand),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: MomCozyV3Colors.brand),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('plan-manual-edit-save'),
                      onPressed: widget.editingEnabled && !_saving
                          ? _save
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: MomCozyV3Colors.brand,
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

PlanSession? _preferredSession(List<PlanSession> sessions) {
  for (final session in sessions) {
    if (session.status == PlanSessionStatus.next) return session;
  }
  return sessions.firstOrNull;
}

Future<void> _showWeekDetails(
  BuildContext context, {
  required CarePlan plan,
  required List<PlanSession> sessions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MomCozyV3Colors.background,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        key: const ValueKey('plan-week-details-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plan.category.label} Week Details',
              style: _PlanText.sectionTitle,
            ),
            const SizedBox(height: 6),
            Text(plan.summary, style: _PlanText.body),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No sessions scheduled for this plan.',
                    style: _PlanText.body,
                  ),
                ),
              )
            else
              for (final session in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xffe8dcda)),
                    ),
                    title: Text(session.title, style: _PlanText.cardTitle),
                    subtitle: Text(
                      '${_monthShort(session.scheduledAt.month)} ${session.scheduledAt.day} · ${_time(session.scheduledAt)}',
                      style: _PlanText.body,
                    ),
                    trailing: Text(switch (session.status) {
                      PlanSessionStatus.completed => 'Completed',
                      PlanSessionStatus.next => 'Next',
                      PlanSessionStatus.upcoming => 'Upcoming',
                    }, style: _PlanText.summaryLabel),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class _MonthlyCalendar extends StatelessWidget {
  const _MonthlyCalendar({required this.selectedDay, this.onSelectDay});

  final DateTime selectedDay;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selectedDay.year, selectedDay.month);
    final count = DateTime(selectedDay.year, selectedDay.month + 1, 0).day;
    final leading = first.weekday - 1;
    return Container(
      key: const ValueKey('plan-monthly-calendar'),
      padding: const EdgeInsets.all(16),
      decoration: _flatCardDecoration(radius: 20, showBorder: true),
      child: Column(
        children: [
          Text(
            '${_monthLong(selectedDay.month)} ${selectedDay.year}',
            style: _PlanText.cardTitle,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _PlanText.caption,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 34,
            ),
            itemCount: leading + count,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              final selected = day == selectedDay.day;
              final date = DateTime(selectedDay.year, selectedDay.month, day);
              return Center(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: '${_monthLong(date.month)} ${date.day}',
                  child: GestureDetector(
                    key: ValueKey('plan-month-day-${_dateKey(date)}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onSelectDay == null
                        ? null
                        : () => onSelectDay!(date),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? MomCozyV3Colors.brand : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: selected ? Colors.white : MomCozyV3Colors.ink,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      key: const ValueKey('plan-milestone-card'),
      height: 112,
      padding: const EdgeInsets.all(16),
      decoration: _flatCardDecoration(radius: 20),
      child: Row(
        children: [
          SizedBox(
            key: const ValueKey('plan-milestone-ring'),
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MilestoneRingPainter(
                      progress: plan.weekNumber / math.max(1, plan.totalWeeks),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Week',
                        style: TextStyle(
                          color: MomCozyV3Colors.ink,
                          fontFamily: MomCozyTypography.interfaceFontFamily,
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${plan.weekNumber}/${plan.totalWeeks}',
                        style: const TextStyle(
                          color: MomCozyV3Colors.brand,
                          fontFamily: MomCozyTypography.interfaceFontFamily,
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, compact ? 0 : 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mid-Way Milestone',
                    style: _PlanText.cardTitle.copyWith(letterSpacing: 0.1),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    "You've consistently completed ${plan.sessionsPerDay} sessions a day this week. Keep it up!",
                    style: _PlanText.body.copyWith(
                      fontSize: compact ? 13 : 14,
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRingPainter extends CustomPainter {
  const _MilestoneRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 3;
    final track = Paint()
      ..color = const Color(0xffe8dcda)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final progressPaint = Paint()
      ..color = MomCozyV3Colors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MilestoneRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MilestoneWeekStrip extends StatelessWidget {
  const _MilestoneWeekStrip({required this.selectedDay, this.onSelectDay});

  final DateTime selectedDay;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final days = _weekDays(selectedDay);
    return Container(
      key: const ValueKey('plan-milestone-week'),
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      decoration: _flatCardDecoration(radius: 18),
      child: Row(
        children: [
          for (var index = 0; index < days.length; index += 1)
            Expanded(
              child: Semantics(
                button: true,
                selected: _sameDay(days[index], selectedDay),
                label:
                    '${_weekdayLong(days[index].weekday)}, ${_monthLong(days[index].month)} ${days[index].day}',
                child: GestureDetector(
                  key: ValueKey('plan-milestone-day-${_dateKey(days[index])}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelectDay == null
                      ? null
                      : () => onSelectDay!(days[index]),
                  child: Column(
                    children: [
                      Text(
                        _weekday(days[index].weekday),
                        style: _PlanText.caption,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: index < 2
                              ? MomCozyV3Colors.brand
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: index < 2
                                ? MomCozyV3Colors.brand
                                : const Color(0xffe7d9d5),
                            width: 2,
                          ),
                        ),
                        child: index < 2
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SingleSessionCard extends StatelessWidget {
  const _SingleSessionCard({super.key, required this.session, this.onStart});

  final PlanSession session;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final completed = session.status == PlanSessionStatus.completed;
    final next = session.status == PlanSessionStatus.next;
    final iconAsset = completed
        ? MomCozyAssets.planDroplet
        : next
        ? MomCozyAssets.planPlay
        : MomCozyAssets.planClock;
    final columnOffset = completed
        ? 0.0
        : next
        ? 1.0
        : 4.0;
    return Opacity(
      opacity: completed || next ? 1 : 0.6,
      child: SizedBox(
        height: next ? 61 : 59,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: next ? const Color(0xfff5ecea) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: next ? MomCozyV3Colors.brand : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xfff5ecea),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    iconAsset,
                    width: completed || !next ? 15 : 14,
                    height: completed || !next ? 15 : 14,
                    colorFilter: !next && !completed
                        ? const ColorFilter.mode(
                            Color(0xff9e8880),
                            BlendMode.srcIn,
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(width: next ? 12 : 10),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, columnOffset),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: TextStyle(
                          color: next
                              ? MomCozyV3Colors.brand
                              : MomCozyV3Colors.ink,
                          fontFamily: MomCozyTypography.interfaceFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${completed
                            ? 'Completed'
                            : next
                            ? 'Next Up'
                            : 'Upcoming'} · ${_time(session.scheduledAt)}',
                        style:
                            const TextStyle(
                              color: Color(0xff9e8880),
                              fontFamily: MomCozyTypography.interfaceFontFamily,
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ).copyWith(
                              color: next
                                  ? MomCozyV3Colors.brand
                                  : const Color(0xff9e8880),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (completed) ...[
                Text(
                  session.valueLabel ?? '',
                  style: const TextStyle(
                    color: Color(0xff42b883),
                    fontFamily: MomCozyTypography.interfaceFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                SvgPicture.asset(
                  MomCozyAssets.planCheckCircle,
                  width: 16,
                  height: 16,
                ),
              ] else if (next)
                _StartButton(onPressed: onStart),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeProgressCard extends StatelessWidget {
  const _VolumeProgressCard({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plan-volume-progress'),
      height: 108,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
      decoration: _flatCardDecoration(radius: 20),
      child: Column(
        children: [
          _VolumeProgressRow(
            label: "Today's Target",
            value: '${plan.todayVolumeMl} / ${plan.dailyTargetVolumeMl} ml',
            progress:
                plan.todayVolumeMl / math.max(1, plan.dailyTargetVolumeMl),
          ),
          const Divider(height: 22, color: Color(0xffe8dcda)),
          _VolumeProgressRow(
            label: 'Weekly Target',
            value:
                '${_thousands(plan.weeklyVolumeMl)} / ${_thousands(plan.weeklyTargetVolumeMl)} ml',
            progress:
                plan.weeklyVolumeMl / math.max(1, plan.weeklyTargetVolumeMl),
          ),
        ],
      ),
    );
  }
}

class _VolumeProgressRow extends StatelessWidget {
  const _VolumeProgressRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Transform.translate(
                offset: Offset(label == 'Weekly Target' ? -1 : -3, 2),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: MomCozyV3Colors.ink,
                    fontFamily: MomCozyTypography.interfaceFontFamily,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, 3),
              child: Text(
                value,
                style: const TextStyle(
                  color: MomCozyV3Colors.brand,
                  fontFamily: MomCozyTypography.interfaceFontFamily,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: (progress * 0.98).clamp(0.0, 1.0),
            color: MomCozyV3Colors.brand,
            backgroundColor: const Color(0xfff5ecea),
          ),
        ),
      ],
    );
  }
}

class _PlanSettingsCard extends StatelessWidget {
  const _PlanSettingsCard({
    required this.plan,
    this.onAdjustWithAi,
    this.onManualEdit,
  });

  final CarePlan plan;
  final VoidCallback? onAdjustWithAi;
  final VoidCallback? onManualEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plan-settings'),
      height: 221,
      decoration: _flatCardDecoration(radius: 20, showBorder: true),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              width: 124,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xfff0ebff),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Transform.translate(
                offset: const Offset(-1, 0),
                child: const Text(
                  'AI Coach Available',
                  style: TextStyle(
                    color: Color(0xff8c73f0),
                    fontFamily: MomCozyTypography.interfaceFontFamily,
                    fontSize: 12,
                    height: 1,
                    letterSpacing: -0.075,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 15,
            top: 48,
            child: Text('Plan Settings', style: _PlanText.cardTitle),
          ),
          Positioned(
            left: 15,
            right: 15,
            top: 77,
            height: 21,
            child: _SettingRow(
              label: 'Sessions per day',
              value: '${plan.sessionsPerDay} sessions',
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            top: 105,
            height: 21,
            child: _SettingRow(
              label: 'Daily Target Volume',
              value: '${plan.dailyTargetVolumeMl} ml',
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            top: 135,
            child: Divider(height: 1, color: Color(0xffe8dcda)),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 143,
            height: 36,
            child: Material(
              color: MomCozyV3Colors.brand,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onAdjustWithAi,
                child: const Center(
                  child: Text(
                    'Adjust with AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: MomCozyTypography.interfaceFontFamily,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 100,
            right: 100,
            top: 184,
            height: 28,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onManualEdit,
                borderRadius: BorderRadius.circular(8),
                child: const Center(
                  child: Text(
                    'Manual Edit',
                    style: TextStyle(
                      color: MomCozyV3Colors.brand,
                      fontFamily: MomCozyTypography.interfaceFontFamily,
                      fontSize: 13,
                      height: 1.2,
                      letterSpacing: -0.3,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: _PlanText.settingsLabel)),
        Text(value, style: _PlanText.settingsValue),
      ],
    );
  }
}

class _PlanText {
  const _PlanText._();

  static const pageTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.displayFontFamily,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w700,
  );
  static const heroTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 24,
    height: 1.3,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w700,
  );
  static const headerTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 18,
    height: 1.3,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w700,
  );
  static const sectionTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 18,
    height: 1.3,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w700,
  );
  static const cardTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 16,
    height: 1.3,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w700,
  );
  static const cardBody = TextStyle(
    color: Color(0xff9e8880),
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 14,
    height: 1.2,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w400,
  );
  static const body = TextStyle(
    color: Color(0xffad938a),
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const caption = TextStyle(
    color: Color(0xffa58f87),
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const serviceLabel = TextStyle(
    color: MomCozyV3Colors.brand,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const serviceTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const weekRange = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 13,
    height: 1.3,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w700,
  );
  static const summaryLabel = TextStyle(
    color: Color(0xff9e8880),
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 13,
    height: 1.3,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w400,
  );
  static const summaryLink = TextStyle(
    color: Color(0xff4a3a38),
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 13,
    height: 1.3,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w400,
  );
  static const settingsLabel = TextStyle(
    color: Color(0xff9e8880),
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 13,
    height: 1.5,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w400,
  );
  static const settingsValue = TextStyle(
    color: MomCozyV3Colors.ink,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const primaryButton = TextStyle(
    color: Colors.white,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const pillButton = TextStyle(
    color: Colors.white,
    fontFamily: MomCozyTypography.interfaceFontFamily,
    fontSize: 13,
    height: 1,
    fontWeight: FontWeight.w700,
  );
}

BoxDecoration _flatCardDecoration({
  required double radius,
  bool showBorder = false,
}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: showBorder ? Border.all(color: const Color(0xffe8dcda)) : null,
);

BoxDecoration _serviceCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xfff0e8e6)),
  boxShadow: const [
    BoxShadow(color: Color(0x10392832), blurRadius: 24, offset: Offset(0, 7)),
  ],
);

List<DateTime> _weekDays(DateTime selectedDay) {
  final first = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
  return [
    for (var index = 0; index < 7; index += 1) first.add(Duration(days: index)),
  ];
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _weekday(int weekday) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

String _weekdayLong(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

Color _dayDotColor(DateTime day) => const [
  Color(0xff8a233f),
  Color(0xff7d65d6),
  Color(0xff40b985),
  Color(0xff8066ef),
  Color(0xff8a233f),
  Color(0xff40b985),
  Color(0xff8a233f),
][day.weekday - 1];

String _monthShort(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

String _monthLong(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _time(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

String _twentyFourHourTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parsePlanTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _thousands(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  return '${digits.substring(0, digits.length - 3)},${digits.substring(digits.length - 3)}';
}
