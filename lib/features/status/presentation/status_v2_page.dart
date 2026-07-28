import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_selection.dart';

class StatusV2Page extends StatefulWidget {
  const StatusV2Page({super.key, required this.path, required this.identity});

  final String path;
  final StatusIdentity identity;

  @override
  State<StatusV2Page> createState() => _StatusV2PageState();
}

class _StatusV2PageState extends State<StatusV2Page>
    with SingleTickerProviderStateMixin {
  static const _settleDuration = Duration(milliseconds: 320);
  static const _dragThreshold = 0.12;

  late final AnimationController _detailsPosition = AnimationController(
    vsync: this,
    duration: _settleDuration,
  );
  late final ScrollController _detailsScroll = ScrollController();
  late String _section = _initialSection(widget.identity);
  double _bodyHeight = 1;
  double _pointerStartY = 0;
  double _positionAtPointerDown = 0;
  bool _trackingSheetDrag = false;
  bool _showAvatarLayer = false;
  bool _avatarExpanded = false;

  @override
  void didUpdateWidget(covariant StatusV2Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity == widget.identity) return;
    _section = _initialSection(widget.identity);
    _detailsPosition.value = 0;
    _showAvatarLayer = false;
    _avatarExpanded = false;
    if (_detailsScroll.hasClients) _detailsScroll.jumpTo(0);
  }

  @override
  void dispose() {
    _detailsPosition.dispose();
    _detailsScroll.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final position = _detailsPosition.value;
    final detailsAtTop =
        !_detailsScroll.hasClients || _detailsScroll.position.pixels <= 0.5;
    final canOpenAvatar = position <= 0.001 && detailsAtTop;
    final canCloseAvatar = position >= 0.999;
    if (!canOpenAvatar && !canCloseAvatar) return;

    _pointerStartY = event.localPosition.dy;
    _positionAtPointerDown = position;
    _trackingSheetDrag = true;
    if (!_showAvatarLayer) {
      setState(() => _showAvatarLayer = true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_trackingSheetDrag) return;
    final delta = event.localPosition.dy - _pointerStartY;
    if (_positionAtPointerDown <= 0.001 && delta < 0) return;
    if (_positionAtPointerDown >= 0.999 && delta > 0) return;
    _detailsPosition.value = (_positionAtPointerDown + delta / _bodyHeight)
        .clamp(0.0, 1.0);
  }

  void _handlePointerEnd() {
    if (!_trackingSheetDrag) return;
    _trackingSheetDrag = false;
    final openedFromDetails = _positionAtPointerDown <= 0.001;
    final target = openedFromDetails
        ? (_detailsPosition.value >= _dragThreshold ? 1.0 : 0.0)
        : (_detailsPosition.value <= 1 - _dragThreshold ? 0.0 : 1.0);
    _settleDetails(target);
  }

  void _settleDetails(double target) {
    final showExpanded = target == 1;
    setState(() {
      _avatarExpanded = showExpanded;
      if (showExpanded) _showAvatarLayer = true;
    });
    _detailsPosition.animateTo(target, curve: Curves.easeOutCubic).then((_) {
      if (!mounted || target != 0 || _avatarExpanded) return;
      setState(() => _showAvatarLayer = false);
    });
  }

  void _selectSection(String section, {bool revealDetails = false}) {
    setState(() => _section = section);
    if (revealDetails) _settleDetails(0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 70),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _bodyHeight = math.max(1, constraints.maxHeight);
                  return Listener(
                    key: const ValueKey('status-v2-avatar-gesture-area'),
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: (_) => _handlePointerEnd(),
                    onPointerCancel: (_) => _handlePointerEnd(),
                    child: Stack(
                      children: [
                        if (_showAvatarLayer)
                          Positioned.fill(
                            child: _AvatarStage(
                              identity: widget.identity,
                              selectedSection: _section,
                              onSelected: (section) =>
                                  _selectSection(section, revealDetails: true),
                            ),
                          ),
                        AnimatedBuilder(
                          animation: _detailsPosition,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                _detailsPosition.value * constraints.maxHeight,
                              ),
                              child: IgnorePointer(
                                ignoring: _detailsPosition.value > 0.98,
                                child: child,
                              ),
                            );
                          },
                          child: ColoredBox(
                            color: _StatusV2Colors.background,
                            child: ListView(
                              key: ValueKey('route-page-${widget.path}'),
                              controller: _detailsScroll,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                4,
                                12,
                                112,
                              ),
                              children: [
                                _ProfileHero(identity: widget.identity),
                                const SizedBox(height: 14),
                                _SectionTabs(
                                  identity: widget.identity,
                                  selected: _section,
                                  onSelected: _selectSection,
                                ),
                                const SizedBox(height: 14),
                                if (widget.identity == StatusIdentity.mom)
                                  _MeContent(section: _section)
                                else
                                  _BabyContent(section: _section),
                              ],
                            ),
                          ),
                        ),
                        if (_avatarExpanded)
                          const SizedBox(
                            key: ValueKey('status-v2-avatar-expanded'),
                          ),
                        AnimatedPositioned(
                          duration: _settleDuration,
                          curve: Curves.easeOutCubic,
                          right: 18,
                          bottom: _avatarExpanded ? 104 : 18,
                          child: const _DisabledCircleAction(
                            actionKey: ValueKey('status-v2-add-disabled'),
                            semanticLabel: 'Add is not available yet',
                            icon: Icons.add_rounded,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ColoredBox(
            color: _StatusV2Colors.background,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _StatusV2Header(identity: widget.identity),
            ),
          ),
        ),
      ],
    );
  }
}

String _initialSection(StatusIdentity identity) {
  return identity == StatusIdentity.mom ? 'lactation' : 'monitor';
}

class _StatusV2Header extends StatelessWidget {
  const _StatusV2Header({required this.identity});

  final StatusIdentity identity;

  @override
  Widget build(BuildContext context) {
    final label = identity == StatusIdentity.mom
        ? 'Postpartum Recovery'
        : 'Infant';
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const _MomCozyWordmark(),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: '$label, fixed profile',
              enabled: false,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _StatusV2Colors.pill,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: _StatusV2Colors.wine,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 8),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _StatusV2Colors.wine,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _StatusV2Colors.wine,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _DisabledCircleAction(
            actionKey: ValueKey('status-v2-notification-disabled'),
            semanticLabel: 'Notifications are not available yet',
            icon: Icons.notifications_none_rounded,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _MomCozyWordmark extends StatelessWidget {
  const _MomCozyWordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _StatusV2Colors.wine,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 10),
        ),
        SizedBox(width: 7),
        Text(
          'momcozy',
          style: TextStyle(
            color: _StatusV2Colors.ink,
            fontSize: 25,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.identity});

  final StatusIdentity identity;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == StatusIdentity.mom;
    return Container(
      key: ValueKey(isMom ? 'me-profile-hero' : 'baby-profile-hero'),
      height: 246,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _StatusV2Colors.hero,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: isMom ? -18 : -8,
            top: isMom ? 4 : 16,
            bottom: isMom ? -38 : -30,
            width: isMom ? 205 : 190,
            child: IgnorePointer(
              child: Image.asset(
                isMom ? _StatusV2Assets.momAvatar : _StatusV2Assets.babyAvatar,
                alignment: Alignment.bottomCenter,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: isMom ? 68 : 72,
            width: isMom ? 238 : 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMom)
                  const Text(
                    'Good morning,',
                    style: TextStyle(
                      color: _StatusV2Colors.ink,
                      fontSize: 28,
                      height: 0.98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                Text(
                  isMom ? 'Sophia' : 'Baby Emma',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _StatusV2Colors.ink,
                    fontSize: isMom ? 38 : 31,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                if (!isMom) ...[
                  const SizedBox(height: 7),
                  const Text(
                    '3 months 2 weeks',
                    style: TextStyle(
                      color: _StatusV2Colors.mutedText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: isMom
                      ? const _CelebrationText(
                          label: 'Weekly milk goal reached',
                        )
                      : const Text(
                          'I had enough milk today ✓',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _StatusV2Colors.ink,
                            fontSize: 14,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
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

class _CelebrationText extends StatelessWidget {
  const _CelebrationText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _StatusV2Colors.ink,
              fontSize: 14,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Icon(
          Icons.celebration_rounded,
          color: _StatusV2Colors.wine,
          size: 17,
        ),
      ],
    );
  }
}

class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.identity,
    required this.selectedSection,
    required this.onSelected,
  });

  final StatusIdentity identity;
  final String selectedSection;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == StatusIdentity.mom;
    return ColoredBox(
      color: _StatusV2Colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 620;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: isMom ? 18 : 24,
                top: compact ? 24 : 54,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMom ? 'Good morning,\nSophia' : 'Baby Emma',
                      style: TextStyle(
                        color: _StatusV2Colors.ink,
                        fontSize: compact ? 30 : 36,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isMom)
                      const Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Your avatar is looking strong today!',
                              style: TextStyle(
                                color: _StatusV2Colors.mutedText,
                                fontSize: 17,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: _StatusV2Colors.wine,
                            size: 18,
                          ),
                        ],
                      )
                    else
                      Text(
                        '3 months 2 weeks',
                        style: TextStyle(
                          color: _StatusV2Colors.mutedText,
                          fontSize: compact ? 15 : 17,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: isMom ? -18 : -32,
                top: isMom ? (compact ? 60 : 90) : (compact ? 24 : 42),
                width: isMom
                    ? math.min(constraints.maxWidth * 0.85, 360)
                    : math.min(constraints.maxWidth * 0.83, 315),
                height: compact
                    ? constraints.maxHeight * 0.67
                    : constraints.maxHeight * 0.74,
                child: Image.asset(
                  isMom
                      ? _StatusV2Assets.momAvatar
                      : _StatusV2Assets.babyAvatarFull,
                  alignment: Alignment.bottomCenter,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                left: 18,
                bottom: compact ? 126 : 151,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.62,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: isMom
                      ? const _CelebrationText(
                          label: 'Weekly milk goal reached',
                        )
                      : const Text(
                          'I slept 14.2h today ✓',
                          style: TextStyle(
                            color: _StatusV2Colors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 18,
                child: Column(
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
                        color: _StatusV2Colors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _SectionTabs(
                      identity: identity,
                      selected: selectedSection,
                      onSelected: onSelected,
                      compact: true,
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

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.identity,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final StatusIdentity identity;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sections = identity == StatusIdentity.mom
        ? const [('lactation', 'Lactation'), ('recovery', 'Recovery')]
        : const [
            ('monitor', 'Monitor'),
            ('sleep', 'Sleep'),
            ('feeding', 'Feeding'),
            ('diaper', 'Diaper'),
            ('growth', 'Growth'),
          ];
    return Row(
      children: [
        for (var index = 0; index < sections.length; index += 1) ...[
          if (index > 0) SizedBox(width: compact ? 5 : 7),
          Expanded(
            child: _SectionTab(
              section: sections[index].$1,
              label: sections[index].$2,
              selected: selected == sections[index].$1,
              prefix: identity == StatusIdentity.mom ? 'me' : 'baby',
              onTap: () => onSelected(sections[index].$1),
              compact: compact,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.section,
    required this.label,
    required this.selected,
    required this.prefix,
    required this.onTap,
    required this.compact,
  });

  final String section;
  final String label;
  final bool selected;
  final String prefix;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        key: ValueKey('$prefix-section-$section'),
        color: selected ? _StatusV2Colors.ink : _StatusV2Colors.pill,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: SizedBox(
            height: compact ? 40 : 48,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _StatusV2Colors.ink,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeContent extends StatelessWidget {
  const _MeContent({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return section == 'recovery'
        ? const _MeRecoveryContent()
        : const _MeLactationContent();
  }
}

class _MeLactationContent extends StatelessWidget {
  const _MeLactationContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _V2Card(
          cardKey: ValueKey('me-todays-milk-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _StatusV2Colors.wine,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 14),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text('Today’s Milk', style: _StatusV2Text.cardTitle),
                  ),
                  Image(
                    image: AssetImage(_StatusV2Assets.milkBottle),
                    width: 58,
                    height: 58,
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('473', style: _StatusV2Text.heroMetric),
                    SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: Text(
                        'ml / 600 ml',
                        style: _StatusV2Text.metricSuffix,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              _ProgressBar(value: 0.79),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '79% of daily goal · Keep going!',
                        style: _StatusV2Text.supporting,
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.celebration_rounded,
                    color: _StatusV2Colors.wine,
                    size: 16,
                  ),
                ],
              ),
              SizedBox(height: 14),
              _FixedLineChart(
                values: [0.25, 0.38, 0.52, 0.44, 0.72, 0.88, 0.95],
                labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
              ),
              Divider(color: _StatusV2Colors.line, height: 26),
              _ConnectDeviceRow(),
            ],
          ),
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Breast',
          subtitle: 'AI self-check · Care',
          actionLabel: 'Check now',
          asset: _StatusV2Assets.breast,
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Lactation',
          subtitle: 'AI feeding guide',
          actionLabel: 'Start',
          asset: _StatusV2Assets.lactation,
        ),
      ],
    );
  }
}

class _MeRecoveryContent extends StatelessWidget {
  const _MeRecoveryContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recovery Score', style: _StatusV2Text.cardTitle),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('78', style: _StatusV2Text.heroMetric),
                        Padding(
                          padding: EdgeInsets.only(bottom: 7, left: 6),
                          child: Text(
                            '/100',
                            style: _StatusV2Text.metricSuffix,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 94,
                    height: 94,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 0.78,
                          strokeWidth: 12,
                          backgroundColor: _StatusV2Colors.line,
                          color: _StatusV2Colors.wine,
                        ),
                        Text(
                          '78%',
                          style: TextStyle(
                            color: _StatusV2Colors.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _StatusV2Colors.pill,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    '↑ 4 vs last week',
                    style: TextStyle(
                      color: _StatusV2Colors.wine,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15),
              _FixedLineChart(
                values: [0.2, 0.38, 0.28, 0.57, 0.68, 0.82, 0.92],
                labels: ['T', 'W', 'T', 'F', 'S', 'S', 'M'],
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Body Assessment',
          subtitle: 'AI postpartum check',
          actionLabel: 'Start',
          asset: _StatusV2Assets.bodyAssessment,
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Yoga',
          subtitle: 'Recovery exercises',
          actionLabel: 'Start',
          asset: _StatusV2Assets.yoga,
        ),
      ],
    );
  }
}

class _BabyContent extends StatelessWidget {
  const _BabyContent({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      'sleep' => const _BabySleepContent(),
      'feeding' => const _BabyFeedingContent(),
      'diaper' => const _BabyDiaperContent(),
      'growth' => const _BabyGrowthContent(),
      _ => const _BabyMonitorContent(),
    };
  }
}

class _BabyMonitorContent extends StatelessWidget {
  const _BabyMonitorContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(22)),
                child: Image(
                  image: AssetImage(_StatusV2Assets.nurseryCamera),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Nursery Camera',
                      style: _StatusV2Text.cardTitle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        children: [
                          Text(
                            '24°C',
                            style: TextStyle(
                              color: _StatusV2Colors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text('Temp', style: _StatusV2Text.supporting),
                          SizedBox(width: 12),
                          Text(
                            '58%',
                            style: TextStyle(
                              color: _StatusV2Colors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text('Humidity', style: _StatusV2Text.supporting),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent Activity', style: _StatusV2Text.cardTitle),
              SizedBox(height: 14),
              _ActivityRow(
                icon: Icons.rotate_left_rounded,
                label: 'Rolled over',
                time: '5 min ago',
              ),
              SizedBox(height: 12),
              _ActivityRow(
                icon: Icons.visibility_outlined,
                label: 'Brief awakening',
                time: '12 min ago',
              ),
              SizedBox(height: 12),
              _ActivityRow(
                icon: Icons.bedtime_outlined,
                label: 'Fell back asleep',
                time: '10 min ago',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BabySleepContent extends StatelessWidget {
  const _BabySleepContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoundIcon(icon: Icons.bedtime_outlined),
                  SizedBox(width: 12),
                  Text('Total Sleep Today', style: _StatusV2Text.cardTitle),
                ],
              ),
              SizedBox(height: 16),
              Text('14.2 h', style: _StatusV2Text.heroMetric),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '79% of daily goal · Keep going!',
                    style: _StatusV2Text.supporting,
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.celebration_rounded,
                    color: _StatusV2Colors.wine,
                    size: 16,
                  ),
                ],
              ),
              SizedBox(height: 12),
              _StatusBadge(label: 'Currently Sleeping'),
            ],
          ),
        ),
        SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sleep Pattern Today',
                      style: _StatusV2Text.cardTitle,
                    ),
                  ),
                  Text(
                    '3 naps',
                    style: TextStyle(
                      color: _StatusV2Colors.wine,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _SleepTimeline(),
              SizedBox(height: 12),
              Text(
                '●  Deep     ●  Light     ●  Awake',
                style: _StatusV2Text.supporting,
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep Trend & Prediction', style: _StatusV2Text.cardTitle),
              SizedBox(height: 16),
              _PredictionRow(label: 'Next wake window: ~4:00 - 5:30 PM'),
              SizedBox(height: 14),
              _PredictionRow(label: 'Predicted wake: ~2:30 PM'),
              SizedBox(height: 14),
              _StatusBadge(label: 'Optimal'),
            ],
          ),
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Sleep Training',
          subtitle: 'AI sleep coaching',
          actionLabel: 'Start',
          asset: _StatusV2Assets.sleepTraining,
        ),
      ],
    );
  }
}

class _BabyFeedingContent extends StatelessWidget {
  const _BabyFeedingContent();

  static const _feeds = [
    ('6:30 AM', 'Breast, Left', '90 ml', '15 min'),
    ('9:00 AM', 'Breast, Right', '85 ml', '12 min'),
    ('11:30 AM', 'Bottle, Formula', '120 ml', 'Formula'),
    ('2:00 PM', 'Breast, Left', '100 ml', '18 min'),
    ('4:30 PM', 'Bottle, Expressed', '125 ml', 'Breastmilk'),
    ('7:00 PM', 'Breast, Right', '90 ml', '15 min'),
    ('9:30 PM', 'Bottle, Formula', '120 ml', 'Formula'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _V2Card(
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0.9,
                      strokeWidth: 8,
                      backgroundColor: _StatusV2Colors.line,
                      color: _StatusV2Colors.wine,
                    ),
                    Text(
                      '90%',
                      style: TextStyle(
                        color: _StatusV2Colors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s Target Achieved',
                      style: _StatusV2Text.cardTitle,
                    ),
                    SizedBox(height: 5),
                    Text(
                      '6 feeds completed · 730 ml out of 800 ml',
                      style: _StatusV2Text.supporting,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today’s Feeds', style: _StatusV2Text.cardTitle),
              const SizedBox(height: 10),
              for (var index = 0; index < _feeds.length; index += 1) ...[
                _FeedRow(feed: _feeds[index]),
                if (index < _feeds.length - 1)
                  const Divider(color: _StatusV2Colors.line, height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly Intake Trend', style: _StatusV2Text.cardTitle),
              SizedBox(height: 16),
              _WeeklyBars(
                values: [680, 720, 650, 710, 730, 690, 720],
                maxValue: 800,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BabyDiaperContent extends StatelessWidget {
  const _BabyDiaperContent();

  static const _entries = [
    (
      Icons.auto_awesome_rounded,
      'Both (Wet + Dirty)',
      'Medium amount, gold color',
      '8:15 PM',
    ),
    (
      Icons.water_drop_outlined,
      'Wet Only',
      'Very heavy, changed immediately',
      '5:00 PM',
    ),
    (
      Icons.water_drop_outlined,
      'Wet Only',
      'Light change after nap',
      '1:30 PM',
    ),
    (
      Icons.baby_changing_station_outlined,
      'Dirty Only',
      'Normal stool consistency',
      '10:15 AM',
    ),
    (Icons.water_drop_outlined, 'Wet Only', 'Heavy morning change', '7:00 AM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TODAY’S SUMMARY', style: _StatusV2Text.eyebrow),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text('7 changes', style: _StatusV2Text.heroMetric),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: Text(
                        'Normal daily frequency',
                        textAlign: TextAlign.right,
                        style: _StatusV2Text.supporting,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DiaperCount(
                      icon: Icons.water_drop_outlined,
                      value: '5 Wet',
                      subtitle: 'Hydrated & active',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _DiaperCount(
                      icon: Icons.baby_changing_station_outlined,
                      value: '2 Dirty',
                      subtitle: 'Regular digestion',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Diaper Timeline', style: _StatusV2Text.cardTitle),
              const SizedBox(height: 10),
              for (var index = 0; index < _entries.length; index += 1) ...[
                _DiaperEntry(entry: _entries[index]),
                if (index < _entries.length - 1)
                  const Divider(color: _StatusV2Colors.line, height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Overview (Total Changes)',
                style: _StatusV2Text.cardTitle,
              ),
              SizedBox(height: 16),
              _WeeklyBars(values: [6, 8, 7, 7, 9, 6, 7], maxValue: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _BabyGrowthContent extends StatelessWidget {
  const _BabyGrowthContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _GrowthMetric(
                label: 'Weight',
                value: '6.2 kg',
                percentile: 'P55 (Normal)',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _GrowthMetric(
                label: 'Height',
                value: '62 cm',
                percentile: 'P60 (Normal)',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _GrowthMetric(
                label: 'Head',
                value: '40.5 cm',
                percentile: 'P50 (Normal)',
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        _GrowthCurveCard(title: 'WHO Weight Curve'),
        SizedBox(height: 14),
        _GrowthCurveCard(title: 'WHO Height Curve'),
        SizedBox(height: 14),
        _GrowthCurveCard(title: 'WHO Head Circ. Curve'),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.asset,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      child: Row(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: _StatusV2Colors.pill,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _StatusV2Text.cardTitle),
                const SizedBox(height: 5),
                Text(subtitle, style: _StatusV2Text.supporting),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: _StatusV2Colors.ink,
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: _StatusV2Colors.pill,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: _StatusV2Colors.wine,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.time,
  });

  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: _StatusV2Colors.pill,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: _StatusV2Colors.wine, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _StatusV2Colors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(time, style: _StatusV2Text.supporting),
      ],
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _RoundIcon(icon: Icons.schedule_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _StatusV2Colors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _StatusV2Colors.pill,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: _StatusV2Colors.wine, size: 22),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffc9f6df),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xff00694d),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SleepTimeline extends StatelessWidget {
  const _SleepTimeline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(flex: 2, child: ColoredBox(color: Color(0xff862644))),
                Expanded(flex: 2, child: ColoredBox(color: Color(0xffe8d9d6))),
                Expanded(child: ColoredBox(color: Color(0xfff3eae7))),
                Expanded(flex: 3, child: ColoredBox(color: Color(0xff862644))),
                Expanded(flex: 7, child: ColoredBox(color: Color(0xffe8d9d6))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('12am', style: _StatusV2Text.supporting),
            Text('3am', style: _StatusV2Text.supporting),
            Text('6am', style: _StatusV2Text.supporting),
            Text('9am', style: _StatusV2Text.supporting),
            Text('12pm', style: _StatusV2Text.supporting),
            Text('3pm', style: _StatusV2Text.supporting),
            Text(
              'Now',
              style: TextStyle(
                color: _StatusV2Colors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.feed});

  final (String, String, String, String) feed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _RoundIcon(icon: Icons.favorite_border_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feed.$1,
                style: const TextStyle(
                  color: _StatusV2Colors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(feed.$2, style: _StatusV2Text.supporting),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              feed.$3,
              style: const TextStyle(
                color: _StatusV2Colors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(feed.$4, style: _StatusV2Text.supporting),
          ],
        ),
      ],
    );
  }
}

class _DiaperCount extends StatelessWidget {
  const _DiaperCount({
    required this.icon,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _StatusV2Colors.background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _StatusV2Colors.wine, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: _StatusV2Colors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: _StatusV2Text.supporting),
          ],
        ),
      ),
    );
  }
}

class _DiaperEntry extends StatelessWidget {
  const _DiaperEntry({required this.entry});

  final (IconData, String, String, String) entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(entry.$1, color: _StatusV2Colors.wine, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.$2,
                style: const TextStyle(
                  color: _StatusV2Colors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(entry.$3, style: _StatusV2Text.supporting),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(entry.$4, style: _StatusV2Text.supporting),
      ],
    );
  }
}

class _GrowthMetric extends StatelessWidget {
  const _GrowthMetric({
    required this.label,
    required this.value,
    required this.percentile,
  });

  final String label;
  final String value;
  final String percentile;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _StatusV2Text.supporting),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: _StatusV2Colors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _StatusV2Colors.pill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  percentile,
                  style: const TextStyle(
                    color: _StatusV2Colors.wine,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _GrowthCurveCard extends StatelessWidget {
  const _GrowthCurveCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: _StatusV2Text.cardTitle)),
              const Text('25%-75% Band', style: _StatusV2Text.supporting),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 126,
            width: double.infinity,
            child: CustomPaint(painter: _GrowthCurvePainter()),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Birth', style: _StatusV2Text.supporting),
              Text('2 Mos', style: _StatusV2Text.supporting),
              Text('3.5 Mos', style: _StatusV2Text.supporting),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: _StatusV2Colors.line,
        color: _StatusV2Colors.wine,
      ),
    );
  }
}

class _ConnectDeviceRow extends StatelessWidget {
  const _ConnectDeviceRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.bluetooth_rounded, color: _StatusV2Colors.mutedText),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Connect Device',
            style: TextStyle(
              color: _StatusV2Colors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: _StatusV2Colors.mutedText),
      ],
    );
  }
}

class _FixedLineChart extends StatelessWidget {
  const _FixedLineChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Column(
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(painter: _LineChartPainter(values)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in labels)
                Text(label, style: _StatusV2Text.supporting),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.values, required this.maxValue});

  final List<int> values;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 124,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index += 1)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${values[index]}', style: _StatusV2Text.supporting),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: 68 * values[index] / maxValue,
                    decoration: const BoxDecoration(
                      color: _StatusV2Colors.wine,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(labels[index], style: _StatusV2Text.supporting),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _V2Card extends StatelessWidget {
  const _V2Card({
    required this.child,
    this.cardKey,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Key? cardKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DisabledCircleAction extends StatelessWidget {
  const _DisabledCircleAction({
    required this.actionKey,
    required this.semanticLabel,
    required this.icon,
    this.compact = false,
  });

  final Key actionKey;
  final String semanticLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 62.0;
    return Semantics(
      key: actionKey,
      label: semanticLabel,
      enabled: false,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: compact ? _StatusV2Colors.pill : _StatusV2Colors.ink,
          shape: BoxShape.circle,
          boxShadow: compact
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x29000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: compact ? _StatusV2Colors.wine : Colors.white,
          size: compact ? 24 : 32,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final line = Path();
    final fill = Path();
    for (var index = 0; index < values.length; index += 1) {
      final x = index / (values.length - 1) * size.width;
      final y = size.height - values[index].clamp(0, 1) * (size.height - 6);
      if (index == 0) {
        line.moveTo(x, y);
        fill
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    fill
      ..addPath(line, Offset.zero)
      ..lineTo(size.width, size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33862644), Color(0x00862644)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = _StatusV2Colors.wine
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _GrowthCurvePainter extends CustomPainter {
  const _GrowthCurvePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()..color = _StatusV2Colors.hero;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 4, size.width, size.height - 8),
        const Radius.circular(18),
      ),
      bandPaint,
    );
    final guidePaint = Paint()
      ..color = _StatusV2Colors.mutedText
      ..strokeWidth = 1;
    for (final y in [size.height * 0.38, size.height * 0.78]) {
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), guidePaint);
      }
    }
    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.58,
        size.width * 0.42,
        size.height * 0.32,
        size.width * 0.58,
        size.height * 0.23,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.15,
        size.width * 0.88,
        size.height * 0.12,
        size.width,
        size.height * 0.06,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _StatusV2Colors.wine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final point in [
      Offset(size.width * 0.28, size.height * 0.53),
      Offset(size.width * 0.58, size.height * 0.23),
      Offset(size.width * 0.92, size.height * 0.09),
    ]) {
      canvas
        ..drawCircle(point, 6, Paint()..color = Colors.white)
        ..drawCircle(point, 4, Paint()..color = _StatusV2Colors.wine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

abstract final class _StatusV2Assets {
  static const momAvatar = 'assets/images/status_v2/mom_avatar.png';
  static const babyAvatar = 'assets/images/status_v2/baby_avatar.png';
  static const babyAvatarFull = 'assets/images/status_v2/baby_avatar_full.png';
  static const nurseryCamera = 'assets/images/status_v2/nursery_camera.png';
  static const milkBottle = 'assets/images/status_v2/milk_bottle.png';
  static const breast = 'assets/images/status_v2/breast.png';
  static const lactation = 'assets/images/status_v2/lactation.png';
  static const bodyAssessment = 'assets/images/status_v2/body_assessment.png';
  static const yoga = 'assets/images/status_v2/yoga.png';
  static const sleepTraining = 'assets/images/status_v2/sleep_training.png';
}

abstract final class _StatusV2Colors {
  static const background = Color(0xfffbf7f5);
  static const hero = Color(0xfff8efec);
  static const pill = Color(0xfff2e9e6);
  static const wine = Color(0xff862644);
  static const ink = Color(0xff181818);
  static const mutedText = Color(0xffa28f89);
  static const line = Color(0xffeadfdb);
}

abstract final class _StatusV2Text {
  static const cardTitle = TextStyle(
    color: _StatusV2Colors.ink,
    fontSize: 21,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );
  static const heroMetric = TextStyle(
    color: _StatusV2Colors.ink,
    fontSize: 50,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
  );
  static const metricSuffix = TextStyle(
    color: _StatusV2Colors.mutedText,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w600,
  );
  static const supporting = TextStyle(
    color: _StatusV2Colors.mutedText,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const eyebrow = TextStyle(
    color: _StatusV2Colors.mutedText,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
}
