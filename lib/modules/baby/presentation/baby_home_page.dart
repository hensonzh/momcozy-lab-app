import 'dart:async';
import '../../../shared/widgets/momcozy_line_icon.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../shared/widgets/knowledge_banner.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
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
import 'baby_saved_feedback.dart';

class BabyHomePage extends StatefulWidget {
  const BabyHomePage({
    super.key,
    required this.controller,
    required this.onAsk,
    required this.onHistory,
    this.onBabySelected,
    this.rememberedBabyId,
  });
  final BabyHomeController controller;
  final ValueChanged<String> onAsk;
  final Future<void> Function(String babyId) onHistory;
  final Future<void> Function(String babyId)? onBabySelected;
  final String? rememberedBabyId;
  @override
  State<BabyHomePage> createState() => _BabyHomePageState();
}

class _BabyHomePageState extends State<BabyHomePage>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _scroll = ScrollController();
  final _feedbackKey = GlobalKey();
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
          const SnackBar(content: Text('当前宝宝已切换，但尚未记住此选择。下次打开时请核对宝宝。')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
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
    );
    if (!mounted) return;
    await _load(selectedBabyId: saved?.id);
  }

  Future<void> _switch() async {
    final c = widget.controller, selected = widget.controller.baby;
    if (_switching || selected == null) return;
    final profiles = c.profiles.value!;
    final choice = await showDialog<String>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: Dialog(
          backgroundColor: MomHomeTokens.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '切换宝宝',
                          style: MomHomeTokens.text(
                            20,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '关闭宝宝切换',
                        onPressed: () => Navigator.pop(context),
                        color: MomHomeTokens.rose,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final profile in profiles) ...[
                          Semantics(
                            selected: profile.id == selected.id,
                            child: Material(
                              color: profile.id == selected.id
                                  ? MomHomeTokens.mint
                                  : MomHomeTokens.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: profile.id == selected.id
                                      ? MomHomeTokens.teal
                                      : MomHomeTokens.border,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.pop(context, profile.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        profile.name,
                                        style: MomHomeTokens.text(
                                          16,
                                          weight: FontWeight.w700,
                                          color: profile.id == selected.id
                                              ? MomHomeTokens.teal
                                              : MomHomeTokens.ink,
                                        ),
                                      ),
                                      if (profile.id == selected.id)
                                        Text(
                                          '当前',
                                          style: MomHomeTokens.text(
                                            12,
                                            color: MomHomeTokens.teal,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          '每个宝宝的喂养、睡眠、尿便和生长发育数据会分开保存。',
                          style: MomHomeTokens.text(
                            13,
                            color: MomHomeTokens.secondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'edit'),
                          child: const Text('编辑当前宝宝资料'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'add'),
                          child: const Text('添加宝宝'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    if (baby == null || zone == null || c.savedFeedback?.busy == true) return;
    c.dismissSaved();
    final activeId = c.summary?.activeSleep?.id;
    final saved = await showBabyRecordEditor(
      context,
      repository: c.recordRepository,
      baby: baby,
      timezone: zone,
      now: c.now,
      kind: kind,
      activeSleep: c.summary?.activeSleep,
      diaperKind: diaper,
      growthMetric: metric ?? _metric,
    );
    if (!mounted) return;
    if (identical(c, widget.controller)) await c.refreshRecords();
    if (saved != null &&
        mounted &&
        identical(c, widget.controller) &&
        c.baby?.id == baby.id) {
      c.showSaved(
        saved,
        allowUndo: saved.every(
          (r) => r.id != activeId && r.recordKind != BabyRecordKind.development,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _scroll.hasClients) {
        await MomCozyMotion.scrollTo(
          context,
          _scroll,
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        final feedbackContext = _feedbackKey.currentContext;
        if (feedbackContext != null && feedbackContext.mounted) {
          await Scrollable.ensureVisible(feedbackContext);
        }
      }
    }
  }

  Future<void> _history() async {
    final baby = widget.controller.baby;
    if (baby == null) return;
    await widget.onHistory(baby.id);
    if (mounted) await widget.controller.refreshRecords();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
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
                padding: MomHomeTokens.padding,
                children: [
                  Text(
                    '宝宝',
                    style: MomHomeTokens.text(26, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  if (c.profiles.loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (c.profiles.failure != null)
                    ProductErrorView(
                      failure: c.profiles.failure!,
                      onRetry: _load,
                      useMomStyle: true,
                    )
                  else
                    MomSettingsCard(
                      children: [
                        Text(
                          '添加宝宝，开始记录',
                          style: MomHomeTokens.text(
                            18,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '先填写宝宝称呼，之后可以逐步完善资料。',
                          style: MomHomeTokens.text(
                            14,
                            color: MomHomeTokens.secondary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _profile,
                          icon: const Icon(Icons.add),
                          label: const Text('添加宝宝'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }
          final summary = c.summary, zone = c.timezone!;
          final missing = c.recentRecords.loading
              ? '载入中…'
              : c.recentRecords.failure != null
              ? '暂未载入'
              : '未记录';
          final article =
              babyKnowledgeArticles[selectBabyKnowledge(
                now: c.now(),
                timezone: zone,
                babyId: baby.id,
                records: c.recentRecords.value ?? [],
              )]!;
          final feedingFacts = [
            if (summary?.latestFeeding != null)
              '最近 ${zonedClock(summary!.latestFeeding!.occurredAt, zone)}',
            if (summary?.measuredIntakeMl != null)
              '已记录瓶喂 ${babyNumber(summary!.measuredIntakeMl!)} ml',
            if (summary?.nursingMinutes != null)
              '已记录亲喂 ${summary!.nursingMinutes} 分钟',
          ];
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: MomHomeTokens.padding,
              children: [
                Semantics(
                  label: '当前宝宝 ${baby.name}，${babySexLabel(baby.sex)}，切换宝宝',
                  container: true,
                  button: true,
                  excludeSemantics: true,
                  onTap: _switching ? null : _switch,
                  child: InkWell(
                    onTap: _switching ? null : _switch,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              baby.name,
                              style: MomHomeTokens.text(
                                26,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.expand_more,
                            size: 24,
                            color: MomHomeTokens.rose,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${babySexLabel(baby.sex)} · ${babyAgeLabel(baby, c.date!)}',
                  style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
                ),
                const SizedBox(height: 14),
                KnowledgeBanner(
                  backgroundDecoration: MomCardDecoration.ai,
                  useMomStyle: true,
                  splitTitle: false,
                  reservePortraitSpace: true,
                  label: '更好地了解 ${baby.name}',
                  article: article,
                  onOpen: () => showKnowledgeArticle(
                    context,
                    article: article,
                    title: '更好地了解 ${baby.name}',
                    babyStyle: true,
                    useMomStyle: true,
                    boundary: '内容用于帮助理解记录，不是对宝宝健康或发育状态的判断。',
                    onAsk: () => widget.onAsk(article.title),
                  ),
                ),
                const SizedBox(height: 14),
                MomHomeSectionHeader(
                  title: '今日吃奶',
                  action: '记录',
                  onTap: () => _record(BabyRecordKind.feeding),
                ),
                const SizedBox(height: 14),
                BabyFeedingSummary(
                  hasRecord: summary != null && summary.feedingCount > 0,
                  value: summary != null && summary.feedingCount > 0
                      ? '${summary.feedingCount} 次'
                      : missing,
                  detail: feedingFacts.isEmpty
                      ? '每次喂养记一条'
                      : feedingFacts.join(' · '),
                  onTap: () => _record(BabyRecordKind.feeding),
                ),
                const SizedBox(height: 16),
                MomHomeSectionHeader(
                  title: '今日状态',
                  action: '记录',
                  onTap: () => _record(BabyRecordKind.sleep),
                ),
                const SizedBox(height: 14),
                if (c.recentRecords.failure != null)
                  ProductErrorView(
                    useMomStyle: true,
                    failure: c.recentRecords.failure!,
                    onRetry: c.refreshRecords,
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack =
                        MediaQuery.textScalerOf(context).scale(1) > 1.35;
                    final cards = [
                      BabyStatusCard(
                        hasRecord: summary?.activeSleep != null ||
                            (summary != null && summary.sleepCount > 0),
                        backgroundDecoration: MomCardDecoration.sleep,
                        label: '睡眠',
                        icon: MomCozyLineGlyph.moon,
                        gradient: MomHomeTokens.sleep,
                        value: summary?.activeSleep != null
                            ? '正在睡'
                            : summary != null && summary.sleepCount > 0
                            ? '累计 ${babyDuration(summary.sleepDuration)}'
                            : missing,
                        detail: summary?.activeSleep != null
                            ? '${zonedClock(summary!.activeSleep!.occurredAt, zone)} 开始'
                            : summary != null && summary.sleepCount > 0
                            ? '${summary.sleepCount} 段 · 最长 ${babyDuration(summary.longestSleep)}'
                            : '每段睡眠记一条',
                        onTap: () => _record(BabyRecordKind.sleep),
                      ),
                      BabyStatusCard(
                        hasRecord: summary != null && summary.wetCount > 0,
                        backgroundDecoration: MomCardDecoration.wet,
                        label: '尿湿',
                        icon: MomCozyLineGlyph.drop,
                        gradient: MomHomeTokens.body,
                        value: summary != null && summary.wetCount > 0
                            ? '${summary.wetCount} 次'
                            : missing,
                        detail: '每次换尿布记一条',
                        onTap: () => _record(
                          BabyRecordKind.diaper,
                          diaper: DiaperKind.wet,
                        ),
                      ),
                      BabyStatusCard(
                        hasRecord: summary != null && summary.dirtyCount > 0,
                        backgroundDecoration: MomCardDecoration.stool,
                        label: '便便',
                        icon: MomCozyLineGlyph.note,
                        gradient: MomHomeTokens.mood,
                        value: summary != null && summary.dirtyCount > 0
                            ? '${summary.dirtyCount} 次'
                            : missing,
                        detail: '记录看到的情况',
                        onTap: () => _record(
                          BabyRecordKind.diaper,
                          diaper: DiaperKind.dirty,
                        ),
                      ),
                    ];
                    return stack
                        ? Column(
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
                MomHomeSectionHeader(
                  title: '生长发育记录',
                  action: '记录',
                  onTap: () => _record(BabyRecordKind.growth),
                ),
                const SizedBox(height: 14),
                if (c.latestGrowth.failure != null)
                  ProductErrorView(
                    useMomStyle: true,
                    failure: c.latestGrowth.failure!,
                    onRetry: c.refreshRecords,
                  ),
                BabyGrowthMetrics(
                  controller: c,
                  onRecord: (metric) =>
                      _record(BabyRecordKind.growth, metric: metric),
                ),
                const SizedBox(height: 12),
                BabyGrowthCurve(
                  baby: baby,
                  metric: _metric,
                  records: c.growthCurve,
                  onMetricChanged: (value) => setState(() => _metric = value),
                  onEditProfile: () => _profile(baby),
                  onRetry: c.refreshRecords,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      textStyle: MomHomeTokens.text(
                        13,
                        weight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => _record(BabyRecordKind.development),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: const Text('记录发育观察'),
                  ),
                ),
                const SizedBox(height: 18),
                const MomHomeSectionHeader(title: '睡眠监测'),
                Text(
                  '即将开放',
                  style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
                ),
                const SizedBox(height: 14),
                const BabySleepMonitor(),
                const SizedBox(height: 16),
                if (c.savedFeedback != null)
                  BabySavedFeedbackView(
                    key: _feedbackKey,
                    feedback: c.savedFeedback!,
                    onUndo: c.undoSaved,
                    onDismiss: c.dismissSaved,
                    onHistory: _history,
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    textStyle: MomHomeTokens.text(13, weight: FontWeight.w700),
                  ),
                  onPressed: _history,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('查看全部记录'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
