import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_controller.dart';

part 'baby_overview_components.dart';
part 'me_stage_components.dart';

enum _BabyDetail { feeding, diaper, sleep, weight, height, headCircumference }

typedef _GrowthSave =
    Future<bool> Function({double? weightKg, double? heightCm, double? headCm});

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
  _BabyDetail? _babyDetail;
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
    _babyDetail = null;
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
    _section = _initialSection(widget.identity, _displayedStage);
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
      controller.plans,
      controller.careStage,
      controller.growthMutation,
      controller.recordMutation,
    ];
  }

  void _handleProfileOverviewResourceChanged() {
    if (!mounted) return;
    final nextStage = _overviewController?.careStage.value.stage;
    if (widget.identity == ProfileIdentity.mom &&
        nextStage != _displayedStage) {
      _displayedStage = nextStage;
      _section = _initialSection(widget.identity, nextStage);
      _detailsPosition.value = 0;
      _showAvatarLayer = false;
      _avatarExpanded = false;
      if (_detailsScroll.hasClients) _detailsScroll.jumpTo(0);
    }
    setState(() {});
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.identity == ProfileIdentity.mom && _displayedStage == null) {
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
    if (widget.identity == ProfileIdentity.baby) {
      switch (section) {
        case 'feeding':
          _openBabyDetail(_BabyDetail.feeding);
          return;
        case 'diaper':
          _openBabyDetail(_BabyDetail.diaper);
          return;
      }
    }
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
      showDragHandle: false,
      useSafeArea: true,
      useRootNavigator: true,
      barrierLabel: 'Dismiss current stage selector',
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (sheetContext) =>
          _CareStageSelectorSheet(controller: controller),
    );
    controller.clearCareStageError();
  }

  void _openBabyDetail(_BabyDetail detail) {
    _detailsPosition.stop();
    _detailsPosition.value = 0;
    if (_detailsScroll.hasClients) _detailsScroll.jumpTo(0);
    setState(() {
      _babyDetail = detail;
      _showAvatarLayer = false;
      _avatarExpanded = false;
    });
  }

  void _closeBabyDetail() {
    setState(() => _babyDetail = null);
  }

  Future<void> _showBabyAddRecordSheet() async {
    final detail = await showGeneralDialog<_BabyDetail>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: 'Dismiss add record sheet',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: _BabyAddRecordSheet(),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
    if (!mounted || detail == null) return;
    _openBabyDetail(detail);
    if (detail == _BabyDetail.feeding) {
      await _openRecordComposer();
      return;
    }
    if (detail.isGrowth) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final controller = _overviewController;
      if (controller == null) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.38),
        builder: (context) => _GrowthRecordSheet(
          detail: detail,
          data: _MeBabyOverviewData.fromController(controller),
          onSave: controller.saveGrowth,
          mutation: controller.growthMutation,
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Recording is not available until this service is connected.',
        ),
      ),
    );
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
        widget.identity == ProfileIdentity.mom &&
        stageState.stage == MomLifeStage.postpartum;
    final hasAvatarWorkspace =
        widget.identity == ProfileIdentity.baby || stageState.stage != null;
    final babyDetail = _babyDetail;
    if (widget.identity == ProfileIdentity.baby && babyDetail != null) {
      return _BabyDetailPage(
        detail: babyDetail,
        data: data,
        onBack: _closeBabyDetail,
      );
    }
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
                        if (_showAvatarLayer && hasAvatarWorkspace)
                          Positioned.fill(
                            child: _AvatarStage(
                              identity: widget.identity,
                              stage: selectedStage,
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
                              child: ClipRect(
                                child: IgnorePointer(
                                  ignoring: _detailsPosition.value > 0.98,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: ColoredBox(
                            color: widget.identity == ProfileIdentity.baby
                                ? _BabyOverviewColors.background
                                : _MeBabyOverviewColors.background,
                            child: ListView(
                              key: ValueKey('route-page-${widget.path}'),
                              controller: _detailsScroll,
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                16,
                                widget.identity == ProfileIdentity.baby ? 7 : 4,
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
                                    ProfileIdentity.mom) ...[
                                  _MomStageWorkspace(
                                    stage: selectedStage!,
                                    data: data,
                                    selectedSection: _section,
                                    onSelected: _selectSection,
                                    onOpenAvatar: () => _settleDetails(1),
                                  ),
                                ] else ...[
                                  _ProfileHero(
                                    identity: widget.identity,
                                    data: data,
                                    babySection: _section,
                                    onOpenAvatar: () => _settleDetails(1),
                                  ),
                                  SizedBox(
                                    height:
                                        widget.identity == ProfileIdentity.baby
                                        ? 11
                                        : 14,
                                  ),
                                  _SectionTabs(
                                    identity: widget.identity,
                                    selected: _section,
                                    onSelected: _selectSection,
                                  ),
                                  SizedBox(
                                    height:
                                        widget.identity == ProfileIdentity.baby
                                        ? (_section == 'sleep' ? 12 : 16)
                                        : 14,
                                  ),
                                  _BabyContent(
                                    section: _section,
                                    data: data,
                                    onOpenDetail: _openBabyDetail,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_avatarExpanded)
                          const SizedBox(
                            key: ValueKey('me-baby-overview-avatar-expanded'),
                          ),
                        if (widget.identity == ProfileIdentity.baby)
                          AnimatedPositioned(
                            duration: _settleDuration,
                            curve: Curves.easeOutCubic,
                            right: 18,
                            bottom: _avatarExpanded ? 104 : 18,
                            child: _CircleAction(
                              actionKey: const ValueKey(
                                'me-baby-overview-add-record',
                              ),
                              semanticLabel: 'Add baby record',
                              icon: Icons.add_rounded,
                              onPressed: _showBabyAddRecordSheet,
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
            color: widget.identity == ProfileIdentity.baby
                ? _BabyOverviewColors.background
                : _MeBabyOverviewColors.background,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.identity == ProfileIdentity.baby ? 22 : 16,
                widget.identity == ProfileIdentity.baby ? 14 : 8,
                widget.identity == ProfileIdentity.baby ? 22 : 16,
                widget.identity == ProfileIdentity.baby ? 2 : 8,
              ),
              child: _MeBabyOverviewHeader(
                identity: widget.identity,
                careStage: stageState,
                avatarExpanded: _avatarExpanded,
                onStagePressed: _openCareStageSelector,
              ),
            ),
          ),
        ),
        if (!_avatarExpanded &&
            widget.identity == ProfileIdentity.mom &&
            usesPostpartumWorkspace &&
            selectedStage != null)
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

String _initialSection(ProfileIdentity identity, [MomLifeStage? stage]) {
  if (identity == ProfileIdentity.baby) return 'monitor';
  return switch (stage) {
    MomLifeStage.fertility => 'cycle',
    MomLifeStage.pregnancy => 'prenatal',
    MomLifeStage.postpartum || null => 'lactation',
  };
}

class _MeBabyOverviewData {
  const _MeBabyOverviewData({
    required this.overview,
    required this.milkTrends,
    required this.feedingRecords,
    required this.growthRecords,
    required this.plans,
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
        plans: const ProfileOverviewResource.initial(),
        now: DateTime.now(),
      );
    }
    return _MeBabyOverviewData(
      overview: controller.overview.value,
      milkTrends: controller.milkTrends.value,
      feedingRecords: controller.feedingRecords.value,
      growthRecords: controller.growthRecords.value,
      plans: controller.plans.value,
      now: controller.now(),
    );
  }

  final ProfileOverviewResource<ProfileOverview> overview;
  final ProfileOverviewResource<List<MilkTrendDay>> milkTrends;
  final ProfileOverviewResource<List<FeedingRecord>> feedingRecords;
  final ProfileOverviewResource<List<GrowthRecord>> growthRecords;
  final ProfileOverviewResource<PlanDashboard> plans;
  final DateTime now;

  bool get hasStaleRefreshFailure => [
    overview,
    milkTrends,
    feedingRecords,
    growthRecords,
    plans,
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
    final values = orderedGrowthRecords;
    if (values.isEmpty) return null;
    return values.first;
  }

  List<GrowthRecord> get orderedGrowthRecords {
    final values = List<GrowthRecord>.of(
      growthRecords.data ?? const <GrowthRecord>[],
    );
    values.sort((left, right) {
      final leftTime = left.measuredAt;
      final rightTime = right.measuredAt;
      if (leftTime == null && rightTime == null) return 0;
      if (leftTime == null) return 1;
      if (rightTime == null) return -1;
      return rightTime.compareTo(leftTime);
    });
    return values;
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
    required this.avatarExpanded,
    required this.onStagePressed,
  });

  final ProfileIdentity identity;
  final CareStageSelectionState careStage;
  final bool avatarExpanded;
  final VoidCallback onStagePressed;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == ProfileIdentity.mom;
    final isBaby = identity == ProfileIdentity.baby;
    final highlighted = isMom && avatarExpanded;
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
    final babyPill = Semantics(
      label: '$label, fixed profile',
      enabled: false,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _BabyOverviewColors.pill,
          borderRadius: BorderRadius.circular(24),
        ),
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
                    color: _BabyOverviewColors.wine,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _BabyOverviewColors.wine,
              size: 19,
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          if (isBaby)
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _MomCozyWordmark(useBabyPalette: true),
              ),
            )
          else if (textScale < 1.8) ...[
            const _MomCozyWordmark(),
            const SizedBox(width: 10),
          ],
          if (isBaby)
            SizedBox(width: 110, child: babyPill)
          else
            Expanded(
              child: Semantics(
                label: 'Current stage: $label. Change current stage.',
                button: true,
                enabled: careStage.isResolved && !careStage.isSaving,
                child: Material(
                  key: const ValueKey('me-current-stage-selector'),
                  color: highlighted
                      ? _MeBabyOverviewColors.wine
                      : _MeBabyOverviewColors.pill,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: careStage.isResolved && !careStage.isSaving
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
                                style: TextStyle(
                                  color: highlighted
                                      ? Colors.white
                                      : _MeBabyOverviewColors.wine,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (careStage.isSaving ||
                                (!careStage.isResolved &&
                                    careStage.error == null))
                              SizedBox.square(
                                dimension: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: highlighted
                                      ? Colors.white
                                      : _MeBabyOverviewColors.wine,
                                ),
                              )
                            else if (!careStage.isResolved)
                              Icon(
                                Icons.error_outline_rounded,
                                color: highlighted
                                    ? Colors.white
                                    : _MeBabyOverviewColors.wine,
                                size: 19,
                              )
                            else
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: highlighted
                                    ? Colors.white
                                    : _MeBabyOverviewColors.wine,
                                size: 19,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          _DisabledCircleAction(
            actionKey: const ValueKey('me-baby-overview-notification-disabled'),
            semanticLabel: 'Notifications are not available yet',
            icon: Icons.notifications_none_rounded,
            compact: true,
            size: isBaby ? 38 : null,
            backgroundColor: isBaby
                ? _BabyOverviewColors.pill
                : highlighted
                ? _MeBabyOverviewColors.wine
                : null,
            foregroundColor: isBaby
                ? _BabyOverviewColors.wine
                : highlighted
                ? Colors.white
                : null,
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
        final maxHeight = math.min(
          MediaQuery.sizeOf(context).height * 0.76,
          520.0,
        );
        return PopScope(
          canPop: !state.isSaving,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Material(
                  key: const ValueKey('me-stage-selector-card'),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          color: _MeBabyOverviewColors.hero,
                          padding: const EdgeInsets.fromLTRB(24, 12, 14, 12),
                          child: Row(
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
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          child: Column(
                            children: [
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
                                    final changed = await controller
                                        .updateCareStage(stage);
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
                      ],
                    ),
                  ),
                ),
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
  const _MomCozyWordmark({this.useBabyPalette = false});

  final bool useBabyPalette;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Text(
        'momcozy',
        style: TextStyle(
          color: useBabyPalette
              ? _BabyOverviewColors.ink
              : _MeBabyOverviewColors.ink,
          fontSize: 25,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.identity,
    required this.data,
    required this.babySection,
    required this.onOpenAvatar,
  });

  final ProfileIdentity identity;
  final _MeBabyOverviewData data;
  final String babySection;
  final VoidCallback onOpenAvatar;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == ProfileIdentity.mom;
    if (!isMom) {
      return _BabyProfileHero(
        data: data,
        compactForSleep: babySection == 'sleep',
        onOpenAvatar: onOpenAvatar,
      );
    }
    final avatar = Positioned(
      key: ValueKey(
        isMom
            ? 'me-baby-overview-mom-hero-avatar'
            : 'me-baby-overview-baby-hero-avatar',
      ),
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
    );
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
          if (isMom) avatar,
          Positioned(
            key: ValueKey(
              isMom
                  ? 'me-baby-overview-mom-hero-copy'
                  : 'me-baby-overview-baby-hero-copy',
            ),
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
          if (!isMom) avatar,
          Positioned.fill(
            child: Semantics(
              key: const ValueKey('me-baby-overview-open-avatar'),
              label: 'View avatar',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenAvatar,
                child: const SizedBox.expand(),
              ),
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

class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.identity,
    required this.stage,
    required this.data,
    required this.selectedSection,
    required this.onClose,
    required this.onSelected,
  });

  final ProfileIdentity identity;
  final MomLifeStage? stage;
  final _MeBabyOverviewData data;
  final String selectedSection;
  final VoidCallback onClose;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (identity == ProfileIdentity.mom) {
      return _MomAvatarStage(
        stage: stage ?? MomLifeStage.postpartum,
        data: data,
        selectedSection: selectedSection,
        onClose: onClose,
        onSelected: onSelected,
      );
    }
    return _BabyAvatarStage(
      data: data,
      selectedSection: selectedSection,
      onClose: onClose,
      onSelected: onSelected,
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
    final isBaby = identity == ProfileIdentity.baby;
    final sections = isBaby
        ? const [
            ('monitor', 'Monitor', Icons.monitor_heart_outlined),
            ('sleep', 'Sleep', Icons.bedtime_outlined),
            ('feeding', 'Feeding', Icons.child_care_rounded),
            ('diaper', 'Diaper', Icons.baby_changing_station_outlined),
          ]
        : const [
            ('lactation', 'Lactation', Icons.water_drop_outlined),
            ('recovery', 'Recovery', Icons.favorite_outline_rounded),
          ];
    if (isBaby) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (var index = 0; index < sections.length; index += 1) ...[
              if (index > 0) SizedBox(width: compact ? 5 : 7),
              Expanded(
                child: _SectionTab(
                  section: sections[index].$1,
                  label: sections[index].$2,
                  icon: sections[index].$3,
                  selected: selected == sections[index].$1,
                  prefix: 'baby',
                  onTap: () => onSelected(sections[index].$1),
                  compact: compact,
                ),
              ),
            ],
          ],
        ),
      );
    }
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
            section: section.$1,
            label: section.$2,
            icon: section.$3,
            selected: selected == section.$1,
            prefix: 'me',
            onTap: () => onSelected(section.$1),
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
    final isBaby = prefix == 'baby';
    final foreground = selected ? Colors.white : _MeBabyOverviewColors.ink;
    final content = isBaby
        ? SizedBox(
            height: MomCozyTapTargets.minimum,
            child: Center(
              child: Material(
                color: selected
                    ? _BabyOverviewColors.ink
                    : _BabyOverviewColors.pill,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onTap,
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              color: selected
                                  ? Colors.white
                                  : _BabyOverviewColors.ink,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : _BabyOverviewColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : Material(
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
                        color: selected
                            ? Colors.white
                            : _MeBabyOverviewColors.wine,
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
          );
    return Semantics(
      key: ValueKey('$prefix-section-$section'),
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: content,
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
        const _RecoveryStatusCard(),
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
        color: Color(0xfff2e9e6),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: Color(0xff862644), size: 22),
      ),
    );
  }
}

const _babyFeedSupportingStyle = TextStyle(
  color: Color(0xffa28f89),
  fontSize: 14,
  height: 1.35,
  fontWeight: FontWeight.w600,
);

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
                        color: Color(0xff181818),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(feed.$2, style: _babyFeedSupportingStyle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            feed.$3,
            style: const TextStyle(
              color: Color(0xff181818),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(feed.$4, style: _babyFeedSupportingStyle),
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
                  color: Color(0xff181818),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(feed.$2, style: _babyFeedSupportingStyle),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              feed.$3,
              style: const TextStyle(
                color: Color(0xff181818),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(feed.$4, style: _babyFeedSupportingStyle),
          ],
        ),
      ],
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
    this.backgroundColor,
    this.foregroundColor,
    this.size,
  });

  final Key actionKey;
  final String semanticLabel;
  final IconData icon;
  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (compact ? 44.0 : 62.0);
    return Semantics(
      key: actionKey,
      label: semanticLabel,
      button: false,
      enabled: false,
      child: SizedBox.square(
        dimension: math.max(resolvedSize, MomCozyTapTargets.minimum),
        child: Center(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: null,
              child: Container(
                width: resolvedSize,
                height: resolvedSize,
                decoration: BoxDecoration(
                  color:
                      backgroundColor ??
                      (compact
                          ? _MeBabyOverviewColors.pill
                          : _MeBabyOverviewColors.ink),
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
                  color:
                      foregroundColor ??
                      (compact ? _MeBabyOverviewColors.wine : Colors.white),
                  size: compact ? 24 : 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.actionKey,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  });

  final Key actionKey;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: actionKey,
      label: semanticLabel,
      button: true,
      enabled: true,
      child: Material(
        color: _BabyOverviewColors.ink,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: const Color(0x52000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 56,
            child: Icon(icon, color: Colors.white, size: 30),
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
  static const pregnancyAvatar =
      'assets/images/me_baby_overview/pregnancy_avatar.png';
  static const babyAvatar = 'assets/images/me_baby_overview/baby_avatar.png';
  static const babyAvatarFull =
      'assets/images/me_baby_overview/baby_avatar_full.png';
  static const milkBottle = 'assets/images/me_baby_overview/milk_bottle.png';
  static const breast = 'assets/images/me_baby_overview/breast.png';
  static const lactation = 'assets/images/me_baby_overview/lactation.png';
  static const bodyAssessment =
      'assets/images/me_baby_overview/body_assessment.png';
  static const yoga = 'assets/images/me_baby_overview/yoga.png';
  static const nurseryCamera =
      'assets/images/me_baby_overview/nursery_camera.png';
  static const sleepTraining =
      'assets/images/me_baby_overview/sleep_training.png';
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

abstract final class _BabyOverviewColors {
  static const background = MomCozyV3Colors.background;
  static const pill = MomCozyV3Colors.surfaceTint;
  static const wine = MomCozyV3Colors.brand;
  static const ink = MomCozyV3Colors.ink;
  static const mutedText = MomCozyV3Colors.mutedText;
  static const line = MomCozyV3Colors.divider;
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

abstract final class _BabyText {
  static const cardTitle = TextStyle(
    color: _BabyOverviewColors.ink,
    fontSize: 16,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );
  static const heroMetric = TextStyle(
    color: _BabyOverviewColors.ink,
    fontSize: 42,
    height: 1,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
  );
  static const supporting = TextStyle(
    color: _BabyOverviewColors.mutedText,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const supportingSmall = TextStyle(
    color: _BabyOverviewColors.mutedText,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
  static const eyebrow = TextStyle(
    color: _BabyOverviewColors.mutedText,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
  static const accentLabel = TextStyle(
    color: _BabyOverviewColors.wine,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );
}
