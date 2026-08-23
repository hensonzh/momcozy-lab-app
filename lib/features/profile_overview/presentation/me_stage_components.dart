part of 'me_baby_overview_page.dart';

class _MomAvatarImage extends StatefulWidget {
  const _MomAvatarImage({
    required this.fileId,
    required this.fit,
    required this.alignment,
  });

  final String? fileId;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  State<_MomAvatarImage> createState() => _MomAvatarImageState();
}

class _MomAvatarImageState extends State<_MomAvatarImage> {
  Future<Uint8List>? _load;
  Uint8List? _initialBytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant _MomAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) _startLoad();
  }

  void _startLoad() {
    final fileId = widget.fileId?.trim();
    if (fileId == null || fileId.isEmpty) {
      _initialBytes = null;
      _load = null;
      return;
    }
    final repository = MomCozyRuntimeScope.of(context).mediaContentRepository;
    _initialBytes =
        repository.cachedImage(fileId) ??
        repository.cachedImageThumbnail(fileId);
    _load = repository.loadImage(fileId);
  }

  @override
  Widget build(BuildContext context) {
    final load = _load;
    if (load == null) return _defaultAvatar();
    return FutureBuilder<Uint8List>(
      future: load,
      initialData: _initialBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data ?? _initialBytes;
        if (bytes == null) {
          return const _CustomAvatarPlaceholder(
            key: ValueKey('mom-custom-avatar-placeholder'),
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
        );
      },
    );
  }

  Widget _defaultAvatar() {
    return Image.asset(
      _MeBabyOverviewAssets.postpartumAvatar,
      fit: widget.fit,
      alignment: widget.alignment,
    );
  }
}

class _CustomAvatarPlaceholder extends StatelessWidget {
  const _CustomAvatarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14B15B74), Color(0x2E932C4A)],
        ),
      ),
      child: Center(
        child: SizedBox.square(
          dimension: 76,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(width: 2, color: Color(0x99932C4A)),
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 62,
              color: Color(0x66932C4A),
            ),
          ),
        ),
      ),
    );
  }
}

class _MomPostpartumWorkspace extends StatelessWidget {
  const _MomPostpartumWorkspace({
    required this.data,
    required this.selectedSection,
    required this.onSelected,
    required this.onOpenAvatar,
  });

  final _MeBabyOverviewData data;
  final String selectedSection;
  final ValueChanged<String> onSelected;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    final showAvatar = MediaQuery.textScalerOf(context).scale(1) <= 1.35;
    final avatarFileId = data.activeAvatarFileId;
    final hasCustomAvatar = avatarFileId?.trim().isNotEmpty == true;
    final avatarTop = hasCustomAvatar ? 4.0 : -18.0;
    final avatarHeight = hasCustomAvatar ? 282.0 : 304.0;
    return Column(
      key: const ValueKey('me-postpartum-workspace'),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _MomPostpartumHero(
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
                    child: _MomPostpartumTabs(
                      selected: selectedSection,
                      onSelected: onSelected,
                    ),
                  ),
                const SizedBox(height: 10),
                _PostpartumPageIndicator(
                  selected: selectedSection == 'recovery' ? 1 : 0,
                ),
              ],
            ),
            if (showAvatar)
              Positioned(
                right: -18,
                top: avatarTop,
                width: 210,
                height: avatarHeight,
                child: IgnorePointer(
                  key: const ValueKey('me-postpartum-avatar'),
                  child: _MomAvatarImage(
                    fileId: avatarFileId,
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
                child: _MomPostpartumTabs(
                  selected: selectedSection,
                  onSelected: onSelected,
                ),
              ),
          ],
        ),
        const SizedBox(height: 21),
        _MeContent(section: selectedSection, data: data),
      ],
    );
  }
}

class _MomPostpartumHero extends StatelessWidget {
  const _MomPostpartumHero({required this.data, required this.onOpenAvatar});

  final _MeBabyOverviewData data;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    final program = _postpartumProgram(data);
    final expandedText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    return Semantics(
      key: const ValueKey('me-baby-overview-open-avatar'),
      label: 'View postpartum avatar',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenAvatar,
        child: SizedBox(
          key: const ValueKey('me-postpartum-hero'),
          height: expandedText ? 326 : 186,
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
                        key: const ValueKey('me-postpartum-program-title'),
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
            key: const ValueKey('me-postpartum-body-profile'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.go('/more/body-profile'),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Ink(
                key: const ValueKey('me-postpartum-body-profile-surface'),
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

class _PostpartumProgram {
  const _PostpartumProgram({
    required this.title,
    required this.progressLabel,
    required this.progress,
  });

  final String title;
  final String progressLabel;
  final double? progress;
}

_PostpartumProgram _postpartumProgram(_MeBabyOverviewData data) {
  final dashboard = data.plans.data;
  final plans = dashboard?.plans ?? const <CarePlan>[];
  final authoritative = data.maternalCareOverview.data?.program;
  if (authoritative != null) {
    final total = authoritative.totalSessions;
    return _PostpartumProgram(
      title: authoritative.title,
      progressLabel: total == 0
          ? 'No sessions scheduled yet'
          : '${authoritative.completedSessions} of $total sessions completed',
      progress: total == 0 ? null : authoritative.completedSessions / total,
    );
  }

  CarePlan? selected = plans
      .where((plan) => plan.category == PlanCategory.pelvicFloor)
      .firstOrNull;
  selected ??= plans
      .where((plan) => plan.category == PlanCategory.yoga)
      .firstOrNull;
  if (selected == null) {
    final loading =
        data.plans.phase == OverviewResourcePhase.initial ||
        data.plans.phase == OverviewResourcePhase.loading;
    return _PostpartumProgram(
      title: 'Postpartum Recovery',
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
  return _PostpartumProgram(
    title: selected.title,
    progressLabel: total == 0
        ? 'Open Plan to view sessions'
        : '$completed of $total sessions completed',
    progress: total == 0 ? null : completed / total,
  );
}

class _MomPostpartumTabs extends StatelessWidget {
  const _MomPostpartumTabs({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const sections = [
      ('lactation', 'Lactation', Icons.water_drop_outlined),
      ('recovery', 'Recovery', Icons.accessibility_new_rounded),
    ];
    return SizedBox(
      key: const ValueKey('me-postpartum-tabs'),
      height: 48,
      child: Row(
        children: [
          for (var index = 0; index < sections.length; index += 1) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: _MomPostpartumTab(
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

class _MomPostpartumTab extends StatelessWidget {
  const _MomPostpartumTab({
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
              key: ValueKey('me-postpartum-tab-surface-$section'),
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

class _PostpartumPageIndicator extends StatelessWidget {
  const _PostpartumPageIndicator({required this.selected});

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
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: _MeBabyOverviewColors.mutedText,
                      size: 28,
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

class _MomPostpartumAvatarStage extends StatelessWidget {
  const _MomPostpartumAvatarStage({
    required this.data,
    required this.selectedSection,
    required this.onClose,
    required this.onSelected,
  });

  final _MeBabyOverviewData data;
  final String selectedSection;
  final VoidCallback onClose;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final program = _postpartumProgram(data);
    return ColoredBox(
      color: _MeBabyOverviewColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 680;
          return Stack(
            children: [
              Positioned.fill(
                bottom: compact ? 92 : 116,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xfffbf5f3), Color(0xfff2e8e5)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -4,
                right: -4,
                top: compact ? 0 : 16,
                bottom: compact ? 118 : 126,
                child: _MomAvatarImage(
                  fileId: data.activeAvatarFileId,
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          'Postpartum',
                          style: TextStyle(
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
                    _MomPostpartumTabs(
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

bool _sameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
