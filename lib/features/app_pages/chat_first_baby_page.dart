import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_labels.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';

/// A conversation-first overview of saved, owner-scoped baby data. The
/// existing full management page remains a secondary destination.
class ChatFirstBabyPage extends StatefulWidget {
  const ChatFirstBabyPage({
    super.key,
    required this.controller,
    required this.onOpenDetails,
    this.onBabySelected,
    this.rememberedBabyId,
  });

  final BabyHomeController controller;
  final Future<void> Function() onOpenDetails;
  final Future<void> Function(String babyId)? onBabySelected;
  final String? rememberedBabyId;

  @override
  State<ChatFirstBabyPage> createState() => _ChatFirstBabyPageState();
}

class _ChatFirstBabyPageState extends State<ChatFirstBabyPage>
    with WidgetsBindingObserver {
  Timer? _clock;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => widget.controller.tick(),
    );
  }

  Future<void> _load() async {
    final controller = widget.controller;
    await controller.load();
    if (mounted &&
        identical(controller, widget.controller) &&
        controller.baby != null &&
        controller.baby!.id != widget.rememberedBabyId) {
      await _remember(controller.baby!.id);
    }
  }

  Future<void> _remember(String babyId) async {
    final save = widget.onBabySelected;
    if (save == null) return;
    try {
      await save(babyId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已切换宝宝，但未能保存选择；下次打开时请确认当前宝宝。')),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ChatFirstBabyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.dispose();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> _editProfile([BabyProfile? profile]) async {
    final controller = widget.controller;
    final timezone = controller.timezone;
    if (timezone == null) return;
    final saved = await showBabyProfileEditor(
      context,
      repository: controller.profileRepository,
      timezone: timezone,
      now: controller.now,
      profile: profile,
      deliveryDate: controller.deliveryDate,
      closeOnSave: true,
      chatFirstExperience: true,
    );
    if (!mounted ||
        saved == null ||
        !identical(controller, widget.controller)) {
      return;
    }
    await controller.applySavedProfile(saved);
    if (mounted && identical(controller, widget.controller)) {
      await _remember(saved.id);
    }
  }

  Future<void> _openDetails() async {
    await widget.onOpenDetails();
    if (mounted) await _load();
  }

  Future<void> _selectBaby(String id) async {
    if (_selecting || id == widget.controller.baby?.id) return;
    setState(() => _selecting = true);
    try {
      await widget.controller.select(id);
      if (mounted) await _remember(id);
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('chat-first-baby-page'),
    color: const Color(0xFFFFFDFA),
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final baby = controller.baby;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 40),
            children: [
              const Text(
                '宝宝信息',
                style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      baby?.name ?? '宝宝资料',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF322C33),
                      ),
                    ),
                  ),
                  if (baby != null &&
                      (controller.profiles.value?.length ?? 0) > 1)
                    PopupMenuButton<String>(
                      key: const ValueKey('baby-switch'),
                      tooltip: '切换宝宝',
                      enabled: !_selecting,
                      onSelected: (id) => unawaited(_selectBaby(id)),
                      itemBuilder: (context) => [
                        for (final profile in controller.profiles.value!)
                          PopupMenuItem(
                            value: profile.id,
                            child: Text(profile.name),
                          ),
                      ],
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                baby == null
                    ? '这里只显示当前账号真实保存的宝宝资料。'
                    : _babyDescription(baby, controller),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF77717B),
                ),
              ),
              const SizedBox(height: 24),
              if (controller.profiles.loading && !controller.profiles.hasValue)
                const Center(child: CircularProgressIndicator())
              else if (controller.profiles.failure != null &&
                  !controller.profiles.hasValue)
                _notice('暂时无法加载宝宝资料', '请检查网络后重试；不会显示演示数据。', onRetry: _load)
              else if (baby == null)
                _notice(
                  '当前账号还没有宝宝资料',
                  '添加并保存宝宝资料后，才会显示属于这个宝宝的记录。',
                  action: FilledButton(
                    onPressed: _editProfile,
                    child: const Text('添加宝宝资料'),
                  ),
                )
              else ...[
                if (controller.profiles.failure != null)
                  _notice('资料暂未更新', '当前显示上次读取的资料；下拉可重试。', onRetry: _load),
                _lead(controller),
                const SizedBox(height: 24),
                const Text(
                  '查看信息',
                  style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
                ),
                const SizedBox(height: 9),
                _detailRow(
                  key: const ValueKey('baby-feeding-sleep'),
                  icon: Icons.child_care_outlined,
                  title: '喂养与睡眠',
                  summary: _careSummary(controller),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  key: const ValueKey('baby-growth'),
                  icon: Icons.trending_up_rounded,
                  title: '生长发育',
                  summary: _growthSummary(controller),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => _editProfile(baby),
                      child: const Text('编辑宝宝资料'),
                    ),
                    TextButton(
                      key: const ValueKey('baby-full-details'),
                      onPressed: _openDetails,
                      child: const Text('查看完整记录与管理'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  String _babyDescription(BabyProfile baby, BabyHomeController controller) {
    final sex = switch (baby.sex) {
      BabySex.female => '女孩',
      BabySex.male => '男孩',
      BabySex.unspecified => null,
    };
    final age = controller.date == null ? null : baby.ageDays(controller.date!);
    final detail = [
      ?sex,
      if (age != null) '出生 $age 天' else if (baby.birthDate == null) '未填写出生日期',
    ];
    return detail.isEmpty ? '当前账号已保存的宝宝资料' : detail.join(' · ');
  }

  String _careSummary(BabyHomeController controller) {
    if (controller.recentRecords.failure != null) return '今日记录暂无法更新，可下拉重试';
    if (!controller.recentRecords.hasValue) return '正在读取今日记录…';
    final summary = controller.summary;
    if (summary == null) return '今日记录暂不可用';
    if (summary.feedingCount == 0 && summary.sleepCount == 0) {
      return '今天还没有喂养或睡眠记录';
    }
    return '今天喂养 ${summary.feedingCount} 次 · 睡眠 ${summary.sleepCount} 次';
  }

  String _growthSummary(BabyHomeController controller) {
    if (controller.latestGrowth.failure != null) return '生长记录暂无法更新，可下拉重试';
    if (!controller.latestGrowth.hasValue) return '正在读取生长记录…';
    final values = controller.latestGrowth.value!;
    final facts = [
      for (final metric in [GrowthMetric.weight, GrowthMetric.length])
        if (values.where((record) => record.metric == metric).firstOrNull
            case final record?)
          '${metric == GrowthMetric.weight ? '体重' : '身长'} ${babyNumber(record.value)} ${record.unit}',
    ];
    return facts.isEmpty ? '还没有身长或体重记录' : facts.join(' · ');
  }

  Widget _lead(BabyHomeController controller) {
    final summary = controller.summary;
    final loaded =
        controller.recentRecords.hasValue &&
        controller.recentRecords.failure == null;
    final value = !loaded || summary == null
        ? '暂不可用'
        : summary.feedingCount == 0
        ? '暂无喂养记录'
        : '${summary.feedingCount} 次喂养';
    final hint = !loaded || summary == null
        ? _careSummary(controller)
        : summary.latestFeeding == null
        ? '仅显示当前账号保存的记录'
        : '最近一次记录于今天';
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日喂养',
            style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Color(0xFF322C33),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: Color(0xFF77717B)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required Key key,
    required IconData icon,
    required String title,
    required String summary,
  }) => Semantics(
    key: key,
    label: '查看$title，$summary',
    button: true,
    onTap: _openDetails,
    child: ExcludeSemantics(
      child: _surface(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: _openDetails,
          borderRadius: BorderRadius.circular(15),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 65),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: const Color(0xFF977A86)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Color(0xFF77717B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Color(0xFF8C858D),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _notice(
    String title,
    String description, {
    VoidCallback? onRetry,
    Widget? action,
  }) => _surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Color(0xFF77717B),
          ),
        ),
        if (onRetry != null || action != null) ...[
          const SizedBox(height: 15),
          ?action,
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ],
    ),
  );

  Widget _surface({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) => Container(
    key: key,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE9E8ED)),
      borderRadius: BorderRadius.circular(17),
    ),
    child: child,
  );
}
