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
  bool _refreshing = false;
  MomLifeStage? _displayedStage;
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
    _displayedStage = null;
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
      controller.recordMutation,
    ];
  }

  void _handleProfileOverviewResourceChanged() {
    if (!mounted) return;
    final nextStage = _overviewController?.careStage.value.stage;
    if (widget.identity == ProfileIdentity.mom &&
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
      useRootNavigator: true,
      barrierLabel: 'Dismiss current stage selector',
      backgroundColor: _MeBabyOverviewColors.background,
      builder: (sheetContext) =>
          _CareStageSelectorSheet(controller: controller),
    );
    controller.clearCareStageError();
  }

  Future<void> _openRecordComposer() async {
    final controller = _overviewController;
    if (controller == null || controller.recordMutation.value.isSaving) return;
    controller.clearRecordMutationError();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      useRootNavigator: true,
      barrierLabel: 'Dismiss add record form',
      backgroundColor: _MeBabyOverviewColors.background,
      builder: (sheetContext) => _RecordComposerSheet(
        identity: widget.identity,
        controller: controller,
      ),
    );
    controller.clearRecordMutationError();
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Record saved')));
  }

  Future<void> _refreshOverview() async {
    final controller = _overviewController;
    if (controller == null || _refreshing) return;
    setState(() => _refreshing = true);
    await controller.refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _MeBabyOverviewData.fromController(_overviewController);
    final stageState =
        _overviewController?.careStage.value ?? const CareStageSelectionState();
    final usesPostpartumWorkspace =
        widget.identity != ProfileIdentity.mom ||
        stageState.stage == MomLifeStage.postpartum;
    final selectedStage = stageState.stage;
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
                                16,
                                4,
                                16,
                                112,
                              ),
                              children: [
                                if (data.hasStaleRefreshFailure) ...[
                                  _RefreshFailureBanner(
                                    onRetry: _refreshOverview,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (widget.identity == ProfileIdentity.mom &&
                                    selectedStage == null) ...[
                                  _UnselectedStageWorkspace(
                                    loading:
                                        !stageState.isResolved &&
                                        stageState.error == null,
                                    loadFailed:
                                        !stageState.isResolved &&
                                        stageState.error != null,
                                    onSelectStage: stageState.isResolved
                                        ? _openCareStageSelector
                                        : null,
                                    onRetry: () {
                                      final controller = _overviewController;
                                      if (controller != null) {
                                        unawaited(controller.refresh());
                                      }
                                    },
                                  ),
                                ] else if (widget.identity ==
                                        ProfileIdentity.mom &&
                                    !usesPostpartumWorkspace) ...[
                                  _LifeStageHero(
                                    stage: selectedStage!,
                                    data: data,
                                    refreshing: _refreshing,
                                    onRefresh: _refreshOverview,
                                  ),
                                  const SizedBox(height: 14),
                                  _LifeStageWorkspace(stage: selectedStage),
                                ] else ...[
                                  _ProfileHero(
                                    identity: widget.identity,
                                    data: data,
                                    onOpenAvatar: () => _settleDetails(1),
                                    refreshing: _refreshing,
                                    onRefresh: _refreshOverview,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _MeBabyOverviewHeader(
                identity: widget.identity,
                careStage: stageState,
                onStagePressed: _openCareStageSelector,
              ),
            ),
          ),
        ),
        if (!_avatarExpanded &&
            usesPostpartumWorkspace &&
            (widget.identity == ProfileIdentity.baby || selectedStage != null))
          Positioned(
            right: 18,
            bottom: 20,
            child: _AddRecordButton(
              saving:
                  _overviewController?.recordMutation.value.isSaving == true,
              onPressed: _openRecordComposer,
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

  bool get hasStaleRefreshFailure => [
    overview,
    milkTrends,
    feedingRecords,
    growthRecords,
  ].any((resource) => resource.hasError && resource.data != null);

  String get momName {
    final name = overview.data?.mom?.displayName?.trim();
    return name == null || name.isEmpty ? 'Me' : name;
  }

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

  List<MilkTrendDay> get recentMilkTrends {
    final today = DateTime(now.year, now.month, now.day);
    final values = orderedMilkTrends
        .where((trend) {
          final date = DateTime(
            trend.date.year,
            trend.date.month,
            trend.date.day,
          );
          return !date.isAfter(today);
        })
        .toList(growable: false);
    return values.length <= 7 ? values : values.sublist(values.length - 7);
  }

  MilkTrendDay? get todayMilkTrend {
    final today = DateTime(now.year, now.month, now.day);
    for (final trend in orderedMilkTrends.reversed) {
      final date = DateTime(trend.date.year, trend.date.month, trend.date.day);
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        return trend;
      }
    }
    return null;
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
    final trend = todayMilkTrend;
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final label = !isMom
        ? 'Infant'
        : careStage.isResolved && careStage.stage != null
        ? careStage.stage!.label
        : careStage.isResolved
        ? 'Select Stage'
        : careStage.error != null
        ? 'Stage unavailable'
        : 'My Stage';
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          if (textScale < 1.8) ...[
            const _MomCozyWordmark(),
            const SizedBox(width: 10),
          ],
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
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _MeBabyOverviewColors.wine,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isMom) ...[
                            const SizedBox(width: 5),
                            if (careStage.isSaving ||
                                (!careStage.isResolved &&
                                    careStage.error == null))
                              const SizedBox.square(
                                dimension: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _MeBabyOverviewColors.wine,
                                ),
                              )
                            else if (!careStage.isResolved)
                              const Icon(
                                Icons.error_outline_rounded,
                                color: _MeBabyOverviewColors.wine,
                                size: 19,
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

class _RefreshFailureBanner extends StatelessWidget {
  const _RefreshFailureBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: const Color(0xfffff0f2),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: _MeBabyOverviewColors.wine,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Couldn’t refresh. Showing saved data.',
                  style: TextStyle(
                    color: _MeBabyOverviewColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
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

enum _RecordKind { pumping, feeding, growth }

class _RecordComposerSheet extends StatefulWidget {
  const _RecordComposerSheet({
    required this.identity,
    required this.controller,
  });

  final ProfileIdentity identity;
  final ProfileOverviewController controller;

  @override
  State<_RecordComposerSheet> createState() => _RecordComposerSheetState();
}

class _RecordComposerSheetState extends State<_RecordComposerSheet> {
  late _RecordKind _kind = widget.identity == ProfileIdentity.mom
      ? _RecordKind.pumping
      : _RecordKind.feeding;
  final _amountController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _headController = TextEditingController();
  String _feedingType = 'bottle';
  String? _validationError;

  @override
  void dispose() {
    _amountController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _headController.dispose();
    super.dispose();
  }

  double? _positiveNumber(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  Future<void> _save() async {
    widget.controller.clearRecordMutationError();
    bool saved;
    switch (_kind) {
      case _RecordKind.pumping:
        final amount = _positiveNumber(_amountController);
        if (amount == null) {
          setState(() => _validationError = 'Enter a milk amount above 0 mL.');
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.savePumpingRecord(amountMl: amount);
      case _RecordKind.feeding:
        final amount = _positiveNumber(_amountController);
        if (amount == null) {
          setState(
            () => _validationError = 'Enter a feeding amount above 0 mL.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveFeedingRecord(
          type: _feedingType,
          amountMl: amount,
        );
      case _RecordKind.growth:
        final weight = _positiveNumber(_weightController);
        final height = _positiveNumber(_heightController);
        final head = _positiveNumber(_headController);
        if (weight == null && height == null && head == null) {
          setState(
            () => _validationError =
                'Enter at least one confirmed growth measurement.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveGrowthRecord(
          weightKg: weight,
          heightCm: height,
          headCm: head,
        );
    }
    if (!mounted || !saved) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isMom = widget.identity == ProfileIdentity.mom;
    return ValueListenableBuilder<RecordMutationState>(
      valueListenable: widget.controller.recordMutation,
      builder: (context, mutation, _) {
        return PopScope(
          canPop: !mutation.isSaving,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMom ? 'Add pumping record' : 'Add baby record',
                          style: const TextStyle(
                            color: _MeBabyOverviewColors.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: mutation.isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!isMom) ...[
                    SegmentedButton<_RecordKind>(
                      segments: const [
                        ButtonSegment(
                          value: _RecordKind.feeding,
                          icon: Icon(Icons.restaurant_outlined),
                          label: Text('Feeding'),
                        ),
                        ButtonSegment(
                          value: _RecordKind.growth,
                          icon: Icon(Icons.monitor_weight_outlined),
                          label: Text('Growth'),
                        ),
                      ],
                      selected: {_kind},
                      onSelectionChanged: mutation.isSaving
                          ? null
                          : (selection) {
                              setState(() {
                                _kind = selection.single;
                                _validationError = null;
                              });
                              widget.controller.clearRecordMutationError();
                            },
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_kind == _RecordKind.growth)
                    _GrowthRecordFields(
                      weightController: _weightController,
                      heightController: _heightController,
                      headController: _headController,
                      enabled: !mutation.isSaving,
                    )
                  else ...[
                    if (_kind == _RecordKind.feeding) ...[
                      const Text(
                        'Feeding type',
                        style: _MeBabyOverviewText.supporting,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'bottle', label: Text('Bottle')),
                          ButtonSegment(
                            value: 'formula',
                            label: Text('Formula'),
                          ),
                        ],
                        selected: {_feedingType},
                        onSelectionChanged: mutation.isSaving
                            ? null
                            : (selection) => setState(
                                () => _feedingType = selection.single,
                              ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _RecordNumberField(
                      fieldKey: ValueKey(
                        _kind == _RecordKind.pumping
                            ? 'record-pumping-amount'
                            : 'record-feeding-amount',
                      ),
                      controller: _amountController,
                      label: _kind == _RecordKind.pumping
                          ? 'Measured milk'
                          : 'Measured amount',
                      suffix: 'mL',
                      enabled: !mutation.isSaving,
                    ),
                  ],
                  if (_validationError != null || mutation.error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _validationError ??
                            'The record could not be saved. Check your connection and try again.',
                        style: const TextStyle(
                          color: _MeBabyOverviewColors.wine,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    key: const ValueKey('record-save'),
                    onPressed: mutation.isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _MeBabyOverviewColors.wine,
                      shape: const StadiumBorder(),
                    ),
                    child: mutation.isSaving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save record'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GrowthRecordFields extends StatelessWidget {
  const _GrowthRecordFields({
    required this.weightController,
    required this.heightController,
    required this.headController,
    required this.enabled,
  });

  final TextEditingController weightController;
  final TextEditingController heightController;
  final TextEditingController headController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RecordNumberField(
          fieldKey: const ValueKey('record-growth-weight'),
          controller: weightController,
          label: 'Weight',
          suffix: 'kg',
          enabled: enabled,
        ),
        const SizedBox(height: 14),
        _RecordNumberField(
          fieldKey: const ValueKey('record-growth-height'),
          controller: heightController,
          label: 'Height',
          suffix: 'cm',
          enabled: enabled,
        ),
        const SizedBox(height: 14),
        _RecordNumberField(
          fieldKey: const ValueKey('record-growth-head'),
          controller: headController,
          label: 'Head circumference',
          suffix: 'cm',
          enabled: enabled,
        ),
      ],
    );
  }
}

class _RecordNumberField extends StatelessWidget {
  const _RecordNumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.enabled,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _AddRecordButton extends StatelessWidget {
  const _AddRecordButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: saving ? 'Saving record' : 'Add record',
      child: FloatingActionButton(
        key: const ValueKey('me-baby-overview-add-record'),
        tooltip: 'Add record',
        onPressed: saving ? null : onPressed,
        backgroundColor: _MeBabyOverviewColors.ink,
        foregroundColor: Colors.white,
        child: saving
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_rounded, size: 30),
      ),
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
    return MediaQuery.withNoTextScaling(
      child: const Row(
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
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.identity,
    required this.data,
    required this.onOpenAvatar,
    required this.refreshing,
    required this.onRefresh,
  });

  final ProfileIdentity identity;
  final _MeBabyOverviewData data;
  final VoidCallback onOpenAvatar;
  final bool refreshing;
  final VoidCallback onRefresh;

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
            right: 58,
            child: IconButton.filledTonal(
              key: const ValueKey('me-baby-overview-refresh'),
              tooltip: 'Refresh profile data',
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _MeBabyOverviewColors.wine,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              color: _MeBabyOverviewColors.wine,
            ),
          ),
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

class _UnselectedStageWorkspace extends StatelessWidget {
  const _UnselectedStageWorkspace({
    required this.loading,
    required this.loadFailed,
    required this.onSelectStage,
    required this.onRetry,
  });

  final bool loading;
  final bool loadFailed;
  final VoidCallback? onSelectStage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? 'Loading your care stage…'
        : loadFailed
        ? 'Your care stage is unavailable'
        : 'Choose your current stage';
    final description = loading
        ? 'Your workspace will appear when your profile is ready.'
        : loadFailed
        ? 'We couldn’t refresh your profile. Your stage was not guessed.'
        : 'Select the stage that matches you now to open the right workspace.';
    return Semantics(
      key: const ValueKey('me-stage-unselected'),
      liveRegion: loadFailed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _MeBabyOverviewColors.hero,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 46,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _MeBabyOverviewColors.wine,
                      ),
                    )
                  : Icon(
                      loadFailed
                          ? Icons.cloud_off_outlined
                          : Icons.favorite_outline_rounded,
                      color: _MeBabyOverviewColors.wine,
                      size: 36,
                    ),
            ),
            const SizedBox(height: 18),
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
            if (!loading) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: ValueKey(
                  loadFailed ? 'me-stage-retry' : 'me-stage-choose',
                ),
                onPressed: loadFailed ? onRetry : onSelectStage,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _MeBabyOverviewColors.wine,
                ),
                icon: Icon(
                  loadFailed ? Icons.refresh_rounded : Icons.swap_horiz_rounded,
                ),
                label: Text(loadFailed ? 'Try again' : 'Select stage'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LifeStageHero extends StatelessWidget {
  const _LifeStageHero({
    required this.stage,
    required this.data,
    required this.refreshing,
    required this.onRefresh,
  });

  final MomLifeStage stage;
  final _MeBabyOverviewData data;
  final bool refreshing;
  final VoidCallback onRefresh;

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
          Row(
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
              const Spacer(),
              IconButton.filledTonal(
                key: const ValueKey('me-baby-overview-refresh'),
                tooltip: 'Refresh profile data',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: _MeBabyOverviewColors.wine,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                color: _MeBabyOverviewColors.wine,
              ),
            ],
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
                      : _MeBabyOverviewAssets.babyAvatar,
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
        ? const [
            ('lactation', 'Lactation', Icons.water_drop_outlined),
            ('recovery', 'Recovery', Icons.favorite_outline_rounded),
          ]
        : const [
            ('monitor', 'Monitor', Icons.videocam_outlined),
            ('sleep', 'Sleep', Icons.bedtime_outlined),
            ('feeding', 'Feeding', Icons.restaurant_outlined),
            ('diaper', 'Diaper', Icons.baby_changing_station_outlined),
            ('growth', 'Growth', Icons.monitor_weight_outlined),
          ];
    return SizedBox(
      height: compact ? 44 : 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: sections.length,
        separatorBuilder: (_, _) => SizedBox(width: compact ? 5 : 7),
        itemBuilder: (context, index) {
          final section = sections[index];
          return _SectionTab(
            section: sections[index].$1,
            label: sections[index].$2,
            icon: section.$3,
            selected: selected == sections[index].$1,
            prefix: identity == ProfileIdentity.mom ? 'me' : 'baby',
            onTap: () => onSelected(sections[index].$1),
            compact: compact,
          );
        },
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.section,
    required this.label,
    required this.icon,
    required this.selected,
    required this.prefix,
    required this.onTap,
    required this.compact,
  });

  final String section;
  final String label;
  final IconData icon;
  final bool selected;
  final String prefix;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _MeBabyOverviewColors.ink;
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: compact ? 62 : 68,
              minHeight: compact ? 40 : 48,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: selected ? Colors.white : _MeBabyOverviewColors.wine,
                    size: compact ? 14 : 16,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w800,
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
    final trends = data.recentMilkTrends;
    final latest = data.todayMilkTrend;
    final isLoading =
        data.milkTrends.phase == OverviewResourcePhase.initial ||
        data.milkTrends.phase == OverviewResourcePhase.loading;
    if (latest == null) {
      return _OverviewStateCard(
        title: isLoading ? 'Loading milk data…' : 'No milk recorded today',
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
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    _formatNumber(latest.pumpedMilkVolumeMl),
                    style: _MeBabyOverviewText.heroMetric,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 7),
                    child: Text(
                      'mL measured today',
                      style: _MeBabyOverviewText.metricSuffix,
                    ),
                  ),
                ],
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
                    child: Text(
                      '${latest.pumpingCount} pumping ${latest.pumpingCount == 1 ? 'session' : 'sessions'}',
                      style: _MeBabyOverviewText.supporting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (trends.length < 2)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _MeBabyOverviewColors.pill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        color: _MeBabyOverviewColors.wine,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add another day to see a trend',
                          style: _MeBabyOverviewText.supporting,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _FixedLineChart(
                  values: [
                    for (final trend in trends)
                      trend.pumpedMilkVolumeMl / maxVolume,
                  ],
                  labels: [
                    for (final trend in trends)
                      _weekdayLabel(trend.date.weekday),
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
    return Column(
      children: [
        const _OverviewStateCard(
          title: 'Recovery data unavailable',
          description:
              'Only confirmed recovery records will appear here. A health score is not estimated from missing data.',
          icon: Icons.health_and_safety_outlined,
        ),
        const SizedBox(height: 14),
        _RoleCard(
          title: 'Body Assessment',
          subtitle: 'View confirmed postpartum profile status',
          actionLabel: 'Open Profile',
          asset: _MeBabyOverviewAssets.bodyAssessment,
          onTap: () => context.go('/more/body-profile'),
        ),
        const SizedBox(height: 14),
        const _RoleCard(
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
    return _OverviewStateCard(
      title: 'Camera not connected',
      description:
          'Connect a supported nursery device to view live video and environmental readings.',
      icon: Icons.videocam_off_outlined,
      actionKey: const ValueKey('baby-monitor-connect-device'),
      actionLabel: 'Connect device',
      onAction: () => context.go('/device'),
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
    final metrics = [
      _GrowthMetric(
        label: 'Weight',
        value: '${_formatNumber(growth.weightKg)} kg',
        percentile: 'Recorded data',
      ),
      _GrowthMetric(
        label: 'Height',
        value: '${_formatNumber(growth.heightCm)} cm',
        percentile: 'Recorded data',
      ),
      _GrowthMetric(
        label: 'Head',
        value: '${_formatNumber(growth.headCm)} cm',
        percentile: 'Recorded data',
      ),
    ];
    final useVerticalMetrics = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      children: [
        if (useVerticalMetrics)
          for (var index = 0; index < metrics.length; index += 1) ...[
            metrics[index],
            if (index < metrics.length - 1) const SizedBox(height: 8),
          ]
        else
          Row(
            children: [
              for (var index = 0; index < metrics.length; index += 1) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: metrics[index]),
              ],
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
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = _V2Card(
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
                      style: TextStyle(
                        color: onTap == null
                            ? _MeBabyOverviewColors.mutedText
                            : _MeBabyOverviewColors.wine,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: _MeBabyOverviewColors.pill,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                onTap == null
                    ? Icons.schedule_rounded
                    : Icons.chevron_right_rounded,
                color: onTap == null
                    ? _MeBabyOverviewColors.mutedText
                    : _MeBabyOverviewColors.wine,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      enabled: onTap != null,
      button: onTap != null,
      label: '$title，$actionLabel',
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(26),
              child: content,
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
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
          const SizedBox(height: 10),
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
      );
    }
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
          Text(
            value,
            style: const TextStyle(
              color: _MeBabyOverviewColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
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
    this.actionKey,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool loading;
  final Key? actionKey;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                key: actionKey,
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: _MeBabyOverviewColors.wine,
                  shape: const StadiumBorder(),
                ),
                child: Text(actionLabel!),
              ),
            ],
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
            colors: [Color(0x337A2840), Color(0x007A2840)],
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
  static const milkBottle = 'assets/images/me_baby_overview/milk_bottle.png';
  static const breast = 'assets/images/me_baby_overview/breast.png';
  static const lactation = 'assets/images/me_baby_overview/lactation.png';
  static const bodyAssessment =
      'assets/images/me_baby_overview/body_assessment.png';
  static const yoga = 'assets/images/me_baby_overview/yoga.png';
}

abstract final class _MeBabyOverviewColors {
  static const background = Color(0xfffbf5f3);
  static const hero = Color(0xfff8efec);
  static const pill = Color(0xfff2e9e6);
  static const wine = Color(0xff7a2840);
  static const ink = Color(0xff1a1a1a);
  static const mutedText = Color(0xff6f625e);
  static const line = Color(0xffe5d7d2);
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
