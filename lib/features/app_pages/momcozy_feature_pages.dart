import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:go_router/go_router.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:app/features/hospital_bag/data/hospital_bag_cart_store.dart';
import 'package:app/features/media/data/product_asset_repository.dart';
import 'package:app/features/media/domain/product_asset.dart';
import 'package:app/features/media/presentation/product_asset_image.dart';
import 'package:app/features/media/presentation/product_asset_video_player.dart';
import 'package:app/features/pump_session/domain/pump_workstate.dart';
import 'package:app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';
import 'package:app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';
import 'package:app/features/schedule/presentation/schedule_dashboard_page.dart';
import 'package:app/features/status/domain/status_overview.dart';
import 'package:app/features/status/domain/status_selection.dart';
import 'package:app/features/status/presentation/baby_growth_chart.dart';
import 'package:app/features/status/presentation/baby_status_cards.dart';
import 'package:app/features/status/presentation/baby_status_sheets.dart';
import 'package:app/features/status/presentation/birth_journey_plan_dashboard.dart';
import 'package:app/features/status/presentation/postpartum_mom_dashboard.dart';
import 'package:app/features/status/presentation/pregnancy_diary_dashboard.dart';
import 'package:app/features/status/presentation/status_entry_intent.dart';
import 'package:app/features/status/presentation/status_dashboard_controller.dart';
import 'package:app/native/p0_platform_interfaces.dart';
import 'package:pdfrx/pdfrx.dart';

class MomCozyFeaturePage extends StatelessWidget {
  const MomCozyFeaturePage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
    this.routeUri,
    this.routeExtra,
    this.onLogout,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;
  final Uri? routeUri;
  final Object? routeExtra;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return switch (path) {
      '/calibration' => _CalibrationPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/pump' => _PumpPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/schedule' => ScheduleDashboardPage(
        key: ValueKey(
          'schedule-dashboard-${MomCozyRuntimeScope.of(context).currentSession.userId}',
        ),
        path: path,
        repository: MomCozyRuntimeScope.of(context).scheduleRepository,
        now: MomCozyRuntimeScope.of(context).now,
        reminderGateway: MomCozyRuntimeScope.of(
          context,
        ).scheduleReminderGateway,
        reminderPreferenceStore: MomCozyRuntimeScope.of(
          context,
        ).scheduleReminderPreferenceStore,
        volumeUnitPreferenceStore: MomCozyRuntimeScope.of(
          context,
        ).volumeUnitPreferenceStore,
        milkPlanChangeStore: MomCozyRuntimeScope.of(
          context,
        ).milkPlanChangeStore,
        deliveryDateLoader: MomCozyRuntimeScope.of(
          context,
        ).loadSchedulePostpartumAnchorDate,
        imageRecognitionGateway: MomCozyRuntimeScope.of(
          context,
        ).scheduleImageRecognitionGateway,
        routeUri: routeUri,
        routeExtra: routeExtra,
        onOpenAgent: () =>
            context.go('/', extra: const {'agentPrefill': '我想调整今天的吸乳排期'}),
      ),
      '/status' => _StatusPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        routeUri: routeUri,
        routeExtra: routeExtra,
      ),
      '/community' => _CommunityPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/device' => _DevicePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        onLogout: onLogout,
      ),
      '/device/manage' => _DeviceManagePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/device/user' => _DeviceUserPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/w1' => _W1Page(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/hospital-bag-cart' => _HospitalBagCartPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        routeExtra: routeExtra,
      ),
      '/ibclc-chat.html' => _IbclcPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        routeUri: routeUri,
        routeExtra: routeExtra,
      ),
      '/media-viewer' => _MediaViewerPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
        routeUri: routeUri,
        routeExtra: routeExtra,
      ),
      _ => _NotFoundPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
    };
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = accent ?? colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _IconBubble(icon: icon, accent: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                height: 1.35,
                                color: MomCozyColors.mutedForeground,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacySegmentedTabs extends StatelessWidget {
  const _LegacySegmentedTabs({
    required this.selected,
    required this.items,
    required this.onChanged,
    required this.accent,
    this.expand = false,
  });

  final String selected;
  final List<_LegacySegmentedTabItem> items;
  final ValueChanged<String> onChanged;
  final Color accent;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final item in items)
        _LegacySegmentedTabButton(
          item: item,
          selected: item.value == selected,
          accent: accent,
          minWidth: 70,
          onTap: () => onChanged(item.value),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MomCozyColors.card.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: expand
            ? [for (final child in children) Expanded(child: child)]
            : children,
      ),
    );
  }
}

class _LegacySegmentedTabItem {
  const _LegacySegmentedTabItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;
}

class _LegacySegmentedTabButton extends StatelessWidget {
  const _LegacySegmentedTabButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.minWidth,
    required this.onTap,
  });

  final _LegacySegmentedTabItem item;
  final bool selected;
  final Color accent;
  final double minWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? accent : MomCozyColors.mutedForeground;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
    );

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 34),
        child: Material(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.control - 3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MomCozyRadii.control - 3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 15, color: foreground),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
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

class _GearStepper extends StatelessWidget {
  const _GearStepper({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  static const _min = 1;
  static const _max = 9;

  @override
  Widget build(BuildContext context) {
    final current = value.round().clamp(_min, _max);

    return SizedBox(
      width: 136,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GearStepButton(
                tooltip: '降低$label档位',
                icon: Icons.remove_rounded,
                enabled: current > _min,
                onTap: () => onChanged((current - 1).toDouble()),
              ),
              const SizedBox(width: 7),
              Container(
                width: 42,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                ),
                child: Text(
                  '$current',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _GearStepButton(
                tooltip: '提高$label档位',
                icon: Icons.add_rounded,
                enabled: current < _max,
                onTap: () => onChanged((current + 1).toDouble()),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var index = _min; index <= _max; index += 1)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1.4),
                    decoration: BoxDecoration(
                      color: index <= current
                          ? accent.withValues(alpha: 0.76)
                          : MomCozyColors.border.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GearStepButton extends StatelessWidget {
  const _GearStepButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? MomCozyColors.muted.withValues(alpha: 0.78)
            : MomCozyColors.muted.withValues(alpha: 0.34),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 16,
              color: enabled
                  ? MomCozyColors.foreground
                  : MomCozyColors.mutedForeground.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.accent,
    this.size = 38,
    this.iconSize = 21,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(size <= 28 ? 8 : 12),
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}

final _statusInteractionStates = Expando<_StatusInteractionState>(
  'momcozy-status-interaction-state',
);

class _StatusInteractionState {
  String view = 'mom';
  String careStage = 'postpartum';
  String milkTrendMode = '周';
  String babyGrowthMetric = '体重';
}

class _StatusPage extends StatefulWidget {
  const _StatusPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Uri? routeUri;
  final Object? routeExtra;

  @override
  State<_StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<_StatusPage> {
  String _milkTrendMode = '周';
  String _babyGrowthMetric = '体重';
  late _StatusInteractionState _interactionState = _StatusInteractionState();
  MomCozyApiRuntime? _runtime;
  PregnancyDiaryChangeStore? _pregnancyDiaryChangeStore;
  PregnancyPlanChangeStore? _pregnancyPlanChangeStore;
  int _handledPregnancyDiaryRevision = 0;
  int _handledPregnancyPlanRevision = 0;
  Future<void> _pregnancyDiaryChangeTail = Future<void>.value();
  Future<void> _pregnancyPlanChangeTail = Future<void>.value();
  late StatusDashboardController _controller;
  late Listenable _dashboardListenable;
  final _growthCurveAnchorKey = GlobalKey();
  final _growthHighlight = ValueNotifier<bool>(false);
  Timer? _growthHighlightTimer;
  final _pregnancyDiaryAnchorKey = GlobalKey();
  final _birthJourneyAnchorKey = GlobalKey();
  final _pregnancyDiaryNotice = ValueNotifier<bool>(false);
  final _birthJourneyNotice = ValueNotifier<bool>(false);
  Timer? _pregnancyDiaryNoticeTimer;
  Timer? _birthJourneyNoticeTimer;
  String? _consumedStatusIntentToken;
  late final AppLifecycleListener _appLifecycleListener;

  String get _view => _controller.identity.value.value;
  String get _careStage => _controller.careStage.value.storageValue;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(onResume: _handleAppResume);
  }

  void _handleAppResume() {
    if (_runtime == null) return;
    unawaited(_controller.refreshStale());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      if (_runtime != null) {
        _pregnancyDiaryChangeStore?.removeListener(
          _handlePregnancyDiaryChangeStore,
        );
        _pregnancyPlanChangeStore?.removeListener(
          _handlePregnancyPlanChangeStore,
        );
        _controller.careStage.removeListener(_handleSelectionChanged);
        _controller.identity.removeListener(_handleSelectionChanged);
        _controller.dispose();
      }
      _runtime = runtime;
      final diaryChangeStore = runtime.pregnancyDiaryChangeStore;
      final planChangeStore = runtime.pregnancyPlanChangeStore;
      _pregnancyDiaryChangeStore = diaryChangeStore;
      _pregnancyPlanChangeStore = planChangeStore;
      _handledPregnancyDiaryRevision =
          diaryChangeStore.hasUnread || diaryChangeStore.highlightCard
          ? diaryChangeStore.revision - 1
          : diaryChangeStore.revision;
      _handledPregnancyPlanRevision =
          planChangeStore.hasUnread || planChangeStore.highlightCard
          ? planChangeStore.revision - 1
          : planChangeStore.revision;
      diaryChangeStore.addListener(_handlePregnancyDiaryChangeStore);
      planChangeStore.addListener(_handlePregnancyPlanChangeStore);
      _interactionState = _statusInteractionStates[runtime] ??=
          _StatusInteractionState();
      if (diaryChangeStore.hasUnread ||
          diaryChangeStore.highlightCard ||
          planChangeStore.hasUnread ||
          planChangeStore.highlightCard) {
        _interactionState
          ..view = 'mom'
          ..careStage = 'pregnancy';
      }
      _milkTrendMode = _interactionState.milkTrendMode;
      _babyGrowthMetric = _interactionState.babyGrowthMetric;
      _controller = runtime.createStatusDashboardController(
        initialCareStage:
            StatusCareStage.fromStorage(_interactionState.careStage) ??
            StatusCareStage.postpartum,
        initialIdentity: StatusIdentity.fromValue(_interactionState.view),
      );
      _controller.careStage.addListener(_handleSelectionChanged);
      _controller.identity.addListener(_handleSelectionChanged);
      _dashboardListenable = Listenable.merge([
        _controller.careStage,
        _controller.identity,
        _controller.overview,
        _controller.pregnancyDiaryEntries,
      ]);
      unawaited(_initializeStatusController(runtime));
      _scheduleStatusEntryIntent();
    }
  }

  Future<void> _initializeStatusController(MomCozyApiRuntime runtime) async {
    final revalidatePregnancyPlan =
        _controller.birthJourneyPlan.value.phase == StatusResourcePhase.data;
    try {
      await _controller.initialize();
    } catch (_) {
      // Individual resources expose their own error state below.
    }
    if (!mounted || !identical(runtime, _runtime)) return;
    if (revalidatePregnancyPlan) {
      await _controller.refreshPregnancyPlan();
    }
    if (!mounted || !identical(runtime, _runtime)) return;
    _schedulePregnancyDiaryChangeRefresh(refresh: false);
    _schedulePregnancyPlanChangeRefresh(refresh: false);
  }

  void _handlePregnancyDiaryChangeStore() {
    _schedulePregnancyDiaryChangeRefresh(refresh: true);
  }

  void _schedulePregnancyDiaryChangeRefresh({required bool refresh}) {
    final store = _pregnancyDiaryChangeStore;
    if (store == null || store.revision <= _handledPregnancyDiaryRevision) {
      return;
    }
    final revision = store.revision;
    final controller = _controller;
    _handledPregnancyDiaryRevision = revision;
    _pregnancyDiaryChangeTail = _pregnancyDiaryChangeTail.then(
      (_) => _refreshAfterPregnancyDiaryChange(
        store,
        controller,
        revision,
        refresh: refresh,
      ),
    );
  }

  Future<void> _refreshAfterPregnancyDiaryChange(
    PregnancyDiaryChangeStore store,
    StatusDashboardController controller,
    int revision, {
    required bool refresh,
  }) async {
    if (!mounted ||
        !identical(store, _pregnancyDiaryChangeStore) ||
        !identical(controller, _controller)) {
      return;
    }
    final shouldShowNotice = store.hasUnread || store.highlightCard;
    if (shouldShowNotice) _showPregnancyView();
    if (refresh) await controller.refreshPregnancyDiary();
    if (!mounted ||
        !identical(store, _pregnancyDiaryChangeStore) ||
        !identical(controller, _controller) ||
        store.revision != revision) {
      return;
    }
    if (controller.pregnancyDiaryEntries.value.phase !=
        StatusResourcePhase.data) {
      if (store.highlightCard) store.restoreNavigationNotice();
      return;
    }
    if (!shouldShowNotice) return;
    if (store.hasUnread) store.transferNavigationNoticeToCard();
    if (store.highlightCard) {
      _showPregnancyDiaryNotice(
        refresh: false,
        changeStore: store,
        revision: revision,
      );
    }
  }

  void _handlePregnancyPlanChangeStore() {
    _schedulePregnancyPlanChangeRefresh(refresh: true);
  }

  void _schedulePregnancyPlanChangeRefresh({required bool refresh}) {
    final store = _pregnancyPlanChangeStore;
    if (store == null || store.revision <= _handledPregnancyPlanRevision) {
      return;
    }
    final revision = store.revision;
    final controller = _controller;
    _handledPregnancyPlanRevision = revision;
    _pregnancyPlanChangeTail = _pregnancyPlanChangeTail.then(
      (_) => _refreshAfterPregnancyPlanChange(
        store,
        controller,
        revision,
        refresh: refresh,
      ),
    );
  }

  Future<void> _refreshAfterPregnancyPlanChange(
    PregnancyPlanChangeStore store,
    StatusDashboardController controller,
    int revision, {
    required bool refresh,
  }) async {
    if (!mounted ||
        !identical(store, _pregnancyPlanChangeStore) ||
        !identical(controller, _controller)) {
      return;
    }
    final shouldShowNotice = store.hasUnread || store.highlightCard;
    if (shouldShowNotice) _showPregnancyView();
    if (refresh) await controller.refreshPregnancyPlan();
    if (!mounted ||
        !identical(store, _pregnancyPlanChangeStore) ||
        !identical(controller, _controller) ||
        store.revision != revision) {
      return;
    }
    final planResource = controller.birthJourneyPlan.value;
    final plan = planResource.data;
    if (planResource.phase != StatusResourcePhase.data ||
        plan == null ||
        !plan.hasStructuredContent) {
      if (store.highlightCard) store.restoreNavigationNotice();
      return;
    }
    if (!shouldShowNotice) return;
    if (store.hasUnread) store.transferNavigationNoticeToCard();
    if (store.highlightCard) {
      _showBirthJourneyNotice(
        refresh: false,
        changeStore: store,
        revision: revision,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _StatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeUri != widget.routeUri ||
        !identical(oldWidget.routeExtra, widget.routeExtra)) {
      _scheduleStatusEntryIntent();
    }
  }

  void _scheduleStatusEntryIntent() {
    final intent = statusEntryIntentFromRoute(
      widget.routeUri,
      widget.routeExtra,
    );
    if (intent == null || intent.token == _consumedStatusIntentToken) return;
    _consumedStatusIntentToken = intent.token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (intent.kind) {
        case StatusEntryIntentKind.growth:
          _showGrowthHighlight();
          break;
        case StatusEntryIntentKind.pregnancyDiary:
          _showPregnancyDiaryNotice();
          break;
        case StatusEntryIntentKind.birthJourney:
          _showBirthJourneyNotice();
          break;
      }
    });
  }

  void _showPregnancyDiaryNotice({
    bool refresh = true,
    PregnancyDiaryChangeStore? changeStore,
    int? revision,
  }) {
    _showPregnancyView();
    if (refresh) unawaited(_controller.refreshPregnancyDiary());
    _pregnancyDiaryNoticeTimer?.cancel();
    _pregnancyDiaryNotice.value = true;
    _pregnancyDiaryNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _pregnancyDiaryNotice.value = false;
      _pregnancyDiaryNoticeTimer = null;
      if (changeStore != null &&
          changeStore.revision == revision &&
          changeStore.highlightCard) {
        changeStore.clearCardNotice();
      }
    });
    _scrollToStatusTarget(_pregnancyDiaryAnchorKey);
  }

  void _showBirthJourneyNotice({
    bool refresh = true,
    PregnancyPlanChangeStore? changeStore,
    int? revision,
  }) {
    _showPregnancyView();
    if (refresh) unawaited(_controller.refreshPregnancyPlan());
    _birthJourneyNoticeTimer?.cancel();
    _birthJourneyNotice.value = true;
    _birthJourneyNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _birthJourneyNotice.value = false;
      _birthJourneyNoticeTimer = null;
      if (changeStore != null &&
          changeStore.revision == revision &&
          changeStore.highlightCard) {
        changeStore.clearCardNotice();
      }
    });
    _scrollToStatusTarget(_birthJourneyAnchorKey);
  }

  void _showPregnancyView() {
    unawaited(_controller.changeCareStage(StatusCareStage.pregnancy));
    _controller.selectIdentity(StatusIdentity.mom);
    _persistInteractionState();
  }

  void _scrollToStatusTarget(GlobalKey targetKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = targetKey.currentContext;
      if (!mounted || targetContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.35,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _showGrowthHighlight() {
    unawaited(_controller.changeCareStage(StatusCareStage.postpartum));
    _controller.selectIdentity(StatusIdentity.baby);
    _persistInteractionState();
    unawaited(_controller.refresh());
    _startGrowthHighlightAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _growthCurveAnchorKey.currentContext;
      if (!mounted || targetContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _startGrowthHighlightAnimation() {
    _growthHighlightTimer?.cancel();
    _growthHighlight.value = true;
    var toggleCount = 0;
    _growthHighlightTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      toggleCount += 1;
      _growthHighlight.value = !_growthHighlight.value;
      if (toggleCount < 5) return;
      timer.cancel();
      _growthHighlightTimer = null;
      _growthHighlight.value = false;
    });
  }

  void _changeCareStage(String stage) {
    setState(() {
      unawaited(
        _controller.changeCareStage(
          StatusCareStage.fromStorage(stage) ?? StatusCareStage.postpartum,
        ),
      );
      unawaited(_controller.loadVisible());
      _persistInteractionState();
    });
  }

  void _handleSelectionChanged() {
    _interactionState
      ..view = _view
      ..careStage = _careStage;
  }

  void _persistInteractionState() {
    _interactionState
      ..view = _view
      ..careStage = _careStage
      ..milkTrendMode = _milkTrendMode
      ..babyGrowthMetric = _babyGrowthMetric;
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    _growthHighlightTimer?.cancel();
    _pregnancyDiaryNoticeTimer?.cancel();
    _birthJourneyNoticeTimer?.cancel();
    _growthHighlight.dispose();
    _pregnancyDiaryNotice.dispose();
    _birthJourneyNotice.dispose();
    if (_runtime != null) {
      _pregnancyDiaryChangeStore?.removeListener(
        _handlePregnancyDiaryChangeStore,
      );
      _pregnancyPlanChangeStore?.removeListener(
        _handlePregnancyPlanChangeStore,
      );
      _controller.careStage.removeListener(_handleSelectionChanged);
      _controller.identity.removeListener(_handleSelectionChanged);
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dashboardListenable,
      builder: (context, _) {
        final isMom = _view == 'mom';
        final isPregnancy = _careStage == 'pregnancy';
        final overviewResource = _controller.overview.value;
        final overview = overviewResource.data ?? const StatusOverview();
        final subtitles = _statusIdentitySubtitles(
          overviewResource: overviewResource,
          diaryEntries: _controller.pregnancyDiaryEntries.value.data,
          isPregnancy: isPregnancy,
        );

        return RefreshIndicator(
          key: const ValueKey('status-refresh-indicator'),
          color: MomCozyColors.primary,
          onRefresh: _controller.refresh,
          child: CustomScrollView(
            key: ValueKey('route-page-${widget.path}'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StatusPinnedHeaderDelegate(
                  child: RepaintBoundary(
                    key: const ValueKey('status-profile-selector'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        children: [
                          _CareStageSelector(
                            selectedStage: _careStage,
                            accent: widget.accent,
                            onChanged: _changeCareStage,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _StatusIdentityTabs(
                              selected: _view,
                              momSubtitle: subtitles.mom,
                              babySubtitle: subtitles.baby,
                              babyDisabled: isPregnancy,
                              onChanged: (next) {
                                if (!_controller.selectIdentity(
                                  StatusIdentity.fromValue(next),
                                )) {
                                  return;
                                }
                                unawaited(_controller.loadVisible());
                                setState(() {
                                  _persistInteractionState();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _statusOverviewChildren(overview, isMom),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _statusOverviewChildren(StatusOverview overview, bool isMom) {
    final content = isMom
        ? _momStatusChildren(overview)
        : _babyStatusChildren(overview);

    return content;
  }

  List<Widget> _momStatusChildren(StatusOverview overview) {
    final isPregnancy = _careStage == 'pregnancy';

    if (isPregnancy) {
      return [
        Container(
          key: _pregnancyDiaryAnchorKey,
          child: _StatusNoticeHighlight(
            surfaceKey: const ValueKey('status-pregnancy-diary-notice'),
            active: _pregnancyDiaryNotice,
            child: PregnancyDiaryDashboard(
              key: const ValueKey('status-pregnancy-diary-dashboard'),
              entries: _controller.pregnancyDiaryEntries,
              mutation: _controller.diaryMutation,
              now: _controller.now,
              onSave: (entryDate, draft) =>
                  _controller.saveDiary(entryDate: entryDate, draft: draft),
              onAgentPrompt: (prompt) {
                context.go('/', extra: {'agentPrefill': prompt});
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          key: _birthJourneyAnchorKey,
          child: _StatusNoticeHighlight(
            surfaceKey: const ValueKey('status-birth-journey-notice'),
            active: _birthJourneyNotice,
            child: BirthJourneyPlanDashboard(
              key: const ValueKey('status-birth-journey-dashboard'),
              plan: _controller.birthJourneyPlan,
              mutation: _controller.planMutation,
              onDeletePlan: _controller.deleteBirthJourneyPlan,
              onToggleTodo: (itemId, completed) => _controller.togglePlanTodo(
                taskId: itemId,
                completed: completed,
              ),
              onRetryPlan: _controller.refreshPregnancyPlan,
              onAgentPrompt: (prompt, {autoSend = false}) {
                context.go(
                  '/',
                  extra: {
                    'agentPrefill': prompt,
                    if (autoSend) 'agentAutoSend': true,
                  },
                );
              },
            ),
          ),
        ),
      ];
    }

    return [
      PostpartumMomDashboard(
        key: const ValueKey('status-postpartum-mom-dashboard'),
        milkTrends: _controller.milkTrends,
        volumeUnit: _controller.volumeUnit,
        now: _controller.now,
        windowDays: _milkTrendMode == '月' ? 30 : 7,
        onWindowDaysChanged: (days) {
          setState(() {
            _milkTrendMode = days == 30 ? '月' : '周';
            _persistInteractionState();
          });
        },
        onAgentPrompt: (prompt) {
          context.go('/', extra: {'agentPrefill': prompt});
        },
      ),
    ];
  }

  List<Widget> _babyStatusChildren(StatusOverview overview) {
    return [
      _StatusModuleGrid(
        children: [
          BabyFeedingCard(
            records: _controller.feedingRecords,
            volumeUnit: _controller.volumeUnit,
            onInfoTap: () => unawaited(showBabyFeedingInfoDialog(context)),
          ),
          BabyGrowthSummaryCard(
            records: _controller.growthRecords,
            mutation: _controller.growthMutation,
            onSave: ({required weightKg, required heightCm, required headCm}) =>
                _controller.saveGrowth(
                  weightKg: weightKg,
                  heightCm: heightCm,
                  headCm: headCm,
                ),
            onMilestoneTap: () => unawaited(
              showBabyStatusPanel(context, panel: BabyStatusPanel.milestone),
            ),
          ),
          BabyHealthCard(
            onOpen: () => unawaited(
              showBabyStatusPanel(context, panel: BabyStatusPanel.health),
            ),
          ),
          BabySleepCard(
            onOpen: () => unawaited(
              showBabyStatusPanel(context, panel: BabyStatusPanel.sleep),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        key: _growthCurveAnchorKey,
        child: _StatusIntentHighlight(
          surfaceKey: const ValueKey('status-baby-growth-highlight'),
          active: _growthHighlight,
          child: BabyGrowthChart(
            key: const ValueKey('status-baby-growth-curve-preview'),
            records: _controller.growthRecords,
            birthDate: overview.baby?.birthDate,
            selectedMetric: _babyGrowthMetric,
            onMetricChanged: (metric) {
              setState(() {
                _babyGrowthMetric = metric;
                _persistInteractionState();
              });
            },
          ),
        ),
      ),
    ];
  }
}

class _StatusIntentHighlight extends StatelessWidget {
  const _StatusIntentHighlight({
    required this.surfaceKey,
    required this.active,
    required this.child,
  });

  final Key surfaceKey;
  final ValueListenable<bool> active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: active,
      child: child,
      builder: (context, isActive, child) {
        if (!isActive) {
          return KeyedSubtree(key: surfaceKey, child: child!);
        }
        return AnimatedContainer(
          key: surfaceKey,
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? const Color(0xff6ee7b7).withValues(alpha: 0.8)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x386ee7b7),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
    );
  }
}

class _StatusNoticeHighlight extends StatefulWidget {
  const _StatusNoticeHighlight({
    required this.surfaceKey,
    required this.active,
    required this.child,
  });

  final Key surfaceKey;
  final ValueListenable<bool> active;
  final Widget child;

  @override
  State<_StatusNoticeHighlight> createState() => _StatusNoticeHighlightState();
}

class _StatusNoticeHighlightState extends State<_StatusNoticeHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  );

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_syncAnimation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _StatusNoticeHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.active, widget.active)) {
      oldWidget.active.removeListener(_syncAnimation);
      widget.active.addListener(_syncAnimation);
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.active.value && !disableAnimations) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    _controller.stop();
    _controller.value = 0;
  }

  @override
  void dispose() {
    widget.active.removeListener(_syncAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.active,
      child: widget.child,
      builder: (context, isActive, child) {
        if (!isActive) {
          return KeyedSubtree(key: widget.surfaceKey, child: child!);
        }
        return AnimatedBuilder(
          animation: _controller,
          child: child,
          builder: (context, child) {
            final wave = isActive
                ? (1 - math.cos(_controller.value * math.pi * 2)) / 2
                : 0.0;
            return Transform.translate(
              offset: Offset(0, -2 * wave),
              child: Transform.scale(
                scale: 1 + 0.025 * wave,
                child: AnimatedContainer(
                  key: widget.surfaceKey,
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isActive
                          ? MomCozyColors.badge.withValues(alpha: 0.48)
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: MomCozyColors.badge.withValues(
                                alpha: 0.3 * wave,
                              ),
                              blurRadius: 34,
                              spreadRadius: -20,
                              offset: const Offset(0, 18),
                            ),
                          ]
                        : const [],
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusModuleGrid extends StatelessWidget {
  const _StatusModuleGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MomCozyLayout.maxAppWidth;
        final childAspectRatio = width < 390 ? 0.94 : 1.08;
        return SizedBox(
          width: width,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          ),
        );
      },
    );
  }
}

({String mom, String baby}) _statusIdentitySubtitles({
  required StatusResource<StatusOverview> overviewResource,
  required List<PregnancyDiaryEntry>? diaryEntries,
  required bool isPregnancy,
}) {
  if (overviewResource.phase == StatusResourcePhase.initial ||
      overviewResource.phase == StatusResourcePhase.loading) {
    return (mom: '正在加载妈妈信息…', baby: '正在加载宝宝信息…');
  }

  final overview = overviewResource.data ?? const StatusOverview();
  if (isPregnancy) {
    final estimatedDueDate = overview.mom?.estimatedDueDate;
    String? diaryStage;
    for (final entry in diaryEntries ?? const <PregnancyDiaryEntry>[]) {
      final value = entry.gestationalWeek.trim();
      if (value.isNotEmpty) {
        diaryStage = value;
        break;
      }
    }
    return (
      mom: estimatedDueDate == null
          ? _formatPregnancyStageSubtitle(diaryStage)
          : '预产期 ${estimatedDueDate.toIso8601String().split('T').first}',
      baby: '宝宝孕育中',
    );
  }

  if (overviewResource.hasError) {
    return (mom: '妈妈档案待绑定', baby: '宝宝档案待绑定');
  }

  final postpartumDay = overview.mom?.postpartumDay;
  final babyAgeDay = postpartumDay ?? overview.baby?.ageDays;
  return (
    mom: postpartumDay == null
        ? '暂无有效分娩日期'
        : '产后第 ${(math.max(0, postpartumDay) ~/ 7) + 1} 周',
    baby: babyAgeDay == null
        ? '暂无有效分娩日期'
        : '宝宝已出生 ${math.max(0, babyAgeDay)} 天',
  );
}

String _formatPregnancyStageSubtitle(String? value) {
  final match = RegExp(
    r'(?:孕期|孕周|怀孕|孕)?\s*(\d{1,2})\s*(?:周|w|W)',
  ).firstMatch(value?.trim() ?? '');
  final week = match?.group(1);
  return week == null ? '处于孕期' : '孕期 $week 周';
}

class _StatusPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StatusPinnedHeaderDelegate({required this.child});

  static const extent = 120.0;

  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          key: const ValueKey('status-pinned-header'),
          color: Theme.of(
            context,
          ).scaffoldBackgroundColor.withValues(alpha: 0.92),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatusPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _CareStageSelector extends StatelessWidget {
  const _CareStageSelector({
    required this.selectedStage,
    required this.accent,
    required this.onChanged,
  });

  final String selectedStage;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        container: true,
        label: '照护阶段切换',
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CareStageOption(
                key: const ValueKey('status-care-stage-pregnancy'),
                label: '孕期',
                selected: selectedStage == 'pregnancy',
                onTap: () => onChanged('pregnancy'),
              ),
              const SizedBox(width: 2),
              _CareStageOption(
                key: const ValueKey('status-care-stage-postpartum'),
                label: '哺乳期',
                selected: selectedStage == 'postpartum',
                onTap: () => onChanged('postpartum'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareStageOption extends StatelessWidget {
  const _CareStageOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 24, minWidth: 42),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              border: selected
                  ? Border.all(
                      color: const Color(0xffeadfd8).withValues(alpha: 0.7),
                    )
                  : null,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? const Color(0xff6f5964)
                    : const Color(0xffaa98a1),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIdentityTabs extends StatelessWidget {
  const _StatusIdentityTabs({
    required this.selected,
    required this.momSubtitle,
    required this.babySubtitle,
    required this.babyDisabled,
    required this.onChanged,
  });

  final String selected;
  final String momSubtitle;
  final String babySubtitle;
  final bool babyDisabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final tabWidth = (constraints.maxWidth - gap) / 2;

        return Row(
          children: [
            SizedBox(
              width: tabWidth,
              child: _StatusIdentityTab(
                value: 'mom',
                title: '妈妈',
                subtitle: momSubtitle,
                asset: MomCozyAssets.momAvatar,
                selected: selected == 'mom',
                onTap: () => onChanged('mom'),
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: tabWidth,
              child: _StatusIdentityTab(
                value: 'baby',
                title: '宝宝',
                subtitle: babySubtitle,
                asset: MomCozyAssets.babyAvatar,
                selected: selected == 'baby',
                disabled: babyDisabled,
                onTap: () => onChanged('baby'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusIdentityTab extends StatelessWidget {
  const _StatusIdentityTab({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.selected,
    this.disabled = false,
    required this.onTap,
  });

  final String value;
  final String title;
  final String subtitle;
  final String asset;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      enabled: !disabled,
      inMutuallyExclusiveGroup: true,
      child: Opacity(
        opacity: disabled
            ? 0.45
            : selected
            ? 1
            : 0.72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: disabled
                ? Colors.white.withValues(alpha: 0.35)
                : selected
                ? const Color(0xfffff7fb)
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xffd8adc2)
                  : Colors.white.withValues(alpha: disabled ? 0.60 : 0.70),
              width: selected ? 2 : 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('status-identity-tab-$value'),
              onTap: disabled ? null : onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: Stack(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: selected ? 1 : 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 4,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xffb46f91),
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(MomCozyRadii.pill),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? const Color(
                                        0xffb46f91,
                                      ).withValues(alpha: 0.45)
                                    : MomCozyColors.border.withValues(
                                        alpha: 0.5,
                                      ),
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: AssetImage(asset),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: selected
                                            ? const Color(0xff35212c)
                                            : MomCozyColors.mutedForeground,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: selected
                                            ? const Color(0xff806171)
                                            : MomCozyColors.mutedForeground,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        height: 1.15,
                                      ),
                                ),
                              ],
                            ),
                          ),
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
  }
}

class _DevicePage extends StatefulWidget {
  const _DevicePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.onLogout,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Future<void> Function()? onLogout;

  @override
  State<_DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<_DevicePage> {
  bool _isScanning = false;
  bool _isLoggingOut = false;
  BlePlatform? _blePlatform;
  BlePermissionState _permissionState = BlePermissionState.unknown;
  List<BleDeviceSnapshot> _connectedDevices = const [];
  List<BleDeviceSnapshot> _scanResults = const [];
  String? _bleError;
  bool _scanAttempted = false;
  String? _runtimeUserId;
  StreamSubscription<BleDeviceSnapshot>? _scanSub;
  StreamSubscription<BleScanFailure>? _scanFailureSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final ble = runtime.blePlatform;
    final previousUserId = _runtimeUserId;
    final userChanged =
        previousUserId != null && previousUserId != runtime.userId;
    _runtimeUserId = runtime.userId;
    if (!identical(ble, _blePlatform)) {
      unawaited(_scanSub?.cancel());
      unawaited(_scanFailureSub?.cancel());
      _blePlatform = ble;
      _scanSub = ble.scanResults.listen(_handleScanResult);
      _scanFailureSub = ble.scanFailures.listen(_handleScanFailure);
      unawaited(_refreshBleState());
    }
    if (userChanged) unawaited(_clearDevicesForUserSwitch());
  }

  @override
  void dispose() {
    unawaited(_scanSub?.cancel());
    unawaited(_scanFailureSub?.cancel());
    super.dispose();
  }

  Future<void> _refreshBleState() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      final permission = await ble.permissionState();
      final connected = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _permissionState = permission;
        _connectedDevices = connected;
        _bleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bleError = 'BLE 状态读取失败';
      });
    }
  }

  Future<void> _clearDevicesForUserSwitch() async {
    final ble = _blePlatform;
    if (ble == null) return;
    final devices = _connectedDevices.isEmpty
        ? await ble.getConnectedDevices()
        : _connectedDevices;
    try {
      if (_isScanning) await ble.stopScan();
      for (final device in devices.where((device) => device.connected)) {
        await ble.disconnect(device.deviceId);
      }
    } catch (_) {
      // Best-effort local isolation; native cleanup is verified in device lab.
    }
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _connectedDevices = const [];
      _scanResults = const [];
      _scanAttempted = false;
      _bleError = '检测到用户切换，已隔离上一用户设备连接。';
    });
  }

  Future<void> _toggleScan() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      if (_isScanning) {
        await ble.stopScan();
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
        return;
      }

      final permission = await ble.requestPermission();
      if (permission != BlePermissionState.granted) {
        if (!mounted) return;
        setState(() {
          _permissionState = permission;
          _bleError = _permissionDeniedMessage(permission);
        });
        return;
      }

      await ble.startScan();
      if (!mounted) return;
      setState(() {
        _permissionState = permission;
        _isScanning = true;
        _scanAttempted = true;
        _scanResults = const [];
        _bleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = 'BLE 扫描启动失败';
      });
    }
  }

  void _handleScanResult(BleDeviceSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _scanResults = [
        snapshot,
        ..._scanResults.where((item) => item.deviceId != snapshot.deviceId),
      ];
      _bleError = null;
    });
  }

  void _handleScanFailure(BleScanFailure failure) {
    if (!mounted) return;
    setState(() {
      _bleError = failure.message;
      _isScanning = false;
    });
  }

  Future<void> _connectScanResult(BleDeviceSnapshot snapshot) async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      await ble.connect(snapshot.deviceId);
      await ble.stopScan();
      await _refreshBleState();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = '${snapshot.deviceName} 已连接';
      });
    } catch (_) {
      await ble.stopScan();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = '连接 ${snapshot.deviceName} 失败，请重试。';
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    final ble = _blePlatform;
    if (ble == null) return;
    if (_permissionState == BlePermissionState.permanentlyDenied) {
      await ble.openAppSettings();
    } else {
      await ble.openBluetoothSettings();
    }
    await _refreshBleState();
  }

  @override
  Widget build(BuildContext context) {
    final leftDevice = _deviceForSide('L') ?? _deviceForSide('left');
    final rightDevice = _deviceForSide('R') ?? _deviceForSide('right');

    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 28),
      children: [
        _DeviceHeader(
          onAdd: _toggleScan,
          onUser: () => context.go('/device/user'),
          onManage: () => context.go('/device/manage'),
          onLogout: widget.onLogout == null
              ? null
              : () => unawaited(_requestLogout()),
          isLoggingOut: _isLoggingOut,
        ),
        const SizedBox(height: 14),
        const _DeviceW1Banner(),
        const SizedBox(height: 17),
        _DeviceAirOnePanel(
          leftDevice: leftDevice,
          rightDevice: rightDevice,
          onStartPump: _canStartPump(leftDevice, rightDevice)
              ? () => context.go('/pump')
              : null,
          onLeftAction: leftDevice?.connected == true
              ? () => context.go('/calibration')
              : _toggleScan,
          onRightAction: rightDevice?.connected == true
              ? () => context.go('/calibration')
              : _toggleScan,
        ),
        if (_scanAttempted || _bleError != null) ...[
          const SizedBox(height: 14),
          _DeviceScanPanel(
            isScanning: _isScanning,
            permissionState: _permissionState,
            connectedCount: _connectedDevices.length,
            error: _bleError,
            accent: widget.accent,
            action: _permissionAction(),
            onScan: _toggleScan,
          ),
        ],
        if (_scanAttempted) ...[
          const SizedBox(height: 12),
          _DeviceScanResultsPanel(
            scanResults: _scanResults,
            onConnect: _connectScanResult,
            accent: widget.accent,
          ),
        ],
      ],
    );
  }

  Widget _permissionAction() {
    if (_permissionState == BlePermissionState.permanentlyDenied) {
      return IconButton(
        tooltip: '打开系统设置',
        onPressed: _openPermissionSettings,
        icon: const Icon(Icons.settings_rounded),
      );
    }
    if (_permissionState == BlePermissionState.denied) {
      return IconButton(
        tooltip: '打开蓝牙设置',
        onPressed: _openPermissionSettings,
        icon: const Icon(Icons.bluetooth_disabled_rounded),
      );
    }
    return const Icon(Icons.chevron_right_rounded);
  }

  BleDeviceSnapshot? _deviceForSide(String side) {
    final normalized = side.toLowerCase();
    for (final device in _connectedDevices) {
      if (device.side.toLowerCase() == normalized) return device;
    }
    return null;
  }

  Future<void> _requestLogout() async {
    final onLogout = widget.onLogout;
    if (onLogout == null || _isLoggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('device-logout-dialog'),
        title: const Text('退出登录'),
        content: const Text('退出后需要重新输入邀请码登录。'),
        actions: [
          TextButton(
            key: const ValueKey('device-logout-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('device-logout-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });
    await _disconnectDevicesForLogout();
    try {
      await onLogout();
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggingOut = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('退出登录失败，请稍后重试。')));
    }
  }

  Future<void> _disconnectDevicesForLogout() async {
    final ble = _blePlatform;
    if (ble == null) return;
    if (_isScanning) {
      try {
        await ble.stopScan();
      } catch (_) {
        // Authentication cleanup must continue even if BLE teardown fails.
      }
    }
    List<BleDeviceSnapshot> devices = _connectedDevices;
    try {
      devices = await ble.getConnectedDevices();
    } catch (_) {
      // Fall back to the latest in-memory snapshots.
    }
    for (final device in devices.where((device) => device.connected)) {
      try {
        await ble.disconnect(device.deviceId);
      } catch (_) {
        // Disconnect each device independently before continuing logout.
      }
    }
  }
}

String _deviceBatteryLabel(BleDeviceSnapshot? device) {
  final battery = device?.battery;
  if (battery == null) return '--';
  return '$battery%';
}

String _scanResultSubtitle(BleDeviceSnapshot device) {
  final details = <String>[
    device.side,
    device.deviceId,
    if (device.battery != null) '电量 ${device.battery}%',
    if (device.rssi != null) 'RSSI ${device.rssi}',
  ];
  return details.join(' · ');
}

String _permissionLabel(BlePermissionState state) {
  return switch (state) {
    BlePermissionState.granted => '已授权',
    BlePermissionState.denied => '未授权',
    BlePermissionState.permanentlyDenied => '永久拒绝',
    BlePermissionState.unknown => '未请求',
  };
}

String _permissionDeniedMessage(BlePermissionState state) {
  if (state == BlePermissionState.permanentlyDenied) {
    return 'BLE 权限已永久拒绝，请从系统设置重新开启。';
  }
  return 'BLE 权限未授权';
}

bool _canStartPump(BleDeviceSnapshot? left, BleDeviceSnapshot? right) {
  return left?.connected == true && right?.connected == true;
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({
    required this.onAdd,
    required this.onUser,
    required this.onManage,
    required this.isLoggingOut,
    this.onLogout,
  });

  final VoidCallback onAdd;
  final VoidCallback onManage;
  final VoidCallback onUser;
  final VoidCallback? onLogout;
  final bool isLoggingOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '设备连接',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: MomCozyColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        PopupMenuButton<String>(
          enabled: !isLoggingOut,
          tooltip: '打开设备快捷菜单',
          color: MomCozyColors.foreground.withValues(alpha: 0.92),
          elevation: 14,
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            switch (value) {
              case 'add':
                onAdd();
                break;
              case 'user':
                onUser();
                break;
              case 'manage':
                onManage();
                break;
              case 'logout':
                onLogout?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'add',
              child: _DeviceQuickMenuLabel('添加设备'),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'user',
              child: _DeviceQuickMenuLabel('用户管理'),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'manage',
              child: _DeviceQuickMenuLabel('设备提醒'),
            ),
            if (onLogout != null) ...[
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                key: ValueKey('device-logout-menu-item'),
                value: 'logout',
                child: _DeviceQuickMenuLabel('退出登录', color: Color(0xffffa8a8)),
              ),
            ],
          ],
          child: Container(
            key: const ValueKey('device-quick-menu-button'),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MomCozyColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: MomCozyShadows.soft,
            ),
            child: isLoggingOut
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded, size: 20),
          ),
        ),
      ],
    );
  }
}

class _DeviceQuickMenuLabel extends StatelessWidget {
  const _DeviceQuickMenuLabel(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color ?? MomCozyColors.background,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DeviceW1Banner extends StatelessWidget {
  const _DeviceW1Banner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/w1'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, 0.6, 1],
              colors: [Color(0xff562938), Color(0xff723141), Color(0xff602e37)],
            ),
            border: Border.all(
              color: MomCozyColors.primary.withValues(alpha: 0.2),
            ),
            boxShadow: MomCozyShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xffffdce5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Momcozy W1 · 全新上市',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0x66ffffff),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceAirOnePanel extends StatelessWidget {
  const _DeviceAirOnePanel({
    required this.leftDevice,
    required this.rightDevice,
    required this.onStartPump,
    required this.onLeftAction,
    required this.onRightAction,
  });

  final BleDeviceSnapshot? leftDevice;
  final BleDeviceSnapshot? rightDevice;
  final VoidCallback? onStartPump;
  final VoidCallback onLeftAction;
  final VoidCallback onRightAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card,
        borderColor: MomCozyColors.border.withValues(alpha: 0.6),
        radius: 24,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Air One',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('device-start-pump-button'),
                  onPressed: onStartPump,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    disabledBackgroundColor: MomCozyColors.primary.withValues(
                      alpha: 0.36,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.72,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('开始吸奶'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DeviceDeckCard(
                    sideCode: 'L',
                    sideLabel: '左侧',
                    device: leftDevice,
                    onTap: onLeftAction,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DeviceDeckCard(
                    sideCode: 'R',
                    sideLabel: '右侧',
                    device: rightDevice,
                    onTap: onRightAction,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDeckCard extends StatelessWidget {
  const _DeviceDeckCard({
    required this.sideCode,
    required this.sideLabel,
    required this.device,
    required this.onTap,
  });

  final String sideCode;
  final String sideLabel;
  final BleDeviceSnapshot? device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paired = device != null;
    final connected = device?.connected == true;
    final statusColor = connected
        ? const Color(0xff3f9d74)
        : MomCozyColors.mutedForeground;

    return Material(
      key: ValueKey('device-deck-card-$sideCode'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 214,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: connected ? MomCozyColors.card : const Color(0xfff7f7f8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: connected
                  ? MomCozyColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            boxShadow: connected ? MomCozyShadows.soft : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sideCode == 'L' ? 'LEFT' : 'RIGHT',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: MomCozyColors.foreground.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (paired)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MomCozyColors.background.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MomCozyColors.border.withValues(alpha: 0.48),
                        ),
                      ),
                      child: const Icon(Icons.info_outline_rounded, size: 15),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: connected
                            ? MomCozyColors.primary.withValues(alpha: 0.06)
                            : MomCozyColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MomCozyColors.border.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    if (paired)
                      Image.asset(
                        MomCozyAssets.pumpM9,
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        opacity: AlwaysStoppedAnimation(connected ? 1 : 0.46),
                      )
                    else
                      Icon(
                        Icons.photo_camera_outlined,
                        color: MomCozyColors.foreground.withValues(alpha: 0.38),
                        size: 25,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (paired)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MomCozyColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.48),
                    ),
                  ),
                  child: _DeviceConnectedDetails(
                    sideLabel: sideLabel,
                    device: device!,
                    statusColor: statusColor,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.54),
                    ),
                    boxShadow: MomCozyShadows.soft,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth_rounded, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '连接设备',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceConnectedDetails extends StatelessWidget {
  const _DeviceConnectedDetails({
    required this.sideLabel,
    required this.device,
    required this.statusColor,
  });

  final String sideLabel;
  final BleDeviceSnapshot device;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final connected = device.connected;
    final name = device.deviceName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                connected ? '已连接' : '未连接',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: connected
                      ? MomCozyColors.foreground
                      : MomCozyColors.mutedForeground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$sideLabel $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: MomCozyColors.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.battery_5_bar_rounded, size: 14),
            const SizedBox(width: 3),
            Text(
              _deviceBatteryLabel(device),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            const Icon(Icons.signal_cellular_alt_rounded, size: 13),
            const SizedBox(width: 3),
            Text(
              _deviceSignalLabel(device),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceScanPanel extends StatelessWidget {
  const _DeviceScanPanel({
    required this.isScanning,
    required this.permissionState,
    required this.connectedCount,
    required this.error,
    required this.accent,
    required this.action,
    required this.onScan,
  });

  final bool isScanning;
  final BlePermissionState permissionState;
  final int connectedCount;
  final String? error;
  final Color accent;
  final Widget action;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final title = isScanning ? '正在扫描附近设备' : 'BLE 权限和扫描';
    final subtitle =
        error ??
        (isScanning
            ? '请确保设备已开机（长按电源键3秒），并靠近手机。'
            : '权限状态 ${_permissionLabel(permissionState)}，已恢复 $connectedCount 台已连接设备。');

    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.92),
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            _DeviceRadarIcon(isScanning: isScanning, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: error == null
                          ? MomCozyColors.mutedForeground
                          : const Color(0xffa94747),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: onScan,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(84, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    isScanning
                        ? Icons.stop_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 17,
                  ),
                  label: Text(isScanning ? '停止扫描' : '扫描'),
                ),
                if (!isScanning) ...[
                  const SizedBox(height: 4),
                  SizedBox(width: 38, height: 32, child: Center(child: action)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRadarIcon extends StatelessWidget {
  const _DeviceRadarIcon({required this.isScanning, required this.accent});

  final bool isScanning;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isScanning)
            for (final size in const [58.0, 42.0])
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
              ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: MomCozyColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.48),
              ),
              boxShadow: MomCozyShadows.soft,
            ),
            child: Icon(
              isScanning
                  ? Icons.navigation_rounded
                  : Icons.bluetooth_searching_rounded,
              color: isScanning ? accent : MomCozyColors.mutedForeground,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceScanResultsPanel extends StatelessWidget {
  const _DeviceScanResultsPanel({
    required this.scanResults,
    required this.onConnect,
    required this.accent,
  });

  final List<BleDeviceSnapshot> scanResults;
  final ValueChanged<BleDeviceSnapshot> onConnect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '扫描结果',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: MomCozyColors.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (scanResults.isEmpty)
          _DeviceSearchRow(
            icon: Icons.bluetooth_disabled_rounded,
            title: '暂无扫描结果',
            subtitle: '请确认设备已开机并靠近手机后重试。',
            accent: MomCozyColors.mutedForeground,
          )
        else
          for (final device in scanResults.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DeviceSearchRow(
                icon: Icons.bluetooth_searching_rounded,
                title: device.deviceName,
                subtitle: _scanResultSubtitle(device),
                accent: accent,
                onTap: () => onConnect(device),
                trailing: const Text(
                  '连接',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
      ],
    );
  }
}

class _DeviceSearchRow extends StatelessWidget {
  const _DeviceSearchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.82),
        shadows: MomCozyShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _IconBubble(icon: icon, accent: accent, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MomCozyColors.mutedForeground,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _deviceSignalLabel(BleDeviceSnapshot? device) {
  final rssi = device?.rssi;
  if (rssi == null) return '强';
  if (rssi >= -55) return '强';
  if (rssi >= -70) return '中';
  return '弱';
}

enum _PumpRunState { idle, running, paused }

class _PumpPage extends StatefulWidget {
  const _PumpPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<_PumpPage> {
  _PumpRunState _runState = _PumpRunState.idle;
  double _leftLevel = 5;
  double _rightLevel = 5;
  int _elapsedMinutes = 0;
  int _leftVolumeMl = 0;
  int _rightVolumeMl = 0;
  String? _sessionOwnerUserId;
  bool _completionUploadLocked = false;
  bool _duplicateCompletionBlocked = false;
  MomCozyApiRuntime? _runtime;
  PumpWorkstateReply? _lastReply;
  Object? _uploadError;
  String? _guardNotice;
  bool _isUploading = false;
  bool _calibrationPromptVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final previousRuntime = _runtime;
    if (previousRuntime != null &&
        previousRuntime.userId != runtime.userId &&
        _runState != _PumpRunState.idle) {
      _runState = _PumpRunState.idle;
      _isUploading = false;
      _elapsedMinutes = 0;
      _leftVolumeMl = 0;
      _rightVolumeMl = 0;
      _sessionOwnerUserId = null;
      _completionUploadLocked = false;
      _duplicateCompletionBlocked = false;
      _lastReply = null;
      _uploadError = null;
      _guardNotice = '检测到用户切换，已清空上一用户 session。';
    }
    _runtime = runtime;
  }

  void _changeRunState(_PumpRunState next) {
    if (next == _PumpRunState.idle && _completionUploadLocked) {
      setState(() {
        _duplicateCompletionBlocked = true;
        _guardNotice = '重复结束已拦截，本次 session 只保留一组结束上传。';
      });
      return;
    }
    if (next == _runState) return;

    setState(() {
      _applyLocalSessionTransition(next);
      _runState = next;
    });
    _uploadWorkstate(next);
  }

  void _applyLocalSessionTransition(_PumpRunState next) {
    final previous = _runState;
    if (previous == _PumpRunState.idle && next == _PumpRunState.running) {
      _sessionOwnerUserId = _runtime?.userId;
      _completionUploadLocked = false;
      _duplicateCompletionBlocked = false;
      _elapsedMinutes = 0;
      _leftVolumeMl = 0;
      _rightVolumeMl = 0;
      _guardNotice = '已绑定 ${_sessionOwnerUserId ?? '当前用户'}。';
      _advanceLocalProgress(minutes: 2);
      return;
    }

    if (previous == _PumpRunState.running && next == _PumpRunState.paused) {
      _advanceLocalProgress(minutes: 3);
      return;
    }

    if (previous == _PumpRunState.paused && next == _PumpRunState.running) {
      _advanceLocalProgress(minutes: 2);
      return;
    }

    if (next == _PumpRunState.idle && previous != _PumpRunState.idle) {
      _advanceLocalProgress(minutes: 1);
      _completionUploadLocked = true;
      _duplicateCompletionBlocked = false;
      _guardNotice = '结束上传已锁定：summary、milk record、Agent context 仅允许一次。';
    }
  }

  void _advanceLocalProgress({required int minutes}) {
    _elapsedMinutes += minutes;
    _leftVolumeMl += (_leftLevel * minutes).round();
    _rightVolumeMl += (_rightLevel * minutes * 0.8).round();
  }

  Future<void> _uploadWorkstate(_PumpRunState state) async {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final reply = await runtime.pumpWorkstateRepository.uploadWorkstate(
        left: PumpSideWorkstate(
          state: _pumpStateCode(state),
          mode: 'massage_expression',
          level: _leftLevel.round(),
        ),
        right: PumpSideWorkstate(
          state: _pumpStateCode(state),
          mode: 'expression',
          level: _rightLevel.round(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lastReply = reply;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadError = error;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _runState == _PumpRunState.running;
    final isPaused = _runState == _PumpRunState.paused;

    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xfffffaf8), Color(0xfffbf2f2), Color(0xfff8edf0)],
              stops: [0, 0.56, 1],
            ),
          ),
          child: Transform.translate(
            offset: const Offset(0, -3),
            child: ListView(
              key: ValueKey('route-page-${widget.path}'),
              scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
              children: [
                _PumpTopBar(sessionLabel: _headerSessionLabel),
                const SizedBox(height: 10),
                Transform.translate(
                  key: const ValueKey('pump-metric-console'),
                  offset: const Offset(6, -6),
                  child: _PumpMetricConsole(
                    totalVolumeMl: _totalVolumeMl,
                    elapsedMinutes: _elapsedMinutes,
                    progress: _sessionProgress,
                    userLabel: _sessionOwnerUserId == null
                        ? '未绑定用户'
                        : '绑定 $_sessionOwnerUserId',
                    accent: widget.accent,
                  ),
                ),
                const SizedBox(height: 10),
                _PumpSessionStage(
                  leftVolumeMl: _leftVolumeMl,
                  rightVolumeMl: _rightVolumeMl,
                  leftLevel: _leftLevel.round(),
                  rightLevel: _rightLevel.round(),
                  bottleFill: _bottleFill,
                  totalVolumeMl: _totalVolumeMl,
                  isRunning: isRunning,
                  accent: widget.accent,
                ),
                const SizedBox(height: 36),
                _PumpControlConsole(
                  leftLevel: _leftLevel,
                  rightLevel: _rightLevel,
                  isRunning: isRunning,
                  isPaused: isPaused,
                  onLeftLevelChanged: (value) =>
                      setState(() => _leftLevel = value),
                  onRightLevelChanged: (value) =>
                      setState(() => _rightLevel = value),
                  onStart: isRunning
                      ? null
                      : () => _changeRunState(_PumpRunState.running),
                  onPause: isRunning
                      ? () => _changeRunState(_PumpRunState.paused)
                      : null,
                  onEnd: () => _changeRunState(_PumpRunState.idle),
                ),
                const SizedBox(height: 10),
                _PumpStatusStrip(
                  label: '结束保护',
                  icon: _duplicateCompletionBlocked
                      ? Icons.block_rounded
                      : Icons.verified_outlined,
                  title: _completionGuardTitle(),
                  subtitle: _guardNotice ?? '开始后绑定当前用户，结束时锁定一次性上传标记。',
                  accent: _duplicateCompletionBlocked
                      ? const Color(0xffb2773b)
                      : const Color(0xff43827b),
                  trailing: _StatusChip(
                    label: _completionUploadLocked ? '1/1' : '待结束',
                    icon: _completionUploadLocked
                        ? Icons.lock_outline_rounded
                        : Icons.hourglass_empty_rounded,
                    accent: _duplicateCompletionBlocked
                        ? const Color(0xffb2773b)
                        : const Color(0xff43827b),
                  ),
                ),
                _PumpStatusStrip(
                  label: '上传状态',
                  icon: _uploadError == null
                      ? Icons.cloud_sync_outlined
                      : Icons.cloud_off_outlined,
                  title: _uploadStatusTitle(),
                  subtitle: _uploadStatusSubtitle(),
                  accent: const Color(0xff6b6da8),
                  trailing: _isUploading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: '重试同步',
                          onPressed: () => _uploadWorkstate(_runState),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_calibrationPromptVisible)
          _PumpCalibrationPromptOverlay(
            onSkip: () => setState(() => _calibrationPromptVisible = false),
            onStartCalibration: () {
              setState(() => _calibrationPromptVisible = false);
              context.go('/calibration');
            },
          ),
      ],
    );
  }

  int get _totalVolumeMl => _leftVolumeMl + _rightVolumeMl;

  double get _sessionProgress {
    return ((_elapsedMinutes / 30) * 100).clamp(0, 100).toDouble();
  }

  double get _bottleFill {
    return (_totalVolumeMl / 180).clamp(0, 1).toDouble();
  }

  String get _headerSessionLabel {
    return switch (_runState) {
      _PumpRunState.running => '运行中',
      _PumpRunState.paused => '已暂停',
      _PumpRunState.idle => '待开始',
    };
  }

  String _uploadStatusTitle() {
    if (_isUploading) return '正在同步 workstate';
    if (_uploadError != null) return 'Workstate 同步失败';
    if (_lastReply != null) return 'Workstate 已同步';
    return 'Agent context 上传';
  }

  String _uploadStatusSubtitle() {
    if (_uploadError is String) return _uploadError! as String;
    if (_uploadError != null) return '检查后端连接或 token 后重试。';
    final reply = _lastReply;
    if (reply == null) return '结束后生成摘要、奶量记录和智能体上下文；重复上传会被自动拦截。';
    if (reply.output.isNotEmpty) return reply.output;
    return reply.needReply ? '后端需要处理设备状态回复。' : '后端已接收当前左右侧状态。';
  }

  String _completionGuardTitle() {
    if (_duplicateCompletionBlocked) return '重复结束已拦截';
    if (_completionUploadLocked) return '结束同步已锁定';
    if (_sessionOwnerUserId != null) return 'Session 用户已绑定';
    return 'Session 等待开始';
  }
}

class _PumpCalibrationPromptOverlay extends StatelessWidget {
  const _PumpCalibrationPromptOverlay({
    required this.onSkip,
    required this.onStartCalibration,
  });

  final VoidCallback onSkip;
  final VoidCallback onStartCalibration;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ColoredBox(
            color: MomCozyColors.foreground.withValues(alpha: 0.43),
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    key: const ValueKey('pump-calibration-prompt-card'),
                    constraints: const BoxConstraints(maxWidth: 392),
                    child: DecoratedBox(
                      decoration: MomCozyDecorations.card(
                        color: MomCozyColors.card,
                        borderColor: MomCozyColors.border,
                        radius: 16,
                        shadows: const [
                          BoxShadow(
                            color: Color(0x40392832),
                            blurRadius: 36,
                            spreadRadius: -10,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -2),
                              child: Row(
                                children: [
                                  const _PumpPromptFlowerIcon(),
                                  const SizedBox(width: 8),
                                  Text(
                                    '个性化舒适档位',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: MomCozyColors.foreground,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Transform.translate(
                              offset: const Offset(-1, 2),
                              child: Column(
                                children: [
                                  _PumpPromptRichLine(
                                    segments: [
                                      const TextSpan(text: '妈妈，检测到您还没有进行过'),
                                      TextSpan(
                                        text: '耐受度滴定',
                                        style: _pumpPromptEmphasisStyle(
                                          context,
                                        ),
                                      ),
                                      const TextSpan(text: '哦~'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _PumpPromptRichLine(
                                    segments: [
                                      const TextSpan(text: '滴定可以帮您找到'),
                                      TextSpan(
                                        text: '最舒适且高效',
                                        style: _pumpPromptEmphasisStyle(
                                          context,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '的吸力档位，避免吸乳时疼痛或效率不佳 ',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _PumpPromptRichLine(
                                    segments: [
                                      const TextSpan(text: '只需要 '),
                                      TextSpan(
                                        text: '2分钟',
                                        style: _pumpPromptEmphasisStyle(
                                          context,
                                        ),
                                      ),
                                      const TextSpan(text: '，就能让每次吸乳都更舒适~'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: onSkip,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: MomCozyColors.foreground,
                                      minimumSize: const Size.fromHeight(40),
                                      side: BorderSide(
                                        color: MomCozyColors.border.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '先跳过',
                                      style: TextStyle(
                                        fontFamily:
                                            MomCozyTypography.fontFamily,
                                        fontFamilyFallback: MomCozyTypography
                                            .fontFamilyFallback,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: onStartCalibration,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(40),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '开始滴定',
                                      style: TextStyle(
                                        fontFamily:
                                            MomCozyTypography.fontFamily,
                                        fontFamilyFallback: MomCozyTypography
                                            .fontFamilyFallback,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
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

class _PumpPromptFlowerIcon extends StatelessWidget {
  const _PumpPromptFlowerIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _PumpPromptFlowerPainter()),
    );
  }
}

class _PumpPromptFlowerPainter extends CustomPainter {
  const _PumpPromptFlowerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final petalPaint = Paint()..color = const Color(0xffff8fb8);
    final petalShadePaint = Paint()..color = const Color(0xffff6fa7);
    final centerPaint = Paint()..color = const Color(0xffffd166);
    final centerDotPaint = Paint()..color = const Color(0xffcc8d24);

    for (var index = 0; index < 5; index += 1) {
      final angle = -math.pi / 2 + index * math.pi * 2 / 5;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -6.2), width: 8.5, height: 12),
        petalPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(1.3, -6.5), width: 3, height: 7),
        petalShadePaint,
      );
      canvas.restore();
    }

    canvas.drawCircle(center, 4, centerPaint);
    canvas.drawCircle(center.translate(0.7, -0.7), 1.1, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PumpPromptRichLine extends StatelessWidget {
  const _PumpPromptRichLine({required this.segments});

  final List<InlineSpan> segments;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: MomCozyColors.mutedForeground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.55,
        ),
        children: segments,
      ),
    );
  }
}

TextStyle _pumpPromptEmphasisStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelMedium!.copyWith(
    color: MomCozyColors.primary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.55,
  );
}

int _pumpStateCode(_PumpRunState state) {
  return switch (state) {
    _PumpRunState.running => 1,
    _PumpRunState.paused => 2,
    _PumpRunState.idle => 0,
  };
}

class _PumpTopBar extends StatelessWidget {
  const _PumpTopBar({required this.sessionLabel});

  final String sessionLabel;

  @override
  Widget build(BuildContext context) {
    final isActive = sessionLabel == '运行中';
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/'),
              style: TextButton.styleFrom(
                foregroundColor: MomCozyColors.mutedForeground,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 34),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                '返回',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '沉浸式吸乳',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? MomCozyColors.primary.withValues(alpha: 0.12)
                      : MomCozyColors.muted,
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                ),
                child: Text(
                  sessionLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? MomCozyColors.primary
                        : MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PumpMetricConsole extends StatelessWidget {
  const _PumpMetricConsole({
    required this.totalVolumeMl,
    required this.elapsedMinutes,
    required this.progress,
    required this.userLabel,
    required this.accent,
  });

  final int totalVolumeMl;
  final int elapsedMinutes;
  final double progress;
  final String userLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.84),
        borderColor: accent.withValues(alpha: 0.12),
        radius: 26,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PumpMetricPanel(
                    label: '吸乳量',
                    value: '$totalVolumeMl',
                    unit: 'mL',
                    accent: accent,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PumpMetricPanel(
                    label: '时间',
                    value: '$elapsedMinutes 分钟',
                    accent: const Color(0xff836775),
                    note: userLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '本次吸乳进度',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${progress.round()}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 9,
                color: accent,
                backgroundColor: MomCozyColors.secondary.withValues(
                  alpha: 0.86,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpMetricPanel extends StatelessWidget {
  const _PumpMetricPanel({
    required this.label,
    required this.value,
    required this.accent,
    this.unit,
    this.note,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? unit;
  final String? note;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized
            ? accent.withValues(alpha: 0.08)
            : MomCozyColors.muted.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PumpSessionStage extends StatelessWidget {
  const _PumpSessionStage({
    required this.leftVolumeMl,
    required this.rightVolumeMl,
    required this.leftLevel,
    required this.rightLevel,
    required this.bottleFill,
    required this.totalVolumeMl,
    required this.isRunning,
    required this.accent,
  });

  final int leftVolumeMl;
  final int rightVolumeMl;
  final int leftLevel;
  final int rightLevel;
  final double bottleFill;
  final int totalVolumeMl;
  final bool isRunning;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.68),
        borderColor: MomCozyColors.border.withValues(alpha: 0.46),
        radius: 26,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          children: [
            SizedBox(
              height: 194,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PumpSideMetric(
                    label: '左侧',
                    value: '$leftVolumeMl mL',
                    meta: '$leftLevel档 · 按摩+吸乳',
                    alignRight: true,
                  ),
                  const SizedBox(width: 4),
                  _PumpCupVisual(
                    sideLabel: 'L',
                    volumeMl: leftVolumeMl,
                    isRunning: isRunning,
                    tone: accent,
                  ),
                  Expanded(
                    child: Center(
                      child: _PumpBottleGauge(
                        fill: bottleFill,
                        totalVolumeMl: totalVolumeMl,
                        active: isRunning,
                      ),
                    ),
                  ),
                  _PumpCupVisual(
                    sideLabel: 'R',
                    volumeMl: rightVolumeMl,
                    isRunning: isRunning,
                    tone: const Color(0xffc86d92),
                  ),
                  const SizedBox(width: 4),
                  _PumpSideMetric(
                    label: '右侧',
                    value: '$rightVolumeMl mL',
                    meta: '$rightLevel档 · 吸乳',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: _PumpForcePanel(
                    label: '奶流强度曲线',
                    sideLabel: 'Left',
                    value: isRunning ? '稳定' : '待开始',
                    active: isRunning,
                    tone: const Color(0xffd87542),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PumpForcePanel(
                    label: '奶流强度曲线',
                    sideLabel: 'Right',
                    value: isRunning ? '柔和' : '待开始',
                    active: isRunning,
                    tone: const Color(0xffc86d92),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpSideMetric extends StatelessWidget {
  const _PumpSideMetric({
    required this.label,
    required this.value,
    required this.meta,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final String meta;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final alignment = alignRight ? TextAlign.right : TextAlign.left;
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: alignment,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: alignment,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: MomCozyColors.foreground,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            meta,
            textAlign: alignment,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpBottleGauge extends StatelessWidget {
  const _PumpBottleGauge({
    required this.fill,
    required this.totalVolumeMl,
    required this.active,
  });

  final double fill;
  final int totalVolumeMl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 82,
          height: 150,
          child: CustomPaint(
            painter: _PumpBottlePainter(fill: fill, active: active),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$totalVolumeMl',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'mL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PumpBottlePainter extends CustomPainter {
  const _PumpBottlePainter({required this.fill, required this.active});

  final double fill;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 215;
    canvas.save();
    canvas.scale(sx, sy);

    final shadowPaint = Paint()
      ..color = MomCozyColors.primary.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 56, 56, 146),
        const Radius.circular(24),
      ),
      shadowPaint,
    );

    final capPaint = Paint()..color = MomCozyColors.card;
    final borderPaint = Paint()
      ..color = MomCozyColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(50, 18, 20, 18),
          const Radius.circular(7),
        ),
        capPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(45, 32, 30, 14),
          const Radius.circular(5),
        ),
        Paint()..color = MomCozyColors.secondary,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(47, 44, 26, 18),
          const Radius.circular(6),
        ),
        capPaint,
      );

    final bottlePath = Path()
      ..moveTo(34, 78)
      ..cubicTo(34, 66, 43, 58, 50, 58)
      ..lineTo(70, 58)
      ..cubicTo(77, 58, 86, 66, 86, 78)
      ..lineTo(86, 182)
      ..cubicTo(86, 192, 78, 200, 68, 200)
      ..lineTo(52, 200)
      ..cubicTo(42, 200, 34, 192, 34, 182)
      ..close();

    final bodyRect = const Rect.fromLTWH(34, 58, 52, 142);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x26a86172), Color(0x12ffffff), Color(0x33a86172)],
      ).createShader(bodyRect);
    canvas.drawPath(bottlePath, bodyPaint);
    canvas.drawPath(bottlePath, borderPaint);

    final fillHeight = (134 * fill.clamp(0, 1)).toDouble();
    final fillY = 192 - fillHeight;
    canvas.save();
    canvas.clipPath(bottlePath);
    canvas.drawRect(
      Rect.fromLTWH(34, fillY, 52, 160),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xfffff4d8), Color(0xffead6a5)],
        ).createShader(Rect.fromLTWH(34, fillY, 52, 160)),
    );
    if (fill > 0.02) {
      final wavePaint = Paint()
        ..color = const Color(0xfffff8df).withValues(alpha: 0.72);
      final wave = Path()
        ..moveTo(34, fillY + 2)
        ..quadraticBezierTo(47, fillY - 4, 60, fillY + 2)
        ..quadraticBezierTo(73, fillY + 8, 86, fillY + 2)
        ..lineTo(86, 204)
        ..lineTo(34, 204)
        ..close();
      canvas.drawPath(wave, wavePaint);
    }
    canvas.restore();

    final shinePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0x33ffffff), Colors.transparent],
      ).createShader(bodyRect);
    canvas.drawPath(bottlePath, shinePaint);

    final markPaint = Paint()
      ..color = MomCozyColors.mutedForeground.withValues(alpha: 0.36)
      ..strokeWidth = 0.8;
    for (final mark in [20, 40, 60, 80, 100, 120, 140, 160]) {
      final y = 192 - (mark / 180) * 134;
      if (y < 66) continue;
      final major = mark % 40 == 0;
      canvas.drawLine(
        Offset(major ? 72 : 76, y),
        Offset(83, y),
        markPaint..strokeWidth = major ? 0.9 : 0.45,
      );
    }

    final portPaint = Paint()..color = MomCozyColors.card;
    canvas
      ..drawCircle(const Offset(34, 112), 4, portPaint)
      ..drawCircle(const Offset(86, 112), 4, portPaint)
      ..drawCircle(const Offset(34, 112), 4, borderPaint)
      ..drawCircle(const Offset(86, 112), 4, borderPaint);

    if (active) {
      final glowPaint = Paint()
        ..color = const Color(0xfffff1bd).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawOval(const Rect.fromLTWH(18, 50, 84, 140), glowPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PumpBottlePainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.active != active;
  }
}

class _PumpCupVisual extends StatelessWidget {
  const _PumpCupVisual({
    required this.sideLabel,
    required this.volumeMl,
    required this.isRunning,
    required this.tone,
  });

  final String sideLabel;
  final int volumeMl;
  final bool isRunning;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final fill = (volumeMl / 36).clamp(0.08, 1).toDouble();
    return SizedBox(
      width: 36,
      height: 98,
      child: CustomPaint(
        painter: _PumpCupPainter(
          fill: fill,
          tone: tone,
          active: isRunning,
          leftSide: sideLabel == 'L',
        ),
      ),
    );
  }
}

class _PumpCupPainter extends CustomPainter {
  const _PumpCupPainter({
    required this.fill,
    required this.tone,
    required this.active,
    required this.leftSide,
  });

  final double fill;
  final Color tone;
  final bool active;
  final bool leftSide;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.06)
      ..cubicTo(
        size.width * (leftSide ? 0.1 : 0.9),
        size.height * 0.3,
        size.width * 0.06,
        size.height * 0.62,
        size.width * 0.5,
        size.height * 0.94,
      )
      ..cubicTo(
        size.width * 0.94,
        size.height * 0.62,
        size.width * (leftSide ? 0.9 : 0.1),
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.06,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tone.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.88),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = tone.withValues(alpha: 0.34),
    );

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * (1 - fill), size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xfffff2cf).withValues(alpha: active ? 0.94 : 0.52),
            tone.withValues(alpha: active ? 0.26 : 0.12),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    final tubePaint = Paint()
      ..color = MomCozyColors.border.withValues(alpha: 0.66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final start = Offset(leftSide ? size.width : 0, size.height * 0.5);
    final end = Offset(leftSide ? size.width + 22 : -22, size.height * 0.38);
    canvas.drawLine(start, end, tubePaint);
  }

  @override
  bool shouldRepaint(covariant _PumpCupPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.tone != tone ||
        oldDelegate.active != active ||
        oldDelegate.leftSide != leftSide;
  }
}

class _PumpForcePanel extends StatelessWidget {
  const _PumpForcePanel({
    required this.label,
    required this.sideLabel,
    required this.value,
    required this.active,
    required this.tone,
  });

  final String label;
  final String sideLabel;
  final String value;
  final bool active;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MomCozyColors.raised.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.46)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      sideLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 36,
            child: CustomPaint(
              painter: _PumpForcePainter(active: active, tone: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpForcePainter extends CustomPainter {
  const _PumpForcePainter({required this.active, required this.tone});

  final bool active;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = MomCozyColors.border.withValues(alpha: 0.52)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.76),
      Offset(size.width, size.height * 0.76),
      baseline,
    );

    final path = Path()..moveTo(0, size.height * 0.66);
    final points = active
        ? const [0.62, 0.3, 0.5, 0.22, 0.42, 0.18]
        : const [0.62, 0.58, 0.64, 0.56, 0.62, 0.6];
    for (var i = 0; i < points.length; i += 1) {
      final x = size.width * ((i + 1) / points.length);
      final y = size.height * points[i];
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tone.withValues(alpha: active ? 0.94 : 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PumpForcePainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.tone != tone;
  }
}

class _PumpControlConsole extends StatelessWidget {
  const _PumpControlConsole({
    required this.leftLevel,
    required this.rightLevel,
    required this.isRunning,
    required this.isPaused,
    required this.onLeftLevelChanged,
    required this.onRightLevelChanged,
    required this.onStart,
    required this.onPause,
    required this.onEnd,
  });

  final double leftLevel;
  final double rightLevel;
  final bool isRunning;
  final bool isPaused;
  final ValueChanged<double> onLeftLevelChanged;
  final ValueChanged<double> onRightLevelChanged;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final primaryAction = isRunning ? onPause : onStart;
    final primaryLabel = isRunning ? '暂停' : (isPaused ? '恢复' : '开始');
    final primaryIcon = isRunning
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;

    return DecoratedBox(
      key: const ValueKey('pump-control-console'),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.9),
        borderColor: MomCozyColors.border.withValues(alpha: 0.5),
        radius: 24,
        shadows: MomCozyShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设备控制',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            _LegacySegmentedTabs(
              selected: 'ai',
              expand: true,
              accent: MomCozyColors.primary,
              items: const [
                _LegacySegmentedTabItem(
                  value: 'ai',
                  label: '自动托管',
                  icon: Icons.auto_awesome_rounded,
                ),
                _LegacySegmentedTabItem(
                  value: 'manual',
                  label: '手动调整',
                  icon: Icons.tune_rounded,
                ),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 7),
            _LegacySegmentedTabs(
              selected: isRunning ? 'deep' : 'stimulate',
              expand: true,
              accent: isRunning ? MomCozyColors.warm : MomCozyColors.primary,
              items: const [
                _LegacySegmentedTabItem(value: 'stimulate', label: '刺激模式'),
                _LegacySegmentedTabItem(value: 'deep', label: '吸乳模式'),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _PumpMiniGearPanel(
                    label: '左侧档位',
                    value: leftLevel,
                    accent: MomCozyColors.primary,
                    onChanged: onLeftLevelChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PumpMiniGearPanel(
                    label: '右侧档位',
                    value: rightLevel,
                    accent: const Color(0xffc86d92),
                    onChanged: onRightLevelChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: primaryAction,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MomCozyColors.card.withValues(
                        alpha: 0.7,
                      ),
                      foregroundColor: MomCozyColors.foreground,
                      disabledBackgroundColor: MomCozyColors.muted.withValues(
                        alpha: 0.5,
                      ),
                      disabledForegroundColor: MomCozyColors.mutedForeground,
                      side: BorderSide(
                        color: MomCozyColors.border.withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    icon: Icon(primaryIcon, size: 14),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEnd,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffb91c1c),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: MomCozyColors.muted,
                      disabledForegroundColor: MomCozyColors.mutedForeground,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 12),
                    label: const Text('结束'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpMiniGearPanel extends StatelessWidget {
  const _PumpMiniGearPanel({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const minLevel = 1;
    const maxLevel = 9;
    final current = value.round().clamp(minLevel, maxLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PumpRoundStepButton(
                tooltip: '降低$label',
                icon: Icons.remove_rounded,
                enabled: current > minLevel,
                onTap: () => onChanged((current - 1).toDouble()),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$current',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _PumpRoundStepButton(
                tooltip: '提高$label',
                icon: Icons.add_rounded,
                enabled: current < maxLevel,
                onTap: () => onChanged((current + 1).toDouble()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PumpRoundStepButton extends StatelessWidget {
  const _PumpRoundStepButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        style: IconButton.styleFrom(
          fixedSize: const Size(30, 30),
          minimumSize: const Size(30, 30),
          padding: EdgeInsets.zero,
          backgroundColor: MomCozyColors.muted.withValues(alpha: 0.82),
          disabledBackgroundColor: MomCozyColors.muted.withValues(alpha: 0.46),
        ),
        icon: Icon(icon, size: 17),
      ),
    );
  }
}

class _PumpStatusStrip extends StatelessWidget {
  const _PumpStatusStrip({
    required this.label,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.trailing,
  });

  final String label;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.card.withValues(alpha: 0.84),
          shadows: MomCozyShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconBubble(icon: icon, accent: accent, size: 38, iconSize: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _CalibrationPage extends StatefulWidget {
  const _CalibrationPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<_CalibrationPage> {
  double _leftComfort = 4;
  double _rightComfort = 4;
  BlePlatform? _blePlatform;
  List<BleDeviceSnapshot> _connectedDevices = const [];
  String? _deviceStatusError;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _introAcknowledged = false;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ble = MomCozyRuntimeScope.of(context).blePlatform;
    if (!identical(ble, _blePlatform)) {
      _blePlatform = ble;
      unawaited(_refreshCalibrationDevices());
    }
  }

  Future<void> _refreshCalibrationDevices() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      final devices = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = devices;
        _deviceStatusError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceStatusError = '设备状态同步失败，请稍后重试。';
      });
    }
  }

  void _setLeftComfort(double value) {
    setState(() {
      _leftComfort = value;
      _hasUnsavedChanges = true;
      _saveError = null;
    });
  }

  void _setRightComfort(double value) {
    setState(() {
      _rightComfort = value;
      _hasUnsavedChanges = true;
      _saveError = null;
    });
  }

  void _resetCalibrationChanges() {
    setState(() {
      _leftComfort = 4;
      _rightComfort = 4;
      _hasUnsavedChanges = false;
      _saveError = '已恢复默认校准档位，可安全退出。';
    });
  }

  Future<void> _saveAndEnterPump() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      await runtime.ensurePumpProtocolReady();
      await runtime.pumpProtocolPlatform.adjustGearForSide(
        PumpSide.left,
        _leftComfort.round(),
      );
      await runtime.pumpProtocolPlatform.adjustGearForSide(
        PumpSide.right,
        _rightComfort.round(),
      );
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = false;
      });
      context.go('/pump');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = _calibrationSaveErrorText(error);
      });
    }
  }

  void _exitCalibration() {
    if (_hasUnsavedChanges) {
      setState(() {
        _saveError = '有未保存校准更改，请先保存或恢复默认后再退出。';
      });
      return;
    }
    context.go('/device');
  }

  @override
  Widget build(BuildContext context) {
    final leftDevice = _deviceForSide('L') ?? _deviceForSide('left');
    final rightDevice = _deviceForSide('R') ?? _deviceForSide('right');

    final progress = _introAcknowledged || _hasUnsavedChanges ? 4 : 1;

    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: EdgeInsets.zero,
      children: [
        RepaintBoundary(
          key: const ValueKey('calibration-top-bar'),
          child: Transform.translate(
            offset: const Offset(-7, 2),
            child: _CalibrationTopBar(
              progress: progress,
              total: 7,
              onBack: _exitCalibration,
            ),
          ),
        ),
        if (!_introAcknowledged)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height - 104,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, 1),
                  child: RepaintBoundary(
                    key: const ValueKey('calibration-intro-step-card'),
                    child: _CalibrationWideCardShell(
                      child: SizedBox(
                        height: 190,
                        child: _CalibrationStepCard(
                          eyebrow: '动作确认 1',
                          title: '请先正确穿戴吸奶器',
                          description:
                              '确认法兰/硅胶塞贴合，左右主机放置稳定。穿戴完成后再进入吸力调节，能减少空吸带来的不适。',
                          primaryLabel: '我已穿戴好',
                          onPrimary: () =>
                              setState(() => _introAcknowledged = true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: _CalibrationWideCardShell(
              child: _CalibrationStepCard(
                eyebrow: '左右侧 · 舒适档位',
                title: '调节到舒适最大档',
                description: '未感不适时持续加档，感受到略微不适时减 1-2 档，恢复到舒适档位。',
                children: [
                  if (_deviceStatusError != null)
                    _ActionTile(
                      icon: Icons.bluetooth_disabled_rounded,
                      title: '设备状态同步失败',
                      subtitle: _deviceStatusError!,
                      accent: Colors.red,
                      trailing: IconButton(
                        tooltip: '重试设备状态',
                        onPressed: _refreshCalibrationDevices,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    )
                  else ...[
                    _CalibrationDeviceTile(
                      label: '左侧',
                      device: leftDevice,
                      accent: widget.accent,
                    ),
                    _CalibrationDeviceTile(
                      label: '右侧',
                      device: rightDevice,
                      accent: const Color(0xff43827b),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _CalibrationSideTile(
                    label: '左侧',
                    value: _leftComfort,
                    accent: widget.accent,
                    onChanged: _setLeftComfort,
                  ),
                  _CalibrationSideTile(
                    label: '右侧',
                    value: _rightComfort,
                    accent: const Color(0xff43827b),
                    onChanged: _setRightComfort,
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 8),
                    _CalibrationFeedbackBanner(
                      text: _saveError!,
                      isError: !_saveError!.startsWith('已恢复'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveAndEnterPump,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(_isSaving ? '保存中' : '保存并进入泵奶'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _exitCalibration,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('退出校准'),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : _resetCalibrationChanges,
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('恢复默认'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  BleDeviceSnapshot? _deviceForSide(String side) {
    final normalized = side.toLowerCase();
    for (final device in _connectedDevices) {
      if (device.side.toLowerCase() == normalized) return device;
    }
    return null;
  }

  String _calibrationSaveErrorText(Object error) {
    final text = '$error';
    if (text.contains('No BLE device') ||
        text.contains('No pump protocol state')) {
      return '未检测到左右设备连接，请先在设备页连接后再保存。';
    }
    if (text.contains('BLE permission')) {
      return '蓝牙权限未开启，请授权后重试。';
    }
    return '校准保存失败，请稍后重试。';
  }
}

class _CalibrationTopBar extends StatelessWidget {
  const _CalibrationTopBar({
    required this.progress,
    required this.total,
    required this.onBack,
  });

  final int progress;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ratio = (progress / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: MomCozyColors.background,
        border: Border(
          bottom: BorderSide(
            color: MomCozyColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '舒适负压调节',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '每一步确认一个动作，找到你的舒适档位',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress/$total',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Transform.translate(
            offset: const Offset(7, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: ratio,
                backgroundColor: MomCozyColors.muted,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MomCozyColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationWideCardShell extends StatelessWidget {
  const _CalibrationWideCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 396.0;
        final shellWidth = math.min(396.0, math.max(0.0, availableWidth));

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: shellWidth, child: child),
        );
      },
    );
  }
}

class _CalibrationStepCard extends StatelessWidget {
  const _CalibrationStepCard({
    required this.eyebrow,
    required this.title,
    this.description,
    this.primaryLabel,
    this.onPrimary,
    this.children = const [],
  });

  final String eyebrow;
  final String title;
  final String? description;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card,
        radius: 22,
        shadows: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MomCozyColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: MomCozyColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontSize: 13,
                height: 1.62,
              ),
            ),
          ],
          if (children.isNotEmpty) ...[const SizedBox(height: 14), ...children],
          if (primaryLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onPrimary,
                child: Text(primaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalibrationFeedbackBanner extends StatelessWidget {
  const _CalibrationFeedbackBanner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : const Color(0xff43827b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w800,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationDeviceTile extends StatelessWidget {
  const _CalibrationDeviceTile({
    required this.label,
    required this.device,
    required this.accent,
  });

  final String label;
  final BleDeviceSnapshot? device;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final connected = device != null;
    return _ActionTile(
      icon: connected
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      title: '$label设备${connected ? '已连接' : '未连接'}',
      subtitle: connected
          ? '${device!.deviceName} · 电量 ${_deviceBatteryLabel(device)}'
          : '未检测到连接设备，保存时会提示重试。',
      accent: connected ? accent : const Color(0xff7f6a75),
      trailing: Icon(
        connected ? Icons.check_circle_outline_rounded : Icons.info_outline,
      ),
    );
  }
}

class _CalibrationSideTile extends StatelessWidget {
  const _CalibrationSideTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.tune_rounded,
      title: '$label 舒适档位 ${value.round()}',
      subtitle: '低档位用于找舒适点，高档位需二次确认。',
      accent: accent,
      trailing: _GearStepper(
        label: label,
        value: value,
        accent: accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _CommunityPage extends StatefulWidget {
  const _CommunityPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<_CommunityPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(24, 57, 24, 28),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 660),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MomCozyColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: MomCozyShadows.soft,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      MomCozyAssets.agentAvatar,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '社区功能还在建设中哦～',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '我们将打造一个妈妈们一起交流分享的社区，敬请期待～',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceManagePage extends StatefulWidget {
  const _DeviceManagePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_DeviceManagePage> createState() => _DeviceManagePageState();
}

class _DeviceManagePageState extends State<_DeviceManagePage> {
  String? _loadingActionKey;
  String? _syncStatus;

  Future<void> _triggerReminderAction(_DeviceReminderActionSpec action) async {
    if (_loadingActionKey != null) return;
    setState(() {
      _loadingActionKey = action.key;
      _syncStatus = null;
    });

    final sent = await _postFeatureClientEvent(
      context,
      eventType: 'device_reminder_action_triggered',
      label: action.label,
      metadata: {'source': 'device-manage', 'action_key': action.key},
    );
    if (!mounted) return;
    setState(() {
      _loadingActionKey = null;
      _syncStatus = sent
          ? '${action.label}已发送到设备提醒通道。'
          : '${action.label}已记录，等待提醒服务同步。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 28),
      children: [
        _DeviceSubpageHeader(
          title: '设备提醒',
          onBack: () => context.go('/device'),
        ),
        const SizedBox(height: 10),
        for (final action in _deviceReminderActions) ...[
          Transform.translate(
            offset: const Offset(-2, 1),
            child: _DeviceReminderActionButton(
              label: action.label,
              loading: _loadingActionKey == action.key,
              onTap: _loadingActionKey == null
                  ? () => _triggerReminderAction(action)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_syncStatus != null) ...[
          const SizedBox(height: 2),
          _DeviceReminderStatusPanel(status: _syncStatus!),
        ],
      ],
    );
  }
}

class _DeviceReminderActionSpec {
  const _DeviceReminderActionSpec({required this.key, required this.label});

  final String key;
  final String label;
}

const _deviceReminderActions = [
  _DeviceReminderActionSpec(key: 'task_reminder', label: '任务提醒'),
  _DeviceReminderActionSpec(key: 'milk_analysis', label: '奶量分析'),
];

class _DeviceSubpageHeader extends StatelessWidget {
  const _DeviceSubpageHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: MomCozyColors.card,
          shape: CircleBorder(
            side: BorderSide(
              color: MomCozyColors.border.withValues(alpha: 0.6),
            ),
          ),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceReminderActionButton extends StatelessWidget {
  const _DeviceReminderActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomCozyColors.card,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: MomCozyColors.border.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loading ? '处理中...' : label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceReminderStatusPanel extends StatelessWidget {
  const _DeviceReminderStatusPanel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff5ede5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffdccfc4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xffb2773b),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceUserPage extends StatefulWidget {
  const _DeviceUserPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_DeviceUserPage> createState() => _DeviceUserPageState();
}

class _DeviceUserPageState extends State<_DeviceUserPage> {
  final TextEditingController _userIdController = TextEditingController();
  bool _initializedUser = false;
  bool _saving = false;
  bool _userListOpen = false;
  String _momStage = 'postpartum';
  String? _status;
  bool _statusIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedUser) return;
    final runtimeUserId = MomCozyRuntimeScope.of(context).userId;
    _userIdController.text = runtimeUserId == 'demo-user-golden'
        ? 'demo-user-b158a211-1294-448e-82ec-000000000000'
        : runtimeUserId;
    _initializedUser = true;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _switchUser() async {
    final trimmedUserId = _userIdController.text.trim();
    if (trimmedUserId.isEmpty) {
      setState(() {
        _status = '保存失败：请输入用户名';
        _statusIsError = true;
      });
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _userListOpen = false;
      _statusIsError = false;
      _status = trimmedUserId == MomCozyRuntimeScope.of(context).userId
          ? '用户已切换'
          : '用户已新建并切换';
    });
  }

  Future<void> _deleteUser() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _userListOpen = false;
      _userIdController.clear();
      _momStage = 'postpartum';
      _statusIsError = false;
      _status = '用户和本地数据已删除';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
      children: [
        Transform.translate(
          offset: const Offset(4, -1),
          child: _DeviceSubpageHeader(
            title: '用户参数配置',
            subtitle: '当前来源：环境变量默认值',
            onBack: () => context.go('/device'),
          ),
        ),
        const SizedBox(height: 18),
        Transform.translate(
          offset: const Offset(0, 7),
          child: RepaintBoundary(
            key: const ValueKey('device-user-form-card'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: MomCozyDecorations.card(
                color: MomCozyColors.card,
                radius: 20,
                shadows: MomCozyShadows.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用户名',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: Stack(
                      children: [
                        TextField(
                          controller: _userIdController,
                          enabled: !_saving,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            hintText: '选择或输入用户 ID',
                            constraints: BoxConstraints.tightFor(height: 46),
                            contentPadding: EdgeInsets.fromLTRB(12, 0, 44, 0),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton(
                            key: const ValueKey('device-user-list-button'),
                            tooltip: '展开用户列表',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 38,
                              height: 38,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: _saving
                                ? null
                                : () => setState(
                                    () => _userListOpen = !_userListOpen,
                                  ),
                            icon: Icon(
                              _userListOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                            ),
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_userListOpen) ...[
                    const SizedBox(height: 6),
                    Container(
                      key: const ValueKey('device-user-list-panel'),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MomCozyColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MomCozyColors.border),
                        boxShadow: MomCozyShadows.soft,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _userListOpen = false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _userIdController.text.isEmpty
                                      ? '暂无已保存用户'
                                      : _userIdController.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: MomCozyColors.foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: MomCozyColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '用户类型',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('device-user-stage-$_momStage'),
                    initialValue: _momStage,
                    decoration: const InputDecoration(
                      constraints: BoxConstraints.tightFor(height: 46),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      key: ValueKey('device-user-stage-menu-icon'),
                      size: 16,
                      color: MomCozyColors.mutedForeground,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'prenatal', child: Text('孕期')),
                      DropdownMenuItem(value: 'postpartum', child: Text('产后')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _momStage = value ?? 'postpartum'),
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _deleteUser,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MomCozyColors.foreground,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('删除用户'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _switchUser,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.manage_accounts_rounded,
                                size: 16,
                              ),
                        label: const Text('切换用户'),
                      ),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _status!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _statusIsError
                            ? const Color(0xffa94747)
                            : const Color(0xff43827b),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _W1Page extends StatefulWidget {
  const _W1Page({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_W1Page> createState() => _W1PageState();
}

class _W1PageState extends State<_W1Page> {
  bool _openingTutorial = false;

  Future<void> _openTutorial() async {
    if (_openingTutorial) return;
    setState(() => _openingTutorial = true);
    await _postFeatureClientEvent(
      context,
      eventType: 'w1_tutorial_opened',
      label: '打开 W1 使用教程',
      metadata: const {'source': 'w1', 'target': 'media-viewer'},
    );
    if (!mounted) return;
    context.go('/media-viewer');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: EdgeInsets.zero,
      children: [
        RepaintBoundary(
          key: const ValueKey('w1-promo-hero'),
          child: _W1PromoHero(onBack: () => context.go('/device')),
        ),
        Transform.translate(
          offset: const Offset(-2, -2),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: RepaintBoundary(
              key: ValueKey('w1-product-summary-card'),
              child: _W1ProductSummary(),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  key: const ValueKey('w1-core-highlights-label'),
                  child: Transform.translate(
                    offset: const Offset(0, -5),
                    child: const _W1SectionLabel('核心亮点'),
                  ),
                ),
                const SizedBox(height: 10),
                Transform.translate(
                  offset: const Offset(-1, -2),
                  child: const RepaintBoundary(
                    key: ValueKey('w1-selling-point-mom-care'),
                    child: _W1SellingPoint(
                      icon: Icons.favorite_border_rounded,
                      title: '妈妈身心关怀模式',
                      subtitle: '内置心率感应与呼吸引导，吸乳时自动播放舒缓白噪音，帮助妈妈放松身心',
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(2, 4),
                  child: const RepaintBoundary(
                    key: ValueKey('w1-selling-point-skin-fit'),
                    child: _W1SellingPoint(
                      icon: Icons.eco_outlined,
                      title: '亲肤零压穿戴',
                      subtitle: '医疗级液态硅胶+记忆棉衬垫，仅 180g 极轻机身，穿戴几乎无感',
                    ),
                  ),
                ),
                const _W1SellingPoint(
                  icon: Icons.bolt_rounded,
                  title: '智能节律吸力',
                  subtitle: 'M.ai 实时分析泌乳节奏，自动切换刺激/深度模式，高效又温柔',
                ),
                const _W1SellingPoint(
                  icon: Icons.shield_outlined,
                  title: '全密封防回流',
                  subtitle: '专利三重密封结构，360° 任意体位使用，躺喂、侧躺均不漏奶',
                ),
                const _W1SellingPoint(
                  icon: Icons.volume_down_outlined,
                  title: '静音科技 ≤35dB',
                  subtitle: '无刷电机+降噪腔体设计，办公室、夜间使用不打扰宝宝和同事',
                ),
                const _W1SellingPoint(
                  icon: Icons.wifi_rounded,
                  title: 'M.ai 智能互联',
                  subtitle: '蓝牙 5.3 自动记录每次吸乳数据，AI 分析趋势并提供个性化建议',
                ),
                const SizedBox(height: 6),
                const _W1SectionLabel('教程'),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: '使用教程',
                  subtitle: '打开视频、PDF 和图文教程。',
                  accent: const Color(0xff6b6da8),
                  onTap: _openTutorial,
                  trailing: _openingTutorial
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _W1PromoHero extends StatelessWidget {
  const _W1PromoHero({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 352,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff4a2635), Color(0xff743448), Color(0xff4d2938)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 16,
                child: _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  foreground: MomCozyColors.background.withValues(alpha: 0.84),
                  background: MomCozyColors.background.withValues(alpha: 0.1),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 62, 24, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MOMCOZY · NEW',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.background.withValues(
                            alpha: 0.5,
                          ),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'W1',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: MomCozyColors.background,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wellness & Well-being',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MomCozyColors.background.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '为妈妈的身心健康而生',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.background.withValues(
                            alpha: 0.5,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: Container(
                          width: 144,
                          height: 144,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MomCozyColors.background.withValues(
                                alpha: 0.12,
                              ),
                              width: 2,
                            ),
                            color: MomCozyColors.background.withValues(
                              alpha: 0.06,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _W1SparklesIcon(
                                size: 40,
                                color: MomCozyColors.background.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'W1',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: MomCozyColors.background
                                          .withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _W1SparklesIcon extends StatelessWidget {
  const _W1SparklesIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _W1SparklesPainter(color),
    );
  }
}

class _W1SparklesPainter extends CustomPainter {
  const _W1SparklesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final sparkle = Path()
      ..moveTo(p(9.94, 15.5).dx, p(9.94, 15.5).dy)
      ..quadraticBezierTo(
        p(9.55, 14.55).dx,
        p(9.55, 14.55).dy,
        p(8.5, 14.06).dx,
        p(8.5, 14.06).dy,
      )
      ..lineTo(p(2.36, 12.48).dx, p(2.36, 12.48).dy)
      ..quadraticBezierTo(
        p(1.86, 12.0).dx,
        p(1.86, 12.0).dy,
        p(2.36, 11.52).dx,
        p(2.36, 11.52).dy,
      )
      ..lineTo(p(8.5, 9.94).dx, p(8.5, 9.94).dy)
      ..quadraticBezierTo(
        p(9.55, 9.45).dx,
        p(9.55, 9.45).dy,
        p(9.94, 8.5).dx,
        p(9.94, 8.5).dy,
      )
      ..lineTo(p(11.52, 2.36).dx, p(11.52, 2.36).dy)
      ..quadraticBezierTo(
        p(12.0, 1.86).dx,
        p(12.0, 1.86).dy,
        p(12.48, 2.36).dx,
        p(12.48, 2.36).dy,
      )
      ..lineTo(p(14.06, 8.5).dx, p(14.06, 8.5).dy)
      ..quadraticBezierTo(
        p(14.45, 9.45).dx,
        p(14.45, 9.45).dy,
        p(15.5, 9.94).dx,
        p(15.5, 9.94).dy,
      )
      ..lineTo(p(21.64, 11.52).dx, p(21.64, 11.52).dy)
      ..quadraticBezierTo(
        p(22.14, 12.0).dx,
        p(22.14, 12.0).dy,
        p(21.64, 12.48).dx,
        p(21.64, 12.48).dy,
      )
      ..lineTo(p(15.5, 14.06).dx, p(15.5, 14.06).dy)
      ..quadraticBezierTo(
        p(14.45, 14.55).dx,
        p(14.45, 14.55).dy,
        p(14.06, 15.5).dx,
        p(14.06, 15.5).dy,
      )
      ..lineTo(p(12.48, 21.64).dx, p(12.48, 21.64).dy)
      ..quadraticBezierTo(
        p(12.0, 22.14).dx,
        p(12.0, 22.14).dy,
        p(11.52, 21.64).dx,
        p(11.52, 21.64).dy,
      )
      ..close();
    canvas.drawPath(sparkle, paint);

    canvas
      ..drawLine(p(20, 3), p(20, 7), paint)
      ..drawLine(p(22, 5), p(18, 5), paint)
      ..drawLine(p(4, 17), p(4, 19), paint)
      ..drawLine(p(5, 18), p(3, 18), paint);
  }

  @override
  bool shouldRepaint(covariant _W1SparklesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.foreground,
    required this.background,
    this.size = 32,
    this.iconSize = 18,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;
  final double size;
  final double iconSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: background,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: Icon(icon, size: iconSize, color: foreground),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _W1SectionLabel extends StatelessWidget {
  const _W1SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: MomCozyColors.mutedForeground,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _W1ProductSummary extends StatelessWidget {
  const _W1ProductSummary();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Transform.translate(
              offset: const Offset(0, 3),
              child: Row(
                children: [
                  const _IconBubble(
                    icon: Icons.favorite_border_rounded,
                    accent: MomCozyColors.primary,
                    size: 34,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Momcozy W1 穿戴式吸奶器',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '新一代身心关怀智能吸乳体验',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Transform.translate(
              offset: const Offset(4, -2),
              child: const Row(
                children: [
                  Expanded(
                    child: _W1SpecTile(label: '重量', value: '180g'),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _W1SpecTile(label: '噪音', value: '≤35dB'),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _W1SpecTile(label: '续航', value: '4h+'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _W1SpecTile extends StatelessWidget {
  const _W1SpecTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _W1SellingPoint extends StatelessWidget {
  const _W1SellingPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBubble(
                    icon: icon,
                    accent: MomCozyColors.primary,
                    size: 40,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
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

Future<bool> _postFeatureClientEvent(
  BuildContext context, {
  required String eventType,
  required String label,
  required Map<String, Object?> metadata,
}) async {
  try {
    final runtime = MomCozyRuntimeScope.of(context);
    final result = await runtime.clientEventClient.post(
      AgentStreamClientEventRequest(
        eventType: eventType,
        label: label,
        occurredAt: runtime.now().toIso8601String(),
        locale: runtime.locale,
        metadata: metadata,
      ),
    );
    return result.sent;
  } catch (_) {
    return false;
  }
}

String? _requestedCartId(Object? routeExtra) {
  return routeExtra is HospitalBagCartRouteState ? routeExtra.cartId : null;
}

class _HospitalBagCartPage extends StatefulWidget {
  const _HospitalBagCartPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Object? routeExtra;

  @override
  State<_HospitalBagCartPage> createState() => _HospitalBagCartPageState();
}

class _HospitalBagCartPageState extends State<_HospitalBagCartPage> {
  bool _isSyncing = false;
  String? _syncStatus;
  HospitalBagCartStore? _cartStore;
  String _cartId = HospitalBagCartStore.defaultCartId;
  int _syncGeneration = 0;

  HospitalBagCartSnapshot get _cart =>
      _cartStore?.snapshot(_cartId) ?? defaultHospitalBagCartSnapshot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextStore = MomCozyRuntimeScope.of(context).hospitalBagCartStore;
    if (identical(_cartStore, nextStore)) return;
    _cartStore?.removeListener(_handleCartChanged);
    _cartStore = nextStore;
    _cartId = nextStore.activate(_requestedCartId(widget.routeExtra));
    nextStore.addListener(_handleCartChanged);
  }

  @override
  void didUpdateWidget(covariant _HospitalBagCartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeExtra == widget.routeExtra) return;
    final store = _cartStore;
    if (store != null) {
      _cartId = store.activate(_requestedCartId(widget.routeExtra));
    }
  }

  @override
  void dispose() {
    _cartStore?.removeListener(_handleCartChanged);
    super.dispose();
  }

  void _handleCartChanged() {
    if (!mounted) return;
    final activeCartId =
        _cartStore?.activeCartId ?? HospitalBagCartStore.defaultCartId;
    setState(() {
      if (_cartId == activeCartId) return;
      _cartId = activeCartId;
      _syncGeneration += 1;
      _isSyncing = false;
      _syncStatus = null;
    });
  }

  void _resetCart() {
    _cartStore?.reset(_cartId);
    unawaited(_syncCart(_cart));
  }

  void _deleteItem(String id) {
    if (_cartStore?.removeItem(cartId: _cartId, itemId: id) != true) return;
    unawaited(_syncCart(_cart));
  }

  Future<void> _syncCart(HospitalBagCartSnapshot cart) async {
    final generation = ++_syncGeneration;
    setState(() {
      _isSyncing = true;
      _syncStatus = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final result = await runtime.hospitalBagCartRepository.syncCart(
        cart: cart,
      );
      if (!mounted || generation != _syncGeneration) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = result.message;
      });
    } catch (_) {
      if (!mounted || generation != _syncGeneration) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = '本地清单已更新，稍后重试同步。';
      });
    }
  }

  List<HospitalBagCartItem> get _visibleCartItems =>
      _cart.items.toList(growable: false);

  int get _itemCount =>
      _visibleCartItems.fold(0, (sum, item) => sum + item.qty);

  double get _subtotal => _cart.totals.subtotal;

  double get _discount => _cart.totals.discount;

  double get _total => _cart.totals.total;

  String _money(double amount) => formatHospitalBagCartMoney(amount);

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups = _cart.groups
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);

    return DecoratedBox(
      key: ValueKey('route-page-${widget.path}'),
      decoration: const BoxDecoration(color: Color(0xfffff9fb)),
      child: Stack(
        children: [
          Column(
            children: [
              _HospitalBagHeader(onBack: _handleBack, itemCount: _itemCount),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 148),
                  children: [
                    if (_isSyncing || _syncStatus != null)
                      _HospitalBagSyncStatusBanner(
                        isSyncing: _isSyncing,
                        message: _syncStatus,
                      ),
                    for (final group in visibleGroups)
                      _HospitalBagGroupSection(
                        group: group,
                        onDelete: _deleteItem,
                      ),
                    if (_itemCount == 0)
                      _HospitalBagEmptyCart(onResetCart: _resetCart),
                    _HospitalBagOrderSummary(
                      subtotal: _subtotal,
                      discount: _discount,
                      total: _total,
                      syncStatus: _syncStatus,
                      isSyncing: _isSyncing,
                      canReset: _cartStore?.canReset(_cartId) == true,
                      onResetCart: _resetCart,
                      money: _money,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Transform.translate(
              offset: const Offset(0, 1),
              child: _HospitalBagFooter(
                total: _total,
                discount: _discount,
                money: _money,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HospitalBagHeader extends StatelessWidget {
  const _HospitalBagHeader({required this.onBack, required this.itemCount});

  final VoidCallback onBack;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xf2fff9fb),
        border: Border(bottom: BorderSide(color: Color(0xfff0dde5))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 15, 12),
        child: Row(
          children: [
            _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              foreground: const Color(0xff6c4457),
              background: Colors.white,
              size: 36,
              iconSize: 16,
              borderColor: Color(0xffedd6df),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '待产包一键打包',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xff372330),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '已按待产包物品清单整理',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xff8a6d7a),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              key: const ValueKey('hospital-bag-item-count-chip'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffeef9f5),
                borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                border: Border.all(color: const Color(0xffd7ece6)),
              ),
              child: Text(
                '$itemCount 件',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xff267c68),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalBagSyncStatusBanner extends StatelessWidget {
  const _HospitalBagSyncStatusBanner({
    required this.isSyncing,
    required this.message,
  });

  final bool isSyncing;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xffeef9f5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffd7ece6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (isSyncing)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.cloud_done_outlined,
                  color: Color(0xff267c68),
                  size: 18,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSyncing ? '购物车同步中...' : message ?? '购物车已同步',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xff267c68),
                    fontWeight: FontWeight.w900,
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

class _HospitalBagGroupSection extends StatelessWidget {
  const _HospitalBagGroupSection({required this.group, required this.onDelete});

  final HospitalBagCartGroup group;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = _hospitalBagToneColors(group.tone);
    final headerOffset = group.title == '宝宝出院'
        ? const Offset(0, -3)
        : const Offset(0, -1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          RepaintBoundary(
            key: ValueKey('hospital-bag-group-header-${group.title}'),
            child: Transform.translate(
              offset: headerOffset,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xff372330),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '${group.items.length} 件',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.foreground,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (index, item) in group.items.indexed)
            _HospitalBagCartItemTile(
              item: item,
              tone: group.tone,
              bottomGap: index == group.items.length - 1 ? 0 : 8,
              onDelete: () => onDelete(item.id),
            ),
        ],
      ),
    );
  }
}

class _HospitalBagCartItemTile extends StatelessWidget {
  const _HospitalBagCartItemTile({
    required this.item,
    required this.tone,
    required this.bottomGap,
    required this.onDelete,
  });

  final HospitalBagCartItem item;
  final HospitalBagCartTone tone;
  final double bottomGap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tileOffset = item.id == 'mom-briefs'
        ? const Offset(0, -1)
        : Offset.zero;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Tooltip(
        message: '长按删除${item.name}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: onDelete,
          child: RepaintBoundary(
            key: ValueKey('hospital-bag-item-${item.id}'),
            child: Transform.translate(
              offset: tileOffset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xfff0e1e7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0f5b3748),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(1, 1),
                        child: _HospitalBagItemImage(item: item, tone: tone),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Transform.translate(
                          offset: const Offset(0, -1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: const Color(0xff372330),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xff7e6672),
                                      fontSize: 11,
                                      height: 1.375,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'x${item.qty}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xff9a7b89),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.translate(
                        offset: const Offset(-1, 1),
                        child: _HospitalBagItemActions(
                          item: item,
                          onDelete: onDelete,
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
    );
  }
}

class _HospitalBagItemActions extends StatelessWidget {
  const _HospitalBagItemActions({required this.item, required this.onDelete});

  final HospitalBagCartItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          item.formattedPrice,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xff372330),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: '删除${item.name}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                  border: Border.all(color: const Color(0xffedd6df)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 12,
                      color: Color(0xff6c4457),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '删除',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xff6c4457),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HospitalBagItemImage extends StatelessWidget {
  const _HospitalBagItemImage({required this.item, required this.tone});

  final HospitalBagCartItem item;
  final HospitalBagCartTone tone;

  @override
  Widget build(BuildContext context) {
    final remoteUrl = _hospitalBagRemoteImageUrl(item.imageUrl);
    final assetPath = _hospitalBagItemImageAssets[item.id];
    final fallback = _HospitalBagItemIcon(tone: tone);
    final image = remoteUrl != null
        ? Image.network(
            remoteUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            semanticLabel: item.imageAlt ?? item.name,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : assetPath != null
        ? Image.asset(
            assetPath,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            semanticLabel: item.imageAlt ?? item.name,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : null;
    if (image == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xfff0e1e7)),
          ),
          child: image,
        ),
      ),
    );
  }
}

String? _hospitalBagRemoteImageUrl(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasAuthority) return null;
  return uri.scheme == 'https' || uri.scheme == 'http' ? normalized : null;
}

const _hospitalBagItemImageAssets = {
  'mom-pad': 'assets/images/hospital_bag_mom_pad.jpg',
  'mom-sanitary': 'assets/images/hospital_bag_mom_sanitary.jpg',
  'mom-underwear': 'assets/images/hospital_bag_mom_underwear.png',
  'mom-wipes': 'assets/images/hospital_bag_mom_wipes.jpg',
  'mom-bottle': 'assets/images/hospital_bag_mom_bottle.jpg',
  'mom-briefs': 'assets/images/hospital_bag_mom_briefs.png',
  'baby-diaper': 'assets/images/hospital_bag_baby_diaper.jpg',
  'baby-wipes': 'assets/images/hospital_bag_baby_wipes.jpg',
  'baby-towel': 'assets/images/hospital_bag_baby_towel.jpg',
  'baby-blanket': 'assets/images/hospital_bag_baby_blanket.jpg',
  'baby-clothes': 'assets/images/hospital_bag_baby_clothes.jpg',
  'baby-bath-towel': 'assets/images/hospital_bag_baby_bath_towel.jpg',
  'milk-pad': 'assets/images/hospital_bag_milk_pad.jpg',
  'milk-cream': 'assets/images/hospital_bag_milk_cream.jpg',
  'milk-storage': 'assets/images/hospital_bag_milk_storage.jpg',
  'pump-m9': 'assets/images/hospital_bag_pump_m9.jpg',
  'milk-bra': 'assets/images/hospital_bag_milk_bra.jpg',
  'milk-bottle': 'assets/images/hospital_bag_milk_bottle.jpg',
};

class _HospitalBagItemIcon extends StatelessWidget {
  const _HospitalBagItemIcon({required this.tone});

  final HospitalBagCartTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _hospitalBagToneColors(tone);
    final icon = switch (tone) {
      HospitalBagCartTone.mint => Icons.child_care_rounded,
      HospitalBagCartTone.sky => Icons.favorite_border_rounded,
      HospitalBagCartTone.rose => Icons.inventory_2_outlined,
    };
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: colors.foreground, size: 24),
    );
  }
}

class _HospitalBagOrderSummary extends StatelessWidget {
  const _HospitalBagOrderSummary({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.syncStatus,
    required this.isSyncing,
    required this.canReset,
    required this.onResetCart,
    required this.money,
  });

  final double subtotal;
  final double discount;
  final double total;
  final String? syncStatus;
  final bool isSyncing;
  final bool canReset;
  final VoidCallback onResetCart;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffefdbe4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x145b3748),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '订单摘要',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xff372330),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _HospitalBagSummaryRow(label: '商品小计', value: money(subtotal)),
              _HospitalBagSummaryRow(
                label: '组合优惠',
                value: '-${money(discount)}',
                valueColor: const Color(0xff267c68),
              ),
              const _HospitalBagSummaryRow(label: '配送', value: '免运费'),
              const Divider(height: 24, color: Color(0xfff0e1e7)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      isSyncing
                          ? '购物车同步中...'
                          : syncStatus ?? '购物车状态会在删除或恢复后同步。',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xff8a6d7a),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    money(total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xff24889a),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (canReset) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onResetCart,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('恢复默认清单'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalBagSummaryRow extends StatelessWidget {
  const _HospitalBagSummaryRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xff6f5663),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xff6f5663),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HospitalBagEmptyCart extends StatelessWidget {
  const _HospitalBagEmptyCart({required this.onResetCart});

  final VoidCallback onResetCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffefdbe4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '购物车已经清空',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xff372330),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onResetCart,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('恢复默认清单'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalBagFooter extends StatelessWidget {
  const _HospitalBagFooter({
    required this.total,
    required this.discount,
    required this.money,
  });

  final double total;
  final double discount;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey('hospital-bag-footer'),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xf5fff9fb),
              border: Border(top: BorderSide(color: Color(0xffead8df))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1a5b3748),
                  blurRadius: 28,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '预计合计',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xff8a6d7a),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                money(total),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: const Color(0xff24889a),
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '已含组合优惠 ${money(discount)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xff8a6d7a),
                                  fontSize: 10,
                                  height: 1.375,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xff24889a),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.credit_card_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '去结算',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
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

class _HospitalBagToneColors {
  const _HospitalBagToneColors({
    required this.background,
    required this.iconBackground,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color iconBackground;
  final Color foreground;
  final Color border;
}

_HospitalBagToneColors _hospitalBagToneColors(HospitalBagCartTone tone) {
  return switch (tone) {
    HospitalBagCartTone.rose => const _HospitalBagToneColors(
      background: Color(0xfffff0f5),
      iconBackground: Color(0xfff9d9e4),
      foreground: Color(0xffb84d73),
      border: Color(0xfff5cfdb),
    ),
    HospitalBagCartTone.mint => const _HospitalBagToneColors(
      background: Color(0xffedf9f5),
      iconBackground: Color(0xffd4f0e7),
      foreground: Color(0xff267c68),
      border: Color(0xffccebe2),
    ),
    HospitalBagCartTone.sky => const _HospitalBagToneColors(
      background: Color(0xffedf6ff),
      iconBackground: Color(0xffd8ebfb),
      foreground: Color(0xff2f6fa8),
      border: Color(0xffcfe5f8),
    ),
  };
}

class _IbclcPage extends StatefulWidget {
  const _IbclcPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Uri? routeUri;
  final Object? routeExtra;

  @override
  State<_IbclcPage> createState() => _IbclcPageState();
}

class _IbclcPageState extends State<_IbclcPage> {
  bool _consultStarted = false;
  bool _isStarting = false;
  bool _isEnding = false;
  bool _chatReady = false;
  int _connectionStepIndex = 1;
  String? _syncStatus;
  final List<Timer> _connectionTimers = [];
  static const _connectionSteps = ['健康信息整理中', '连接中', '连接成功', '对方正在读取背景中'];
  late final IbclcConsultRouteState _routeState;

  @override
  void initState() {
    super.initState();
    _routeState = IbclcConsultRouteState.fromRoute(
      extra: widget.routeExtra,
      uri: widget.routeUri,
    );
    _scheduleConnectionFlow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startConsult());
    });
  }

  @override
  void dispose() {
    for (final timer in _connectionTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _scheduleConnectionFlow() {
    const durations = [
      Duration(milliseconds: 1000),
      Duration(milliseconds: 2000),
      Duration(milliseconds: 1000),
      Duration(milliseconds: 2000),
    ];
    var elapsed = Duration.zero;
    for (var index = 1; index < _connectionSteps.length; index += 1) {
      _connectionTimers.add(
        Timer(elapsed, () {
          if (mounted) setState(() => _connectionStepIndex = index);
        }),
      );
      elapsed += durations[index];
    }
    _connectionTimers.add(
      Timer(elapsed + const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _chatReady = true);
      }),
    );
  }

  Future<void> _startConsult() async {
    if (_consultStarted || _isStarting) return;
    setState(() {
      _isStarting = true;
      _syncStatus = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final result = await runtime.clientEventClient.post(
        AgentStreamClientEventRequest(
          eventType: 'ibclc_consult_started',
          runId: _routeState.runId,
          label: '用户进入 IBCLC 在线咨询队列',
          occurredAt: runtime.now().toIso8601String(),
          locale: runtime.locale,
          metadata: _routeState.eventMetadata(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _consultStarted = true;
        _isStarting = false;
        _syncStatus = result.sent ? '咨询事件已同步。' : '已进入咨询，但本次状态未同步。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consultStarted = true;
        _isStarting = false;
        _syncStatus = '已进入咨询，但本次状态未同步。';
      });
    }
  }

  void _returnToAgentHub() {
    context.go(_routeState.returnPath);
  }

  void _endConsult() {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    final runtime = MomCozyRuntimeScope.of(context);
    unawaited(runtime.ibclcConsultStore.markCompleted(_routeState));
    unawaited(
      runtime.clientEventClient.post(
        AgentStreamClientEventRequest(
          eventType: 'ibclc_consult_completed',
          runId: _routeState.runId,
          label: '用户已完成一次 IBCLC 在线咨询',
          occurredAt: runtime.now().toIso8601String(),
          locale: runtime.locale,
          metadata: _routeState.eventMetadata(),
        ),
      ),
    );
    _returnToAgentHub();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('route-page-${widget.path}'),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          _IbclcChatHeader(isEnding: _isEnding, onEndConsult: _endConsult),
          Expanded(
            child: _IbclcChatBody(
              chatReady: _chatReady,
              connectionText: _connectionSteps[_connectionStepIndex],
              syncStatus: _syncStatus,
              routeState: _routeState,
            ),
          ),
          if (_chatReady) const _IbclcChatComposer(),
        ],
      ),
    );
  }
}

class _IbclcChatHeader extends StatelessWidget {
  const _IbclcChatHeader({required this.isEnding, required this.onEndConsult});

  final bool isEnding;
  final VoidCallback onEndConsult;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffdce8e5))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 26, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'IBCLC 在线咨询',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xff172625),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton(
              key: const ValueKey('ibclc-return-status-button'),
              onPressed: isEnding ? null : onEndConsult,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffd64b4b),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xffd64b4b),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                fixedSize: const Size(78, 32),
                minimumSize: const Size(78, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: Color(0xffc84444)),
                ),
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(isEnding ? '结束中...' : '结束咨询'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IbclcChatBody extends StatelessWidget {
  const _IbclcChatBody({
    required this.chatReady,
    required this.connectionText,
    required this.syncStatus,
    required this.routeState,
  });

  final bool chatReady;
  final String connectionText;
  final String? syncStatus;
  final IbclcConsultRouteState routeState;

  @override
  Widget build(BuildContext context) {
    if (!chatReady) {
      return Center(
        child: Transform.translate(
          offset: const Offset(0, 19),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xfff7fcfa),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffd9e8e4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14224844),
                  blurRadius: 34,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SizedBox(
              width: 300,
              height: 50,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _IbclcPulseDot(),
                    const SizedBox(width: 10),
                    Text(
                      connectionText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xff177a89),
                        fontWeight: FontWeight.w900,
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

    return ListView(
      padding: EdgeInsets.fromLTRB(14, chatReady ? 14 : 0, 14, 14),
      children: [
        if (!chatReady)
          SizedBox(
            height: 560,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff7fcfa),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffd9e8e4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14224844),
                      blurRadius: 34,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 300,
                  height: 50,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _IbclcPulseDot(),
                        const SizedBox(width: 10),
                        Text(
                          connectionText,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xff177a89),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff1f7f5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    _openingMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff233c39),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (syncStatus != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xffedf6f3),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xffd5e5e1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    syncStatus!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xff28615c),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  String get _openingMessage {
    final contextParts = <String>[
      if (routeState.reason.isNotEmpty) '咨询原因：${routeState.reason}',
      if (routeState.feedingContext.isNotEmpty)
        '当前情况：${routeState.feedingContext}',
    ];
    final contextText = contextParts.isEmpty
        ? ''
        : '（${contextParts.join('；')}）';
    return '你好，我是 ${routeState.consultantName}，IBCLC。我已经看到你从 CoMate 带过来的背景了$contextText，你可以先告诉我现在最困扰你的哺乳问题。';
  }
}

class _IbclcPulseDot extends StatelessWidget {
  const _IbclcPulseDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xff177a89),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _IbclcChatComposer extends StatelessWidget {
  const _IbclcChatComposer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xfffbfefd),
        border: Border(top: BorderSide(color: Color(0xffdce8e5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
          child: Row(
            children: [
              const _IbclcComposerIconButton(
                key: ValueKey('ibclc-upload-image-button'),
                icon: Icons.add_photo_alternate_outlined,
                tooltip: '上传图片',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    key: const ValueKey('ibclc-message-input'),
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: const Color(0xff78918e),
                            fontWeight: FontWeight.w500,
                          ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xffd5e1de)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xff177a89)),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff172625),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const _IbclcComposerIconButton(
                key: ValueKey('ibclc-voice-button'),
                icon: Icons.mic_none_rounded,
                tooltip: '语音输入',
              ),
              const SizedBox(width: 6),
              FilledButton(
                key: const ValueKey('ibclc-send-button'),
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff177a89),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                child: const Text('发送'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IbclcComposerIconButton extends StatelessWidget {
  const _IbclcComposerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          tooltip: tooltip,
          onPressed: () {},
          icon: Icon(icon, size: 20),
          color: const Color(0xff28615c),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xfff2f8f6),
            side: const BorderSide(color: Color(0xffd5e1de)),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _MediaViewerPage extends StatefulWidget {
  const _MediaViewerPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Uri? routeUri;
  final Object? routeExtra;

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  void _returnFromMediaViewer() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final media = _MediaViewerRouteState.from(
      routeUri: widget.routeUri,
      routeExtra: widget.routeExtra,
    );
    final headerTitle = media?.title ?? '媒体';

    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: MomCozyColors.background,
      child: Column(
        children: [
          _MediaViewerHeader(
            title: headerTitle,
            onBack: _returnFromMediaViewer,
          ),
          Expanded(
            child: media == null
                ? const _MediaViewerMissingResource()
                : _MediaViewerContent(media: media),
          ),
        ],
      ),
    );
  }
}

class _MediaViewerHeader extends StatelessWidget {
  const _MediaViewerHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MomCozyColors.background,
        border: Border(bottom: BorderSide(color: MomCozyColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  key: const ValueKey('media-return-button'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  color: MomCozyColors.foreground,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w700,
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

class _MediaViewerMissingResource extends StatelessWidget {
  const _MediaViewerMissingResource();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '缺少资源参数，请从资料卡片进入。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaViewerContent extends StatelessWidget {
  const _MediaViewerContent({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    return switch (media.kind) {
      'image' => _ImageViewerStage(media: media),
      'video' => _VideoViewerStage(media: media),
      _ => _PdfViewerStage(media: media),
    };
  }
}

class _PdfViewerStage extends StatefulWidget {
  const _PdfViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  State<_PdfViewerStage> createState() => _PdfViewerStageState();
}

class _PdfViewerStageState extends State<_PdfViewerStage> {
  ProductAssetReference? _reference;
  ProductAssetRepository? _repository;
  Future<ProductAssetContent>? _content;
  var _documentRevision = 0;
  final _pdfController = PdfViewerController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncContent();
  }

  @override
  void didUpdateWidget(_PdfViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url ||
        oldWidget.media.kind != widget.media.kind) {
      _syncContent();
    }
  }

  void _syncContent() {
    final reference = ProductAssetReference.tryParse(
      widget.media.url,
      kind: widget.media.kind,
      title: widget.media.title,
    );
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;
    if (_reference?.assetId == reference?.assetId &&
        _reference?.kind == reference?.kind &&
        identical(_repository, repository)) {
      return;
    }
    _reference = reference;
    _repository = repository;
    _documentRevision += 1;
    _content = _load();
  }

  Future<ProductAssetContent>? _load() {
    final reference = _reference;
    final repository = _repository;
    if (reference == null || repository == null) {
      return null;
    }
    return repository.load(reference);
  }

  void _retry() {
    setState(() {
      _documentRevision += 1;
      _content = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reference = _reference;
    final content = _content;
    if (reference == null || content == null) {
      return const _MediaViewerLoadError(
        message: 'PDF 加载失败',
        darkBackground: false,
        icon: Icons.picture_as_pdf_outlined,
      );
    }
    return FutureBuilder<ProductAssetContent>(
      future: content,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MediaViewerLoadError(
            message: 'PDF 加载失败',
            darkBackground: false,
            icon: Icons.picture_as_pdf_outlined,
            onRetry: _retry,
          );
        }
        final loaded = snapshot.data;
        if (loaded == null) {
          return const ColoredBox(
            color: MomCozyColors.background,
            child: _MediaViewerLoading(label: '加载 PDF…', darkBackground: false),
          );
        }
        return KeyedSubtree(
          key: const ValueKey('media-pdf-viewer'),
          child: PdfViewer.data(
            loaded.bytes,
            key: ValueKey('media-pdf-document-$_documentRevision'),
            sourceName: reference.assetId,
            controller: _pdfController,
            params: PdfViewerParams(
              margin: 8,
              backgroundColor: MomCozyColors.background,
              minScale: 0.1,
              maxScale: 4,
              panAxis: PanAxis.free,
              pageDropShadow: const BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
              loadingBannerBuilder: (context, downloaded, total) {
                return const _MediaViewerLoading(
                  label: '正在打开 PDF…',
                  darkBackground: false,
                );
              },
              errorBannerBuilder: (context, error, stackTrace, documentRef) {
                return _MediaViewerLoadError(
                  message: 'PDF 加载失败',
                  darkBackground: false,
                  icon: Icons.picture_as_pdf_outlined,
                  onRetry: _retry,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ImageViewerStage extends StatefulWidget {
  const _ImageViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  State<_ImageViewerStage> createState() => _ImageViewerStageState();
}

class _ImageViewerStageState extends State<_ImageViewerStage> {
  static const _doubleTapScale = 2.5;

  final _transformationController = TransformationController();
  Offset? _doubleTapPosition;

  @override
  void didUpdateWidget(_ImageViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url) {
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.01) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapPosition ?? Offset.zero;
    _transformationController.value =
        Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
          ..setTranslationRaw(
            -position.dx * (_doubleTapScale - 1),
            -position.dy * (_doubleTapScale - 1),
            0,
          );
  }

  @override
  Widget build(BuildContext context) {
    final reference = ProductAssetReference.tryParse(
      widget.media.url,
      kind: widget.media.kind,
      title: widget.media.title,
    );
    if (reference == null) {
      return const _MediaViewerLoadError(message: '图片加载失败');
    }
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;

    return ColoredBox(
      color: Colors.black,
      child: ProductAssetImage(
        reference: reference,
        repository: repository,
        fit: BoxFit.contain,
        semanticLabel: widget.media.title,
        loadingBuilder: (context) {
          return const _MediaViewerLoading(label: '加载图片…');
        },
        errorBuilder: (context, error, retry) {
          return _MediaViewerLoadError(message: '图片加载失败', onRetry: retry);
        },
        loadedBuilder: (context, content, image) {
          return GestureDetector(
            key: const ValueKey('media-image-viewer'),
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) {
              _doubleTapPosition = details.localPosition;
            },
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              key: const ValueKey('media-image-interactive-viewer'),
              transformationController: _transformationController,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.expand(child: image),
            ),
          );
        },
      ),
    );
  }
}

class _MediaViewerLoading extends StatelessWidget {
  const _MediaViewerLoading({required this.label, this.darkBackground = true});

  final String label;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final foreground = darkBackground
        ? const Color(0xb3ffffff)
        : MomCozyColors.mutedForeground;
    return Center(
      key: const ValueKey('media-viewer-loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaViewerLoadError extends StatelessWidget {
  const _MediaViewerLoadError({
    required this.message,
    this.onRetry,
    this.darkBackground = true,
    this.icon = Icons.broken_image_outlined,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool darkBackground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final background = darkBackground ? Colors.black : MomCozyColors.background;
    final foreground = darkBackground
        ? const Color(0xb3ffffff)
        : MomCozyColors.mutedForeground;
    return ColoredBox(
      color: background,
      child: Center(
        key: const ValueKey('media-viewer-load-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              IconButton(
                key: const ValueKey('media-viewer-retry'),
                tooltip: '重新加载',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                color: foreground,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoViewerStage extends StatelessWidget {
  const _VideoViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    final reference = ProductAssetReference.tryParse(
      media.url,
      kind: media.kind,
      title: media.title,
    );
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;
    if (reference == null || repository == null) {
      return const _MediaViewerLoadError(
        message: '视频加载失败',
        icon: Icons.videocam_off_outlined,
      );
    }
    return ProductAssetVideoPlayer(
      reference: reference,
      repository: repository,
    );
  }
}

class _MediaViewerRouteState {
  const _MediaViewerRouteState({
    required this.kind,
    required this.url,
    required this.title,
  });

  final String kind;
  final String url;
  final String title;

  static const _supportedKinds = {'pdf', 'image', 'video'};

  static _MediaViewerRouteState? from({
    required Uri? routeUri,
    required Object? routeExtra,
  }) {
    final extra = routeExtra is Map ? routeExtra : null;
    final query = routeUri?.queryParameters ?? const <String, String>{};
    final kind = _normalizeKind(
      _stringFromMap(extra, 'kind') ?? _stringFromQuery(query, 'kind'),
    );
    final url = _nonEmpty(
      _stringFromMap(extra, 'url') ?? _stringFromQuery(query, 'url'),
    );
    if (kind == null || url == null) return null;
    final title =
        _nonEmpty(
          _stringFromMap(extra, 'title') ?? _stringFromQuery(query, 'title'),
        ) ??
        _defaultTitleForKind(kind);
    return _MediaViewerRouteState(kind: kind, url: url, title: title);
  }

  static String? _normalizeKind(String? value) {
    final normalized = _nonEmpty(value)?.toLowerCase();
    if (normalized == null || !_supportedKinds.contains(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _stringFromMap(Map<Object?, Object?>? map, String key) {
    final value = map?[key];
    return value is String ? value : null;
  }

  static String? _stringFromQuery(Map<String, String> query, String key) {
    final value = query[key];
    return value;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _defaultTitleForKind(String kind) {
    return switch (kind) {
      'image' => '图片',
      'video' => '视频',
      _ => 'PDF',
    };
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-$path'),
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 700,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, 103),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '404',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Oops! Page not found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => context.go('/'),
                    style: TextButton.styleFrom(
                      foregroundColor: MomCozyColors.primary,
                      textStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    child: const Text('Return to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
