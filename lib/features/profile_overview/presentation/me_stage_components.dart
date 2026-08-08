part of 'me_baby_overview_page.dart';

class _MomStageWorkspace extends StatelessWidget {
  const _MomStageWorkspace({
    required this.stage,
    required this.data,
    required this.selectedSection,
    required this.onSelected,
    required this.onOpenAvatar,
  });

  final MomLifeStage stage;
  final _MeBabyOverviewData data;
  final String selectedSection;
  final ValueChanged<String> onSelected;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    final showAvatar = MediaQuery.textScalerOf(context).scale(1) <= 1.35;
    return Column(
      key: ValueKey('me-stage-workspace-${stage.wireValue}'),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _MomStageHero(
                    stage: stage,
                    data: data,
                    onOpenAvatar: onOpenAvatar,
                  ),
                ),
                const SizedBox(height: 6),
                if (showAvatar)
                  const SizedBox(height: 48)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _MomStageTabs(
                      stage: stage,
                      selected: selectedSection,
                      onSelected: onSelected,
                    ),
                  ),
                if (stage == MomLifeStage.postpartum) ...[
                  const SizedBox(height: 10),
                  _StagePageIndicator(
                    selected: selectedSection == 'recovery' ? 1 : 0,
                  ),
                ],
              ],
            ),
            if (showAvatar)
              Positioned(
                right: stage == MomLifeStage.pregnancy ? -28 : -18,
                top: stage == MomLifeStage.pregnancy ? -16 : -30,
                width: stage == MomLifeStage.pregnancy ? 218 : 210,
                height: stage == MomLifeStage.pregnancy ? 290 : 304,
                child: IgnorePointer(
                  child: Image.asset(
                    stage == MomLifeStage.pregnancy
                        ? _MeBabyOverviewAssets.pregnancyAvatar
                        : _MeBabyOverviewAssets.momAvatar,
                    alignment: Alignment.bottomCenter,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            if (showAvatar)
              Positioned(
                left: 6,
                right: 6,
                top: 207,
                child: _MomStageTabs(
                  stage: stage,
                  selected: selectedSection,
                  onSelected: onSelected,
                ),
              ),
          ],
        ),
        SizedBox(height: stage == MomLifeStage.postpartum ? 21 : 25),
        _MomStageContent(stage: stage, section: selectedSection, data: data),
      ],
    );
  }
}

class _MomStageHero extends StatelessWidget {
  const _MomStageHero({
    required this.stage,
    required this.data,
    required this.onOpenAvatar,
  });

  final MomLifeStage stage;
  final _MeBabyOverviewData data;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    final program = _stageProgram(stage, data);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final expandedText = textScale > 1.35;
    final heroHeight = expandedText ? 326.0 : 186.0;
    return Semantics(
      key: const ValueKey('me-baby-overview-open-avatar'),
      label: 'View ${stage.label} avatar',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenAvatar,
        child: SizedBox(
          key: ValueKey('me-stage-hero-${stage.wireValue}'),
          height: heroHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _MeBabyOverviewColors.hero,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 16,
                  top: expandedText ? 28 : 36,
                  right: expandedText ? 24 : 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.title,
                        key: const ValueKey('me-stage-program-title'),
                        maxLines: expandedText ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _MeBabyOverviewColors.ink,
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ProgramProgress(value: program.progress),
                      const SizedBox(height: 6),
                      Text(
                        program.progressLabel,
                        maxLines: expandedText ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _MeBabyOverviewColors.mutedText,
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _BodyProfileButton(compact: expandedText),
                    ],
                  ),
                ),
                if (!expandedText)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xffd8d8d8),
                          borderRadius: BorderRadius.circular(3),
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

class _BodyProfileButton extends StatelessWidget {
  const _BodyProfileButton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tapHeight = compact ? 48.0 : MomCozyTapTargets.minimum;
    final surfaceHeight = compact ? 48.0 : 32.0;
    final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final buttonWidth = math.min(230.0, (compact ? 150.0 : 132.0) * textScale);
    return Semantics(
      button: true,
      label: 'Open Body Profile',
      child: SizedBox(
        width: buttonWidth,
        height: tapHeight,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const ValueKey('me-stage-body-profile'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.go('/more/body-profile'),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Ink(
                key: const ValueKey('me-stage-body-profile-surface'),
                height: surfaceHeight,
                padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Body Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _MeBabyOverviewColors.wine,
                          fontSize: compact ? 15 : 12,
                          fontWeight: compact
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 9 : 7),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: _MeBabyOverviewColors.wine,
                      size: compact ? 20 : 16,
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

class _ProgramProgress extends StatelessWidget {
  const _ProgramProgress({required this.value, this.light = false});

  final double? value;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final track = light
        ? Colors.white.withValues(alpha: 0.34)
        : const Color(0xffeee6e3);
    final fill = light ? Colors.white : _MeBabyOverviewColors.wine;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        width: 180,
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            if (value != null && value! > 0)
              FractionallySizedBox(
                widthFactor: value!.clamp(0.0, 1.0),
                child: ColoredBox(color: fill),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageProgram {
  const _StageProgram({
    required this.title,
    required this.progressLabel,
    required this.progress,
    this.plan,
    this.sessions = const <PlanSession>[],
  });

  final String title;
  final String progressLabel;
  final double? progress;
  final CarePlan? plan;
  final List<PlanSession> sessions;
}

_StageProgram _stageProgram(MomLifeStage stage, _MeBabyOverviewData data) {
  final dashboard = data.plans.data;
  final plans = dashboard?.plans ?? const <CarePlan>[];
  final authoritative = data.maternalCareOverview.data;
  if (authoritative?.stage == stage) {
    final progress = authoritative?.program;
    if (progress == null) {
      return _StageProgram(
        title: stage == MomLifeStage.pregnancy
            ? 'Prenatal Program'
            : stage == MomLifeStage.postpartum
            ? 'Postpartum Recovery'
            : 'Cycle Tracking',
        progressLabel: 'No active program yet',
        progress: null,
      );
    }
    final selected = plans
        .where((plan) => plan.id == progress.planId)
        .firstOrNull;
    final sessions = selected == null
        ? const <PlanSession>[]
        : dashboard!.sessionsFor(selected.id);
    final total = progress.totalSessions;
    return _StageProgram(
      title: progress.title,
      progressLabel: total == 0
          ? 'No sessions scheduled yet'
          : '${progress.completedSessions} of $total sessions completed',
      progress: total == 0 ? null : progress.completedSessions / total,
      plan: selected,
      sessions: sessions,
    );
  }
  if (stage == MomLifeStage.fertility) {
    return const _StageProgram(
      title: 'Cycle Tracking',
      progressLabel: 'Cycle data not connected',
      progress: null,
    );
  }
  CarePlan? selected;
  if (stage == MomLifeStage.pregnancy) {
    selected = plans
        .where((plan) => plan.category == PlanCategory.yoga)
        .firstOrNull;
    selected ??= plans
        .where((plan) => plan.category == PlanCategory.other)
        .firstOrNull;
  } else {
    selected = plans
        .where((plan) => plan.category == PlanCategory.pelvicFloor)
        .firstOrNull;
    selected ??= plans
        .where((plan) => plan.category == PlanCategory.yoga)
        .firstOrNull;
  }
  if (selected == null) {
    final loading =
        data.plans.phase == OverviewResourcePhase.initial ||
        data.plans.phase == OverviewResourcePhase.loading;
    return _StageProgram(
      title: stage == MomLifeStage.pregnancy
          ? 'Prenatal Program'
          : 'Postpartum Recovery',
      progressLabel: loading
          ? 'Loading active program…'
          : data.plans.hasError
          ? 'Program data unavailable'
          : 'No active program yet',
      progress: null,
    );
  }
  final sessions = dashboard!.sessionsFor(selected.id);
  final completed = sessions
      .where((session) => session.status == PlanSessionStatus.completed)
      .length;
  final total = sessions.length;
  return _StageProgram(
    title: selected.title,
    progressLabel: total == 0
        ? 'Open Plan to view sessions'
        : '$completed of $total sessions completed',
    progress: total == 0 ? null : completed / total,
    plan: selected,
    sessions: sessions,
  );
}

class _MomStageTabs extends StatelessWidget {
  const _MomStageTabs({
    required this.stage,
    required this.selected,
    required this.onSelected,
  });

  final MomLifeStage stage;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final sections = switch (stage) {
      MomLifeStage.fertility => const [
        ('cycle', 'Cycle', Icons.radio_button_checked_rounded),
        ('wellness', 'Wellness', Icons.favorite_border_rounded),
      ],
      MomLifeStage.pregnancy => const [
        ('prenatal', 'Prenatal', Icons.calendar_today_outlined),
        ('wellness', 'Wellness', Icons.favorite_border_rounded),
      ],
      MomLifeStage.postpartum => const [
        ('lactation', 'Lactation', Icons.water_drop_outlined),
        ('recovery', 'Recovery', Icons.accessibility_new_rounded),
      ],
    };
    return SizedBox(
      key: ValueKey('me-stage-tabs-${stage.wireValue}'),
      height: 48,
      child: Row(
        children: [
          for (var index = 0; index < sections.length; index += 1) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: _MomStageTab(
                section: sections[index].$1,
                label: sections[index].$2,
                icon: sections[index].$3,
                selected: selected == sections[index].$1,
                onTap: () => onSelected(sections[index].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MomStageTab extends StatelessWidget {
  const _MomStageTab({
    required this.section,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String section;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('me-section-$section'),
      label: label,
      excludeSemantics: true,
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Center(
            child: Ink(
              key: ValueKey('me-stage-tab-surface-$section'),
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? _MeBabyOverviewColors.ink
                    : _MeBabyOverviewColors.pill,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? Colors.white
                          : _MeBabyOverviewColors.ink,
                      size: 16,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : _MeBabyOverviewColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
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

class _StagePageIndicator extends StatelessWidget {
  const _StagePageIndicator({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < 2; index += 1) ...[
          if (index > 0) const SizedBox(width: 9),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == selected
                  ? _MeBabyOverviewColors.ink
                  : const Color(0xffdedede),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _MomStageContent extends StatelessWidget {
  const _MomStageContent({
    required this.stage,
    required this.section,
    required this.data,
  });

  final MomLifeStage stage;
  final String section;
  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      MomLifeStage.fertility =>
        section == 'wellness'
            ? _StageWellnessContent(stage: stage)
            : _FertilityCycleContent(data: data),
      MomLifeStage.pregnancy =>
        section == 'wellness'
            ? _StageWellnessContent(stage: stage)
            : _PregnancyPrenatalContent(data: data),
      MomLifeStage.postpartum => _MeContent(section: section, data: data),
    };
  }
}

class _FertilityCycleContent extends StatelessWidget {
  const _FertilityCycleContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      cardKey: const ValueKey('me-fertility-cycle-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xffdf6a91),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 14),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ovulation Prediction',
                  style: _MeBabyOverviewText.cardTitle,
                ),
              ),
              Text(
                'NOT READY',
                style: TextStyle(
                  color: Color(0xffdf6a91),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfffff3f6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_florist_rounded,
                  color: Color(0xffdf6a91),
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cycle records needed',
                        style: TextStyle(
                          color: _MeBabyOverviewColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add confirmed period dates before predictions are shown.',
                        style: _MeBabyOverviewText.supporting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _MeBabyOverviewColors.line, height: 30),
          _CalendarStrip(today: data.now),
        ],
      ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final localToday = DateTime(today.year, today.month, today.day);
    final dates = [
      for (var offset = -3; offset <= 3; offset += 1)
        localToday.add(Duration(days: offset)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthName(localToday.month).toUpperCase()} ${localToday.year}',
                style: const TextStyle(
                  color: _MeBabyOverviewColors.wine,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Text('Calendar', style: _MeBabyOverviewText.supporting),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final date in dates)
              Expanded(
                child: _CalendarDay(
                  date: date,
                  selected: _sameCalendarDay(date, localToday),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.date, required this.selected});

  final DateTime date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
          style: _MeBabyOverviewText.supporting,
        ),
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xffdf6a91) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: selected ? Colors.white : _MeBabyOverviewColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PregnancyPrenatalContent extends StatelessWidget {
  const _PregnancyPrenatalContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final pregnancy = _pregnancyProgress(data);
    final program = _stageProgram(MomLifeStage.pregnancy, data);
    return _V2Card(
      cardKey: const ValueKey('me-pregnancy-milestones-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _MeBabyOverviewColors.wine,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 14),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Today’s Milestones',
                  style: _MeBabyOverviewText.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (pregnancy == null)
            const _PregnancyEmptyState()
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _MeBabyOverviewColors.pill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.child_friendly_rounded,
                    color: _MeBabyOverviewColors.wine,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Week ${pregnancy.week}',
                        style: const TextStyle(
                          color: _MeBabyOverviewColors.ink,
                          fontSize: 25,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Based on your confirmed due date',
                        style: _MeBabyOverviewText.supporting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Week ${pregnancy.week} of 40',
                    style: const TextStyle(
                      color: _MeBabyOverviewColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  pregnancy.hasConfirmedDueDate
                      ? '${pregnancy.daysRemaining} days to go'
                      : 'About ${pregnancy.daysRemaining} days to go',
                  style: _MeBabyOverviewText.supporting,
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: pregnancy.week / 40,
                color: _MeBabyOverviewColors.wine,
                backgroundColor: _MeBabyOverviewColors.line,
              ),
            ),
          ],
          const Divider(color: _MeBabyOverviewColors.line, height: 30),
          const Text(
            'TODAY’S PLAN',
            style: TextStyle(
              color: _MeBabyOverviewColors.wine,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (program.sessions.isEmpty)
            const Text(
              'No confirmed milestones or appointments for today.',
              style: _MeBabyOverviewText.supporting,
            )
          else
            for (final session in program.sessions.take(3)) ...[
              _PlanSessionRow(session: session),
              if (session != program.sessions.take(3).last)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PregnancyEmptyState extends StatelessWidget {
  const _PregnancyEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _MeBabyOverviewColors.pill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: _MeBabyOverviewColors.wine,
            size: 30,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add a confirmed due date to see gestational progress.',
              style: _MeBabyOverviewText.supporting,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSessionRow extends StatelessWidget {
  const _PlanSessionRow({required this.session});

  final PlanSession session;

  @override
  Widget build(BuildContext context) {
    final completed = session.status == PlanSessionStatus.completed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          completed ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: completed
              ? _MeBabyOverviewColors.wine
              : _MeBabyOverviewColors.mutedText,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            session.title,
            style: TextStyle(
              color: completed
                  ? _MeBabyOverviewColors.ink
                  : _MeBabyOverviewColors.mutedText,
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PregnancyProgress {
  const _PregnancyProgress({
    required this.week,
    required this.daysRemaining,
    required this.trimester,
    required this.hasConfirmedDueDate,
  });

  final int week;
  final int daysRemaining;
  final String trimester;
  final bool hasConfirmedDueDate;
}

class _RecoveryStatusCard extends StatelessWidget {
  const _RecoveryStatusCard();

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      cardKey: const ValueKey('me-recovery-status-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Recovery Score',
                  style: _MeBabyOverviewText.cardTitle,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _MeBabyOverviewColors.pill,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 14),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Not scored',
                      style: TextStyle(
                        color: _MeBabyOverviewColors.ink,
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Recovery data unavailable',
                      style: TextStyle(
                        color: _MeBabyOverviewColors.wine,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 92,
                child: CustomPaint(
                  painter: _EmptyRecoveryRingPainter(),
                  child: Center(
                    child: Text(
                      '—',
                      style: TextStyle(
                        color: _MeBabyOverviewColors.mutedText,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _MeBabyOverviewColors.pill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Only confirmed recovery records will appear here. A health score is not estimated from missing data.',
              style: _MeBabyOverviewText.supporting,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecoveryRingPainter extends CustomPainter {
  const _EmptyRecoveryRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 - 8,
      Paint()
        ..color = _MeBabyOverviewColors.line
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyRecoveryRingPainter oldDelegate) => false;
}

_PregnancyProgress? _pregnancyProgress(_MeBabyOverviewData data) {
  final authoritative = data.maternalCareOverview.data;
  if (authoritative?.stage == MomLifeStage.pregnancy) {
    final progress = authoritative?.pregnancy;
    if (progress?.state != PregnancyProgressState.ready ||
        progress?.gestationalWeek == null ||
        progress?.daysRemaining == null ||
        progress?.trimester == null) {
      return null;
    }
    return _PregnancyProgress(
      week: progress!.gestationalWeek!,
      daysRemaining: progress.daysRemaining!,
      trimester: progress.trimester!.label,
      hasConfirmedDueDate: true,
    );
  }
  final mom = data.overview.data?.mom;
  final dueDate = mom?.expectedDueDate ?? mom?.deliveryDate;
  int week;
  int daysRemaining;
  final hasConfirmedDueDate = dueDate != null;
  if (dueDate != null) {
    final today = DateTime(data.now.year, data.now.month, data.now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    daysRemaining = due.difference(today).inDays;
    if (daysRemaining < 0 || daysRemaining > 280) return null;
    week = ((280 - daysRemaining) ~/ 7).clamp(0, 40);
  } else {
    final confirmed = mom?.dueDateOrWeek?.trim();
    final match = confirmed == null
        ? null
        : RegExp(r'(?<!\d)([0-3]?\d|40)(?!\d)').firstMatch(confirmed);
    final parsedWeek = int.tryParse(match?.group(1) ?? '');
    if (parsedWeek == null || parsedWeek < 0 || parsedWeek > 40) return null;
    week = parsedWeek;
    daysRemaining = (40 - week) * 7;
  }
  final trimester = week <= 13
      ? 'First Trimester'
      : week <= 27
      ? 'Second Trimester'
      : 'Third Trimester';
  return _PregnancyProgress(
    week: week,
    daysRemaining: daysRemaining,
    trimester: trimester,
    hasConfirmedDueDate: hasConfirmedDueDate,
  );
}

class _StageWellnessContent extends StatelessWidget {
  const _StageWellnessContent({required this.stage});

  final MomLifeStage stage;

  @override
  Widget build(BuildContext context) {
    final pregnancy = stage == MomLifeStage.pregnancy;
    return Column(
      key: ValueKey('me-stage-wellness-${stage.wireValue}'),
      children: [
        _StageActionCard(
          actionKey: ValueKey('me-stage-${stage.wireValue}-plan'),
          icon: Icons.event_note_rounded,
          title: pregnancy ? 'Pregnancy Plan' : 'Wellness Plan',
          subtitle: pregnancy
              ? 'Review confirmed prenatal tasks and sessions'
              : 'Organize preparation and wellness tasks',
          actionLabel: 'Open Plan',
          onTap: () => context.go('/schedule'),
        ),
        const SizedBox(height: 14),
        _StageActionCard(
          actionKey: ValueKey('me-stage-${stage.wireValue}-cozymate'),
          icon: Icons.auto_awesome_rounded,
          title: 'Cozymate',
          subtitle: pregnancy
              ? 'Ask about prenatal care with cited guidance'
              : 'Ask about fertility and preconception care',
          actionLabel: 'Ask Cozymate',
          onTap: () => context.go('/'),
        ),
      ],
    );
  }
}

class _StageActionCard extends StatelessWidget {
  const _StageActionCard({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle. $actionLabel',
      child: Material(
        key: actionKey,
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _MeBabyOverviewColors.pill,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Icon(
                        icon,
                        color: _MeBabyOverviewColors.wine,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: _MeBabyOverviewText.cardTitle),
                        const SizedBox(height: 5),
                        Text(subtitle, style: _MeBabyOverviewText.supporting),
                        const SizedBox(height: 8),
                        Text(
                          actionLabel,
                          style: const TextStyle(
                            color: _MeBabyOverviewColors.wine,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _MeBabyOverviewColors.wine,
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

class _MomAvatarStage extends StatelessWidget {
  const _MomAvatarStage({
    required this.stage,
    required this.data,
    required this.selectedSection,
    required this.onClose,
    required this.onSelected,
  });

  final MomLifeStage stage;
  final _MeBabyOverviewData data;
  final String selectedSection;
  final VoidCallback onClose;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final program = _stageProgram(stage, data);
    final pregnancy = stage == MomLifeStage.pregnancy
        ? _pregnancyProgress(data)
        : null;
    final chipLabel = pregnancy == null
        ? stage == MomLifeStage.fertility
              ? 'Cycle data not connected'
              : stage.label
        : 'Week ${pregnancy.week} · ${pregnancy.trimester}';
    return ColoredBox(
      color: _MeBabyOverviewColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 680;
          return Stack(
            children: [
              Positioned.fill(
                bottom: compact ? 92 : 116,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xfffbf5f3), Color(0xfff2e8e5)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: stage == MomLifeStage.pregnancy ? -24 : -4,
                right: stage == MomLifeStage.pregnancy ? -24 : -4,
                top: compact ? 0 : 16,
                bottom: compact ? 118 : 126,
                child: Image.asset(
                  stage == MomLifeStage.pregnancy
                      ? _MeBabyOverviewAssets.pregnancyAvatar
                      : _MeBabyOverviewAssets.momAvatar,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: constraints.maxHeight * (compact ? 0.34 : 0.38),
                bottom: compact ? 92 : 116,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xc7000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: compact ? 170 : 214,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _MeBabyOverviewColors.wine,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          chipLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      program.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 24 : 29,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProgramProgress(value: program.progress, light: true),
                    const SizedBox(height: 8),
                    Text(
                      program.progressLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _BodyProfileButton(compact: true),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  children: [
                    Semantics(
                      key: const ValueKey('me-baby-overview-close-avatar'),
                      label: 'Show detailed stats',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: SizedBox(
                          height: MomCozyTapTargets.minimum,
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xffd8d8d8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 7),
                              const Text(
                                'Swipe up to see detailed stats',
                                style: TextStyle(
                                  color: _MeBabyOverviewColors.mutedText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    _MomStageTabs(
                      stage: stage,
                      selected: selectedSection,
                      onSelected: onSelected,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _monthName(int month) {
  return const [
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
}

bool _sameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
