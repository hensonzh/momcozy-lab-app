import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/baby/growth_reference.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_labels.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';

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
  BabyRecordKind _careMetric = BabyRecordKind.feeding;
  GrowthMetric _growthMetric = GrowthMetric.weight;

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
    setState(() {
      _selecting = true;
      _careMetric = BabyRecordKind.feeding;
      _growthMetric = GrowthMetric.weight;
    });
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
                '当前宝宝',
                style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFDFC), Color(0xFFE8F3EF)],
                  ),
                  border: Border.all(color: const Color(0xFFE1EBE7)),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
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
                _todayCare(controller),
                const SizedBox(height: 22),
                _careTrend(controller),
                const SizedBox(height: 22),
                _growthTrend(controller, baby),
                const SizedBox(height: 24),
                const Text(
                  '宝宝资料与记录',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
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

  Widget _todayCare(BabyHomeController c) {
    final loaded = c.recentRecords.hasValue && c.recentRecords.failure == null;
    final summary = loaded ? c.summary : null;
    final labels = ['喂养记录', '湿尿布记录', '脏尿布记录', '睡眠记录'];
    final counts = summary == null
        ? null
        : [
            summary.feedingCount,
            summary.wetCount,
            summary.dirtyCount,
            summary.sleepCount,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日照护',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.recentRecords.failure != null)
                const Text('今日记录暂时无法读取；请下拉重试。')
              else if (!loaded)
                const Text('正在读取今日记录…')
              else ...[
                Row(
                  children: [
                    for (var index = 0; index < 2; index++)
                      Expanded(
                        child: _countCell(labels[index], counts![index]),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 2; index < 4; index++)
                      Expanded(
                        child: _countCell(labels[index], counts![index]),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                const Text(
                  '— 表示尚无记录，不代表没有发生。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('baby-record-action'),
                  onPressed: _openDetails,
                  child: const Text('记一笔 / 查看记录'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _countCell(String label, int count) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF526D6C)),
            ),
            const SizedBox(height: 7),
            Text(
              count == 0 ? '—' : '$count 次',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _careTrend(BabyHomeController c) {
    final day = c.date, zone = c.timezone, baby = c.baby;
    if (day == null || zone == null || baby == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '照护趋势',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最近 7 天 · ${baby.name}的已保存记录',
                style: const TextStyle(color: Color(0xFF77717B), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final (metric, label) in [
                    (BabyRecordKind.feeding, '喂养'),
                    (BabyRecordKind.diaper, '尿布'),
                    (BabyRecordKind.sleep, '睡眠'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _careMetric == metric,
                      onSelected: (_) => setState(() => _careMetric = metric),
                    ),
                ],
              ),
              if (c.recentRecords.failure != null)
                const Text('近 7 天记录暂时无法读取；请下拉重试。')
              else if (!c.recentRecords.hasValue)
                const Text('正在读取近 7 天记录…')
              else ...[
                const Divider(),
                for (var offset = 0; offset < 7; offset++)
                  _careDayRow(
                    c.recentRecords.value!,
                    baby.id,
                    day.addDays(-offset),
                    zone,
                  ),
                const SizedBox(height: 7),
                const Text(
                  '空白日期表示未记录，不代表没有发生。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _careDayRow(
    List<BabyRecord> records,
    String babyId,
    LocalDate day,
    String zone,
  ) {
    final window = zonedDayWindow(day, zone);
    final summary = BabyDaySummary.fromRecords(
      records,
      babyId: babyId,
      window: window,
      calendarDate: day,
      now: widget.controller.now(),
    );
    final now = widget.controller.now();
    final hasRecords = records.any(
      (record) =>
          record.babyId == babyId &&
          switch (record) {
            BabyDailyStatusRecord(
              :final recordedOn,
              :final wetCount,
              :final stoolCount,
            ) =>
              _careMetric == BabyRecordKind.diaper &&
                  recordedOn == day &&
                  (wetCount != null || stoolCount != null),
            BabyFeedingRecord(:final occurredAt) =>
              _careMetric == BabyRecordKind.feeding &&
                  !occurredAt.isAfter(now) &&
                  window.contains(occurredAt),
            BabyDiaperRecord(:final occurredAt) =>
              _careMetric == BabyRecordKind.diaper &&
                  !occurredAt.isAfter(now) &&
                  window.contains(occurredAt),
            BabySleepRecord(:final occurredAt, :final endedAt) =>
              _careMetric == BabyRecordKind.sleep &&
                  !occurredAt.isAfter(now) &&
                  occurredAt.isBefore(window.end) &&
                  (endedAt ?? now).isAfter(window.start),
            _ => false,
          },
    );
    final value = !hasRecords
        ? '未记录'
        : switch (_careMetric) {
            BabyRecordKind.feeding => '${summary.feedingCount} 次喂养',
            BabyRecordKind.diaper =>
              '湿 ${summary.wetCount} · 脏 ${summary.dirtyCount}',
            BabyRecordKind.sleep => '${summary.sleepCount} 段睡眠',
            _ => '未记录',
          };
    return Padding(
      key: ValueKey('baby-care-${day.toString()}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 65, child: Text('${day.month}/${day.day}')),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _growthTrend(BabyHomeController c, BabyProfile baby) {
    final records = c.growthCurve.value;
    final measured =
        records == null
              ? <BabyGrowthRecord>[]
              : records
                    .where(
                      (record) =>
                          record.babyId == baby.id &&
                          record.metric == _growthMetric,
                    )
                    .toList()
          ..sort((a, b) => b.recordedOn.compareTo(a.recordedOn));
    final latest = c.latestGrowth.value
        ?.where(
          (record) =>
              record.babyId == baby.id && record.metric == _growthMetric,
        )
        .firstOrNull;
    final inCurveRange =
        baby.birthDate != null &&
        c.date != null &&
        c.date!.compareTo(baby.birthDate!.addMonths(whoGrowthMaxMonths)) <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (latest != null)
          _surface(
            child: Text(
              '${growthMetricLabelZh(_growthMetric)}最近测量 ${latest.recordedOn.month}/${latest.recordedOn.day} · ${babyNumber(latest.value)} ${latest.unit}',
              key: const ValueKey('baby-growth-latest'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (!inCurveRange)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '目前的生长曲线只覆盖出生后前 6 个月；最近测量以已保存记录为准。',
              style: TextStyle(color: Color(0xFF77717B)),
            ),
          )
        else
          BabyGrowthCurve(
            baby: baby,
            metric: _growthMetric,
            records: c.growthCurve,
            onMetricChanged: (metric) => setState(() => _growthMetric = metric),
            onEditProfile: () => _editProfile(baby),
            onRetry: c.refreshRecords,
            chatFirstExperience: true,
          ),
        if (inCurveRange &&
            c.growthCurve.failure == null &&
            records != null &&
            measured.isNotEmpty)
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '逐笔测量',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final record in measured)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${record.recordedOn.month}/${record.recordedOn.day}',
                          ),
                        ),
                        Text('${babyNumber(record.value)} ${record.unit}'),
                      ],
                    ),
                  ),
                const Text(
                  '只展示当前宝宝的实测值，不据此作健康判断。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF77717B)),
                ),
              ],
            ),
          ),
      ],
    );
  }

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
      if (baby.birthDate case final date?) '出生日期 $date',
      if (baby.feedingMode != FeedingMode.unknown)
        switch (baby.feedingMode) {
          FeedingMode.breastfeeding => '亲喂',
          FeedingMode.expressedMilk => '瓶喂母乳',
          FeedingMode.mixed => '混合喂养',
          FeedingMode.formula => '配方奶',
          FeedingMode.unknown => '',
        },
    ];
    return detail.isEmpty ? '当前账号已保存的宝宝资料' : detail.join(' · ');
  }

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
