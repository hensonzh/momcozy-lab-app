import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_controller.dart';

class MeBabyOverviewPage extends StatefulWidget {
  const MeBabyOverviewPage({
    super.key,
    required this.path,
    required this.identity,
  });

  final String path;
  final ProfileIdentity identity;

  @override
  State<MeBabyOverviewPage> createState() => _MeBabyOverviewPageState();
}

class _MeBabyOverviewPageState extends State<MeBabyOverviewPage>
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
  MomLifeStage _displayedStage = MomLifeStage.postpartum;
  MomCozyApiRuntime? _runtime;
  ProfileOverviewController? _overviewController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _attachOverviewController(runtime);
    }
  }

  @override
  void didUpdateWidget(covariant MeBabyOverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity == widget.identity) return;
    _section = _initialSection(widget.identity);
    _detailsPosition.value = 0;
    _showAvatarLayer = false;
    _avatarExpanded = false;
    _displayedStage = MomLifeStage.postpartum;
    if (_detailsScroll.hasClients) _detailsScroll.jumpTo(0);
    final runtime = _runtime;
    if (runtime != null) _attachOverviewController(runtime);
  }

  @override
  void dispose() {
    _detachOverviewController();
    _detailsPosition.dispose();
    _detailsScroll.dispose();
    super.dispose();
  }

  void _attachOverviewController(MomCozyApiRuntime runtime) {
    _detachOverviewController();
    final controller = runtime.createProfileOverviewController(
      initialIdentity: widget.identity,
    );
    _overviewController = controller;
    _displayedStage = controller.careStage.value.stage;
    for (final resource in _overviewResources(controller)) {
      resource.addListener(_handleProfileOverviewResourceChanged);
    }
    unawaited(_initializeOverviewController(controller));
  }

  Future<void> _initializeOverviewController(
    ProfileOverviewController controller,
  ) async {
    try {
      await controller.initialize();
    } catch (_) {
      // Each resource keeps its own error state for an honest partial UI.
    }
  }

  void _detachOverviewController() {
    final controller = _overviewController;
    if (controller == null) return;
    for (final resource in _overviewResources(controller)) {
      resource.removeListener(_handleProfileOverviewResourceChanged);
    }
    controller.dispose();
    _overviewController = null;
  }

  Iterable<Listenable> _overviewResources(
    ProfileOverviewController controller,
  ) {
    return [
      controller.overview,
      controller.milkTrends,
      controller.feedingRecords,
      controller.growthRecords,
      controller.careStage,
    ];
  }

  void _handleProfileOverviewResourceChanged() {
    if (!mounted) return;
    final nextStage = _overviewController?.careStage.value.stage;
    if (widget.identity == ProfileIdentity.mom &&
        nextStage != null &&
        nextStage != _displayedStage) {
      _displayedStage = nextStage;
      _section = _initialSection(widget.identity);
      _detailsPosition.value = 0;
      _showAvatarLayer = false;
      _avatarExpanded = false;
      if (_detailsScroll.hasClients) _detailsScroll.jumpTo(0);
    }
    setState(() {});
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.identity == ProfileIdentity.mom &&
        _displayedStage != MomLifeStage.postpartum) {
      return;
    }
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

  Future<void> _openCareStageSelector() async {
    final controller = _overviewController;
    if (controller == null || !controller.careStage.value.isResolved) return;
    controller.clearCareStageError();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      barrierLabel: 'Dismiss current stage selector',
      backgroundColor: _MeBabyOverviewColors.background,
      builder: (sheetContext) =>
          _CareStageSelectorSheet(controller: controller),
    );
    controller.clearCareStageError();
  }

  @override
  Widget build(BuildContext context) {
    final data = _MeBabyOverviewData.fromController(_overviewController);
    final stageState =
        _overviewController?.careStage.value ?? const CareStageSelectionState();
    final usesPostpartumWorkspace =
        widget.identity != ProfileIdentity.mom ||
        stageState.stage == MomLifeStage.postpartum;
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
                    key: const ValueKey('me-baby-overview-avatar-gesture-area'),
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: (_) => _handlePointerEnd(),
                    onPointerCancel: (_) => _handlePointerEnd(),
                    child: Stack(
                      children: [
                        if (_showAvatarLayer && usesPostpartumWorkspace)
                          Positioned.fill(
                            child: _AvatarStage(
                              identity: widget.identity,
                              data: data,
                              selectedSection: _section,
                              onClose: () => _settleDetails(0),
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
                            color: _MeBabyOverviewColors.background,
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
                                if (widget.identity == ProfileIdentity.mom &&
                                    !usesPostpartumWorkspace) ...[
                                  _LifeStageHero(
                                    stage: stageState.stage,
                                    data: data,
                                  ),
                                  const SizedBox(height: 14),
                                  _LifeStageWorkspace(stage: stageState.stage),
                                ] else ...[
                                  _ProfileHero(
                                    identity: widget.identity,
                                    data: data,
                                    onOpenAvatar: () => _settleDetails(1),
                                  ),
                                  const SizedBox(height: 14),
                                  _SectionTabs(
                                    identity: widget.identity,
                                    selected: _section,
                                    onSelected: _selectSection,
                                  ),
                                  const SizedBox(height: 14),
                                  if (widget.identity == ProfileIdentity.mom)
                                    _MeContent(section: _section, data: data)
                                  else
                                    _BabyContent(section: _section, data: data),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_avatarExpanded)
                          const SizedBox(
                            key: ValueKey('me-baby-overview-avatar-expanded'),
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
            color: _MeBabyOverviewColors.background,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _MeBabyOverviewHeader(
                identity: widget.identity,
                careStage: stageState,
                onStagePressed: _openCareStageSelector,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _initialSection(ProfileIdentity identity) {
  return identity == ProfileIdentity.mom ? 'lactation' : 'monitor';
}

class _MeBabyOverviewData {
  const _MeBabyOverviewData({
    required this.overview,
    required this.milkTrends,
    required this.feedingRecords,
    required this.growthRecords,
    required this.now,
  });

  factory _MeBabyOverviewData.fromController(
    ProfileOverviewController? controller,
  ) {
    if (controller == null) {
      return _MeBabyOverviewData(
        overview: const ProfileOverviewResource.initial(),
        milkTrends: const ProfileOverviewResource.initial(),
        feedingRecords: const ProfileOverviewResource.initial(),
        growthRecords: const ProfileOverviewResource.initial(),
        now: DateTime.now(),
      );
    }
    return _MeBabyOverviewData(
      overview: controller.overview.value,
      milkTrends: controller.milkTrends.value,
      feedingRecords: controller.feedingRecords.value,
      growthRecords: controller.growthRecords.value,
      now: controller.now(),
    );
  }

  final ProfileOverviewResource<ProfileOverview> overview;
  final ProfileOverviewResource<List<MilkTrendDay>> milkTrends;
  final ProfileOverviewResource<List<FeedingRecord>> feedingRecords;
  final ProfileOverviewResource<List<GrowthRecord>> growthRecords;
  final DateTime now;

  String get momName => 'Me';

  String get babyName {
    final nickname = overview.data?.baby?.nickname?.trim();
    return nickname == null || nickname.isEmpty ? 'Baby' : nickname;
  }

  String get babyAge => _formatBabyAge(overview.data?.baby?.ageDays);

  List<MilkTrendDay> get orderedMilkTrends {
    final values = List<MilkTrendDay>.of(
      milkTrends.data ?? const <MilkTrendDay>[],
    );
    values.sort((left, right) => left.date.compareTo(right.date));
    return values;
  }

  MilkTrendDay? get latestMilkTrend {
    final values = orderedMilkTrends;
    return values.isEmpty ? null : values.last;
  }

  List<FeedingRecord> get feeds {
    final values = List<FeedingRecord>.of(
      feedingRecords.data ?? const <FeedingRecord>[],
    );
    values.sort((left, right) {
      final leftTime = left.occurredAt;
      final rightTime = right.occurredAt;
      if (leftTime == null && rightTime == null) return 0;
      if (leftTime == null) return 1;
      if (rightTime == null) return -1;
      return leftTime.compareTo(rightTime);
    });
    return values;
  }

  int get measuredFeedTotalMl =>
      feeds.fold<int>(0, (total, record) => total + (record.amountMl ?? 0));

  GrowthRecord? get latestGrowth {
    final values = growthRecords.data ?? const <GrowthRecord>[];
    if (values.isEmpty) return null;
    return values.reduce((left, right) {
      final leftTime = left.measuredAt;
      final rightTime = right.measuredAt;
      if (leftTime == null) return right;
      if (rightTime == null) return left;
      return leftTime.isAfter(rightTime) ? left : right;
    });
  }

  String get momAvatarSummary {
    final trend = latestMilkTrend;
    if (trend == null) return 'No milk data recorded today';
    return '${_formatNumber(trend.pumpedMilkVolumeMl)} mL recorded today';
  }

  String get babyAvatarSummary {
    final count = feeds.length;
    return count == 0
        ? 'No feeding data recorded today'
        : '$count ${count == 1 ? 'feed' : 'feeds'} recorded today';
  }
}

String _formatBabyAge(int? ageDays) {
  if (ageDays == null || ageDays < 0) return 'Age not recorded';
  final weeks = ageDays ~/ 7;
  final days = ageDays % 7;
  if (weeks == 0) return '$days ${days == 1 ? 'day' : 'days'}';
  return '$weeks ${weeks == 1 ? 'week' : 'weeks'} $days ${days == 1 ? 'day' : 'days'}';
}

String _formatNumber(num? value) {
  if (value == null) return '—';
  final number = value.toDouble();
  return number == number.roundToDouble()
      ? number.round().toString()
      : number.toStringAsFixed(1);
}

class _MeBabyOverviewHeader extends StatelessWidget {
  const _MeBabyOverviewHeader({
    required this.identity,
    required this.careStage,
    required this.onStagePressed,
  });

  final ProfileIdentity identity;
  final CareStageSelectionState careStage;
  final VoidCallback onStagePressed;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == ProfileIdentity.mom;
    final label = isMom
        ? (careStage.isResolved ? careStage.stage.label : 'My Stage')
        : 'Infant';
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const _MomCozyWordmark(),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: isMom
                  ? 'Current stage: $label. Change current stage.'
                  : '$label, fixed profile',
              button: isMom,
              enabled: isMom && careStage.isResolved && !careStage.isSaving,
              child: Material(
                key: isMom ? const ValueKey('me-current-stage-selector') : null,
                color: _MeBabyOverviewColors.pill,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: isMom && careStage.isResolved && !careStage.isSaving
                      ? onStagePressed
                      : null,
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: _MeBabyOverviewColors.wine,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (isMom) ...[
                            const SizedBox(width: 5),
                            if (!careStage.isResolved || careStage.isSaving)
                              const SizedBox.square(
                                dimension: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _MeBabyOverviewColors.wine,
                                ),
                              )
                            else
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _MeBabyOverviewColors.wine,
                                size: 19,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _DisabledCircleAction(
            actionKey: ValueKey('me-baby-overview-notification-disabled'),
            semanticLabel: 'Notifications are not available yet',
            icon: Icons.notifications_none_rounded,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _CareStageSelectorSheet extends StatelessWidget {
  const _CareStageSelectorSheet({required this.controller});

  final ProfileOverviewController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CareStageSelectionState>(
      valueListenable: controller.careStage,
      builder: (context, state, _) {
        return PopScope(
          canPop: !state.isSaving,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Current Stage',
                          style: TextStyle(
                            color: _MeBabyOverviewColors.wine,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('me-stage-selector-close'),
                        tooltip: 'Close',
                        onPressed: state.isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: _MeBabyOverviewColors.wine,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final stage in MomLifeStage.values) ...[
                    _CareStageOption(
                      stage: stage,
                      selected: state.stage == stage,
                      saving: state.pendingStage == stage,
                      enabled: !state.isSaving,
                      onTap: () async {
                        if (stage == state.stage) {
                          Navigator.of(context).pop();
                          return;
                        }
                        final changed = await controller.updateCareStage(stage);
                        if (context.mounted && changed) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    if (stage != MomLifeStage.values.last)
                      const Divider(
                        color: _MeBabyOverviewColors.line,
                        height: 1,
                      ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xfffff0f2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: _MeBabyOverviewColors.wine,
                              size: 20,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Couldn’t change stage. Try again.',
                                style: TextStyle(
                                  color: _MeBabyOverviewColors.wine,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CareStageOption extends StatelessWidget {
  const _CareStageOption({
    required this.stage,
    required this.selected,
    required this.saving,
    required this.enabled,
    required this.onTap,
  });

  final MomLifeStage stage;
  final bool selected;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      label: '${stage.label}. ${stage.subtitle}',
      child: Material(
        key: ValueKey('me-stage-option-${stage.wireValue}'),
        color: selected ? const Color(0xfffff8f8) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 86),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _stageColor(stage),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 12),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.label,
                          style: TextStyle(
                            color: selected
                                ? _MeBabyOverviewColors.wine
                                : _MeBabyOverviewColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stage.subtitle,
                          style: _MeBabyOverviewText.supporting,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 28,
                    child: saving
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _MeBabyOverviewColors.wine,
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: selected
                                  ? _MeBabyOverviewColors.wine
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: _MeBabyOverviewColors.line,
                                      width: 2,
                                    ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
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

Color _stageColor(MomLifeStage stage) {
  return switch (stage) {
    MomLifeStage.fertility => const Color(0xffdf6a91),
    MomLifeStage.pregnancy => _MeBabyOverviewColors.wine,
    MomLifeStage.postpartum => const Color(0xffaa928a),
  };
}

class _MomCozyWordmark extends StatelessWidget {
  const _MomCozyWordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'momcozy',
          style: TextStyle(
            color: _MeBabyOverviewColors.ink,
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
  const _ProfileHero({
    required this.identity,
    required this.data,
    required this.onOpenAvatar,
  });

  final ProfileIdentity identity;
  final _MeBabyOverviewData data;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == ProfileIdentity.mom;
    return Container(
      key: ValueKey(isMom ? 'me-profile-hero' : 'baby-profile-hero'),
      height: 246,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _MeBabyOverviewColors.hero,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filledTonal(
              key: const ValueKey('me-baby-overview-open-avatar'),
              tooltip: 'View avatar',
              onPressed: onOpenAvatar,
              icon: const Icon(Icons.fullscreen_rounded),
              color: _MeBabyOverviewColors.wine,
            ),
          ),
          Positioned(
            right: isMom ? -18 : -8,
            top: isMom ? 4 : 16,
            bottom: isMom ? -38 : -30,
            width: isMom ? 205 : 190,
            child: IgnorePointer(
              child: Image.asset(
                isMom
                    ? _MeBabyOverviewAssets.momAvatar
                    : _MeBabyOverviewAssets.babyAvatar,
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
                      color: _MeBabyOverviewColors.ink,
                      fontSize: 28,
                      height: 0.98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                Text(
                  isMom ? data.momName : data.babyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _MeBabyOverviewColors.ink,
                    fontSize: isMom ? 38 : 31,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                if (!isMom) ...[
                  const SizedBox(height: 7),
                  Text(
                    data.babyAge,
                    style: TextStyle(
                      color: _MeBabyOverviewColors.mutedText,
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
                      ? _CelebrationText(label: data.momAvatarSummary)
                      : Text(
                          data.babyAvatarSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _MeBabyOverviewColors.ink,
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
              color: _MeBabyOverviewColors.ink,
              fontSize: 14,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Icon(
          Icons.celebration_rounded,
          color: _MeBabyOverviewColors.wine,
          size: 17,
        ),
      ],
    );
  }
}

class _LifeStageHero extends StatelessWidget {
  const _LifeStageHero({required this.stage, required this.data});

  final MomLifeStage stage;
  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('me-stage-hero-${stage.wireValue}'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _MeBabyOverviewColors.hero,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                stage == MomLifeStage.pregnancy
                    ? Icons.pregnant_woman_rounded
                    : Icons.favorite_outline_rounded,
                color: _MeBabyOverviewColors.wine,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            stage.label,
            style: const TextStyle(
              color: _MeBabyOverviewColors.ink,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage.subtitle,
            style: const TextStyle(
              color: _MeBabyOverviewColors.wine,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _lifeStageProfileSummary(context, stage, data),
            style: _MeBabyOverviewText.supporting,
          ),
        ],
      ),
    );
  }
}

String _lifeStageProfileSummary(
  BuildContext context,
  MomLifeStage stage,
  _MeBabyOverviewData data,
) {
  if (stage == MomLifeStage.fertility) {
    return 'Cycle insights will use only records you confirm.';
  }
  final mom = data.overview.data?.mom;
  final dueDate = mom?.deliveryDate;
  final now = data.now;
  final today = DateTime(now.year, now.month, now.day);
  if (dueDate != null && dueDate.isAfter(today)) {
    final formatted = MaterialLocalizations.of(
      context,
    ).formatMediumDate(dueDate);
    return 'Due date: $formatted';
  }
  final dueDateOrWeek = mom?.dueDateOrWeek?.trim();
  if (dueDateOrWeek?.isNotEmpty == true) return dueDateOrWeek!;
  return 'Add confirmed pregnancy details to personalize this workspace.';
}

class _LifeStageWorkspace extends StatelessWidget {
  const _LifeStageWorkspace({required this.stage});

  final MomLifeStage stage;

  @override
  Widget build(BuildContext context) {
    final isPregnancy = stage == MomLifeStage.pregnancy;
    return Column(
      key: ValueKey('me-stage-workspace-${stage.wireValue}'),
      children: [
        _OverviewStateCard(
          title: isPregnancy
              ? 'Pregnancy milestones are ready to connect'
              : 'Cycle data not connected',
          description: isPregnancy
              ? 'Confirmed appointments and pregnancy-plan tasks will appear here when their data source is connected.'
              : 'Cycle dates and predictions will appear only after you add or connect confirmed records.',
          icon: isPregnancy
              ? Icons.calendar_month_outlined
              : Icons.track_changes_rounded,
        ),
        const SizedBox(height: 14),
        _LifeStageActionCard(
          actionKey: ValueKey('me-stage-${stage.wireValue}-plan'),
          icon: Icons.event_note_rounded,
          title: isPregnancy ? 'Pregnancy Plan' : 'Planning',
          subtitle: isPregnancy
              ? 'Review confirmed tasks and appointments'
              : 'Organize preparation and wellness tasks',
          actionLabel: 'Open Plan',
          onTap: () => context.go('/schedule'),
        ),
        const SizedBox(height: 14),
        _LifeStageActionCard(
          actionKey: ValueKey('me-stage-${stage.wireValue}-cozymate'),
          icon: Icons.auto_awesome_rounded,
          title: 'Cozymate',
          subtitle: isPregnancy
              ? 'Ask about prenatal care with cited guidance'
              : 'Ask about fertility and preconception care',
          actionLabel: 'Ask Cozymate',
          onTap: () => context.go('/'),
        ),
      ],
    );
  }
}

class _LifeStageActionCard extends StatelessWidget {
  const _LifeStageActionCard({
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

class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.identity,
    required this.data,
    required this.selectedSection,
    required this.onClose,
    required this.onSelected,
  });

  final ProfileIdentity identity;
  final _MeBabyOverviewData data;
  final String selectedSection;
  final VoidCallback onClose;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == ProfileIdentity.mom;
    return ColoredBox(
      color: _MeBabyOverviewColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 620;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filledTonal(
                  key: const ValueKey('me-baby-overview-close-avatar'),
                  tooltip: 'Show data',
                  onPressed: onClose,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  color: _MeBabyOverviewColors.wine,
                ),
              ),
              Positioned(
                left: isMom ? 18 : 24,
                top: compact ? 24 : 54,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMom ? 'Good morning,\n${data.momName}' : data.babyName,
                      style: TextStyle(
                        color: _MeBabyOverviewColors.ink,
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
                                color: _MeBabyOverviewColors.mutedText,
                                fontSize: 17,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: _MeBabyOverviewColors.wine,
                            size: 18,
                          ),
                        ],
                      )
                    else
                      Text(
                        data.babyAge,
                        style: TextStyle(
                          color: _MeBabyOverviewColors.mutedText,
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
                      ? _MeBabyOverviewAssets.momAvatar
                      : _MeBabyOverviewAssets.babyAvatarFull,
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
                      ? _CelebrationText(label: data.momAvatarSummary)
                      : Text(
                          data.babyAvatarSummary,
                          style: TextStyle(
                            color: _MeBabyOverviewColors.ink,
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
                        color: _MeBabyOverviewColors.mutedText,
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

  final ProfileIdentity identity;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sections = identity == ProfileIdentity.mom
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
              prefix: identity == ProfileIdentity.mom ? 'me' : 'baby',
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
        color: selected
            ? _MeBabyOverviewColors.ink
            : _MeBabyOverviewColors.pill,
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
                    color: selected ? Colors.white : _MeBabyOverviewColors.ink,
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
  const _MeContent({required this.section, required this.data});

  final String section;
  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    return section == 'recovery'
        ? const _MeRecoveryContent()
        : _MeLactationContent(data: data);
  }
}

class _MeLactationContent extends StatelessWidget {
  const _MeLactationContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final trends = data.orderedMilkTrends;
    final latest = data.latestMilkTrend;
    final isLoading =
        data.milkTrends.phase == OverviewResourcePhase.initial ||
        data.milkTrends.phase == OverviewResourcePhase.loading;
    if (latest == null) {
      return _OverviewStateCard(
        title: isLoading ? 'Loading milk data…' : 'No milk data yet',
        description: data.milkTrends.hasError
            ? 'Milk records could not be refreshed. Try again later.'
            : 'Record a pumping session to see today’s measured total.',
        icon: isLoading ? Icons.sync_rounded : Icons.water_drop_outlined,
        loading: isLoading,
      );
    }
    final maxVolume = trends.fold<double>(
      1,
      (maximum, item) => math.max(maximum, item.pumpedMilkVolumeMl),
    );
    return Column(
      children: [
        _V2Card(
          cardKey: const ValueKey('me-todays-milk-card'),
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
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Today’s Milk',
                      style: _MeBabyOverviewText.cardTitle,
                    ),
                  ),
                  Image(
                    image: AssetImage(_MeBabyOverviewAssets.milkBottle),
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
                    Text(
                      _formatNumber(latest.pumpedMilkVolumeMl),
                      style: _MeBabyOverviewText.heroMetric,
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: const Text(
                        'mL measured today',
                        style: _MeBabyOverviewText.metricSuffix,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: _MeBabyOverviewColors.wine,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${latest.pumpingCount} pumping ${latest.pumpingCount == 1 ? 'session' : 'sessions'}',
                        style: _MeBabyOverviewText.supporting,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FixedLineChart(
                values: [
                  for (final trend in trends)
                    trend.pumpedMilkVolumeMl / maxVolume,
                ],
                labels: [
                  for (final trend in trends) _weekdayLabel(trend.date.weekday),
                ],
              ),
              const Divider(color: _MeBabyOverviewColors.line, height: 26),
              const _ConnectDeviceRow(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _RoleCard(
          title: 'Breast',
          subtitle: 'AI self-check · Care',
          actionLabel: 'Coming soon',
          asset: _MeBabyOverviewAssets.breast,
        ),
        const SizedBox(height: 14),
        const _RoleCard(
          title: 'Lactation',
          subtitle: 'AI feeding guide',
          actionLabel: 'Coming soon',
          asset: _MeBabyOverviewAssets.lactation,
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
        _OverviewStateCard(
          title: 'Recovery data unavailable',
          description:
              'Only confirmed recovery records will appear here. A health score is not estimated from missing data.',
          icon: Icons.health_and_safety_outlined,
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Body Assessment',
          subtitle: 'Postpartum records require your confirmation',
          actionLabel: 'Coming soon',
          asset: _MeBabyOverviewAssets.bodyAssessment,
        ),
        SizedBox(height: 14),
        _RoleCard(
          title: 'Yoga',
          subtitle: 'Recovery exercises',
          actionLabel: 'Coming soon',
          asset: _MeBabyOverviewAssets.yoga,
        ),
      ],
    );
  }
}

String _weekdayLabel(int weekday) {
  return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _BabyContent extends StatelessWidget {
  const _BabyContent({required this.section, required this.data});

  final String section;
  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      'sleep' => const _BabySleepContent(),
      'feeding' => _BabyFeedingContent(data: data),
      'diaper' => const _BabyDiaperContent(),
      'growth' => _BabyGrowthContent(data: data),
      _ => const _BabyMonitorContent(),
    };
  }
}

class _BabyMonitorContent extends StatelessWidget {
  const _BabyMonitorContent();

  @override
  Widget build(BuildContext context) {
    return const _OverviewStateCard(
      title: 'Camera not connected',
      description:
          'Connect a supported nursery device to view live video and environmental readings.',
      icon: Icons.videocam_off_outlined,
    );
  }
}

class _BabySleepContent extends StatelessWidget {
  const _BabySleepContent();

  @override
  Widget build(BuildContext context) {
    return const _OverviewStateCard(
      title: 'No sleep data yet',
      description:
          'Sleep totals and predictions will appear only after a supported device or confirmed record provides data.',
      icon: Icons.bedtime_outlined,
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
          child: Row(
            children: [
              const _RoundIcon(icon: Icons.restaurant_outlined),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${feeds.length} ${feeds.length == 1 ? 'feed' : 'feeds'} recorded',
                      style: _MeBabyOverviewText.cardTitle,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${data.measuredFeedTotalMl} mL measured',
                      style: _MeBabyOverviewText.supporting,
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
              const Text('Today’s Feeds', style: _MeBabyOverviewText.cardTitle),
              const SizedBox(height: 10),
              for (var index = 0; index < feeds.length; index += 1) ...[
                _FeedRow(feed: _feedRowData(context, feeds[index])),
                if (index < feeds.length - 1)
                  const Divider(color: _MeBabyOverviewColors.line, height: 16),
              ],
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
    return const _OverviewStateCard(
      title: 'No diaper data yet',
      description:
          'Confirmed diaper records will appear here after the recording flow is connected.',
      icon: Icons.baby_changing_station_outlined,
    );
  }
}

class _BabyGrowthContent extends StatelessWidget {
  const _BabyGrowthContent({required this.data});

  final _MeBabyOverviewData data;

  @override
  Widget build(BuildContext context) {
    final growth = data.latestGrowth;
    final isLoading =
        data.growthRecords.phase == OverviewResourcePhase.initial ||
        data.growthRecords.phase == OverviewResourcePhase.loading;
    if (growth == null) {
      return _OverviewStateCard(
        title: isLoading ? 'Loading growth data…' : 'No growth data yet',
        description: data.growthRecords.hasError
            ? 'Growth records could not be refreshed. Try again later.'
            : 'Add a confirmed measurement to start the growth history.',
        icon: isLoading ? Icons.sync_rounded : Icons.monitor_weight_outlined,
        loading: isLoading,
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _GrowthMetric(
                label: 'Weight',
                value: '${_formatNumber(growth.weightKg)} kg',
                percentile: 'Recorded data',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GrowthMetric(
                label: 'Height',
                value: '${_formatNumber(growth.heightCm)} cm',
                percentile: 'Recorded data',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GrowthMetric(
                label: 'Head',
                value: '${_formatNumber(growth.headCm)} cm',
                percentile: 'Recorded data',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _OverviewStateCard(
          title: 'Reference curves are not available yet',
          description:
              'Percentiles will appear only after the reference standard and calculation contract are verified.',
          icon: Icons.show_chart_rounded,
        ),
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
    return Semantics(
      enabled: false,
      label: '$title，$actionLabel',
      child: _V2Card(
        child: Row(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: _MeBabyOverviewColors.pill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _MeBabyOverviewText.cardTitle),
                  const SizedBox(height: 5),
                  Text(subtitle, style: _MeBabyOverviewText.supporting),
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _MeBabyOverviewColors.pill,
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
                          color: _MeBabyOverviewColors.mutedText,
                          fontSize: 13,
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
                color: _MeBabyOverviewColors.pill,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.schedule_rounded,
                  color: _MeBabyOverviewColors.mutedText,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
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
        color: _MeBabyOverviewColors.pill,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: _MeBabyOverviewColors.wine, size: 22),
      ),
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
                  color: _MeBabyOverviewColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(feed.$2, style: _MeBabyOverviewText.supporting),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              feed.$3,
              style: const TextStyle(
                color: _MeBabyOverviewColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(feed.$4, style: _MeBabyOverviewText.supporting),
          ],
        ),
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
          Text(label, style: _MeBabyOverviewText.supporting),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: _MeBabyOverviewColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _MeBabyOverviewColors.pill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  percentile,
                  style: const TextStyle(
                    color: _MeBabyOverviewColors.wine,
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

class _ConnectDeviceRow extends StatelessWidget {
  const _ConnectDeviceRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Connect Device',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('me-baby-overview-connect-device'),
          onTap: () => context.go('/device'),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: const Row(
              children: [
                Icon(
                  Icons.bluetooth_rounded,
                  color: _MeBabyOverviewColors.mutedText,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connect Device',
                    style: TextStyle(
                      color: _MeBabyOverviewColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _MeBabyOverviewColors.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
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
                Text(label, style: _MeBabyOverviewText.supporting),
            ],
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

class _OverviewStateCard extends StatelessWidget {
  const _OverviewStateCard({
    required this.title,
    required this.description,
    required this.icon,
    this.loading = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _V2Card(
      child: Semantics(
        liveRegion: true,
        label: '$title. $description',
        child: Column(
          children: [
            SizedBox.square(
              dimension: 64,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: _MeBabyOverviewColors.pill,
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: _MeBabyOverviewColors.wine,
                        ),
                      )
                    : Icon(icon, color: _MeBabyOverviewColors.wine, size: 30),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _MeBabyOverviewText.cardTitle,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: _MeBabyOverviewText.supporting,
            ),
          ],
        ),
      ),
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
      button: false,
      enabled: false,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: null,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: compact
                  ? _MeBabyOverviewColors.pill
                  : _MeBabyOverviewColors.ink,
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
              color: compact ? _MeBabyOverviewColors.wine : Colors.white,
              size: compact ? 24 : 32,
            ),
          ),
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
          ..color = _MeBabyOverviewColors.wine
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

abstract final class _MeBabyOverviewAssets {
  static const momAvatar = 'assets/images/me_baby_overview/mom_avatar.png';
  static const babyAvatar = 'assets/images/me_baby_overview/baby_avatar.png';
  static const babyAvatarFull =
      'assets/images/me_baby_overview/baby_avatar_full.png';
  static const milkBottle = 'assets/images/me_baby_overview/milk_bottle.png';
  static const breast = 'assets/images/me_baby_overview/breast.png';
  static const lactation = 'assets/images/me_baby_overview/lactation.png';
  static const bodyAssessment =
      'assets/images/me_baby_overview/body_assessment.png';
  static const yoga = 'assets/images/me_baby_overview/yoga.png';
}

abstract final class _MeBabyOverviewColors {
  static const background = Color(0xfffbf7f5);
  static const hero = Color(0xfff8efec);
  static const pill = Color(0xfff2e9e6);
  static const wine = Color(0xff862644);
  static const ink = Color(0xff181818);
  static const mutedText = Color(0xffa28f89);
  static const line = Color(0xffeadfdb);
}

abstract final class _MeBabyOverviewText {
  static const cardTitle = TextStyle(
    color: _MeBabyOverviewColors.ink,
    fontSize: 21,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );
  static const heroMetric = TextStyle(
    color: _MeBabyOverviewColors.ink,
    fontSize: 50,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
  );
  static const metricSuffix = TextStyle(
    color: _MeBabyOverviewColors.mutedText,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w600,
  );
  static const supporting = TextStyle(
    color: _MeBabyOverviewColors.mutedText,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
}
