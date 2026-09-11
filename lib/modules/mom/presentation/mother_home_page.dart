import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../domain/mother/postpartum_stage.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/knowledge_banner.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/mother_home_controller.dart';
import '../application/mother_knowledge_content.dart';
import '../application/mother_knowledge_selection.dart';
import 'diary_labels.dart';
import 'lactation_panel.dart';
import 'mother_diary_editor.dart';
import 'mother_status_card.dart';

class MotherHomePage extends StatefulWidget {
  const MotherHomePage({
    super.key,
    required this.controller,
    required this.onAsk,
    required this.expertSupport,
  });
  final MotherHomeController controller;
  final ValueChanged<String> onAsk;
  final Widget expertSupport;
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

  Future<void> _diary(DiarySection section) => showMotherDiaryEditor(
    context,
    repository: widget.controller.diaryRepository,
    date: widget.controller.date,
    section: section,
    onSaved: () => unawaited(widget.controller.load()),
  );
  Future<void> _milk({bool create = false}) => showLactationPanel(
    context,
    repository: widget.controller.lactationRepository,
    ownerUserId: widget.controller.ownerUserId,
    date: widget.controller.date,
    now: widget.controller.now,
    create: create,
    onChanged: () => unawaited(widget.controller.load()),
  );
  Future<void> _chooseRecord() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('记录我的状态'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('选择这次想记录的内容'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'diary'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('身体与心情'),
              subtitle: Text('休息、身体精力和今日心情'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'milk'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('泌乳记录'),
              subtitle: Text('泵奶与亲喂'),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'diary') await _diary(DiarySection.rest);
    if (choice == 'milk') await _milk(create: true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final profile = controller.profile.value;
      final day = profile?.postpartumDay(controller.date);
      final diary = controller.todayDiary;
      final missingDiary = controller.diaries.hasValue
          ? '未记录'
          : controller.diaries.loading
          ? '载入中…'
          : '暂未载入';
      final missingMilk = controller.lactation.hasValue
          ? '未记录'
          : controller.lactation.loading
          ? '载入中…'
          : '暂未载入';
      final milk = controller.milk;
      final milkValue = milk == null || milk.recordCount == 0
          ? missingMilk
          : milk.measuredVolumeMl != null
          ? '${compactNumber(milk.measuredVolumeMl!)} ml'
          : milk.nursingMinutes != null
          ? '${milk.nursingMinutes} 分钟'
          : '${milk.recordCount} 次';
      final topic = selectMotherKnowledge(
        now: controller.now(),
        ownerUserId: controller.ownerUserId,
        diaries: controller.diaries.value ?? [],
        lactation: controller.lactation.value ?? [],
      );
      final article = motherKnowledgeArticles[topic]!;
      final hour = controller.now().toLocal().hour;
      final greeting = hour < 12
          ? '早上好'
          : hour < 18
          ? '下午好'
          : '晚上好';
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: MomCozyInsets.page,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Text(
                  '$greeting${profile?.displayName.isNotEmpty == true ? '，${profile!.displayName}' : ''}',
                  style: const TextStyle(
                    fontSize: MomCozyTypography.pageTitleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  day == null ? '陪伴每个阶段' : formatPostpartumDay(day),
                  style: const TextStyle(
                    fontSize: MomCozyTypography.labelSize,
                    fontWeight: FontWeight.w600,
                    color: MomCozyColors.textTertiary,
                  ),
                ),
              ],
            ),
            if (controller.profile.failure case final failure?)
              ProductErrorView(failure: failure, onRetry: controller.load),
            const SizedBox(height: 28),
            KnowledgeBanner(
              label: '更好地了解自己的身体',
              article: article,
              onOpen: () => showKnowledgeArticle(
                context,
                article: article,
                boundary: '日常知识用于帮助记录与理解自己的变化，不能代替医疗专业人员的评估。',
                onAsk: () => widget.onAsk(article.title),
              ),
            ),
            const SizedBox(height: 22),
            MomCozySectionHeading(
              icon: Icons.favorite_border_rounded,
              title: '我的状态',
              action: TextButton(
                onPressed: _chooseRecord,
                child: const Text('记录'),
              ),
            ),
            if (controller.diaries.failure case final failure?)
              ProductErrorView(failure: failure, onRetry: controller.load),
            if (controller.lactation.failure case final failure?)
              ProductErrorView(failure: failure, onRetry: controller.load),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final height = 148.0 + (scale - 1).clamp(0, 3) * 75;
                return Column(
                  children: [
                    SizedBox(
                      height: height,
                      child: Row(
                        children: [
                          Expanded(
                            child: MotherStatusCard(
                              kind: MotherCardKind.rest,
                              label: '昨夜休息',
                              value: _restValue(diary, missingDiary),
                              onTap: () => _diary(DiarySection.rest),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MotherStatusCard(
                              kind: MotherCardKind.body,
                              label: '身体与精力',
                              value:
                                  energyLabels[diary?.body.energy] ??
                                  missingDiary,
                              onTap: () => _diary(DiarySection.body),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: height,
                      child: Row(
                        children: [
                          Expanded(
                            child: MotherStatusCard(
                              kind: MotherCardKind.mood,
                              label: '今日心情',
                              value:
                                  toneLabels[diary?.mood.tone] ?? missingDiary,
                              onTap: () => _diary(DiarySection.mood),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MotherStatusCard(
                              kind: MotherCardKind.lactation,
                              label: '今日泌乳',
                              value: milkValue,
                              detail: milk == null || milk.recordCount == 0
                                  ? '按次保存，随时可补充'
                                  : [
                                      if (milk.pumpCount > 0)
                                        '泵奶 ${milk.pumpCount} 次',
                                      if (milk.nursingCount > 0)
                                        '亲喂 ${milk.nursingCount} 次',
                                    ].join(' · '),
                              onTap: _milk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            widget.expertSupport,
            const SizedBox(height: 24),
            const MomCozySectionHeading(
              icon: Icons.grid_view_rounded,
              title: '其它功能',
            ),
            const _UpcomingTools(),
          ],
        ),
      );
    },
  );
}

String _restValue(MotherDiary? diary, String fallback) =>
    sleepTotalLabels[diary?.rest.total] ??
    recoveryLabels[diary?.rest.recovery] ??
    fallback;

class _UpcomingTools extends StatelessWidget {
  const _UpcomingTools();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _group('泌乳管理', Icons.water_drop_outlined, ['奶量评估', '奶量趋势']),
      const SizedBox(height: 12),
      _group('身体恢复', Icons.favorite_border_rounded, ['产后身体评估']),
    ],
  );
  Widget _group(String title, IconData icon, List<String> items) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: MomCozyColors.raised,
      border: Border.all(color: MomCozyColors.border),
      borderRadius: BorderRadius.circular(MomCozyRadii.card),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: MomCozyColors.primary),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Semantics(
              button: true,
              enabled: false,
              child: Row(
                children: [
                  Expanded(child: Text(item)),
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: MomCozyColors.mutedForeground,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '即将开放',
                    style: TextStyle(
                      fontSize: MomCozyTypography.labelSize,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
