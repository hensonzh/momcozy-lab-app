part of 'me_baby_overview_page.dart';

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
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: compactForSleep ? 125 : 156,
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
                        color: _BabyOverviewColors.ink,
                        fontSize: 31,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.babyAge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BabyOverviewColors.mutedText,
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w700,
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
                            color: _BabyOverviewColors.ink,
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w900,
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
          final avatarWidth = math.min(constraints.maxWidth * 0.88, 378.0);
          final avatarHeight = math.min(cardHeight * 1.05, 560.0);
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
                top: compact ? -34 : -24,
                width: avatarWidth,
                height: avatarHeight,
                child: ClipRect(
                  key: const ValueKey('baby-avatar-without-baked-name'),
                  clipper: const _BabyAvatarWithoutBakedNameClipper(),
                  child: Image.asset(
                    _MeBabyOverviewAssets.babyAvatarFull,
                    key: const ValueKey('baby-avatar-expanded-image'),
                    alignment: Alignment.bottomRight,
                    fit: BoxFit.contain,
                    semanticLabel: 'Baby avatar',
                  ),
                ),
              ),
              Positioned(
                right: compact ? 58 : 76,
                top: cardHeight * 0.81,
                width: 120,
                child: Text(
                  data.babyName,
                  key: const ValueKey('baby-avatar-dynamic-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xffffcaca),
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Color(0x55c98d8d), offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 38,
                top: cardHeight * 0.43,
                right: constraints.maxWidth * 0.49,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.babyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BabyOverviewColors.ink,
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.babyAge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                            color: _BabyOverviewColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
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
                bottom: 112,
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
                bottom: 72,
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
                top: constraints.maxHeight - 60,
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

class _BabyAvatarWithoutBakedNameClipper extends CustomClipper<Rect> {
  const _BabyAvatarWithoutBakedNameClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * 0.83);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class _AvatarMonitorPreview extends StatelessWidget {
  const _AvatarMonitorPreview();

  @override
  Widget build(BuildContext context) {
    return _V2Card(
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
        data: data,
        onOpenDetail: () => onOpenDetail(_BabyDetail.sleep),
      ),
      'feeding' => _BabyFeedingContent(data: data),
      'diaper' => _BabyDiaperContent(data: data),
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
          padding: const EdgeInsets.all(14),
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
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nursery Camera',
                      style: TextStyle(
                        color: _BabyOverviewColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '—°C',
                    style: TextStyle(
                      color: _BabyOverviewColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('Temp', style: _BabyText.supportingSmall),
                  SizedBox(width: 14),
                  Text(
                    '—%',
                    style: TextStyle(
                      color: _BabyOverviewColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('Humidity', style: _BabyText.supportingSmall),
                ],
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
              Text('Recent Activity', style: _BabyText.cardTitle),
              SizedBox(height: 10),
              _EmptyInlineState(
                icon: Icons.history_rounded,
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
  const _BabySleepContent({required this.data, required this.onOpenDetail});

  final _MeBabyOverviewData data;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final records = data.todaySleepRecords;
    final naps = data.todayNaps;
    final isLoading =
        data.sleepRecords.phase == OverviewResourcePhase.initial ||
        data.sleepRecords.phase == OverviewResourcePhase.loading;
    final summary = records.isEmpty
        ? data.sleepRecords.hasError
              ? 'Sleep records could not be refreshed'
              : isLoading
              ? 'Loading confirmed sleep records…'
              : 'No sleep data recorded today'
        : '${records.length} confirmed ${records.length == 1 ? 'session' : 'sessions'}';
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('baby-sleep-summary-card'),
            borderRadius: BorderRadius.circular(26),
            onTap: onOpenDetail,
            child: _V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _BabyRoundIcon(icon: Icons.bedtime_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Total Sleep Today',
                          style: _BabyText.cardTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    records.isEmpty
                        ? '— h'
                        : _formatSleepDuration(data.todaySleepDuration),
                    style: _BabyText.heroMetric,
                  ),
                  const SizedBox(height: 7),
                  Text(summary, style: _BabyText.supporting),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _V2Card(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sleep Pattern Today',
                      style: _BabyText.cardTitle,
                    ),
                  ),
                  Text(
                    '${naps.length} ${naps.length == 1 ? 'nap' : 'naps'}',
                    style: _BabyText.accentLabel,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const _EmptyTimeline()
              else
                _SleepDayTimeline(records: records, now: data.now),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _V2Card(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep Trend & Prediction', style: _BabyText.cardTitle),
              SizedBox(height: 12),
              _EmptyInlineState(
                icon: Icons.schedule_rounded,
                title: 'Prediction unavailable',
                description: 'A confirmed sleep history is required.',
              ),
            ],
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
      return Column(
        children: [
          _OverviewStateCard(
            title: isLoading
                ? 'Loading feeding data…'
                : 'No feeding data today',
            description: data.feedingRecords.hasError
                ? 'Feeding records could not be refreshed. Try again later.'
                : 'Confirmed feeding records will appear here.',
            icon: isLoading ? Icons.sync_rounded : Icons.restaurant_outlined,
            loading: isLoading,
          ),
          const SizedBox(height: 14),
          _FeedingDiaperSummaryCard(data: data),
          const SizedBox(height: 14),
          _FeedingWeekTrendCard(data: data),
        ],
      );
    }
    return Column(
      children: [
        _V2Card(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 5,
                      backgroundColor: _BabyOverviewColors.line,
                      color: _BabyOverviewColors.wine,
                    ),
                    Text(
                      '${feeds.length}',
                      style: const TextStyle(
                        color: _BabyOverviewColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
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
        const SizedBox(height: 14),
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
        _FeedingDiaperSummaryCard(data: data),
        const SizedBox(height: 14),
        _FeedingWeekTrendCard(data: data),
      ],
    );
  }
}

class _FeedingDiaperSummaryCard extends StatelessWidget {
  const _FeedingDiaperSummaryCard({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final records = data.todayDiaperRecords;
    final wet = records.where((record) => record.includesWet).length;
    final dirty = records.where((record) => record.includesDirty).length;
    final isLoading =
        data.diaperRecords.phase == OverviewResourcePhase.initial ||
        data.diaperRecords.phase == OverviewResourcePhase.loading;
    return _V2Card(
      cardKey: const ValueKey('baby-feeding-diaper-summary'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Diaper Tracker', style: _BabyText.cardTitle),
              ),
              if (records.isNotEmpty)
                Text(
                  '$wet wet / $dirty dirty today',
                  style: _BabyText.accentLabel,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            _EmptyInlineState(
              icon: Icons.baby_changing_station_outlined,
              title: isLoading
                  ? 'Loading diaper records…'
                  : 'No diaper records today',
              description: data.diaperRecords.hasError
                  ? 'Diaper records could not be refreshed.'
                  : 'Confirmed changes will appear here.',
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _FeedingCareMetric(
                  icon: Icons.water_drop_outlined,
                  label: '$wet Wet Diapers',
                ),
                _FeedingCareMetric(
                  icon: Icons.baby_changing_station_outlined,
                  label: '$dirty Dirty Diapers',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeedingCareMetric extends StatelessWidget {
  const _FeedingCareMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _BabyOverviewColors.wine, size: 22),
        const SizedBox(width: 7),
        Text(label, style: _BabyText.cardTitle),
      ],
    );
  }
}

class _FeedingWeekTrendCard extends StatelessWidget {
  const _FeedingWeekTrendCard({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      cardKey: const ValueKey('baby-feeding-weekly-trend'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Intake Trend', style: _BabyText.cardTitle),
          const SizedBox(height: 12),
          _FeedingWeekBars(records: data.orderedFeedingRecords, now: data.now),
        ],
      ),
    );
  }
}

class _BabyFeedingWeekContent extends StatelessWidget {
  const _BabyFeedingWeekContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final records = _feedingRecordsInWeek(
      records: data.orderedFeedingRecords,
      now: data.now,
    );
    final measuredTotal = records.fold<int>(
      0,
      (total, record) => total + (record.amountMl ?? 0),
    );
    return Column(
      children: [
        _V2Card(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('7-Day Feeding Summary', style: _BabyText.cardTitle),
              const SizedBox(height: 7),
              Text(
                '${records.length} confirmed ${records.length == 1 ? 'feed' : 'feeds'} · $measuredTotal mL measured',
                style: _BabyText.supporting,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FeedingWeekTrendCard(data: data),
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
  const _BabyDiaperContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final records = data.todayDiaperRecords;
    final wetCount = records.where((record) => record.includesWet).length;
    final dirtyCount = records.where((record) => record.includesDirty).length;
    final count = records.length;
    final isLoading =
        data.diaperRecords.phase == OverviewResourcePhase.initial ||
        data.diaperRecords.phase == OverviewResourcePhase.loading;
    final stateLabel = count > 0
        ? 'Confirmed records'
        : data.diaperRecords.hasError
        ? 'Refresh failed'
        : isLoading
        ? 'Loading records…'
        : 'No diaper data yet';
    return Column(
      children: [
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TODAY’S SUMMARY', style: _BabyText.eyebrow),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        '$count ${count == 1 ? 'change' : 'changes'}',
                        style: _BabyText.heroMetric,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        stateLabel,
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DiaperMetric(
                icon: Icons.water_drop_outlined,
                iconColor: const Color(0xff2d9cdb),
                value: '$wetCount Wet',
                subtitle: wetCount == 0 ? 'No records' : 'Confirmed today',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DiaperMetric(
                icon: Icons.baby_changing_station_outlined,
                value: '$dirtyCount Dirty',
                subtitle: dirtyCount == 0 ? 'No records' : 'Confirmed today',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Diaper Timeline', style: _BabyText.cardTitle),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const _EmptyInlineState(
                  icon: Icons.history_rounded,
                  title: 'No confirmed changes',
                  description: 'Recorded diaper changes will appear here.',
                )
              else
                for (var index = 0; index < records.length; index += 1) ...[
                  _DiaperTimelineRow(record: records[index]),
                  if (index < records.length - 1)
                    const Divider(color: _BabyOverviewColors.line, height: 16),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Overview (Total Changes)',
                style: _BabyText.cardTitle,
              ),
              const SizedBox(height: 12),
              _DiaperWeekBars(
                records: data.orderedDiaperRecords,
                now: data.now,
              ),
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
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
        children: [
          _BabyDetailHeader(
            detail: detail,
            title: title,
            subtitle: subtitle,
            onBack: onBack,
          ),
          const SizedBox(height: 16),
          if (detail == _BabyDetail.feeding)
            _BabyFeedingDetailContent(data: data)
          else if (detail == _BabyDetail.diaper)
            _BabyDiaperContent(data: data)
          else if (detail == _BabyDetail.sleep)
            _BabySleepReportContent(data: data)
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
            child: Center(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: _BabyOverviewColors.line),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: _BabyOverviewColors.ink,
                      size: 27,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                    color: _BabyOverviewColors.ink,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w900,
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
        const _DisabledCircleAction(
          actionKey: ValueKey('baby-detail-more-disabled'),
          semanticLabel: 'More actions are not available yet',
          icon: Icons.more_horiz_rounded,
          compact: true,
          size: 40,
          backgroundColor: Colors.white,
          foregroundColor: _BabyOverviewColors.ink,
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
        const SizedBox(height: 16),
        if (_period == 'day')
          _BabyFeedingContent(data: widget.data)
        else
          _BabyFeedingWeekContent(data: widget.data),
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
    return Container(
      height: MomCozyTapTargets.minimum,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BabyOverviewColors.line),
      ),
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
                  color: selected == period.$1
                      ? _BabyOverviewColors.pill
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => onSelected(period.$1),
                    child: Center(
                      child: Text(
                        period.$2,
                        style: TextStyle(
                          color: selected == period.$1
                              ? _BabyOverviewColors.wine
                              : _BabyOverviewColors.mutedText,
                          fontSize: 16,
                          fontWeight: selected == period.$1
                              ? FontWeight.w900
                              : FontWeight.w800,
                        ),
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

class _BabySleepReportContent extends StatelessWidget {
  const _BabySleepReportContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final nightRecords = data.orderedSleepRecords
        .where((record) => record.kind == SleepKind.night)
        .toList(growable: false);
    final latestNight = nightRecords.isEmpty ? null : nightRecords.first;
    final naps = data.todayNaps;
    return Column(
      children: [
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("LAST NIGHT'S SLEEP", style: _BabyText.eyebrow),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      latestNight == null
                          ? '— hours'
                          : _formatSleepDuration(
                              latestNight.durationUntil(data.now),
                            ),
                      style: _BabyText.heroMetric,
                    ),
                  ),
                  _WineBadge(
                    label: latestNight == null ? 'No data' : 'Recorded',
                  ),
                ],
              ),
              const Divider(color: _BabyOverviewColors.line, height: 28),
              Text(
                latestNight == null
                    ? 'No confirmed sleep record is available for ${data.babyName}.'
                    : _sleepIntervalLabel(context, latestNight),
                style: _BabyText.supporting,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sleep Timeline', style: _BabyText.cardTitle),
              const SizedBox(height: 16),
              if (data.todaySleepRecords.isEmpty)
                const _EmptyTimeline()
              else
                _SleepDayTimeline(
                  records: data.todaySleepRecords,
                  now: data.now,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Naps", style: _BabyText.cardTitle),
              const SizedBox(height: 12),
              if (naps.isEmpty)
                const _EmptyInlineState(
                  icon: Icons.bedtime_outlined,
                  title: 'No naps recorded',
                  description: 'Confirmed nap records will appear here.',
                )
              else
                for (var index = 0; index < naps.length; index += 1) ...[
                  _SleepRecordRow(record: naps[index], now: data.now),
                  if (index < naps.length - 1)
                    const Divider(color: _BabyOverviewColors.line, height: 16),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Pattern', style: _BabyText.cardTitle),
              const SizedBox(height: 16),
              _SleepWeekBars(records: data.orderedSleepRecords, now: data.now),
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
                      style: _BabyText.heroMetric,
                    ),
                  ),
                  const _WineBadge(label: 'Recorded'),
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
        const SizedBox(height: 14),
        _V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent History', style: _BabyText.cardTitle),
              const SizedBox(height: 12),
              for (var index = 0; index < records.length; index += 1) ...[
                _GrowthHistoryRow(
                  value: _formatMeasurement(_measurement(records[index])),
                  date: _formatGrowthDate(context, records[index].measuredAt),
                  change: _formatChange(records, index),
                ),
                if (index < records.length - 1)
                  const Divider(color: _BabyOverviewColors.line, height: 18),
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
                  color: _BabyOverviewColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(date, style: _BabyText.supporting),
            ],
          ),
        ),
        Text(
          change,
          style: TextStyle(
            color: _BabyOverviewColors.wine,
            fontSize: 14,
            fontWeight: FontWeight.w900,
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
      (_BabyDetail.sleep, 'Sleep', Icons.bedtime_outlined),
      (_BabyDetail.feeding, 'Feeding', Icons.child_care_rounded),
      (_BabyDetail.diaper, 'Diaper', Icons.baby_changing_station_outlined),
      (_BabyDetail.weight, 'Weight', Icons.monitor_weight_outlined),
      (_BabyDetail.height, 'Height', Icons.straighten_rounded),
      (_BabyDetail.headCircumference, 'Head Circ.', Icons.straighten_rounded),
    ];
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(16);
    final childAspectRatio = scaledLabelHeight > 22 ? 1.25 : 1.58;
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
                        color: _BabyOverviewColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('baby-add-record-close'),
                    tooltip: 'Close add record',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: _BabyOverviewColors.pill,
                      foregroundColor: _BabyOverviewColors.wine,
                      minimumSize: const Size.square(MomCozyTapTargets.minimum),
                    ),
                    icon: const Icon(Icons.close_rounded),
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
                    return Material(
                      key: ValueKey('baby-add-record-${option.$1.id}'),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: _BabyOverviewColors.line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop(option.$1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DecoratedBox(
                              decoration: const BoxDecoration(
                                color: _BabyOverviewColors.pill,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Icon(
                                  option.$3,
                                  color: _BabyOverviewColors.wine,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              option.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _BabyOverviewColors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                          color: _BabyOverviewColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
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
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BabyRoundIcon extends StatelessWidget {
  const _BabyRoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _BabyOverviewColors.pill,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, color: _BabyOverviewColors.wine, size: 20),
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  const _EmptyInlineState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BabyRoundIcon(icon: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _BabyOverviewColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
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

class _SleepDayTimeline extends StatelessWidget {
  const _SleepDayTimeline({required this.records, required this.now});

  final List<SleepRecord> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final localNow = now.toLocal();
    final dayStart = DateTime(localNow.year, localNow.month, localNow.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final segments = <({double start, double end, SleepKind kind})>[];
    for (final record in records) {
      final rawStart = record.startedAt.toLocal();
      final rawEnd = (record.endedAt ?? now).toLocal();
      final start = rawStart.isBefore(dayStart) ? dayStart : rawStart;
      final end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
      if (!end.isAfter(start)) continue;
      segments.add((
        start: start.difference(dayStart).inSeconds / 86400,
        end: end.difference(dayStart).inSeconds / 86400,
        kind: record.kind,
      ));
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 24,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: _BabyOverviewColors.pill),
                    ),
                    for (final segment in segments)
                      Positioned(
                        left: segment.start * constraints.maxWidth,
                        width: math.max(
                          4,
                          (segment.end - segment.start) * constraints.maxWidth,
                        ),
                        top: 0,
                        bottom: 0,
                        child: ColoredBox(
                          color: segment.kind == SleepKind.nap
                              ? const Color(0xffd96c8f)
                              : _BabyOverviewColors.wine,
                        ),
                      ),
                  ],
                );
              },
            ),
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

class _SleepRecordRow extends StatelessWidget {
  const _SleepRecordRow({required this.record, required this.now});

  final SleepRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BabyRoundIcon(icon: Icons.bedtime_outlined),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatSleepDuration(record.durationUntil(now)),
                style: _BabyText.cardTitle,
              ),
              const SizedBox(height: 2),
              Text(
                _sleepIntervalLabel(context, record),
                style: _BabyText.supportingSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiaperTimelineRow extends StatelessWidget {
  const _DiaperTimelineRow({required this.record});

  final DiaperRecord record;

  @override
  Widget build(BuildContext context) {
    final localTime = record.changedAt.toLocal();
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(localTime));
    final label = switch (record.kind) {
      DiaperKind.wet => 'Wet diaper',
      DiaperKind.dirty => 'Dirty diaper',
      DiaperKind.both => 'Wet & dirty',
    };
    final observations = <String>[
      if (record.wetness != null) _capitalize(record.wetness!.name),
      if (record.stoolColor?.trim().isNotEmpty == true)
        record.stoolColor!.trim(),
      if (record.stoolConsistency?.trim().isNotEmpty == true)
        record.stoolConsistency!.trim(),
    ];
    return Row(
      children: [
        _BabyRoundIcon(
          icon: record.includesWet
              ? Icons.water_drop_outlined
              : Icons.baby_changing_station_outlined,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _BabyText.cardTitle),
              if (observations.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  observations.join(' · '),
                  style: _BabyText.supportingSmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(time, style: _BabyText.supporting),
      ],
    );
  }
}

class _SleepWeekBars extends StatelessWidget {
  const _SleepWeekBars({required this.records, required this.now});

  final List<SleepRecord> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final days = [
      for (var offset = 6; offset >= 0; offset -= 1)
        today.subtract(Duration(days: offset)),
    ];
    final minutes = [
      for (final day in days)
        records.fold<int>(
          0,
          (total, record) =>
              total + _sleepDurationInDay(record, day, now).inMinutes,
        ),
    ];
    return _RawWeekBars(
      values: minutes,
      labels: days.map(_babyWeekdayLabel).toList(growable: false),
      semanticsLabel: 'Confirmed sleep minutes for the last seven days',
    );
  }
}

class _DiaperWeekBars extends StatelessWidget {
  const _DiaperWeekBars({required this.records, required this.now});

  final List<DiaperRecord> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final days = [
      for (var offset = 6; offset >= 0; offset -= 1)
        today.subtract(Duration(days: offset)),
    ];
    final counts = [
      for (final day in days)
        records.where((record) {
          final value = record.changedAt.toLocal();
          return value.year == day.year &&
              value.month == day.month &&
              value.day == day.day;
        }).length,
    ];
    return _RawWeekBars(
      values: counts,
      labels: days.map(_babyWeekdayLabel).toList(growable: false),
      semanticsLabel: 'Confirmed diaper changes for the last seven days',
    );
  }
}

class _FeedingWeekBars extends StatelessWidget {
  const _FeedingWeekBars({required this.records, required this.now});

  final List<FeedingRecord> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final days = [
      for (var offset = 6; offset >= 0; offset -= 1)
        today.subtract(Duration(days: offset)),
    ];
    final totals = [
      for (final day in days)
        records.fold<int>(0, (total, record) {
          final value = record.occurredAt?.toLocal();
          if (value == null ||
              value.year != day.year ||
              value.month != day.month ||
              value.day != day.day) {
            return total;
          }
          return total + (record.amountMl ?? 0);
        }),
    ];
    return _RawWeekBars(
      values: totals,
      labels: days.map(_babyWeekdayLabel).toList(growable: false),
      semanticsLabel:
          'Confirmed measured feeding totals for the last seven days',
    );
  }
}

List<FeedingRecord> _feedingRecordsInWeek({
  required List<FeedingRecord> records,
  required DateTime now,
}) {
  final localNow = now.toLocal();
  final end = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
  ).add(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 7));
  return records
      .where((record) {
        final value = record.occurredAt?.toLocal();
        return value != null && !value.isBefore(start) && value.isBefore(end);
      })
      .toList(growable: false);
}

class _RawWeekBars extends StatelessWidget {
  const _RawWeekBars({
    required this.values,
    required this.labels,
    required this.semanticsLabel,
  });

  final List<int> values;
  final List<String> labels;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final maximum = values.fold<int>(
      0,
      (current, value) => current > value ? current : value,
    );
    final scaleMaximum = math.max(1, maximum);
    return Semantics(
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < values.length; index += 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${values[index]}',
                        style: _BabyText.supportingSmall,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: math.max(
                          5,
                          48 * values[index] / scaleMaximum,
                        ),
                        decoration: BoxDecoration(
                          color: _BabyOverviewColors.wine,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[index], style: _BabyText.supportingSmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Duration _sleepDurationInDay(SleepRecord record, DateTime day, DateTime now) {
  final dayEnd = day.add(const Duration(days: 1));
  final rawStart = record.startedAt.toLocal();
  final rawEnd = (record.endedAt ?? now).toLocal();
  final start = rawStart.isBefore(day) ? day : rawStart;
  final end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

String _formatSleepDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes m';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes m';
}

String _sleepIntervalLabel(BuildContext context, SleepRecord record) {
  final localizations = MaterialLocalizations.of(context);
  final start = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(record.startedAt.toLocal()),
  );
  final end = record.endedAt == null
      ? 'Ongoing'
      : localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(record.endedAt!.toLocal()),
        );
  return '$start – $end';
}

String _babyWeekdayLabel(DateTime value) {
  return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][value.weekday - 1];
}

String _capitalize(String value) {
  return value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1)}';
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
    return _V2Card(
      padding: const EdgeInsets.all(14),
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
                _WineBadge(label: 'Coming soon'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaperMetric extends StatelessWidget {
  const _DiaperMetric({
    required this.icon,
    required this.value,
    required this.subtitle,
    this.iconColor = _BabyOverviewColors.wine,
  });

  final IconData icon;
  final String value;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _BabyOverviewColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: _BabyText.supporting),
        ],
      ),
    );
  }
}

class _WineBadge extends StatelessWidget {
  const _WineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _BabyOverviewColors.pill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: _BabyOverviewColors.wine,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
