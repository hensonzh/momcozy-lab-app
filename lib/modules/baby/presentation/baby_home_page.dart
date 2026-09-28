import 'baby_motion.dart';
import 'dart:async';
import '../../../app/primary_tab_activity.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import 'baby_artwork.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/design_system/mom_home_tokens.dart';

import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/zoned_time.dart';
import '../application/baby_home_controller.dart';
import '../application/baby_knowledge_content.dart';
import '../application/baby_knowledge_selection.dart';
import 'baby_growth_curve.dart';
import 'baby_overview_cards.dart';
import 'baby_labels.dart';
import 'baby_profile_editor.dart';
import 'baby_record_editor.dart';
import 'baby_design.dart';
import 'baby_knowledge_sheet.dart';

class BabyHomePage extends StatefulWidget {
  const BabyHomePage({
    super.key,
    required this.controller,
    required this.onAsk,
    this.onBabySelected,
    this.rememberedBabyId,
  });
  final BabyHomeController controller;
  final ValueChanged<String> onAsk;
  final Future<void> Function(String babyId)? onBabySelected;
  final String? rememberedBabyId;
  @override
  State<BabyHomePage> createState() => _BabyHomePageState();
}

class _BabyHomePageState extends State<BabyHomePage>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _tabRefresh = PrimaryTabRefresh(1);
  final _scroll = ScrollController();
  GrowthMetric _metric = GrowthMetric.weight;
  bool _switching = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => widget.controller.tick(),
    );
  }

  Future<void> _load({String? selectedBabyId}) async {
    final c = widget.controller;
    await c.load(selectedBabyId: selectedBabyId);
    if (mounted &&
        identical(c, widget.controller) &&
        c.baby != null &&
        c.baby!.id != widget.rememberedBabyId) {
      await _remember(c.baby!.id);
    }
  }

  Future<void> _remember(String id) async {
    if (widget.onBabySelected == null) return;
    try {
      await widget.onBabySelected!(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Baby switched, but we could not save your selection. Check which baby is selected next time you open the app.',
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabRefresh.shouldRefresh(context, widget.controller.now())) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant BabyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.dispose();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> _profile([BabyProfile? profile]) async {
    final c = widget.controller, zone = widget.controller.timezone;
    if (zone == null) return;
    final saved = await showBabyProfileEditor(
      context,
      repository: c.profileRepository,
      timezone: zone,
      now: c.now,
      profile: profile,
      deliveryDate: c.deliveryDate,
    );
    if (!mounted || saved == null || !identical(c, widget.controller)) return;
    await c.applySavedProfile(saved);
    if (mounted && identical(c, widget.controller)) await _remember(saved.id);
  }

  Future<void> _switch() async {
    final c = widget.controller, selected = widget.controller.baby;
    if (_switching || selected == null) return;
    final profiles = c.profiles.value!;
    final choice = await showBabySheet<String>(
      context,
      Builder(
        builder: (sheetContext) => BabySheetBody(
          title: 'Switch baby',
          style: BabySheetStyle.switcher,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              for (final profile in profiles)
                BabyPressFeedback(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, profile.id),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.all(14),
                      backgroundColor: profile.id == selected.id
                          ? BabyDesign.selected
                          : MomHomeTokens.surface,
                      foregroundColor: profile.id == selected.id
                          ? BabyDesign.selectedInk
                          : MomHomeTokens.ink,
                      side: BorderSide(
                        color: profile.id == selected.id
                            ? BabyDesign.selectedBorder
                            : MomHomeTokens.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: BabyDesign.text(
                        16,
                        line: 22,
                        weight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      '${profile.name}${profile.id == selected.id ? '  · Current' : ''}',
                    ),
                  ),
                ),
              Text(
                'Feeding, after-feeding mood, diapers, growth, and development records are saved separately for each baby.',
                style: BabyDesign.text(
                  13,
                  line: 18,
                  color: MomHomeTokens.secondary,
                ),
              ),
              BabyPressFeedback(
                child: TextButton(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 13,
                    ),
                    textStyle: BabyDesign.text(
                      13,
                      line: 18,
                      weight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext, 'edit'),
                  child: const Text('Edit this baby\'s profile'),
                ),
              ),
              BabyPressFeedback(
                child: TextButton(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 13,
                    ),
                    textStyle: BabyDesign.text(
                      13,
                      line: 18,
                      weight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext, 'add'),
                  child: const Text('Add a baby'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'edit') {
      await _profile(selected);
      return;
    }
    if (choice == 'add') {
      await _profile();
      return;
    }
    setState(() {
      _switching = true;
      _metric = GrowthMetric.weight;
    });
    await c.select(choice);
    if (mounted && identical(c, widget.controller)) await _remember(choice);
    if (mounted) setState(() => _switching = false);
  }

  Future<void> _record(
    BabyRecordKind kind, {
    DiaperKind? diaper,
    GrowthMetric? metric,
  }) async {
    final c = widget.controller,
        baby = widget.controller.baby,
        zone = widget.controller.timezone;
    if (baby == null || zone == null) return;
    final currentDaily = kind == BabyRecordKind.dailyStatus
        ? c.recentRecords.value
              ?.whereType<BabyDailyStatusRecord>()
              .where(
                (record) =>
                    record.babyId == baby.id &&
                    record.recordedOn == dateInTimezone(c.now(), zone),
              )
              .firstOrNull
        : null;
    final saved = await showBabyRecordEditor(
      context,
      repository: c.recordRepository,
      baby: baby,
      timezone: zone,
      now: c.now,
      kind: kind,
      initial: currentDaily,
      diaperKind: diaper,
      growthMetric: metric ?? _metric,
    );
    if (saved != null && mounted && identical(c, widget.controller)) {
      await c.refreshRecords(kind: kind);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: BabyDesign.theme(
      Theme.of(context),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    ),
    child: ColoredBox(
      color: MomHomeTokens.background,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final c = widget.controller, baby = widget.controller.baby;
          if (baby == null) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                children: [
                  Text(
                    'Baby',
                    style: BabyDesign.text(26, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 26),
                  if (c.profiles.loading && !c.profiles.hasValue)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (c.profiles.failure != null)
                    ProductErrorView(
                      failure: c.profiles.failure!,
                      onRetry: _load,
                      useMomStyle: true,
                      compactMomStyle: true,
                    )
                  else
                    MomSettingsCard(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Add your baby to get started',
                          style: BabyDesign.text(18, weight: FontWeight.w700),
                        ),
                        Text(
                          'Start with a name for your baby. You can add more details later.',
                          style: BabyDesign.text(
                            14,
                            color: MomHomeTokens.secondary,
                          ),
                        ),
                        BabyPressFeedback(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(45),
                            ),
                            onPressed: _profile,
                            icon: const Icon(Icons.add),
                            label: const Text('Add a baby'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }
          final summary = c.summary, zone = c.timezone!;
          final missing = c.recentRecords.loading && !c.recentRecords.hasValue
              ? 'Loading…'
              : c.recentRecords.failure != null && !c.recentRecords.hasValue
              ? 'Not loaded yet'
              : 'No entry yet';
          final article =
              babyKnowledgeArticles[selectBabyKnowledge(
                now: c.now(),
                timezone: zone,
                babyId: baby.id,
                records: c.recentRecords.value ?? [],
              )]!;
          final feedingFacts = [
            if (summary?.latestFeeding != null)
              'Latest: ${zonedClock(summary!.latestFeeding!.occurredAt, zone)}',
            if (summary?.measuredIntakeMl != null)
              'Bottle-fed: ${babyNumber(summary!.measuredIntakeMl!)} ml recorded',
            if (summary?.nursingMinutes != null)
              'Nursing: ${summary!.nursingMinutes} min recorded',
          ];
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                Semantics(
                  label:
                      'Current baby: ${baby.name}, ${babySexLabel(baby.sex)}. Switch baby',
                  container: true,
                  button: true,
                  excludeSemantics: true,
                  onTap: _switching ? null : _switch,
                  child: InkWell(
                    onTap: _switching ? null : _switch,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: BabyDesign.asset(
                              'ChevronDownRounded',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Text(
                                baby.name,
                                softWrap: true,
                                style: BabyDesign.text(
                                  22,
                                  line: 36,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${babySexLabel(baby.sex)} · ${babyAgeLabel(baby, c.date!)}',
                                style: BabyDesign.text(
                                  12,
                                  line: 17,
                                  color: MomHomeTokens.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BabyPressFeedback(
                  child: BabyKnowledgeBanner(
                    article: article,
                    onOpen: () => showBabyKnowledge(
                      context,
                      article,
                      () => widget.onAsk(article.title),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const BabySectionHeader(title: 'Feeding today'),
                const SizedBox(height: 14),
                BabyPressFeedback(
                  child: BabyFeedingSummary(
                    hasRecord: summary != null && summary.feedingCount > 0,
                    value: summary != null && summary.feedingCount > 0
                        ? '${summary.feedingCount} ${summary.feedingCount == 1 ? 'feeding' : 'feedings'}'
                        : missing,
                    detail: feedingFacts.isEmpty
                        ? 'Log each feeding as it happens'
                        : feedingFacts.join(' · '),
                    onTap: () => _record(BabyRecordKind.feeding),
                  ),
                ),
                const SizedBox(height: 14),
                const BabySectionHeader(title: "Today's check-in"),
                const SizedBox(height: 14),
                if (c.recentRecords.failure != null) ...[
                  ProductErrorView(
                    useMomStyle: true,
                    compactMomStyle: true,
                    failure: c.recentRecords.failure!,
                    onRetry: c.refreshRecords,
                  ),
                  const SizedBox(height: 11),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack =
                        MediaQuery.textScalerOf(context).scale(1) > 1.35 ||
                        constraints.maxWidth < 380;
                    final cards = [
                      BabyPressFeedback(
                        child: BabyStatusCard(
                          hasRecord: summary?.latestMentalState != null,
                          artwork: 'mental',
                          label: 'Baby\'s mood after feeding',
                          asset: 'IconMentalState',
                          icon: MomCozyLineGlyph.status,
                          gradient: MomHomeTokens.sleep,
                          value: summary?.latestMentalState != null
                              ? babyMentalLabels[summary!.latestMentalState]!
                              : missing,
                          detail: summary?.latestMentalState != null
                              ? 'Latest'
                              : '',
                          onTap: () => _record(BabyRecordKind.dailyStatus),
                        ),
                      ),
                      BabyPressFeedback(
                        child: BabyStatusCard(
                          hasRecord: summary != null && summary.wetCount > 0,
                          artwork: 'wet',
                          asset: 'IconDrop1',
                          label: 'Wet diapers',
                          icon: MomCozyLineGlyph.drop,
                          gradient: MomHomeTokens.body,
                          value: summary != null && summary.wetCount > 0
                              ? '${summary.wetCount}'
                              : missing,
                          detail: 'Wet diapers today',
                          onTap: () => _record(
                            BabyRecordKind.dailyStatus,
                            diaper: DiaperKind.wet,
                          ),
                        ),
                      ),
                      BabyPressFeedback(
                        child: BabyStatusCard(
                          hasRecord: summary != null && summary.dirtyCount > 0,
                          artwork: 'stool',
                          asset: 'IconNote',
                          label: 'Dirty diapers',
                          icon: MomCozyLineGlyph.note,
                          gradient: MomHomeTokens.mood,
                          value: summary != null && summary.dirtyCount > 0
                              ? '${summary.dirtyCount}'
                              : missing,
                          detail: 'Dirty diapers today',
                          onTap: () => _record(
                            BabyRecordKind.dailyStatus,
                            diaper: DiaperKind.dirty,
                          ),
                        ),
                      ),
                    ];
                    return stack
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final card in cards)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: card,
                                ),
                            ],
                          )
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var index = 0;
                                  index < cards.length;
                                  index++
                                ) ...[
                                  if (index > 0)
                                    SizedBox(
                                      width: constraints.maxWidth < 343
                                          ? 8
                                          : 10,
                                    ),
                                  Expanded(child: cards[index]),
                                ],
                              ],
                            ),
                          );
                  },
                ),
                const SizedBox(height: 14),
                const BabySectionHeader(title: 'Growth'),
                const SizedBox(height: 14),
                if (c.latestGrowth.failure != null) ...[
                  ProductErrorView(
                    useMomStyle: true,
                    compactMomStyle: true,
                    failure: c.latestGrowth.failure!,
                    onRetry: c.refreshRecords,
                  ),
                  const SizedBox(height: 14),
                ],
                BabyGrowthMetrics(
                  controller: c,
                  onRecord: (metric) =>
                      _record(BabyRecordKind.growth, metric: metric),
                ),
                const SizedBox(height: 14),
                BabyGrowthCurve(
                  baby: baby,
                  metric: _metric,
                  records: c.growthCurve,
                  onMetricChanged: (value) => setState(() => _metric = value),
                  onEditProfile: () => _profile(baby),
                  onRetry: c.refreshRecords,
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
