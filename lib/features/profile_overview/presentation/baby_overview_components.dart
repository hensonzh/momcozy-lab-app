part of 'me_baby_overview_page.dart';

class _BabySvgIcon extends StatelessWidget {
  const _BabySvgIcon({
    required this.asset,
    required this.color,
    required this.size,
  });

  final String asset;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class _BabyDevelopmentPage extends StatelessWidget {
  const _BabyDevelopmentPage({
    required this.data,
    required this.onBack,
    required this.onStartEducation,
  });

  final _MeBabyOverviewData data;
  final VoidCallback onBack;
  final VoidCallback onStartEducation;

  @override
  Widget build(BuildContext context) {
    final overview = data.overview;
    final week = _confirmedGestationalWeek(overview.data?.mom?.dueDateOrWeek);
    final isLoading =
        overview.data == null &&
        (overview.phase == OverviewResourcePhase.initial ||
            overview.phase == OverviewResourcePhase.loading);
    final visualizationLabel = isLoading
        ? 'Loading confirmed week'
        : week == null
        ? 'Week not confirmed'
        : 'Week $week Visualization';
    final milestoneTitle = week == null
        ? 'Pregnancy milestones'
        : 'Week $week Milestones';

    return KeyedSubtree(
      key: const ValueKey('route-page-/baby/development'),
      child: ColoredBox(
        color: _BabyOverviewColors.background,
        child: ListView(
          key: const ValueKey('baby-development-page'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: MomCozyTapTargets.minimum,
                  child: IconButton(
                    key: const ValueKey('baby-development-back'),
                    tooltip: 'Back to Baby',
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: _BabyOverviewColors.wine,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Expanded(
                  child: Text(
                    'Baby Development',
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: MomCozyTypography.displayFontFamily,
                      color: _BabyOverviewColors.ink,
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: MomCozyTapTargets.minimum),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              image: true,
              label: visualizationLabel,
              child: AspectRatio(
                aspectRatio: 716 / 440,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        _MeBabyOverviewAssets.babyDevelopment,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 96,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xcc8f796f),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 9,
                              ),
                              child: Text(
                                visualizationLabel,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontFamily:
                                      MomCozyTypography.displayFontFamily,
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                ),
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
            const SizedBox(height: 14),
            _V2Card(
              cardKey: const ValueKey('baby-development-milestones'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 174),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(milestoneTitle, style: _BabyText.cardTitle),
                    const SizedBox(height: 7),
                    const Text(
                      'Milestone guidance unavailable',
                      style: TextStyle(
                        fontFamily: MomCozyTypography.bodyFontFamily,
                        color: _BabyOverviewColors.mutedText,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 34),
                    const _BabyDevelopmentUnavailableRow(
                      icon: Icons.fact_check_outlined,
                      text:
                          'Clinically reviewed milestones are not connected yet.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _V2Card(
              cardKey: const ValueKey('baby-development-prenatal-education'),
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      _MeBabyOverviewAssets.prenatalEducation,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                      semanticLabel: 'Prenatal education illustration',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Prenatal Ed',
                          style: _BabyText.cardTitle,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Personalized education grounded in confirmed details and cited guidance.',
                          style: _BabyText.supporting,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey(
                            'baby-development-start-education',
                          ),
                          onPressed: onStartEducation,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: const Text('Start session'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: _BabyOverviewColors.ink,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontFamily: MomCozyTypography.bodyFontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _V2Card(
              cardKey: const ValueKey('baby-development-size-weight'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Size & Weight', style: _BabyText.cardTitle),
                  const SizedBox(height: 18),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BabyDevelopmentMetric(
                          label: 'Estimated Length',
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: _BabyDevelopmentMetric(
                          label: 'Estimated Weight',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _BabyOverviewColors.pill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.straighten_rounded,
                      color: _BabyOverviewColors.wine,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _BabyOverviewColors.pill,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: _BabyDevelopmentUnavailableRow(
                  icon: Icons.show_chart_rounded,
                  text:
                      'Growth percentile guidance requires a clinically reviewed reference source.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BabyDevelopmentMetric extends StatelessWidget {
  const _BabyDevelopmentMetric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _BabyText.supporting),
        const SizedBox(height: 6),
        const Text(
          'Not available',
          style: TextStyle(
            fontFamily: MomCozyTypography.displayFontFamily,
            color: _BabyOverviewColors.ink,
            fontSize: 19,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BabyDevelopmentUnavailableRow extends StatelessWidget {
  const _BabyDevelopmentUnavailableRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: _BabyOverviewColors.wine, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: _BabyText.supporting)),
      ],
    );
  }
}

int? _confirmedGestationalWeek(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final patterns = [
    RegExp(r'\b(?:week|wk)\s*[:\-]?\s*(\d{1,2})\b', caseSensitive: false),
    RegExp(r'\b(\d{1,2})\s*(?:weeks?|wks?)\b', caseSensitive: false),
    RegExp(r'孕\s*(\d{1,2})\s*周'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(normalized);
    final week = int.tryParse(match?.group(1) ?? '');
    if (week != null && week >= 1 && week <= 42) return week;
  }
  return null;
}

class _BabyProfileHero extends StatelessWidget {
  const _BabyProfileHero({
    required this.data,
    required this.compactForSleep,
    required this.onOpenAvatar,
  });

  final _MeBabyOverviewData data;
  final bool compactForSleep;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('me-baby-overview-open-avatar'),
      label: 'View baby avatar',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenAvatar,
        child: SizedBox(
          key: const ValueKey('baby-profile-hero'),
          height: compactForSleep ? 138 : 175,
          child: Stack(
            clipBehavior: compactForSleep ? Clip.none : Clip.hardEdge,
            children: [
              Positioned(
                left: 6,
                right: 6,
                top: 0,
                height: compactForSleep ? 125 : 156,
                child: DecoratedBox(
                  key: const ValueKey('baby-profile-hero-background'),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _BabyOverviewColors.background,
                        _BabyOverviewColors.pill,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                key: const ValueKey('me-baby-overview-baby-hero-copy'),
                left: 22,
                top: compactForSleep ? 24 : 35,
                right: 178,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.babyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: MomCozyTypography.displayFontFamily,
                        color: _BabyOverviewColors.ink,
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.babyAge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: MomCozyTypography.bodyFontFamily,
                        color: _BabyOverviewColors.mutedText,
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 31,
                      constraints: const BoxConstraints(maxWidth: 190),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0d000000),
                            blurRadius: 16,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.babyAvatarSummary,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: MomCozyTypography.bodyFontFamily,
                            color: _BabyOverviewColors.ink,
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                key: const ValueKey('me-baby-overview-baby-hero-avatar'),
                right: -10,
                top: compactForSleep ? -141 : -105,
                width: compactForSleep ? 198 : 194,
                height: compactForSleep ? 330 : 324,
                child: const IgnorePointer(
                  child: Image(
                    image: AssetImage(_MeBabyOverviewAssets.babyAvatar),
                    fit: BoxFit.contain,
                    semanticLabel: 'Baby avatar',
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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
    );
  }
}

class _BabyAvatarStage extends StatelessWidget {
  const _BabyAvatarStage({
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
    return ColoredBox(
      color: _BabyOverviewColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 700;
          final cardHeight = math.min(
            constraints.maxHeight * (compact ? 0.67 : 0.70),
            538.0,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 16,
                right: 16,
                top: 7,
                height: cardHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _BabyOverviewColors.background,
                        _BabyOverviewColors.pill,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                right: compact ? -8 : 3,
                top: compact ? -37 : -27,
                width: math.min(constraints.maxWidth * 0.88, 378),
                height: math.min(cardHeight * 1.05, 560),
                child: LayoutBuilder(
                  builder: (context, avatarConstraints) {
                    final fullHeight = avatarConstraints.maxHeight;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: avatarConstraints.maxWidth,
                        height: fullHeight * 0.82,
                        child: ClipRect(
                          key: const ValueKey('baby-avatar-name-free-clip'),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: avatarConstraints.maxWidth,
                            maxWidth: avatarConstraints.maxWidth,
                            minHeight: fullHeight,
                            maxHeight: fullHeight,
                            child: Image.asset(
                              _MeBabyOverviewAssets.babyAvatarFull,
                              alignment: Alignment.bottomRight,
                              fit: BoxFit.contain,
                              semanticLabel: 'Baby avatar',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 38,
                top: cardHeight * 0.43 + 3,
                right: constraints.maxWidth * 0.49,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.babyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: MomCozyTypography.displayFontFamily,
                        color: _BabyOverviewColors.ink,
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.babyAge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: MomCozyTypography.bodyFontFamily,
                        color: _BabyOverviewColors.mutedText,
                        fontSize: 14,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 31,
                      constraints: const BoxConstraints(maxWidth: 188),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0d000000),
                            blurRadius: 16,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.babyAvatarSummary,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: MomCozyTypography.bodyFontFamily,
                            color: _BabyOverviewColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 143,
                height: MomCozyTapTargets.minimum,
                child: Semantics(
                  key: const ValueKey('me-baby-overview-close-avatar'),
                  label: 'Show baby data',
                  button: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onClose,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          key: const ValueKey('baby-avatar-handle'),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xffd8d8d8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 97,
                child: _SectionTabs(
                  identity: ProfileIdentity.baby,
                  selected: selectedSection,
                  onSelected: onSelected,
                  compact: true,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: constraints.maxHeight - 86,
                height: 210,
                child: const _AvatarMonitorPreview(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AvatarMonitorPreview extends StatelessWidget {
  const _AvatarMonitorPreview();

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      cardKey: const ValueKey('baby-avatar-monitor-preview'),
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          _MeBabyOverviewAssets.nurseryCamera,
          alignment: Alignment.topCenter,
          fit: BoxFit.cover,
          semanticLabel: 'Nursery camera preview',
        ),
      ),
    );
  }
}

class _BabyContent extends StatelessWidget {
  const _BabyContent({
    required this.section,
    required this.data,
    required this.onOpenDetail,
  });

  final String section;
  final _MeBabyOverviewData data;
  final ValueChanged<_BabyDetail> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      'sleep' => _BabySleepContent(
        onOpenDetail: () => onOpenDetail(_BabyDetail.sleep),
      ),
      'feeding' => _BabyFeedingContent(data: data),
      'diaper' => const _BabyDiaperContent(),
      _ => const _BabyMonitorContent(),
    };
  }
}

class _BabyMonitorContent extends StatelessWidget {
  const _BabyMonitorContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _V2Card(
          cardKey: const ValueKey('baby-monitor-camera-card'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0x806a5f5b),
                        BlendMode.saturation,
                      ),
                      child: Image.asset(
                        _MeBabyOverviewAssets.nurseryCamera,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        semanticLabel: 'Offline nursery camera preview',
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _StatusPill(
                      label: 'OFFLINE',
                      icon: Icons.videocam_off_outlined,
                      background: _BabyOverviewColors.wine,
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Semantics(
                      key: const ValueKey('me-baby-overview-connect-camera'),
                      label: 'Connect nursery camera',
                      button: true,
                      child: SizedBox.square(
                        dimension: MomCozyTapTargets.minimum,
                        child: Center(
                          child: Material(
                            color: _BabyOverviewColors.ink.withValues(
                              alpha: 0.74,
                            ),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => context.go('/device'),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.link_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nursery Camera',
                      style: TextStyle(
                        fontFamily: MomCozyTypography.displayFontFamily,
                        color: _BabyOverviewColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '—°C',
                    style: TextStyle(
                      fontFamily: MomCozyTypography.displayFontFamily,
                      color: _BabyOverviewColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('Temp', style: _BabyText.supportingSmall),
                  SizedBox(width: 14),
                  Text(
                    '—%',
                    style: TextStyle(
                      fontFamily: MomCozyTypography.displayFontFamily,
                      color: _BabyOverviewColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('Humidity', style: _BabyText.supportingSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _V2Card(
          cardKey: ValueKey('baby-monitor-recent-card'),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontFamily: MomCozyTypography.displayFontFamily,
                  color: _BabyOverviewColors.mutedText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              _EmptyInlineState(
                iconAsset: _MeBabyOverviewAssets.clockIcon,
                title: 'No confirmed activity yet',
                description: 'Connect a supported monitor to receive events.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BabySleepContent extends StatelessWidget {
  const _BabySleepContent({required this.onOpenDetail});

  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('baby-sleep-summary-card'),
            borderRadius: BorderRadius.circular(26),
            onTap: onOpenDetail,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 168),
              child: const _V2Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _BabyRoundIcon(
                          iconAsset: _MeBabyOverviewAssets.moonStarIcon,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Total Sleep Today',
                            style: _BabyText.cardTitle,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('— h', style: _BabyText.heroMetric),
                    SizedBox(height: 7),
                    Text(
                      'No sleep data recorded today',
                      style: _BabyText.supporting,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 116),
          child: const _V2Card(
            cardKey: ValueKey('baby-sleep-pattern-card'),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sleep Pattern Today',
                        style: _BabyText.cardTitle,
                      ),
                    ),
                    Text('0 naps', style: _BabyText.accentLabel),
                  ],
                ),
                SizedBox(height: 16),
                _EmptyTimeline(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 143),
          child: const _V2Card(
            cardKey: ValueKey('baby-sleep-trend-card'),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sleep Trend & Prediction', style: _BabyText.cardTitle),
                SizedBox(height: 12),
                _EmptyInlineState(
                  iconAsset: _MeBabyOverviewAssets.clockIcon,
                  title: 'Prediction unavailable',
                  description: 'A confirmed sleep history is required.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _SleepTrainingCard(),
      ],
    );
  }
}

class _BabyFeedingContent extends StatelessWidget {
  const _BabyFeedingContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final feeds = data.feeds;
    final isLoading =
        data.feedingRecords.phase == OverviewResourcePhase.initial ||
        data.feedingRecords.phase == OverviewResourcePhase.loading;
    if (feeds.isEmpty) {
      return _OverviewStateCard(
        title: isLoading ? 'Loading feeding data…' : 'No feeding data yet',
        description: data.feedingRecords.hasError
            ? 'Feeding records could not be refreshed. Try again later.'
            : 'Confirmed feeding records will appear here.',
        icon: isLoading ? Icons.sync_rounded : Icons.restaurant_outlined,
        loading: isLoading,
      );
    }
    return Column(
      children: [
        _V2Card(
          cardKey: const ValueKey('baby-feeding-summary-card'),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 4,
                        backgroundColor: _BabyOverviewColors.line,
                        color: _BabyOverviewColors.wine,
                      ),
                    ),
                    Text(
                      '${feeds.length}',
                      style: const TextStyle(
                        fontFamily: MomCozyTypography.displayFontFamily,
                        color: _BabyOverviewColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today’s Feeding Summary',
                      style: _BabyText.cardTitle,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${feeds.length} confirmed ${feeds.length == 1 ? 'feed' : 'feeds'} · ${data.measuredFeedTotalMl} mL measured',
                      maxLines: 2,
                      style: _BabyText.supporting,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _V2Card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today’s Feeds', style: _BabyText.cardTitle),
              const SizedBox(height: 10),
              for (var index = 0; index < feeds.length; index += 1) ...[
                _FeedRow(feed: _feedRowData(context, feeds[index])),
                if (index < feeds.length - 1)
                  const Divider(color: _BabyOverviewColors.line, height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _V2Card(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diaper Tracker', style: _BabyText.cardTitle),
              SizedBox(height: 10),
              _EmptyInlineState(
                iconAsset: _MeBabyOverviewAssets.babyIcon,
                title: 'No linked diaper data',
                description: 'Diaper records are not available yet.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _V2Card(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly Intake Trend', style: _BabyText.cardTitle),
              SizedBox(height: 10),
              _EmptyInlineState(
                iconAsset: _MeBabyOverviewAssets.activityIcon,
                title: 'Weekly trend unavailable',
                description: 'The current API provides today’s records only.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

(String, String, String, String) _feedRowData(
  BuildContext context,
  FeedingRecord record,
) {
  final occurredAt = record.occurredAt?.toLocal();
  final time = occurredAt == null
      ? 'Time not recorded'
      : MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt));
  final type = switch (record.type.toLowerCase()) {
    'breast' || 'breastfeeding' => 'Breastfeeding',
    'formula' => 'Formula',
    'bottle' => 'Bottle feeding',
    _ => 'Feeding',
  };
  final amount = record.amountMl == null
      ? 'Not measured'
      : '${record.amountMl} mL';
  return (time, type, amount, 'Confirmed record');
}

class _BabyDiaperContent extends StatelessWidget {
  const _BabyDiaperContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _V2Card(
          cardKey: ValueKey('baby-diaper-summary-card'),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 19.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TODAY’S SUMMARY', style: _BabyText.eyebrow),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text('0 changes', style: _BabyText.heroMetric),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: Text(
                        'No diaper data yet',
                        textAlign: TextAlign.right,
                        style: _BabyText.supporting,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DiaperMetric(
                metricKey: ValueKey('baby-diaper-wet-card'),
                iconAsset: _MeBabyOverviewAssets.dropletIcon,
                iconColor: Color(0xff2d9cdb),
                value: '0 Wet',
                subtitle: 'No records',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _DiaperMetric(
                metricKey: ValueKey('baby-diaper-dirty-card'),
                iconAsset: _MeBabyOverviewAssets.babyIcon,
                value: '0 Dirty',
                subtitle: 'No records',
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _V2Card(
          cardKey: ValueKey('baby-diaper-timeline-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diaper Timeline', style: _BabyText.cardTitle),
              SizedBox(height: 12),
              _EmptyInlineState(
                iconAsset: _MeBabyOverviewAssets.clockIcon,
                title: 'No confirmed changes',
                description:
                    'Recorded diaper changes will appear here when the service is connected.',
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Overview (Total Changes)',
                style: _BabyText.cardTitle,
              ),
              SizedBox(height: 12),
              _EmptyTimeline(),
            ],
          ),
        ),
      ],
    );
  }
}

class _BabyDetailPage extends StatelessWidget {
  const _BabyDetailPage({
    required this.detail,
    required this.data,
    required this.onBack,
  });

  final _BabyDetail detail;
  final _MeBabyOverviewData data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (detail) {
      _BabyDetail.feeding => ('Feeding & Care', 'Logs & Summaries'),
      _BabyDetail.diaper => ('Diaper Tracker', 'Logs & Summaries'),
      _BabyDetail.sleep => ('Baby Sleep', 'Rest & Recovery'),
      _BabyDetail.weight => ('Baby Weight', 'Growth Tracking'),
      _BabyDetail.height => ('Baby Height', 'Growth Tracking'),
      _BabyDetail.headCircumference => (
        'Head Circumference',
        'Growth Tracking',
      ),
    };
    return ColoredBox(
      color: _BabyOverviewColors.background,
      child: ListView(
        key: ValueKey('baby-detail-${detail.id}'),
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 28),
        children: [
          _BabyDetailHeader(
            detail: detail,
            title: title,
            subtitle: subtitle,
            onBack: onBack,
          ),
          SizedBox(height: detail == _BabyDetail.feeding ? 8 : 25),
          if (detail == _BabyDetail.feeding)
            _BabyFeedingDetailContent(data: data)
          else if (detail == _BabyDetail.diaper)
            const _BabyDiaperContent()
          else if (detail == _BabyDetail.sleep)
            _BabySleepReportContent(babyName: data.babyName)
          else
            _BabyGrowthDetailContent(detail: detail, data: data),
        ],
      ),
    );
  }
}

extension on _BabyDetail {
  bool get isGrowth => switch (this) {
    _BabyDetail.weight ||
    _BabyDetail.height ||
    _BabyDetail.headCircumference => true,
    _ => false,
  };

  String get id => switch (this) {
    _BabyDetail.feeding => 'feeding',
    _BabyDetail.diaper => 'diaper',
    _BabyDetail.sleep => 'sleep',
    _BabyDetail.weight => 'weight',
    _BabyDetail.height => 'height',
    _BabyDetail.headCircumference => 'head-circumference',
  };
}

class _BabyDetailHeader extends StatelessWidget {
  const _BabyDetailHeader({
    required this.detail,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final _BabyDetail detail;
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          key: ValueKey('baby-detail-back-${detail.id}'),
          label: 'Back',
          button: true,
          child: SizedBox.square(
            dimension: MomCozyTapTargets.minimum,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -1.5),
                    child: SvgPicture.asset(
                      _MeBabyOverviewAssets.backButton,
                      width: 36,
                      height: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: MomCozyTypography.displayFontFamily,
                    color: _BabyOverviewColors.ink,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(subtitle, style: _BabyText.supporting),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          key: const ValueKey('baby-detail-more-disabled'),
          label: 'More actions are not available yet',
          button: false,
          enabled: false,
          child: SizedBox.square(
            dimension: MomCozyTapTargets.minimum,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -1.5),
                child: SvgPicture.asset(
                  _MeBabyOverviewAssets.moreButton,
                  width: 40,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BabyFeedingDetailContent extends StatefulWidget {
  const _BabyFeedingDetailContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  State<_BabyFeedingDetailContent> createState() =>
      _BabyFeedingDetailContentState();
}

class _BabyFeedingDetailContentState extends State<_BabyFeedingDetailContent> {
  String _period = 'day';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailPeriodTabs(
          selected: _period,
          onSelected: (period) => setState(() => _period = period),
        ),
        const SizedBox(height: 17),
        if (_period == 'day')
          _BabyFeedingContent(data: widget.data)
        else
          const _OverviewStateCard(
            title: 'Weekly feeding data unavailable',
            description:
                'The current service provides today’s confirmed records only.',
            icon: Icons.bar_chart_rounded,
          ),
      ],
    );
  }
}

class _DetailPeriodTabs extends StatelessWidget {
  const _DetailPeriodTabs({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MomCozyTapTargets.minimum,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              key: const ValueKey('baby-feeding-period-background'),
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _BabyOverviewColors.line),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                for (final period in const [('day', 'Day'), ('week', 'Week')])
                  Expanded(
                    child: Semantics(
                      key: ValueKey('baby-feeding-period-${period.$1}'),
                      selected: selected == period.$1,
                      button: true,
                      inMutuallyExclusiveGroup: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onSelected(period.$1),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: selected == period.$1
                                    ? _BabyOverviewColors.pill
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: Text(
                                  period.$2,
                                  style: TextStyle(
                                    fontFamily:
                                        MomCozyTypography.bodyFontFamily,
                                    color: selected == period.$1
                                        ? _BabyOverviewColors.wine
                                        : _BabyOverviewColors.mutedText,
                                    fontSize: 16,
                                    fontWeight: selected == period.$1
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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

class _BabySleepReportContent extends StatelessWidget {
  const _BabySleepReportContent({required this.babyName});

  final String babyName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _V2Card(
          cardKey: const ValueKey('baby-sleep-last-night-card'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("LAST NIGHT'S SLEEP", style: _BabyText.eyebrow),
              const SizedBox(height: 7),
              const Row(
                children: [
                  Expanded(
                    child: Text('— hours', style: _BabyText.detailMetric),
                  ),
                  _WineBadge(label: 'No data'),
                ],
              ),
              const Divider(color: _BabyOverviewColors.line, height: 12),
              Text(
                'No confirmed sleep record is available for $babyName.',
                style: _BabyText.supporting,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _V2Card(
          cardKey: ValueKey('baby-sleep-timeline-card'),
          padding: EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep Timeline', style: _BabyText.cardTitle),
              SizedBox(height: 8),
              _EmptyTimeline(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Naps", style: _BabyText.cardTitle),
              SizedBox(height: 12),
              _EmptyInlineState(
                iconAsset: _MeBabyOverviewAssets.moonStarIcon,
                title: 'No naps recorded',
                description: 'Confirmed nap records will appear here.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly Pattern', style: _BabyText.cardTitle),
              SizedBox(height: 16),
              _EmptyTimeline(),
            ],
          ),
        ),
      ],
    );
  }
}

class _BabyGrowthDetailContent extends StatelessWidget {
  const _BabyGrowthDetailContent({required this.detail, required this.data});

  final _BabyDetail detail;
  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final records = data.orderedGrowthRecords
        .where((record) => _measurement(record) != null)
        .toList(growable: false);
    final isLoading =
        data.growthRecords.phase == OverviewResourcePhase.initial ||
        data.growthRecords.phase == OverviewResourcePhase.loading;
    if (records.isEmpty) {
      return _OverviewStateCard(
        title: isLoading ? 'Loading growth data…' : 'No growth data yet',
        description: data.growthRecords.hasError
            ? 'Growth records could not be refreshed. Try again later.'
            : 'Add a confirmed ${_measurementLabel.toLowerCase()} measurement to begin the history.',
        icon: isLoading ? Icons.sync_rounded : _icon,
        loading: isLoading,
      );
    }
    final latest = records.first;
    final values = records
        .map(_measurement)
        .whereType<double>()
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    final chronologicalRecords = records.reversed.toList(growable: false);
    return Column(
      children: [
        _V2Card(
          cardKey: const ValueKey('baby-growth-current-card'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CURRENT MEASUREMENT', style: _BabyText.eyebrow),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatMeasurement(_measurement(latest)),
                      style: _BabyText.detailMetric,
                    ),
                  ),
                  const _WineBadge(label: 'Recorded'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _V2Card(
          cardKey: const ValueKey('baby-growth-trend-card'),
          padding: const EdgeInsets.fromLTRB(20, 16.5, 20, 16.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_trendTitle, style: _BabyText.cardTitle),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text(
                      'Reference band unavailable',
                      style: _BabyText.supportingSmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _GrowthTrendChart(
                values: values,
                labels: _growthChartLabels(context, chronologicalRecords),
                semanticLabel:
                    '$_measurementLabel trend based on ${values.length} confirmed measurements',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _V2Card(
          cardKey: const ValueKey('baby-growth-history-card'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent History', style: _BabyText.cardTitle),
              const SizedBox(height: 8),
              for (var index = 0; index < records.length; index += 1) ...[
                _GrowthHistoryRow(
                  value: _formatMeasurement(_measurement(records[index])),
                  date: _formatGrowthDate(context, records[index].measuredAt),
                  change: _formatChange(records, index),
                ),
                if (index < records.length - 1)
                  const Divider(color: _BabyOverviewColors.line, height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String get _measurementLabel => switch (detail) {
    _BabyDetail.weight => 'Weight',
    _BabyDetail.height => 'Height',
    _ => 'Head Circumference',
  };

  String get _trendTitle => switch (detail) {
    _BabyDetail.headCircumference => 'Head Circ. Trend',
    _ => '$_measurementLabel Trend',
  };

  IconData get _icon => switch (detail) {
    _BabyDetail.weight => Icons.monitor_weight_outlined,
    _BabyDetail.height => Icons.height_rounded,
    _ => Icons.straighten_rounded,
  };

  double? _measurement(GrowthRecord record) => switch (detail) {
    _BabyDetail.weight => record.weightKg,
    _BabyDetail.height => record.heightCm,
    _ => record.headCm,
  };

  String _formatMeasurement(double? value) {
    final unit = detail == _BabyDetail.weight ? 'kg' : 'cm';
    return '${_formatNumber(value)} $unit';
  }

  String _formatChange(List<GrowthRecord> records, int index) {
    if (index >= records.length - 1) return 'Baseline';
    final current = _measurement(records[index]);
    final previous = _measurement(records[index + 1]);
    if (current == null || previous == null) return 'Confirmed';
    final delta = current - previous;
    if (delta.abs() < 0.0001) return 'No change';
    final sign = delta > 0 ? '+' : '−';
    final unit = detail == _BabyDetail.weight ? 'kg' : 'cm';
    return '$sign${delta.abs().toStringAsFixed(1)} $unit';
  }
}

List<String> _growthChartLabels(
  BuildContext context,
  List<GrowthRecord> records,
) {
  if (records.isEmpty) return const ['—'];
  final indexes = records.length == 1
      ? const [0]
      : records.length == 2
      ? const [0, 1]
      : [0, records.length ~/ 2, records.length - 1];
  return [
    for (final index in indexes)
      _formatGrowthShortDate(context, records[index].measuredAt),
  ];
}

String _formatGrowthShortDate(BuildContext context, DateTime? value) {
  if (value == null) return 'Date unavailable';
  return MaterialLocalizations.of(context).formatShortDate(value.toLocal());
}

class _GrowthTrendChart extends StatelessWidget {
  const _GrowthTrendChart({
    required this.values,
    required this.labels,
    required this.semanticLabel,
  });

  final List<double> values;
  final List<String> labels;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          height: 130,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          decoration: BoxDecoration(
            color: _BabyOverviewColors.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Expanded(
                child: SizedBox.expand(
                  child: CustomPaint(painter: _GrowthTrendPainter(values)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (index, label) in labels.indexed)
                    Expanded(
                      child: Align(
                        alignment: index == 0
                            ? Alignment.centerLeft
                            : index == labels.length - 1
                            ? Alignment.centerRight
                            : Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: _BabyText.supportingSmall,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthTrendPainter extends CustomPainter {
  const _GrowthTrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final guidePaint = Paint()
      ..color = _BabyOverviewColors.mutedText.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (final y in [size.height * 0.34, size.height * 0.78]) {
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          guidePaint,
        );
      }
    }

    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final spread = math.max(0.1, maximum - minimum);
    Offset pointAt(int index) {
      final x = values.length == 1
          ? size.width / 2
          : index / (values.length - 1) * size.width;
      final normalized = (values[index] - minimum) / spread;
      final y = size.height * (0.82 - normalized * 0.66);
      return Offset(x, y);
    }

    final path = Path();
    for (var index = 0; index < values.length; index += 1) {
      final point = pointAt(index);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _BabyOverviewColors.wine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < values.length; index += 1) {
      final point = pointAt(index);
      canvas
        ..drawCircle(point, 6, Paint()..color = Colors.white)
        ..drawCircle(point, 4, Paint()..color = _BabyOverviewColors.wine);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthTrendPainter oldDelegate) {
    return !listEquals(oldDelegate.values, values);
  }
}

String _formatGrowthDate(BuildContext context, DateTime? value) {
  if (value == null) return 'Date not recorded';
  return MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
}

class _GrowthHistoryRow extends StatelessWidget {
  const _GrowthHistoryRow({
    required this.value,
    required this.date,
    required this.change,
  });

  final String value;
  final String date;
  final String change;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: MomCozyTypography.displayFontFamily,
                  color: _BabyOverviewColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(date, style: _BabyText.supporting),
            ],
          ),
        ),
        Text(
          change,
          style: TextStyle(
            fontFamily: MomCozyTypography.bodyFontFamily,
            color: _BabyOverviewColors.wine,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BabyAddRecordSheet extends StatelessWidget {
  const _BabyAddRecordSheet();

  @override
  Widget build(BuildContext context) {
    final options = const [
      (_BabyDetail.sleep, 'Sleep', _MeBabyOverviewAssets.moonStarIcon, false),
      (_BabyDetail.feeding, 'Feeding', _MeBabyOverviewAssets.babyIcon, true),
      (_BabyDetail.diaper, 'Diaper', _MeBabyOverviewAssets.babyIcon, false),
      (_BabyDetail.weight, 'Weight', _MeBabyOverviewAssets.weightIcon, true),
      (_BabyDetail.height, 'Height', _MeBabyOverviewAssets.rulerIcon, true),
      (
        _BabyDetail.headCircumference,
        'Head Circ.',
        _MeBabyOverviewAssets.rulerIcon,
        true,
      ),
    ];
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(16);
    final childAspectRatio = scaledLabelHeight > 22 ? 1.1 : 1.58;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          key: const ValueKey('baby-add-record-sheet'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: _BabyOverviewColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Record',
                      style: TextStyle(
                        fontFamily: MomCozyTypography.displayFontFamily,
                        color: _BabyOverviewColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('baby-add-record-close'),
                    tooltip: 'Close add record',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      minimumSize: const Size.square(MomCozyTapTargets.minimum),
                      padding: const EdgeInsets.all(7),
                    ),
                    icon: SvgPicture.asset(
                      _MeBabyOverviewAssets.closeButton,
                      width: 30,
                      height: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final enabled = option.$4;
                    return Semantics(
                      label: enabled
                          ? 'Add ${option.$2} record'
                          : '${option.$2} recording, coming soon',
                      button: true,
                      enabled: enabled,
                      child: Material(
                        key: ValueKey('baby-add-record-${option.$1.id}'),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: _BabyOverviewColors.line,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: enabled
                              ? () => Navigator.of(context).pop(option.$1)
                              : null,
                          child: Opacity(
                            opacity: enabled ? 1 : 0.58,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: _BabyOverviewColors.pill,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: _BabySvgIcon(
                                      asset: option.$3,
                                      color: _BabyOverviewColors.wine,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  option.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily:
                                        MomCozyTypography.bodyFontFamily,
                                    color: _BabyOverviewColors.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!enabled) ...[
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Coming soon',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily:
                                          MomCozyTypography.bodyFontFamily,
                                      color: _BabyOverviewColors.wine,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthRecordSheet extends StatefulWidget {
  const _GrowthRecordSheet({
    required this.detail,
    required this.data,
    required this.onSave,
    required this.mutation,
  });

  final _BabyDetail detail;
  final _MeBabyOverviewData data;
  final _GrowthSave onSave;
  final ValueListenable<ProfileOverviewMutationState> mutation;

  @override
  State<_GrowthRecordSheet> createState() => _GrowthRecordSheetState();
}

class _GrowthRecordSheetState extends State<_GrowthRecordSheet> {
  late final TextEditingController _valueController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final latest = widget.data.latestGrowth;
    final current = switch (widget.detail) {
      _BabyDetail.weight => latest?.weightKg,
      _BabyDetail.height => latest?.heightCm,
      _ => latest?.headCm,
    };
    _valueController = TextEditingController(
      text: current == null ? '' : _formatNumber(current),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_valueController.text.trim());
    if (value == null || value <= 0) {
      setState(() => _validationError = 'Enter a valid measurement.');
      return;
    }
    setState(() => _validationError = null);
    final saved = await switch (widget.detail) {
      _BabyDetail.weight => widget.onSave(weightKg: value),
      _BabyDetail.height => widget.onSave(heightCm: value),
      _ => widget.onSave(headCm: value),
    };
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Growth measurement saved.')),
      );
      return;
    }
    setState(() {
      _validationError =
          widget.mutation.value.message ??
          'The measurement could not be saved.';
    });
  }

  String get _label => switch (widget.detail) {
    _BabyDetail.weight => 'Weight',
    _BabyDetail.height => 'Height',
    _ => 'Head Circumference',
  };

  String get _unit => widget.detail == _BabyDetail.weight ? 'kg' : 'cm';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          key: ValueKey('baby-growth-editor-${widget.detail.id}'),
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _BabyOverviewColors.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add $_label',
                        style: const TextStyle(
                          fontFamily: MomCozyTypography.displayFontFamily,
                          color: _BabyOverviewColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const ValueKey('baby-growth-editor-close'),
                      tooltip: 'Close growth record',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: _BabyOverviewColors.pill,
                        foregroundColor: _BabyOverviewColors.wine,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Saved measurements sync with the Baby growth history.',
                  style: _BabyText.supporting,
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('baby-growth-value-input'),
                  controller: _valueController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: _label,
                    suffixText: _unit,
                    errorText: _validationError,
                    filled: true,
                    fillColor: _BabyOverviewColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: _BabyOverviewColors.wine,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<ProfileOverviewMutationState>(
                  valueListenable: widget.mutation,
                  builder: (context, mutation, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey('baby-growth-save'),
                        onPressed: mutation.isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _BabyOverviewColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          mutation.isSaving ? 'Saving…' : 'Save record',
                          style: const TextStyle(
                            fontFamily: MomCozyTypography.bodyFontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: MomCozyTypography.bodyFontFamily,
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BabyRoundIcon extends StatelessWidget {
  const _BabyRoundIcon({required this.iconAsset});

  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _BabyOverviewColors.pill,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: _BabySvgIcon(
          asset: iconAsset,
          color: _BabyOverviewColors.wine,
          size: 18,
        ),
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  const _EmptyInlineState({
    required this.iconAsset,
    required this.title,
    required this.description,
  });

  final String iconAsset;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BabyRoundIcon(iconAsset: iconAsset),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: MomCozyTypography.bodyFontFamily,
                  color: _BabyOverviewColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(description, style: _BabyText.supportingSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            height: 24,
            width: double.infinity,
            child: ColoredBox(color: _BabyOverviewColors.pill),
          ),
        ),
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('12am', style: _BabyText.supportingSmall),
            Text('6am', style: _BabyText.supportingSmall),
            Text('12pm', style: _BabyText.supportingSmall),
            Text('6pm', style: _BabyText.supportingSmall),
            Text('Now', style: _BabyText.supportingSmall),
          ],
        ),
      ],
    );
  }
}

class _SleepTrainingCard extends StatelessWidget {
  const _SleepTrainingCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 104),
      child: _V2Card(
        cardKey: const ValueKey('baby-sleep-training-card'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _BabyOverviewColors.pill,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                _MeBabyOverviewAssets.sleepTraining,
                fit: BoxFit.contain,
                semanticLabel: 'Sleep training illustration',
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sleep Training', style: _BabyText.cardTitle),
                  SizedBox(height: 4),
                  Text('AI sleep coaching', style: _BabyText.supporting),
                  SizedBox(height: 8),
                  _WineBadge(label: 'Coming soon', compact: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaperMetric extends StatelessWidget {
  const _DiaperMetric({
    required this.metricKey,
    required this.iconAsset,
    required this.value,
    required this.subtitle,
    this.iconColor = _BabyOverviewColors.wine,
  });

  final Key metricKey;
  final String iconAsset;
  final String value;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      cardKey: metricKey,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BabySvgIcon(asset: iconAsset, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: MomCozyTypography.displayFontFamily,
              color: _BabyOverviewColors.ink,
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: MomCozyTypography.bodyFontFamily,
              color: _BabyOverviewColors.mutedText,
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WineBadge extends StatelessWidget {
  const _WineBadge({required this.label, this.compact = true});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _BabyOverviewColors.pill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 3 : 7,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MomCozyTypography.bodyFontFamily,
            color: _BabyOverviewColors.wine,
            fontSize: compact ? 12 : 14,
            fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
