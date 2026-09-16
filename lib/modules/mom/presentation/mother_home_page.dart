import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/observability/momcozy_observability.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../application/mom_home_view_data.dart';
import 'mom_home_sections.dart';
import '../../../domain/mother/postpartum_stage.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/mother_home_controller.dart';
import 'lactation_panel.dart';
import 'mother_diary_editor.dart';

class MotherHomePage extends StatefulWidget {
  const MotherHomePage({
    super.key,
    required this.controller,
    required this.onAsk,
    required this.expertSupport,
    this.onRecoveryDetails,
    this.onLactationDetails,
    this.observability,
  });
  final MotherHomeController controller;
  final ValueChanged<String> onAsk;
  final Widget expertSupport;
  final Future<void> Function()? onRecoveryDetails, onLactationDetails;
  final MomCozyObservability? observability;
  @override
  State<MotherHomePage> createState() => _MotherHomePageState();
}

class _MotherHomePageState extends State<MotherHomePage>
    with WidgetsBindingObserver {
  Timer? _dayTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.load());
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    final now = widget.controller.now().toLocal();
    final next = now.hour < 8
        ? DateTime(now.year, now.month, now.day, 8)
        : DateTime(now.year, now.month, now.day + 1);
    _dayTimer?.cancel();
    _dayTimer = Timer(next.difference(now), () {
      unawaited(widget.controller.load());
      _scheduleRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.load());
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MotherHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.dispose();
      unawaited(widget.controller.load());
      _scheduleRefresh();
    }
  }

  Future<void> _diary(DiarySection section, {MoodTone? initialMood}) {
    final day = widget.controller.profile.value?.postpartumDay(
      widget.controller.date,
    );
    return showMotherDiaryEditor(
      context,
      repository: widget.controller.diaryRepository,
      date: widget.controller.date,
      section: section,
      initialMood: initialMood,
      stageLabel: day == null ? null : formatPostpartumDay(day),
      onSaved: () => unawaited(widget.controller.load()),
    );
  }

  Future<void> _milk({bool create = false}) => showLactationPanel(
    context,
    repository: widget.controller.lactationRepository,
    ownerUserId: widget.controller.ownerUserId,
    date: widget.controller.date,
    now: widget.controller.now,
    create: create,
    onChanged: () => unawaited(widget.controller.load()),
  );

  void _track(String event, VoidCallback action) {
    widget.observability?.recordFeatureEvent('mom_home', event);
    action();
  }

  Future<void> _details(
    Future<void> Function()? navigate,
    DiarySection fallback,
  ) async {
    if (navigate == null) {
      await _diary(fallback);
      return;
    }
    await navigate();
    if (mounted) await widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MomHomeTokens.background,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (c.profile.loading &&
            !c.profile.hasValue &&
            c.diaries.loading &&
            !c.diaries.hasValue &&
            c.lactation.loading &&
            !c.lactation.hasValue) {
          return const MomHomeSkeleton();
        }
        final data = MomHomeViewData.fromController(c);
        return RefreshIndicator(
          onRefresh: c.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MomHomeTokens.padding,
            children: [
              MomHomeHeader(data: data),
              if (c.profile.failure case final failure?)
                ProductErrorView(failure: failure, onRetry: c.load),
              const SizedBox(height: 14),
              MomAiInsightCard(
                insight: data.insight,
                onTap: () => _track(
                  'mom_home_ai_insight_click',
                  () => widget.onAsk('请结合我今天的记录，帮我了解恢复状态。'),
                ),
              ),
              const SizedBox(height: 7),
              MomHomeSectionHeader(
                title: '今日泌乳',
                action: '查看记录 ›',
                onTap: () => _track(
                  'mom_home_lactation_trend_click',
                  () => unawaited(
                    widget.onLactationDetails == null
                        ? _milk()
                        : _details(
                            widget.onLactationDetails,
                            DiarySection.rest,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              MomLactationCard(
                data: data,
                onRecord: () => _track(
                  'mom_home_lactation_record_click',
                  () => unawaited(_milk(create: true)),
                ),
              ),
              if (c.lactation.failure case final failure?)
                ProductErrorView(failure: failure, onRetry: c.load),
              const SizedBox(height: 7),
              MomHomeSectionHeader(
                title: '今日状态',
                action: data.completedGroups == 3
                    ? '今日已完成记录 ›'
                    : '今日完成 ${data.completedGroups}/3 · ${data.completedGroups == 0 ? '开始' : '继续'}记录 ›',
                onTap: () => _track(
                  'mom_home_recovery_click',
                  () => unawaited(
                    data.completedGroups == 3
                        ? _details(widget.onRecoveryDetails, DiarySection.rest)
                        : _diary(DiarySection.body),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              MomRecoveryStatus(
                data: data,
                onBody: () => _track(
                  'mom_home_recovery_click',
                  () => unawaited(_diary(DiarySection.body)),
                ),
                onRest: () => _track(
                  'mom_home_recovery_click',
                  () => unawaited(_diary(DiarySection.rest)),
                ),
                onMood: (index) => _track(
                  'mom_home_recovery_click',
                  () => unawaited(
                    _diary(
                      DiarySection.mood,
                      initialMood: index == 0
                          ? MoodTone.low
                          : index == null
                          ? null
                          : index == 1
                          ? MoodTone.unclear
                          : MoodTone.steady,
                    ),
                  ),
                ),
              ),
              if (c.diaries.failure case final failure?)
                ProductErrorView(failure: failure, onRetry: c.load),
              const SizedBox(height: 14),
              widget.expertSupport,
            ],
          ),
        );
      },
    ),
  );
}
