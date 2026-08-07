import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    this.onChat,
    this.onStartSession,
    this.onManualEdit,
    this.changeStore,
  });

  final PlanRepository repository;
  final DateTime Function() now;
  final VoidCallback? onCreatePlan;
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
          onChat: widget.onChat,
        ),
        _ when dashboard != null && dashboard.isSinglePlan => _SinglePlanView(
          dashboard: dashboard,
          onStartSession: widget.onStartSession,
          onAdjustWithAi: widget.onChat,
          onManualEdit: widget.onManualEdit,
        ),
        _ when dashboard != null => _MultiPlanView(
          dashboard: dashboard,
          selectedPlan: state.selectedPlan!,
          onSelectPlan: _controller.selectPlan,
          onBrowseWeek: _controller.browseWeek,
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
    this.onChat,
  });

  final DateTime selectedDay;
  final VoidCallback? onCreatePlan;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const ValueKey('plan-empty-state'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const _PlanHeader(),
          const SizedBox(height: 24),
          _PlanWeekStrip(selectedDay: selectedDay, compact: true),
          const SizedBox(height: 30),
          const _EmptyPlanIllustration(),
          const SizedBox(height: 14),
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
            height: 54,
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
          const SizedBox(height: 28),
          _ServiceHeader(onChat: onChat),
          const SizedBox(height: 14),
          const _ServiceCard(
            icon: Icons.favorite_border_rounded,
            title: 'Postpartum Recovery',
            subtitle: 'Postpartum recovery plan for body\nand mind',
            action: 'Start guide',
          ),
          const SizedBox(height: 12),
          const _ServiceCard(
            icon: Icons.electric_bolt_rounded,
            title: 'momcozy Smart Pump',
            subtitle: 'Connect your momcozy pump and\ntrack sessions',
            action: 'Check now',
          ),
          const SizedBox(height: 12),
          const _ServiceCard(
            icon: Icons.health_and_safety_outlined,
            title: 'Breast Health Check',
            subtitle: 'AI-powered breast health assessment',
            action: 'Check now',
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
    this.onStartSession,
  });

  final PlanDashboard dashboard;
  final CarePlan selectedPlan;
  final ValueChanged<String> onSelectPlan;
  final ValueChanged<int> onBrowseWeek;
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const _PlanHeader(),
          const SizedBox(height: 20),
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
          const SizedBox(height: 16),
          const _PeriodSelector(),
          const SizedBox(height: 10),
          _WeekRangeRow(
            selectedDay: dashboard.weekOf,
            onPrevious: () => onBrowseWeek(-1),
            onNext: () => onBrowseWeek(1),
          ),
          const SizedBox(height: 12),
          const Text('This Week', style: _PlanText.sectionTitle),
          const SizedBox(height: 10),
          _PlanWeekStrip(selectedDay: dashboard.weekOf),
          const SizedBox(height: 24),
          const Text('Today', style: _PlanText.sectionTitle),
          const SizedBox(height: 12),
          for (final session in visibleSessions) ...[
            _PlanSessionCard(
              session: session,
              onStart: session.status == PlanSessionStatus.next
                  ? onStartSession
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          const Text('This Week', style: _PlanText.sectionTitle),
          const SizedBox(height: 12),
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
    this.onStartSession,
    this.onAdjustWithAi,
    this.onManualEdit,
  });

  final PlanDashboard dashboard;
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _SinglePlanHeader(
            title: plan.title,
            onBack: Navigator.of(context).canPop()
                ? Navigator.of(context).pop
                : null,
          ),
          const SizedBox(height: 22),
          _MilestoneCard(plan: plan),
          const SizedBox(height: 20),
          _MilestoneWeekStrip(selectedDay: dashboard.weekOf),
          const SizedBox(height: 22),
          const Text("Today's Sessions", style: _PlanText.sectionTitle),
          const SizedBox(height: 12),
          for (final session in sessions) ...[
            _SingleSessionCard(
              session: session,
              onStart: session.status == PlanSessionStatus.next
                  ? onStartSession
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
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
  const _PlanHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('My Plans', style: _PlanText.pageTitle)),
        const _HeaderAction(
          icon: Icons.calendar_month_rounded,
          outlined: true,
          tooltip: 'Calendar',
        ),
        const SizedBox(width: 12),
        _HeaderAction(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'All plans',
          color: MomCozyV3Colors.brand.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _SinglePlanHeader extends StatelessWidget {
  const _SinglePlanHeader({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MomCozyV3Colors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const _HeaderAction(icon: Icons.edit_outlined, tooltip: 'Edit plan'),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'All plans',
          color: MomCozyV3Colors.brand.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    this.outlined = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: const Color(0xffe7d9d5)) : null,
        ),
        child: Icon(icon, color: MomCozyV3Colors.ink, size: 25),
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
      height: compact ? 58 : 72,
      child: Row(
        children: [
          for (final day in week)
            Expanded(
              child: _PlanDay(
                day: day,
                selected: _sameDay(day, selectedDay),
                showDot: !compact,
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
  });

  final DateTime day;
  final bool selected;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : MomCozyV3Colors.ink;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            _weekday(day.weekday),
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xffa58f87),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${day.day}',
            style: TextStyle(
              color: foreground,
              fontSize: compactFont(showDot ? 19 : 18),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (showDot) ...[
            const SizedBox(height: 3),
            Container(
              width: 7,
              height: 7,
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
      height: 176,
      child: Center(
        child: SizedBox(
          width: 190,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 18,
                top: 8,
                child: _softCircle(104, const Color(0x55d4a4b2)),
              ),
              Positioned(
                right: 15,
                top: 64,
                child: _softCircle(82, const Color(0x55d4a4b2)),
              ),
              Positioned(
                left: 76,
                bottom: 5,
                child: _softCircle(62, const Color(0x55d4a4b2)),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xfff9ecef),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: MomCozyV3Colors.brand,
                  size: 34,
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
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        const CircleAvatar(
          radius: 30,
          backgroundImage: AssetImage(MomCozyAssets.planCozymateAvatar),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onChat,
          style: FilledButton.styleFrom(
            backgroundColor: MomCozyV3Colors.ink,
            shape: const StadiumBorder(),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chat'),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 22),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xfff7edeb),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: MomCozyV3Colors.brand, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _PlanText.cardTitle),
                const SizedBox(height: 3),
                Text(subtitle, style: _PlanText.body),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: MomCozyV3Colors.ink,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xffad9b95),
            size: 36,
          ),
        ],
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
            const CircleAvatar(
              radius: 22,
              backgroundImage: AssetImage(MomCozyAssets.planCozymateAvatar),
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? MomCozyV3Colors.brand : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? MomCozyV3Colors.brand : const Color(0xffe4d4d0),
            ),
          ),
          child: Text(
            plan.category == PlanCategory.other
                ? plan.title
                : plan.category.label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xff9d8981),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xfff2e9e6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xffe4d4d0)),
      ),
      child: const Row(
        children: [
          _PeriodChip(label: 'Day'),
          _PeriodChip(label: 'Week', selected: true),
          _PeriodChip(label: 'Month'),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? MomCozyV3Colors.brand : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xff9d8981),
            fontSize: 15,
            fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: next ? const Color(0xfffbf2f2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: next ? MomCozyV3Colors.brand : const Color(0xffeadbd7),
          width: next ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.title,
                  style: TextStyle(
                    color: muted
                        ? const Color(0xffc4b5af)
                        : const Color(0xffa9897e),
                    fontSize: 14,
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
            PlanSessionStatus.next => FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: MomCozyV3Colors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('Start'),
            ),
            PlanSessionStatus.upcoming => const _StatusBadge(
              label: 'Upcoming',
              foreground: Color(0xffad7b89),
              background: Color(0xfff8eeee),
            ),
          },
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
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
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: MomCozyV3Colors.brand,
              backgroundColor: const Color(0xffeee3e0),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: Text('View week details', style: _PlanText.cardTitle),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xffaa9992),
                size: 34,
              ),
            ],
          ),
        ],
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
      decoration: _cardDecoration(radius: 22),
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
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 24),
      child: Row(
        children: [
          SizedBox(
            width: 106,
            height: 106,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: plan.weekNumber / math.max(1, plan.totalWeeks),
                  strokeWidth: 8,
                  color: MomCozyV3Colors.brand,
                  backgroundColor: const Color(0xffeadfdd),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Week', style: _PlanText.bodyStrong),
                    Text(
                      '${plan.weekNumber}/${plan.totalWeeks}',
                      style: const TextStyle(
                        color: MomCozyV3Colors.brand,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mid-Way Milestone', style: _PlanText.cardTitle),
                SizedBox(height: 8),
                Text(
                  "You've consistently completed ${plan.sessionsPerDay} sessions a day this week. Keep it up!",
                  style: _PlanText.body,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: _cardDecoration(radius: 22),
      child: Row(
        children: [
          for (var index = 0; index < days.length; index += 1)
            Expanded(
              child: Column(
                children: [
                  Text(_weekday(days[index].weekday), style: _PlanText.caption),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 32,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: next ? const Color(0xfffbf2f2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            child: Icon(
              completed
                  ? Icons.water_drop_outlined
                  : next
                  ? Icons.play_arrow_rounded
                  : Icons.schedule_rounded,
              color: next ? MomCozyV3Colors.brand : const Color(0xffc6b7b2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${completed
                      ? 'Completed'
                      : next
                      ? 'Next Up'
                      : 'Upcoming'} · ${_time(session.scheduledAt)}',
                  style: _PlanText.body,
                ),
              ],
            ),
          ),
          if (completed) ...[
            Text(
              session.valueLabel ?? '',
              style: const TextStyle(
                color: Color(0xff3dbb86),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xff3dbb86),
            ),
          ] else if (next)
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: MomCozyV3Colors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Start'),
            ),
        ],
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
      decoration: _cardDecoration(radius: 22),
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
      decoration: _cardDecoration(radius: 22),
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
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
  );
  static const cardTitle = TextStyle(
    color: MomCozyV3Colors.ink,
    fontSize: 17,
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
