import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/maternal_care_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_overview.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_controller.dart';

part 'baby_overview_components.dart';
part 'me_stage_components.dart';

enum _BabyDetail { feeding, diaper, sleep, weight, height, headCircumference }

typedef _GrowthSave =
    Future<bool> Function({
      double? weightKg,
      double? heightCm,
      double? headCm,
      required MeasurementPosition measurementPosition,
      required MeasurementContext measurementContext,
    });

class MeBabyOverviewPage extends StatefulWidget {
  const MeBabyOverviewPage({
    super.key,
    required this.path,
    required this.identity,
    this.onBabySelected,
  });

  final String path;
  final ProfileIdentity identity;
  final Future<void> Function(String babyId)? onBabySelected;

  @override
  State<MeBabyOverviewPage> createState() => _MeBabyOverviewPageState();
}

class _MeBabyOverviewPageState extends State<MeBabyOverviewPage>
    with SingleTickerProviderStateMixin {
  static const _settleDuration = Duration(milliseconds: 320);
  static const _dragThreshold = 0.12;

  late final AnimationController _detailsPosition;
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
  void initState() {
    super.initState();
    _detailsPosition = AnimationController(
      vsync: this,
      duration: _settleDuration,
    );
  }

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
      controller.maternalCareOverview,
      controller.milkTrends,
      controller.waterRecords,
      controller.waterTrends,
      controller.vitalRecords,
      controller.feedingRecords,
      controller.feedingSummary,
      controller.sleepRecords,
      controller.diaperRecords,
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
    if (detail == _BabyDetail.feeding ||
        detail == _BabyDetail.sleep ||
        detail == _BabyDetail.diaper) {
      _openBabyDetail(detail);
      await _openRecordComposer(
        initialKind: switch (detail) {
          _BabyDetail.sleep => _RecordKind.sleep,
          _BabyDetail.diaper => _RecordKind.diaper,
          _BabyDetail.feeding => _RecordKind.feeding,
          _ => null,
        },
      );
      return;
    }
    if (!detail.isGrowth) return;
    _openBabyDetail(detail);
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
  }

  Future<void> _showMomAddRecordSheet() async {
    final choice = await showGeneralDialog<_MomRecordChoice>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.28),
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
              Align(
                alignment: Alignment.bottomCenter,
                child: const _MomAddRecordSheet(),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _MomRecordChoice.pumpingLeft:
        await _openRecordComposer(
          initialKind: _RecordKind.pumping,
          initialBreastSide: PumpingSide.left,
        );
      case _MomRecordChoice.pumpingRight:
        await _openRecordComposer(
          initialKind: _RecordKind.pumping,
          initialBreastSide: PumpingSide.right,
        );
      case _MomRecordChoice.water:
        await _openRecordComposer(initialKind: _RecordKind.water);
      case _MomRecordChoice.weight:
        await _openRecordComposer(initialKind: _RecordKind.weight);
      case _MomRecordChoice.vitals:
        await _openRecordComposer(initialKind: _RecordKind.vitals);
      case _MomRecordChoice.sleep:
        return;
    }
  }

  Future<void> _openRecordComposer({
    _RecordKind? initialKind,
    PumpingSide? initialBreastSide,
  }) async {
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
        initialKind: initialKind,
        initialBreastSide: initialBreastSide,
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
    if (widget.identity == ProfileIdentity.baby &&
        widget.path == '/baby/development') {
      return _BabyDevelopmentPage(
        data: data,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/baby');
          }
        },
        onStartEducation: () => context.go(
          '/',
          extra: const {
            'agentPrefill':
                'Start a prenatal education session using only confirmed profile details and cited guidance',
          },
        ),
      );
    }
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
                                        ? (_section == 'sleep' ? 7 : 4)
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
                                        ? (_section == 'sleep' ? 7 : 11)
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
                            right: 24,
                            bottom: 20,
                            child: _CircleAction(
                              actionKey: const ValueKey(
                                'me-baby-overview-add-record',
                              ),
                              semanticLabel: 'Add baby record',
                              iconAsset: _MeBabyOverviewAssets.plusIcon,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _MeBabyOverviewHeader(
                identity: widget.identity,
                careStage: stageState,
                avatarExpanded: _avatarExpanded,
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
              onPressed: _showMomAddRecordSheet,
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
    required this.maternalCareOverview,
    required this.milkTrends,
    required this.waterRecords,
    required this.waterTrends,
    required this.vitalRecords,
    required this.sleepRecords,
    required this.diaperRecords,
    required this.feedingRecords,
    required this.feedingSummary,
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
        maternalCareOverview: const ProfileOverviewResource.initial(),
        milkTrends: const ProfileOverviewResource.initial(),
        waterRecords: const ProfileOverviewResource.initial(),
        waterTrends: const ProfileOverviewResource.initial(),
        vitalRecords: const ProfileOverviewResource.initial(),
        sleepRecords: const ProfileOverviewResource.initial(),
        diaperRecords: const ProfileOverviewResource.initial(),
        feedingRecords: const ProfileOverviewResource.initial(),
        feedingSummary: const ProfileOverviewResource.initial(),
        growthRecords: const ProfileOverviewResource.initial(),
        plans: const ProfileOverviewResource.initial(),
        now: DateTime.now(),
      );
    }
    return _MeBabyOverviewData(
      overview: controller.overview.value,
      maternalCareOverview: controller.maternalCareOverview.value,
      milkTrends: controller.milkTrends.value,
      waterRecords: controller.waterRecords.value,
      waterTrends: controller.waterTrends.value,
      vitalRecords: controller.vitalRecords.value,
      sleepRecords: controller.sleepRecords.value,
      diaperRecords: controller.diaperRecords.value,
      feedingRecords: controller.feedingRecords.value,
      feedingSummary: controller.feedingSummary.value,
      growthRecords: controller.growthRecords.value,
      plans: controller.plans.value,
      now: controller.now(),
    );
  }

  final ProfileOverviewResource<ProfileOverview> overview;
  final ProfileOverviewResource<MaternalCareOverview> maternalCareOverview;
  final ProfileOverviewResource<List<MilkTrendDay>> milkTrends;
  final ProfileOverviewResource<List<WaterIntakeRecord>> waterRecords;
  final ProfileOverviewResource<List<WaterTrendDay>> waterTrends;
  final ProfileOverviewResource<List<VitalRecord>> vitalRecords;
  final ProfileOverviewResource<List<SleepRecord>> sleepRecords;
  final ProfileOverviewResource<List<DiaperRecord>> diaperRecords;
  final ProfileOverviewResource<List<FeedingRecord>> feedingRecords;
  final ProfileOverviewResource<FeedingSummary> feedingSummary;
  final ProfileOverviewResource<List<GrowthRecord>> growthRecords;
  final ProfileOverviewResource<PlanDashboard> plans;
  final DateTime now;

  bool get hasStaleRefreshFailure => [
    overview,
    maternalCareOverview,
    milkTrends,
    waterRecords,
    waterTrends,
    vitalRecords,
    sleepRecords,
    diaperRecords,
    feedingRecords,
    feedingSummary,
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

  List<FeedingRecord> get _orderedFeeds {
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

  List<FeedingRecord> get feeds {
    final today = now.toLocal();
    return _orderedFeeds
        .where((record) {
          final occurredAt = record.occurredAt?.toLocal();
          return occurredAt != null && _sameCalendarDay(occurredAt, today);
        })
        .toList(growable: false);
  }

  List<FeedingTrendDay> get weeklyFeedingDays =>
      feedingSummary.data?.completedDays.dailySeries ??
      const <FeedingTrendDay>[];

  double get measuredFeedTotalMl => feeds
      .map((record) => record.measuredVolumeMl)
      .whereType<double>()
      .fold<double>(0, (total, value) => total + value);

  int get weeklyFeedingCount => feedingSummary.data?.feedingCount ?? 0;

  double get weeklyMeasuredFeedTotalMl =>
      feedingSummary.data?.measuredVolumeMl ?? 0;

  List<SleepRecord> get weeklySleeps {
    final values = List<SleepRecord>.of(
      sleepRecords.data ?? const <SleepRecord>[],
    );
    values.sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return values;
  }

  List<SleepRecord> get todaySleeps {
    final today = now.toLocal();
    return weeklySleeps
        .where((record) {
          final startedAt = record.startedAt.toLocal();
          return _sameCalendarDay(startedAt, today);
        })
        .toList(growable: false);
  }

  int get todaySleepSeconds => todaySleeps.fold<int>(
    0,
    (total, record) => total + record.durationSeconds,
  );

  List<SleepRecord> get todayNaps => todaySleeps
      .where((record) => record.type.toLowerCase() == 'nap')
      .toList(growable: false);

  SleepRecord? get latestNightSleep {
    for (final record in weeklySleeps) {
      if (record.type.toLowerCase() == 'night') return record;
    }
    return null;
  }

  List<({DateTime date, int seconds})> get weeklySleepDays {
    final today = now.toLocal();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - DateTime.monday));
    return List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      return (
        date: date,
        seconds: weeklySleeps
            .where((record) {
              final startedAt = record.startedAt.toLocal();
              return _sameCalendarDay(startedAt, date);
            })
            .fold<int>(0, (total, record) => total + record.durationSeconds),
      );
    }, growable: false);
  }

  List<DiaperRecord> get weeklyDiapers {
    final values = List<DiaperRecord>.of(
      diaperRecords.data ?? const <DiaperRecord>[],
    );
    values.sort((left, right) => right.changedAt.compareTo(left.changedAt));
    return values;
  }

  List<DiaperRecord> get todayDiapers {
    final today = now.toLocal();
    return weeklyDiapers
        .where((record) {
          final changedAt = record.changedAt.toLocal();
          return _sameCalendarDay(changedAt, today);
        })
        .toList(growable: false);
  }

  int get todayWetDiapers => todayDiapers
      .where(
        (record) => const {'wet', 'mixed'}.contains(record.type.toLowerCase()),
      )
      .length;

  int get todayDirtyDiapers => todayDiapers
      .where(
        (record) =>
            const {'dirty', 'mixed'}.contains(record.type.toLowerCase()),
      )
      .length;

  List<({DateTime date, int count})> get weeklyDiaperDays {
    final today = now.toLocal();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - DateTime.monday));
    return List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      return (
        date: date,
        count: weeklyDiapers.where((record) {
          final changedAt = record.changedAt.toLocal();
          return _sameCalendarDay(changedAt, date);
        }).length,
      );
    }, growable: false);
  }

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
    final measuredVolume = trend.measuredVolumeMl;
    if (measuredVolume == null) {
      return '${trend.pumpingCount} ${trend.pumpingCount == 1 ? 'session' : 'sessions'} · volume not measured';
    }
    return '${_formatNumber(measuredVolume)} mL recorded today';
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

String _formatNumber(num value) {
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
  });

  final ProfileIdentity identity;
  final CareStageSelectionState careStage;
  final bool avatarExpanded;

  @override
  Widget build(BuildContext context) {
    final isMom = identity == ProfileIdentity.mom;
    final isBaby = identity == ProfileIdentity.baby;
    final highlighted =
        isMom && avatarExpanded && careStage.stage == MomLifeStage.pregnancy;
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
      key: const ValueKey('baby-current-profile-indicator'),
      label: 'Infant profile. Locked to the infant selected for this session.',
      button: false,
      enabled: false,
      child: Material(
        color: _MeBabyOverviewColors.pill,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
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
          ),
        ),
      ),
    );
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          if (textScale < 1.8) ...[
            const _MomCozyWordmark(),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: isBaby
                ? babyPill
                : Semantics(
                    label: 'Current stage: $label. Locked after onboarding.',
                    child: Material(
                      key: const ValueKey('me-current-stage-indicator'),
                      color: highlighted
                          ? _MeBabyOverviewColors.wine
                          : _MeBabyOverviewColors.pill,
                      borderRadius: BorderRadius.circular(24),
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
                              if (!careStage.isResolved) ...[
                                const SizedBox(width: 5),
                                if (careStage.error == null)
                                  SizedBox.square(
                                    dimension: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: highlighted
                                          ? Colors.white
                                          : _MeBabyOverviewColors.wine,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: highlighted
                                        ? Colors.white
                                        : _MeBabyOverviewColors.wine,
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
          const SizedBox(width: 8),
          _HeaderCircleAction(
            actionKey: const ValueKey('me-baby-overview-notification'),
            semanticLabel: 'Open notifications',
            icon: Icons.notifications_none_rounded,
            compact: true,
            backgroundColor: highlighted ? _MeBabyOverviewColors.wine : null,
            foregroundColor: highlighted ? Colors.white : null,
            onPressed: () => context.go(
              Uri(
                path: '/notifications',
                queryParameters: {'from': isBaby ? '/baby' : '/me'},
              ).toString(),
            ),
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

enum _MomRecordChoice {
  pumpingLeft,
  pumpingRight,
  sleep,
  weight,
  water,
  vitals,
}

class _MomAddRecordSheet extends StatelessWidget {
  const _MomAddRecordSheet();

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        _MomRecordChoice.pumpingLeft,
        'pumping-left',
        'Pumping (Left)',
        Icons.cancel_outlined,
        true,
      ),
      (
        _MomRecordChoice.pumpingRight,
        'pumping-right',
        'Pumping (Right)',
        Icons.cancel_outlined,
        true,
      ),
      (_MomRecordChoice.sleep, 'sleep', 'Sleep', Icons.bedtime_outlined, false),
      (
        _MomRecordChoice.weight,
        'weight',
        'Weight',
        Icons.monitor_weight_outlined,
        true,
      ),
      (
        _MomRecordChoice.water,
        'water-intake',
        'Water Intake',
        Icons.water_drop_outlined,
        true,
      ),
      (
        _MomRecordChoice.vitals,
        'vitals',
        'Vitals',
        Icons.monitor_heart_outlined,
        true,
      ),
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
          key: const ValueKey('mom-add-record-sheet'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 72),
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
                  color: _MeBabyOverviewColors.line,
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
                        color: _MeBabyOverviewColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('mom-add-record-close'),
                    tooltip: 'Close add record',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: _MeBabyOverviewColors.pill,
                      foregroundColor: _MeBabyOverviewColors.wine,
                      shape: const CircleBorder(),
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
                    return Semantics(
                      key: ValueKey('mom-add-record-${option.$2}'),
                      label: option.$3,
                      hint: option.$5 ? 'Add record' : 'Coming soon',
                      button: true,
                      enabled: option.$5,
                      excludeSemantics: true,
                      child: Material(
                        color: option.$5
                            ? Colors.white
                            : _MeBabyOverviewColors.pill.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: _MeBabyOverviewColors.line,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: option.$5
                              ? () => Navigator.of(context).pop(option.$1)
                              : null,
                          child: Opacity(
                            opacity: option.$5 ? 1 : 0.58,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: _MeBabyOverviewColors.pill,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(13),
                                    child: Icon(
                                      option.$4,
                                      color: _MeBabyOverviewColors.wine,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  option.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _MeBabyOverviewColors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!option.$5) ...[
                                  const SizedBox(height: 1),
                                  const Text(
                                    'Coming soon',
                                    style: TextStyle(
                                      color: _MeBabyOverviewColors.wine,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
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

enum _RecordKind {
  pumping,
  feeding,
  growth,
  water,
  weight,
  vitals,
  sleep,
  diaper,
}

class _RecordComposerSheet extends StatefulWidget {
  const _RecordComposerSheet({
    required this.identity,
    required this.controller,
    this.initialKind,
    this.initialBreastSide,
  });

  final ProfileIdentity identity;
  final ProfileOverviewController controller;
  final _RecordKind? initialKind;
  final PumpingSide? initialBreastSide;

  @override
  State<_RecordComposerSheet> createState() => _RecordComposerSheetState();
}

class _RecordComposerSheetState extends State<_RecordComposerSheet> {
  late _RecordKind _kind =
      widget.initialKind ??
      (widget.identity == ProfileIdentity.mom
          ? _RecordKind.pumping
          : _RecordKind.feeding);
  late final Set<PumpingSide> _pumpingSides = {
    widget.initialBreastSide ?? PumpingSide.left,
  };
  final Map<PumpingSide, TextEditingController> _pumpingVolumeControllers = {
    for (final side in PumpingSide.values) side: TextEditingController(),
  };
  final Map<MilkSource, TextEditingController> _feedingVolumeControllers = {
    for (final source in MilkSource.values) source: TextEditingController(),
  };
  Set<MilkSource> _milkSources = {MilkSource.breastMilk};
  final _amountController = TextEditingController();
  final _durationController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _headController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _stoolColorController = TextEditingController();
  final _stoolConsistencyController = TextEditingController();
  final _notesController = TextEditingController();
  FeedingMethod _feedingMethod = FeedingMethod.bottle;
  MeasurementPosition? _measurementPosition;
  MeasurementContext? _measurementContext;
  SleepKind _sleepKind = SleepKind.nap;
  DiaperKind _diaperKind = DiaperKind.wet;
  DiaperWetness _diaperWetness = DiaperWetness.medium;
  String? _validationError;

  @override
  void dispose() {
    _amountController.dispose();
    for (final controller in _pumpingVolumeControllers.values) {
      controller.dispose();
    }
    for (final controller in _feedingVolumeControllers.values) {
      controller.dispose();
    }
    _durationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _headController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _stoolColorController.dispose();
    _stoolConsistencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _positiveNumber(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  int? _positiveInteger(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value > 0 ? value : null;
  }

  ({double? value, bool valid}) _optionalNonNegativeNumber(
    TextEditingController controller,
  ) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return (value: null, valid: true);
    final value = double.tryParse(text);
    return (value: value, valid: value != null && value >= 0);
  }

  void _selectFeedingMethod(FeedingMethod method) {
    setState(() {
      _feedingMethod = method;
      if (method == FeedingMethod.directBreastfeeding) {
        _milkSources = {MilkSource.breastMilk};
      }
      _validationError = null;
    });
  }

  void _toggleMilkSource(MilkSource source, bool selected) {
    if (_feedingMethod == FeedingMethod.directBreastfeeding) return;
    setState(() {
      if (selected) {
        _milkSources = source == MilkSource.unknown
            ? {MilkSource.unknown}
            : ({..._milkSources}
                ..remove(MilkSource.unknown)
                ..add(source));
      } else if (_milkSources.length > 1) {
        _milkSources = {..._milkSources}..remove(source);
      }
      _validationError = null;
    });
  }

  void _togglePumpingSide(PumpingSide side, bool selected) {
    setState(() {
      if (selected) {
        final nextSides = side == PumpingSide.unassigned
            ? const {PumpingSide.unassigned}
            : ({..._pumpingSides}
                ..remove(PumpingSide.unassigned)
                ..add(side));
        _pumpingSides
          ..clear()
          ..addAll(nextSides);
      } else if (_pumpingSides.length > 1) {
        _pumpingSides.remove(side);
      }
      _validationError = null;
    });
  }

  String get _title => switch (_kind) {
    _RecordKind.pumping => 'Log pumping session',
    _RecordKind.water => 'Add water intake',
    _RecordKind.weight => 'Add weight',
    _RecordKind.vitals => 'Add vitals',
    _RecordKind.sleep => 'Add sleep',
    _RecordKind.diaper => 'Add diaper change',
    _RecordKind.feeding || _RecordKind.growth => 'Add baby record',
  };

  Future<void> _save() async {
    widget.controller.clearRecordMutationError();
    bool saved;
    switch (_kind) {
      case _RecordKind.pumping:
        final outputs = <PumpingOutput>[];
        var volumesAreValid = true;
        for (final side in _pumpingSides) {
          final parsed = _optionalNonNegativeNumber(
            _pumpingVolumeControllers[side]!,
          );
          volumesAreValid = volumesAreValid && parsed.valid;
          outputs.add(PumpingOutput(breastSide: side, volumeMl: parsed.value));
        }
        final durationMinutes = _positiveInteger(_durationController);
        if (!volumesAreValid ||
            (outputs.every((output) => output.volumeMl == null) &&
                durationMinutes == null)) {
          setState(
            () => _validationError =
                'Enter a non-negative output for at least one side or a duration.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.savePumpingRecord(
          outputs: outputs,
          durationSeconds: durationMinutes == null
              ? null
              : durationMinutes * 60,
        );
      case _RecordKind.feeding:
        final components = <FeedingMilkComponent>[];
        var volumesAreValid = true;
        for (final source in _milkSources) {
          final parsed = _optionalNonNegativeNumber(
            _feedingVolumeControllers[source]!,
          );
          volumesAreValid = volumesAreValid && parsed.valid;
          components.add(
            FeedingMilkComponent(milkSource: source, volumeMl: parsed.value),
          );
        }
        final durationMinutes = _positiveInteger(_durationController);
        if (!volumesAreValid ||
            (components.every((component) => component.volumeMl == null) &&
                durationMinutes == null)) {
          setState(
            () => _validationError =
                'Enter a non-negative measured amount or a feeding duration.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveFeedingRecord(
          feedingMethod: _feedingMethod,
          milkComponents: components,
          durationSeconds: durationMinutes == null
              ? null
              : durationMinutes * 60,
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
        if (_measurementPosition == null || _measurementContext == null) {
          setState(
            () => _validationError =
                'Select how and why this growth measurement was taken.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveGrowthRecord(
          weightKg: weight,
          heightCm: height,
          headCm: head,
          measurementPosition: _measurementPosition!,
          measurementContext: _measurementContext!,
        );
      case _RecordKind.water:
        final amount = _positiveNumber(_amountController);
        if (amount == null || amount > 10000) {
          setState(
            () => _validationError =
                'Enter a water amount between 1 and 10,000 mL.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveWaterRecord(amountMl: amount);
      case _RecordKind.weight:
        final weight = _positiveNumber(_weightController);
        if (weight == null || weight > 500) {
          setState(
            () => _validationError = 'Enter a weight between 0 and 500 kg.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveVitalRecord(weightKg: weight);
      case _RecordKind.vitals:
        final systolic = _positiveInteger(_systolicController);
        final diastolic = _positiveInteger(_diastolicController);
        final heartRate = _positiveInteger(_heartRateController);
        final temperature = _positiveNumber(_temperatureController);
        final bloodPressureIsPartial =
            (systolic == null) != (diastolic == null);
        final hasMeasurement =
            systolic != null ||
            diastolic != null ||
            heartRate != null ||
            temperature != null;
        if (!hasMeasurement || bloodPressureIsPartial) {
          setState(
            () => _validationError = bloodPressureIsPartial
                ? 'Enter both systolic and diastolic blood pressure.'
                : 'Enter at least one confirmed vital measurement.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveVitalRecord(
          systolicMmhg: systolic,
          diastolicMmhg: diastolic,
          heartRateBpm: heartRate,
          temperatureC: temperature,
        );
      case _RecordKind.sleep:
        final durationMinutes = _positiveInteger(_durationController);
        if (durationMinutes == null || durationMinutes > 1440) {
          setState(
            () => _validationError =
                'Enter a sleep duration between 1 and 1,440 minutes.',
          );
          return;
        }
        setState(() => _validationError = null);
        saved = await widget.controller.saveSleepRecord(
          durationMinutes: durationMinutes,
          kind: _sleepKind,
        );
      case _RecordKind.diaper:
        setState(() => _validationError = null);
        final includesWet =
            _diaperKind == DiaperKind.wet || _diaperKind == DiaperKind.both;
        final includesDirty =
            _diaperKind == DiaperKind.dirty || _diaperKind == DiaperKind.both;
        saved = await widget.controller.saveDiaperRecord(
          kind: _diaperKind,
          wetness: includesWet ? _diaperWetness : null,
          stoolColor: includesDirty
              ? _optionalText(_stoolColorController)
              : null,
          stoolConsistency: includesDirty
              ? _optionalText(_stoolConsistencyController)
              : null,
          notes: _notesController.text.trim(),
        );
    }
    if (!mounted || !saved) return;
    Navigator.of(context).pop(true);
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
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
                          _title,
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<_RecordKind>(
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
                          ButtonSegment(
                            value: _RecordKind.sleep,
                            icon: Icon(Icons.bedtime_outlined),
                            label: Text('Sleep'),
                          ),
                          ButtonSegment(
                            value: _RecordKind.diaper,
                            icon: Icon(Icons.baby_changing_station_outlined),
                            label: Text('Diaper'),
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
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_kind == _RecordKind.growth)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GrowthRecordFields(
                          weightController: _weightController,
                          heightController: _heightController,
                          headController: _headController,
                          enabled: !mutation.isSaving,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Measurement position',
                          style: _MeBabyOverviewText.supporting,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<MeasurementPosition>(
                          key: const ValueKey('record-growth-position'),
                          segments: const [
                            ButtonSegment(
                              value: MeasurementPosition.recumbent,
                              label: Text('Lying down'),
                            ),
                            ButtonSegment(
                              value: MeasurementPosition.standing,
                              label: Text('Standing'),
                            ),
                          ],
                          selected: {?_measurementPosition},
                          emptySelectionAllowed: true,
                          onSelectionChanged: mutation.isSaving
                              ? null
                              : (selection) => setState(
                                  () => _measurementPosition = selection.single,
                                ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Measurement context',
                          style: _MeBabyOverviewText.supporting,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<MeasurementContext>(
                          key: const ValueKey('record-growth-context'),
                          segments: const [
                            ButtonSegment(
                              value: MeasurementContext.routine,
                              label: Text('Routine'),
                            ),
                            ButtonSegment(
                              value: MeasurementContext.birth,
                              label: Text('At birth'),
                            ),
                          ],
                          selected: {?_measurementContext},
                          emptySelectionAllowed: true,
                          onSelectionChanged: mutation.isSaving
                              ? null
                              : (selection) => setState(
                                  () => _measurementContext = selection.single,
                                ),
                        ),
                      ],
                    )
                  else if (_kind == _RecordKind.weight)
                    _RecordNumberField(
                      fieldKey: const ValueKey('record-maternal-weight'),
                      controller: _weightController,
                      label: 'Measured weight',
                      suffix: 'kg',
                      enabled: !mutation.isSaving,
                    )
                  else if (_kind == _RecordKind.vitals)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _RecordNumberField(
                                fieldKey: const ValueKey(
                                  'record-vital-systolic',
                                ),
                                controller: _systolicController,
                                label: 'Systolic',
                                suffix: 'mmHg',
                                enabled: !mutation.isSaving,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _RecordNumberField(
                                fieldKey: const ValueKey(
                                  'record-vital-diastolic',
                                ),
                                controller: _diastolicController,
                                label: 'Diastolic',
                                suffix: 'mmHg',
                                enabled: !mutation.isSaving,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _RecordNumberField(
                          fieldKey: const ValueKey('record-vital-heart-rate'),
                          controller: _heartRateController,
                          label: 'Heart rate',
                          suffix: 'bpm',
                          enabled: !mutation.isSaving,
                        ),
                        const SizedBox(height: 14),
                        _RecordNumberField(
                          fieldKey: const ValueKey('record-vital-temperature'),
                          controller: _temperatureController,
                          label: 'Temperature',
                          suffix: '°C',
                          enabled: !mutation.isSaving,
                        ),
                      ],
                    )
                  else if (_kind == _RecordKind.sleep)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sleep type',
                          style: _MeBabyOverviewText.supporting,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<SleepKind>(
                          key: const ValueKey('record-sleep-kind'),
                          segments: const [
                            ButtonSegment(
                              value: SleepKind.nap,
                              label: Text('Nap'),
                            ),
                            ButtonSegment(
                              value: SleepKind.night,
                              label: Text('Night'),
                            ),
                            ButtonSegment(
                              value: SleepKind.other,
                              label: Text('Other'),
                            ),
                          ],
                          selected: {_sleepKind},
                          onSelectionChanged: mutation.isSaving
                              ? null
                              : (selection) => setState(
                                  () => _sleepKind = selection.single,
                                ),
                        ),
                        const SizedBox(height: 18),
                        _RecordNumberField(
                          fieldKey: const ValueKey('record-sleep-duration'),
                          controller: _durationController,
                          label: 'Duration',
                          suffix: 'minutes',
                          enabled: !mutation.isSaving,
                        ),
                      ],
                    )
                  else if (_kind == _RecordKind.diaper)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Change type',
                          style: _MeBabyOverviewText.supporting,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<DiaperKind>(
                          key: const ValueKey('record-diaper-kind'),
                          segments: const [
                            ButtonSegment(
                              value: DiaperKind.wet,
                              label: Text('Wet'),
                            ),
                            ButtonSegment(
                              value: DiaperKind.dirty,
                              label: Text('Dirty'),
                            ),
                            ButtonSegment(
                              value: DiaperKind.both,
                              label: Text('Both'),
                            ),
                          ],
                          selected: {_diaperKind},
                          onSelectionChanged: mutation.isSaving
                              ? null
                              : (selection) => setState(
                                  () => _diaperKind = selection.single,
                                ),
                        ),
                        if (_diaperKind != DiaperKind.dirty) ...[
                          const SizedBox(height: 18),
                          const Text(
                            'Wetness',
                            style: _MeBabyOverviewText.supporting,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<DiaperWetness>(
                            key: const ValueKey('record-diaper-wetness'),
                            segments: const [
                              ButtonSegment(
                                value: DiaperWetness.light,
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: DiaperWetness.medium,
                                label: Text('Medium'),
                              ),
                              ButtonSegment(
                                value: DiaperWetness.heavy,
                                label: Text('Heavy'),
                              ),
                            ],
                            selected: {_diaperWetness},
                            onSelectionChanged: mutation.isSaving
                                ? null
                                : (selection) => setState(
                                    () => _diaperWetness = selection.single,
                                  ),
                          ),
                        ],
                        if (_diaperKind != DiaperKind.wet) ...[
                          const SizedBox(height: 14),
                          _RecordTextField(
                            fieldKey: const ValueKey(
                              'record-diaper-stool-color',
                            ),
                            controller: _stoolColorController,
                            label: 'Stool color (optional)',
                            enabled: !mutation.isSaving,
                          ),
                          const SizedBox(height: 14),
                          _RecordTextField(
                            fieldKey: const ValueKey(
                              'record-diaper-stool-consistency',
                            ),
                            controller: _stoolConsistencyController,
                            label: 'Consistency (optional)',
                            enabled: !mutation.isSaving,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _RecordTextField(
                          fieldKey: const ValueKey('record-diaper-notes'),
                          controller: _notesController,
                          label: 'Notes (optional)',
                          enabled: !mutation.isSaving,
                        ),
                      ],
                    )
                  else if (_kind == _RecordKind.pumping)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pumping outputs',
                          style: _MeBabyOverviewText.supporting,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final side in PumpingSide.values)
                              FilterChip(
                                key: ValueKey(
                                  'record-pumping-side-${side.apiValue}',
                                ),
                                label: Text(_pumpingSideLabel(side)),
                                selected: _pumpingSides.contains(side),
                                onSelected: mutation.isSaving
                                    ? null
                                    : (selected) =>
                                          _togglePumpingSide(side, selected),
                              ),
                          ],
                        ),
                        for (final side in _pumpingSides) ...[
                          const SizedBox(height: 14),
                          _RecordNumberField(
                            fieldKey: ValueKey(
                              'record-pumping-${side.apiValue}-amount',
                            ),
                            controller: _pumpingVolumeControllers[side]!,
                            label: '${_pumpingSideLabel(side)} measured milk',
                            suffix: 'mL',
                            enabled: !mutation.isSaving,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _RecordNumberField(
                          fieldKey: const ValueKey('record-pumping-duration'),
                          controller: _durationController,
                          label: 'Duration (optional)',
                          suffix: 'minutes',
                          enabled: !mutation.isSaving,
                        ),
                      ],
                    )
                  else if (_kind == _RecordKind.feeding)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<FeedingMethod>(
                          key: const ValueKey('record-feeding-method'),
                          initialValue: _feedingMethod,
                          decoration: const InputDecoration(
                            labelText: 'Feeding method',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final method in FeedingMethod.values)
                              DropdownMenuItem(
                                value: method,
                                child: Text(_feedingMethodLabel(method)),
                              ),
                          ],
                          onChanged: mutation.isSaving
                              ? null
                              : (method) {
                                  if (method != null) {
                                    _selectFeedingMethod(method);
                                  }
                                },
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Milk sources',
                          style: _MeBabyOverviewText.supporting,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final source in MilkSource.values)
                              FilterChip(
                                key: ValueKey(
                                  'record-feeding-source-${source.apiValue}',
                                ),
                                label: Text(_milkSourceLabel(source)),
                                selected: _milkSources.contains(source),
                                onSelected:
                                    mutation.isSaving ||
                                        _feedingMethod ==
                                            FeedingMethod.directBreastfeeding
                                    ? null
                                    : (selected) =>
                                          _toggleMilkSource(source, selected),
                              ),
                          ],
                        ),
                        for (final source in _milkSources) ...[
                          const SizedBox(height: 14),
                          _RecordNumberField(
                            fieldKey: ValueKey(
                              'record-feeding-${source.apiValue}-amount',
                            ),
                            controller: _feedingVolumeControllers[source]!,
                            label:
                                '${_milkSourceLabel(source)} amount (optional)',
                            suffix: 'mL',
                            enabled: !mutation.isSaving,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _RecordNumberField(
                          fieldKey: const ValueKey('record-feeding-duration'),
                          controller: _durationController,
                          label: 'Duration (optional)',
                          suffix: 'minutes',
                          enabled: !mutation.isSaving,
                        ),
                      ],
                    )
                  else
                    _RecordNumberField(
                      fieldKey: const ValueKey('record-water-amount'),
                      controller: _amountController,
                      label: 'Water amount',
                      suffix: 'mL',
                      enabled: !mutation.isSaving,
                    ),
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

String _pumpingSideLabel(PumpingSide side) => switch (side) {
  PumpingSide.left => 'Left',
  PumpingSide.right => 'Right',
  PumpingSide.unassigned => 'Not separated',
};

String _feedingMethodLabel(FeedingMethod method) => switch (method) {
  FeedingMethod.directBreastfeeding => 'Direct breastfeeding',
  FeedingMethod.bottle => 'Bottle',
  FeedingMethod.cup => 'Cup',
  FeedingMethod.syringe => 'Syringe',
  FeedingMethod.tube => 'Tube',
  FeedingMethod.other => 'Other',
};

String _milkSourceLabel(MilkSource source) => switch (source) {
  MilkSource.breastMilk => 'Breast milk',
  MilkSource.formula => 'Formula',
  MilkSource.donorMilk => 'Donor milk',
  MilkSource.unknown => 'Unknown',
};

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

class _RecordTextField extends StatelessWidget {
  const _RecordTextField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
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

class _MomCozyWordmark extends StatelessWidget {
  const _MomCozyWordmark();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Text(
        'momcozy',
        style: const TextStyle(
          color: _MeBabyOverviewColors.ink,
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
        child: isMom
            ? _MomAvatarImage(
                stage:
                    data.overview.data?.mom?.stage ?? MomLifeStage.postpartum,
                fileId: data.overview.data?.mom?.avatarFileId,
                alignment: Alignment.bottomCenter,
                fit: BoxFit.contain,
              )
            : Image.asset(
                _MeBabyOverviewAssets.babyAvatar,
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
    required this.onRetry,
  });

  final bool loading;
  final bool loadFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? 'Loading your care stage…'
        : loadFailed
        ? 'Your care stage is unavailable'
        : 'Complete onboarding to continue';
    final description = loading
        ? 'Your workspace will appear when your profile is ready.'
        : loadFailed
        ? 'We couldn’t refresh your profile. Your stage was not guessed.'
        : 'Your care stage is collected during onboarding and locked afterwards.';
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
            if (loadFailed) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('me-stage-retry'),
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _MeBabyOverviewColors.wine,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
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
    if (isBaby) {
      const sections = [
        ('monitor', 'Monitor', _MeBabyOverviewAssets.activityIcon, 94.0),
        ('sleep', 'Sleep', _MeBabyOverviewAssets.moonIcon, 81.0),
        ('feeding', 'Feeding', _MeBabyOverviewAssets.babyIcon, 95.0),
        ('diaper', 'Diaper', _MeBabyOverviewAssets.circleXIcon, 87.0),
      ];
      final tabs = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < sections.length; index += 1) ...[
            if (index > 0) const SizedBox(width: 8),
            SizedBox(
              width: sections[index].$4,
              child: _SectionTab(
                section: sections[index].$1,
                label: sections[index].$2,
                iconAsset: sections[index].$3,
                selected: selected == sections[index].$1,
                prefix: 'baby',
                onTap: () => onSelected(sections[index].$1),
                compact: compact,
              ),
            ),
          ],
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 381) {
            if (compact) return tabs;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: tabs,
            );
          }
          return Row(
            children: [
              for (var index = 0; index < sections.length; index += 1) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: _SectionTab(
                    section: sections[index].$1,
                    label: sections[index].$2,
                    iconAsset: sections[index].$3,
                    selected: selected == sections[index].$1,
                    prefix: 'baby',
                    onTap: () => onSelected(sections[index].$1),
                    compact: compact,
                  ),
                ),
              ],
            ],
          );
        },
      );
    }
    const sections = [
      ('lactation', 'Lactation', Icons.water_drop_outlined),
      ('recovery', 'Recovery', Icons.favorite_outline_rounded),
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
    this.icon,
    this.iconAsset,
    required this.selected,
    required this.prefix,
    required this.onTap,
    required this.compact,
  });

  final String section;
  final String label;
  final IconData? icon;
  final String? iconAsset;
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
                            _BabySvgIcon(
                              asset: iconAsset!,
                              color: selected
                                  ? Colors.white
                                  : _BabyOverviewColors.ink,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: MomCozyTypography.bodyFontFamily,
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
                        icon!,
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
    final measuredVolume = latest?.measuredVolumeMl;
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
      (maximum, item) => math.max(maximum, item.measuredVolumeMl ?? 0),
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
              if (measuredVolume != null)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      _formatNumber(measuredVolume),
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
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: _MeBabyOverviewColors.pill,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _MeBabyOverviewColors.wine,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Volume not measured',
                            style: TextStyle(
                              color: _MeBabyOverviewColors.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      trend.measuredVolumeMl == null
                          ? null
                          : trend.measuredVolumeMl! / maxVolume,
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

const _babyFeedSupportingStyle = TextStyle(
  fontFamily: MomCozyTypography.bodyFontFamily,
  color: Color(0xffa28f89),
  fontSize: 14,
  height: 1.35,
  fontWeight: FontWeight.w500,
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
              const _BabyRoundIcon(
                iconAsset: _MeBabyOverviewAssets.bottleWineIcon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feed.$1,
                      style: const TextStyle(
                        fontFamily: MomCozyTypography.bodyFontFamily,
                        color: Color(0xff181818),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
              fontFamily: MomCozyTypography.bodyFontFamily,
              color: Color(0xff181818),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(feed.$4, style: _babyFeedSupportingStyle),
        ],
      );
    }
    return Row(
      children: [
        const _BabyRoundIcon(iconAsset: _MeBabyOverviewAssets.bottleWineIcon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feed.$1,
                style: const TextStyle(
                  fontFamily: MomCozyTypography.bodyFontFamily,
                  color: Color(0xff181818),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
                fontFamily: MomCozyTypography.bodyFontFamily,
                color: Color(0xff181818),
                fontSize: 16,
                fontWeight: FontWeight.w700,
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

  final List<double?> values;
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

class _HeaderCircleAction extends StatelessWidget {
  const _HeaderCircleAction({
    required this.actionKey,
    required this.semanticLabel,
    required this.icon,
    this.compact = false,
    this.backgroundColor,
    this.foregroundColor,
    this.onPressed,
  });

  final Key actionKey;
  final String semanticLabel;
  final IconData icon;
  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = compact ? 44.0 : 62.0;
    return Semantics(
      key: actionKey,
      label: semanticLabel,
      button: onPressed != null,
      enabled: onPressed != null,
      child: SizedBox.square(
        dimension: math.max(resolvedSize, MomCozyTapTargets.minimum),
        child: Center(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
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
    required this.iconAsset,
    required this.onPressed,
  });

  final Key actionKey;
  final String semanticLabel;
  final String iconAsset;
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
            child: Center(
              child: _BabySvgIcon(
                asset: iconAsset,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.values);

  final List<double?> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    if (values.any((value) => value == null)) {
      _paintMeasuredSegments(canvas, size);
      return;
    }
    final line = Path();
    final fill = Path();
    for (var index = 0; index < values.length; index += 1) {
      final x = index / (values.length - 1) * size.width;
      final y = size.height - values[index]!.clamp(0, 1) * (size.height - 6);
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

  void _paintMeasuredSegments(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _MeBabyOverviewColors.wine
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path? segment;
    for (var index = 0; index < values.length; index += 1) {
      final value = values[index];
      if (value == null) {
        if (segment != null) canvas.drawPath(segment, paint);
        segment = null;
        continue;
      }
      final x = index / (values.length - 1) * size.width;
      final y = size.height - value.clamp(0, 1) * (size.height - 6);
      if (segment == null) {
        segment = Path()..moveTo(x, y);
      } else {
        segment.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
    if (segment != null) canvas.drawPath(segment, paint);
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
  static const postpartumAvatar =
      'assets/images/me_baby_overview/postpartum_avatar.png';
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
      'assets/images/me_baby_overview/nursery_camera_clean.png';
  static const babyDevelopment =
      'assets/images/me_baby_overview/baby_development.png';
  static const prenatalEducation =
      'assets/images/me_baby_overview/prenatal_education.png';
  static const sleepTraining =
      'assets/images/me_baby_overview/sleep_training.png';
  static const _babyIconRoot = 'assets/images/me_baby_overview/icons';
  static const activityIcon = '$_babyIconRoot/activity.svg';
  static const backButton = '$_babyIconRoot/back-button.svg';
  static const babyIcon = '$_babyIconRoot/baby.svg';
  static const bottleWineIcon = '$_babyIconRoot/bottle-wine.svg';
  static const circleXIcon = '$_babyIconRoot/circle-x.svg';
  static const closeButton = '$_babyIconRoot/close-button.svg';
  static const clockIcon = '$_babyIconRoot/clock.svg';
  static const dropletIcon = '$_babyIconRoot/droplet.svg';
  static const moonIcon = '$_babyIconRoot/moon.svg';
  static const moonStarIcon = '$_babyIconRoot/moon-star.svg';
  static const moreButton = '$_babyIconRoot/more-button.svg';
  static const plusIcon = '$_babyIconRoot/plus.svg';
  static const rulerIcon = '$_babyIconRoot/ruler.svg';
  static const weightIcon = '$_babyIconRoot/weight.svg';
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
    fontFamily: MomCozyTypography.displayFontFamily,
    color: _BabyOverviewColors.ink,
    fontSize: 16,
    height: 1.1,
    fontWeight: FontWeight.w700,
  );
  static const heroMetric = TextStyle(
    fontFamily: MomCozyTypography.displayFontFamily,
    color: _BabyOverviewColors.ink,
    fontSize: 42,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
  );
  static const detailMetric = TextStyle(
    fontFamily: MomCozyTypography.displayFontFamily,
    color: _BabyOverviewColors.ink,
    fontSize: 32,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );
  static const supporting = TextStyle(
    fontFamily: MomCozyTypography.bodyFontFamily,
    color: _BabyOverviewColors.mutedText,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
  static const supportingSmall = TextStyle(
    fontFamily: MomCozyTypography.bodyFontFamily,
    color: _BabyOverviewColors.mutedText,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
  static const eyebrow = TextStyle(
    fontFamily: MomCozyTypography.bodyFontFamily,
    color: _BabyOverviewColors.mutedText,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const accentLabel = TextStyle(
    fontFamily: MomCozyTypography.bodyFontFamily,
    color: _BabyOverviewColors.wine,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}
