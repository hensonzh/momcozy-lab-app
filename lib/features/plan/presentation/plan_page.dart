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

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final dashboard = state.dashboard;
    return Material(
      key: const ValueKey('route-page-/plan'),
      color: MomCozyV3Colors.background,
      child: switch (state.phase) {
        PlanLoadPhase.loading when dashboard == null =>
          const _PlanLoadingView(),
        PlanLoadPhase.error when dashboard == null => _PlanErrorView(
          onRetry: _controller.load,
        ),
        PlanLoadPhase.empty => _EmptyPlanView(
          selectedDay: state.weekOf,
          onCreatePlan: widget.onCreatePlan,
          onOpenCalendar: widget.onOpenCalendar,
          onOpenAllPlans: widget.onOpenAllPlans,
          onChat: widget.onChat,
          onStartSession: widget.onStartSession,
        ),
        _ when dashboard != null && dashboard.isSinglePlan => _SinglePlanView(
          dashboard: dashboard,
          onBackToPlans: widget.onBackToPlans,
          onOpenAllPlans: widget.onOpenAllPlans,
          onStartSession: widget.onStartSession,
          onAdjustWithAi: widget.onChat,
          onManualEdit: widget.onManualEdit,
        ),
        _ when dashboard != null => _MultiPlanView(
          dashboard: dashboard,
          selectedPlan: state.selectedPlan!,
          onSelectPlan: _controller.selectPlan,
          onBrowseWeek: _controller.browseWeek,
          onOpenCalendar: widget.onOpenCalendar,
          onOpenAllPlans: widget.onOpenAllPlans,
          onStartSession: widget.onStartSession,
        ),
        _ => _PlanErrorView(onRetry: _controller.load),
      },
    );
  }
}

class _PlanLoadingView extends StatelessWidget {
  const _PlanLoadingView();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: CircularProgressIndicator(color: MomCozyV3Colors.brand),
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
    this.onChat,
    this.onStartSession,
  });

  final DateTime selectedDay;
  final VoidCallback? onCreatePlan;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenAllPlans;
  final VoidCallback? onChat;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-empty-state'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _PlanHeader(
            calendarAsset: MomCozyAssets.planEmptyAction,
            onOpenCalendar: onOpenCalendar,
            onOpenAllPlans: onOpenAllPlans,
          ),
          const SizedBox(height: 20),
          _PlanWeekStrip(selectedDay: selectedDay, compact: true),
          const SizedBox(height: 24),
          const _EmptyPlanIllustration(),
          const SizedBox(height: 10),
          const Text(
            'No Plans Yet',
            textAlign: TextAlign.center,
            style: _PlanText.heroTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a personalized recovery plan to track your\npostpartum journey',
            textAlign: TextAlign.center,
            style: _PlanText.body,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const ValueKey('plan-create-first-plan'),
              onPressed: onCreatePlan,
              style: FilledButton.styleFrom(
                backgroundColor: MomCozyV3Colors.brand,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                '+ Create Your First Plan',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 25),
          _ServiceHeader(onChat: onChat),
          const SizedBox(height: 14),
          _ServiceCard(
            actionKey: const ValueKey('plan-service-recovery'),
            iconAsset: MomCozyAssets.planRecovery,
            title: 'Postpartum Recovery',
            subtitle: 'Postpartum recovery plan for body and mind',
            action: 'Start guide',
            onTap: onCreatePlan,
          ),
          const SizedBox(height: 12),
          _ServiceCard(
            actionKey: const ValueKey('plan-service-pump'),
            iconAsset: MomCozyAssets.planPump,
            title: 'momcozy Smart Pump',
            subtitle: 'Connect your momcozy pump and track sessions',
            action: 'Check now',
            onTap: onStartSession,
          ),
          const SizedBox(height: 12),
          _ServiceCard(
            actionKey: const ValueKey('plan-service-health'),
            iconAsset: MomCozyAssets.planHealth,
            title: 'Breast Health Check',
            subtitle: 'AI-powered breast health assessment',
            action: 'Check now',
            onTap: onChat,
          ),
          const SizedBox(height: 18),
          _CozymateAssistantCard(onChat: onChat),
        ],
      ),
    );
  }
}

class _MultiPlanView extends StatelessWidget {
  const _MultiPlanView({
    required this.dashboard,
    required this.selectedPlan,
    required this.onSelectPlan,
    required this.onBrowseWeek,
    this.onOpenCalendar,
    this.onOpenAllPlans,
    this.onStartSession,
  });

  final PlanDashboard dashboard;
  final CarePlan selectedPlan;
  final ValueChanged<String> onSelectPlan;
  final ValueChanged<int> onBrowseWeek;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenAllPlans;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    final visibleSessions = dashboard.sessions
        .where((session) => _sameDay(session.scheduledAt, dashboard.weekOf))
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
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final plan in dashboard.plans) ...[
                  _PlanCategoryChip(
                    plan: plan,
                    selected: plan.id == selectedPlan.id,
                    onTap: () => onSelectPlan(plan.id),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _PeriodSelector(),
          const SizedBox(height: 6),
          _WeekRangeRow(
            selectedDay: dashboard.weekOf,
            onPrevious: () => onBrowseWeek(-1),
            onNext: () => onBrowseWeek(1),
          ),
          const SizedBox(height: 6),
          const Text('This Week', style: _PlanText.sectionTitle),
          const SizedBox(height: 4),
          _PlanWeekStrip(selectedDay: dashboard.weekOf),
          const SizedBox(height: 18),
          const Text('Today', style: _PlanText.sectionTitle),
          const SizedBox(height: 10),
          for (final session in visibleSessions) ...[
            _PlanSessionCard(
              session: session,
              onStart: session.status == PlanSessionStatus.next
                  ? onStartSession
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const Text('This Week', style: _PlanText.sectionTitle),
          const SizedBox(height: 10),
          _WeekSummaryCard(completed: completed, total: total),
          const SizedBox(height: 22),
          const Text('Monthly Calendar', style: _PlanText.sectionTitle),
          const SizedBox(height: 12),
          _MonthlyCalendar(selectedDay: dashboard.weekOf),
        ],
      ),
    );
  }
}

class _SinglePlanView extends StatelessWidget {
  const _SinglePlanView({
    required this.dashboard,
    this.onBackToPlans,
    this.onOpenAllPlans,
    this.onStartSession,
    this.onAdjustWithAi,
    this.onManualEdit,
  });

  final PlanDashboard dashboard;
  final VoidCallback? onBackToPlans;
  final VoidCallback? onOpenAllPlans;
  final VoidCallback? onStartSession;
  final VoidCallback? onAdjustWithAi;
  final VoidCallback? onManualEdit;

  @override
  Widget build(BuildContext context) {
    final plan = dashboard.plans.single;
    final sessions = dashboard.sessionsFor(plan.id);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-single-category-state'),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          _SinglePlanHeader(
            title: plan.title,
            onBack: onBackToPlans,
            onEdit: onManualEdit,
            onOpenAllPlans: onOpenAllPlans,
          ),
          const SizedBox(height: 22),
          _MilestoneCard(plan: plan),
          const SizedBox(height: 14),
          _MilestoneWeekStrip(selectedDay: dashboard.weekOf),
          const SizedBox(height: 18),
          const Text("Today's Sessions", style: _PlanText.sectionTitle),
          const SizedBox(height: 10),
          for (final session in sessions) ...[
            _SingleSessionCard(
              session: session,
              onStart: session.status == PlanSessionStatus.next
                  ? onStartSession
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const Text('Volume Progress', style: _PlanText.sectionTitle),
          const SizedBox(height: 12),
          _VolumeProgressCard(plan: plan),
          const SizedBox(height: 20),
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
    return Row(
      children: [
        const Expanded(child: Text('My Plans', style: _PlanText.pageTitle)),
        _HeaderAssetButton(
          key: const ValueKey('plan-header-calendar'),
          asset: calendarAsset,
          tooltip: 'Calendar',
          onTap: onOpenCalendar,
          width: 36,
          height: 36,
        ),
        const SizedBox(width: 12),
        _HeaderAssetButton(
          key: const ValueKey('plan-header-all-plans'),
          asset: MomCozyAssets.planAllPlans,
          tooltip: 'All plans',
          onTap: onOpenAllPlans,
          width: 36,
          height: 19,
        ),
      ],
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
    return Row(
      children: [
        _HeaderAssetButton(
          key: const ValueKey('plan-single-back'),
          asset: MomCozyAssets.planBack,
          tooltip: 'Back to plans',
          onTap: onBack,
          width: 36,
          height: 38,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MomCozyV3Colors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _HeaderAssetButton(
          key: const ValueKey('plan-single-edit'),
          asset: MomCozyAssets.planEdit,
          tooltip: 'Edit plan',
          onTap: onEdit,
          width: 24,
          height: 24,
        ),
        const SizedBox(width: 8),
        _HeaderAssetButton(
          key: const ValueKey('plan-single-all-plans'),
          asset: MomCozyAssets.planAllPlans,
          tooltip: 'All plans',
          onTap: onOpenAllPlans,
          width: 36,
          height: 19,
        ),
      ],
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
  const _PlanWeekStrip({required this.selectedDay, this.compact = false});

  final DateTime selectedDay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final week = _weekDays(selectedDay);
    return SizedBox(
      height: compact ? 40 : 56,
      child: Row(
        children: [
          for (final day in week)
            Expanded(
              child: _PlanDay(
                day: day,
                selected: _sameDay(day, selectedDay),
                showDot: !compact,
                showFullWeekday: compact,
              ),
            ),
        ],
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
  });

  final DateTime day;
  final bool selected;
  final bool showDot;
  final bool showFullWeekday;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : MomCozyV3Colors.ink;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.symmetric(vertical: showDot ? 2 : 1),
      decoration: BoxDecoration(
        color: selected ? const Color(0xffa94d6d) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x2ca94d6d),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showFullWeekday ? _weekdayLong(day.weekday) : _weekday(day.weekday),
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xffa58f87),
              fontSize: showFullWeekday ? 11 : 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: showDot ? 2 : 1),
          Text(
            '${day.day}',
            style: TextStyle(
              color: foreground,
              fontSize: compactFont(showDot ? 17 : 18),
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (showDot) ...[
            const SizedBox(height: 1),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: selected ? Colors.white : _dayDotColor(day),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

double compactFont(double value) => value;

class _EmptyPlanIllustration extends StatelessWidget {
  const _EmptyPlanIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Center(
        child: SizedBox(
          width: 170,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 10,
                top: 0,
                child: _softCircle(96, const Color(0x55d4a4b2)),
              ),
              Positioned(
                right: 6,
                top: 46,
                child: _softCircle(72, const Color(0x55d4a4b2)),
              ),
              Positioned(
                left: 66,
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
                    width: 28,
                    height: 28,
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
        BoxShadow(color: Color(0x18a94d6d), blurRadius: 28, spreadRadius: 8),
      ],
    ),
  );
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({this.onChat});

  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service', style: _PlanText.sectionTitle),
              SizedBox(height: 2),
              Text(
                'Cozymate 1 on 1',
                style: TextStyle(
                  color: MomCozyV3Colors.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('Your AI wellness companion', style: _PlanText.caption),
            ],
          ),
        ),
        const _PlanAvatar(radius: 27),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onChat,
          style: FilledButton.styleFrom(
            backgroundColor: MomCozyV3Colors.ink,
            minimumSize: const Size(68, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: const StadiumBorder(),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14),
            ],
          ),
        ),
      ],
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
    this.onTap,
  });

  final Key actionKey;
  final String iconAsset;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: MediaQuery.sizeOf(context).width < 380 ? 112 : 104,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: _serviceCardDecoration(),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xfff5ecea),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SvgPicture.asset(iconAsset, width: 25, height: 25),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _PlanText.cardTitle.copyWith(height: 1)),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _PlanText.body.copyWith(fontSize: 13, height: 1),
                    ),
                    const SizedBox(height: 4),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: MomCozyV3Colors.ink,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              action,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                MomCozyAssets.planChevronRight,
                width: 16,
                height: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CozymateAssistantCard extends StatelessWidget {
  const _CozymateAssistantCard({this.onChat});

  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff7eeeb),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: 18),
        child: Row(
          children: [
            const _PlanAvatar(radius: 22, showBorder: false),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cozymate Assistant', style: _PlanText.cardTitle),
                  Text(
                    'Let Cozymate help you build a plan',
                    style: _PlanText.body,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onChat,
              style: FilledButton.styleFrom(
                backgroundColor: MomCozyV3Colors.brand,
                shape: const StadiumBorder(),
              ),
              child: const Text('Chat AI'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanAvatar extends StatelessWidget {
  const _PlanAvatar({required this.radius, this.showBorder = true});

  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: EdgeInsets.all(showBorder ? 2 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: const Color(0xffeadbd7)) : null,
        boxShadow: showBorder
            ? const [
                BoxShadow(
                  color: Color(0x26392832),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
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
              color: selected ? MomCozyV3Colors.brand : const Color(0xffe4d4d0),
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

enum _PlanPeriod { day, week, month }

class _PeriodSelector extends StatefulWidget {
  const _PeriodSelector();

  @override
  State<_PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<_PeriodSelector> {
  _PlanPeriod selected = _PlanPeriod.week;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            period: _PlanPeriod.day,
            label: 'Day',
            width: 51,
            selected: selected == _PlanPeriod.day,
            onTap: _select,
          ),
          _PeriodChip(
            period: _PlanPeriod.week,
            label: 'Week',
            width: 58,
            selected: selected == _PlanPeriod.week,
            onTap: _select,
          ),
          _PeriodChip(
            period: _PlanPeriod.month,
            label: 'Month',
            width: 62,
            selected: selected == _PlanPeriod.month,
            onTap: _select,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  void _select(_PlanPeriod value) {
    if (value == selected) return;
    setState(() => selected = value);
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

  final _PlanPeriod period;
  final String label;
  final double width;
  final bool selected;
  final ValueChanged<_PlanPeriod> onTap;

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
        ),
        Text(
          '${_monthShort(days.first.month)} ${days.first.day} – ${_monthShort(days.last.month)} ${days.last.day}',
          style: const TextStyle(
            color: MomCozyV3Colors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 32),
        ),
      ],
    );
  }
}

class _PlanSessionCard extends StatelessWidget {
  const _PlanSessionCard({required this.session, this.onStart});

  final PlanSession session;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final next = session.status == PlanSessionStatus.next;
    final muted = session.status == PlanSessionStatus.upcoming;
    return SizedBox(
      height: 59,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: next ? const Color(0xfffbf2f2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: next ? MomCozyV3Colors.brand : const Color(0xffeadbd7),
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
                      color: muted
                          ? const Color(0xff7d7b7b)
                          : next
                          ? MomCozyV3Colors.brand
                          : MomCozyV3Colors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted
                          ? const Color(0xffc4b5af)
                          : const Color(0xffa9897e),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            switch (session.status) {
              PlanSessionStatus.completed => const _StatusBadge(
                label: 'Completed',
                foreground: Color(0xff3dbb86),
                background: Color(0xffe6f7f1),
              ),
              PlanSessionStatus.next => _StartButton(onPressed: onStart),
              PlanSessionStatus.upcoming => const _StatusBadge(
                label: 'Upcoming',
                foreground: Color(0xffad7b89),
                background: Color(0xfff8eeee),
              ),
            },
          ],
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
      width: 66,
      height: 30,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(66, 30),
          backgroundColor: MomCozyV3Colors.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Start',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = (completed / total).clamp(0.0, 1.0);
    return SizedBox(
      height: 94,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        decoration: _flatCardDecoration(radius: 22, showBorder: true),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$completed of $total sessions completed',
                    style: _PlanText.bodyStrong,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: MomCozyV3Colors.brand,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                color: MomCozyV3Colors.brand,
                backgroundColor: const Color(0xffeee3e0),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('View week details', style: _PlanText.cardTitle),
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
    );
  }
}

class _MonthlyCalendar extends StatelessWidget {
  const _MonthlyCalendar({required this.selectedDay});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selectedDay.year, selectedDay.month);
    final count = DateTime(selectedDay.year, selectedDay.month + 1, 0).day;
    final leading = first.weekday - 1;
    return Container(
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
              return Center(
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
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
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
    return Container(
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
                  child: CircularProgressIndicator(
                    value: plan.weekNumber / math.max(1, plan.totalWeeks),
                    strokeWidth: 6,
                    color: MomCozyV3Colors.brand,
                    backgroundColor: const Color(0xffeadfdd),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Week', style: _PlanText.bodyStrong),
                    Text(
                      '${plan.weekNumber}/${plan.totalWeeks}',
                      style: const TextStyle(
                        color: MomCozyV3Colors.brand,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mid-Way Milestone', style: _PlanText.cardTitle),
                const SizedBox(height: 4),
                Text(
                  "You've consistently completed ${plan.sessionsPerDay} sessions a day this week. Keep it up!",
                  style: _PlanText.body.copyWith(fontSize: 13, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneWeekStrip extends StatelessWidget {
  const _MilestoneWeekStrip({required this.selectedDay});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final days = _weekDays(selectedDay);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: _flatCardDecoration(radius: 18),
      child: Row(
        children: [
          for (var index = 0; index < days.length; index += 1)
            Expanded(
              child: Column(
                children: [
                  Text(_weekday(days[index].weekday), style: _PlanText.caption),
                  const SizedBox(height: 5),
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: index < 2 ? MomCozyV3Colors.brand : Colors.white,
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
                            size: 18,
                          )
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SingleSessionCard extends StatelessWidget {
  const _SingleSessionCard({required this.session, this.onStart});

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
    return SizedBox(
      height: 59,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: next ? const Color(0xfffbf2f2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: next ? MomCozyV3Colors.brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xfff9efed),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconAsset,
                  width: completed || !next ? 18 : 16,
                  height: completed || !next ? 18 : 16,
                  colorFilter: !next && !completed
                      ? const ColorFilter.mode(
                          Color(0xffc6b7b2),
                          BlendMode.srcIn,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: TextStyle(
                      color: next
                          ? MomCozyV3Colors.brand
                          : completed
                          ? MomCozyV3Colors.ink
                          : const Color(0xff898584),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${completed
                        ? 'Completed'
                        : next
                        ? 'Next Up'
                        : 'Upcoming'} · ${_time(session.scheduledAt)}',
                    style: _PlanText.body.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (completed) ...[
              Text(
                session.valueLabel ?? '',
                style: const TextStyle(
                  color: Color(0xff3dbb86),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 7),
              SvgPicture.asset(
                MomCozyAssets.planCheckCircle,
                width: 20,
                height: 20,
              ),
            ] else if (next)
              _StartButton(onPressed: onStart),
          ],
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
      padding: const EdgeInsets.all(18),
      decoration: _flatCardDecoration(radius: 20),
      child: Column(
        children: [
          _VolumeProgressRow(
            label: "Today's Target",
            value: '${plan.todayVolumeMl} / ${plan.dailyTargetVolumeMl} ml',
            progress:
                plan.todayVolumeMl / math.max(1, plan.dailyTargetVolumeMl),
          ),
          const Divider(height: 28, color: Color(0xffeadbd7)),
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
            Expanded(child: Text(label, style: _PlanText.bodyStrong)),
            Text(
              value,
              style: const TextStyle(
                color: MomCozyV3Colors.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress.clamp(0.0, 1.0),
            color: MomCozyV3Colors.brand,
            backgroundColor: const Color(0xffeee3e0),
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
      padding: const EdgeInsets.all(18),
      decoration: _flatCardDecoration(radius: 20, showBorder: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xffeee4ff),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'AI Coach Available',
              style: TextStyle(
                color: Color(0xff9a75ed),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Plan Settings', style: _PlanText.sectionTitle),
          const SizedBox(height: 16),
          _SettingRow(
            label: 'Sessions per day',
            value: '${plan.sessionsPerDay} sessions',
          ),
          const SizedBox(height: 14),
          _SettingRow(
            label: 'Daily Target Volume',
            value: '${plan.dailyTargetVolumeMl} ml',
          ),
          const Divider(height: 28, color: Color(0xffeadbd7)),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onAdjustWithAi,
              style: FilledButton.styleFrom(
                backgroundColor: MomCozyV3Colors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Adjust with AI'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: onManualEdit,
              child: const Text(
                'Manual Edit',
                style: TextStyle(
                  color: MomCozyV3Colors.brand,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w800,
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
        Expanded(child: Text(label, style: _PlanText.body)),
        Text(value, style: _PlanText.bodyStrong),
      ],
    );
  }
}

class _PlanText {
  const _PlanText._();

  static const pageTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontSize: 34,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
  );
  static const heroTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontSize: 28,
    fontWeight: FontWeight.w900,
  );
  static const sectionTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
  );
  static const cardTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );
  static const bodyStrong = TextStyle(
    color: Color(0xff5d4b46),
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
  static const body = TextStyle(
    color: Color(0xffad938a),
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const caption = TextStyle(
    color: Color(0xffa58f87),
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

BoxDecoration _cardDecoration({required double radius}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xffeadbd7)),
  boxShadow: const [
    BoxShadow(color: Color(0x0f392832), blurRadius: 18, offset: Offset(0, 7)),
  ],
);

BoxDecoration _flatCardDecoration({
  required double radius,
  bool showBorder = false,
}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: showBorder ? Border.all(color: const Color(0xffeadbd7)) : null,
);

BoxDecoration _serviceCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xffe8dcda)),
  boxShadow: const [
    BoxShadow(color: Color(0x20392832), blurRadius: 18, offset: Offset(0, 7)),
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

String _weekday(int weekday) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

String _weekdayLong(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

Color _dayDotColor(DateTime day) => const [
  Color(0xff8a233f),
  Color(0xff7d65d6),
  Color(0xff40b985),
  Color(0xff8a233f),
  Color(0xff7d65d6),
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

String _thousands(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  return '${digits.substring(0, digits.length - 3)},${digits.substring(digits.length - 3)}';
}
