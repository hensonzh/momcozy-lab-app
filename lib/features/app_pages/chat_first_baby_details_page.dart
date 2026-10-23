import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_labels.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

import 'chat_first_baby_knowledge.dart';

/// Secondary management surface. The same owner-scoped repositories and
/// controller power the old App; this page does not use the Demo's profiles.
class ChatFirstBabyDetailsPage extends StatefulWidget {
  const ChatFirstBabyDetailsPage({
    super.key,
    required this.controller,
    this.onBabySelected,
    this.onRecordSleep,
    this.onAsk,
    this.rememberedBabyId,
    this.mutationNotificationsRefreshPage = false,
  });

  final BabyHomeController controller;
  final Future<void> Function(String babyId)? onBabySelected;
  final Future<void> Function(String babyId)? onRecordSleep;
  final ValueChanged<String>? onAsk;
  final String? rememberedBabyId;
  final bool mutationNotificationsRefreshPage;

  @override
  State<ChatFirstBabyDetailsPage> createState() =>
      _ChatFirstBabyDetailsPageState();
}

class _ChatFirstBabyDetailsPageState extends State<ChatFirstBabyDetailsPage>
    with WidgetsBindingObserver {
  Timer? _clock;
  GrowthMetric _metric = GrowthMetric.weight;
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
    final c = widget.controller;
    await c.load();
    if (mounted &&
        identical(c, widget.controller) &&
        c.baby != null &&
        c.baby!.id != widget.rememberedBabyId) {
      await _remember(c.baby!.id);
    }
  }

  Future<void> _remember(String babyId) async {
    final save = widget.onBabySelected;
    if (save == null) return;
    try {
      await save(babyId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已切换宝宝，但未能保存选择；下次打开时请确认当前宝宝。')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ChatFirstBabyDetailsPage oldWidget) {
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
    final c = widget.controller;
    final zone = c.timezone;
    if (zone == null) return;
    final saved = await showBabyProfileEditor(
      context,
      repository: c.profileRepository,
      timezone: zone,
      now: c.now,
      profile: profile,
      deliveryDate: c.deliveryDate,
      closeOnSave: true,
      chatFirstExperience: true,
    );
    if (!mounted || saved == null || !identical(c, widget.controller)) return;
    await c.applySavedProfile(saved);
    if (mounted && identical(c, widget.controller)) await _remember(saved.id);
  }

  Future<void> _selectBaby(String id) async {
    final c = widget.controller;
    if (_selecting || id == c.baby?.id) return;
    setState(() {
      _selecting = true;
      _metric = GrowthMetric.weight;
    });
    try {
      await c.select(id);
      if (mounted && identical(c, widget.controller)) await _remember(id);
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _record(
    BabyRecordKind kind, {
    DiaperKind? diaper,
    GrowthMetric? metric,
  }) async {
    final c = widget.controller;
    final baby = c.baby;
    final zone = c.timezone;
    if (baby == null || zone == null) return;
    // An update to today's cumulative status needs a confirmed current
    // snapshot; otherwise an offline read could create a duplicate.
    if (kind == BabyRecordKind.dailyStatus &&
        (c.recentRecords.failure != null || !c.recentRecords.hasValue)) {
      return;
    }
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
      chatFirstExperience: true,
    );
    if (saved != null && mounted && identical(c, widget.controller)) {
      if (!widget.mutationNotificationsRefreshPage) {
        await c.refreshRecords(kind: kind);
      }
    }
  }

  Future<void> _refreshAfterMutation(BabyRecordKind kind) async {
    if (!widget.mutationNotificationsRefreshPage && mounted) {
      await widget.controller.refreshRecords(kind: kind);
    }
  }

  Future<void> _editRecord(BabyRecord record) async {
    final c = widget.controller;
    final baby = c.baby;
    final zone = c.timezone;
    if (baby == null || zone == null || record.babyId != baby.id) return;
    final saved = await showBabyRecordEditor(
      context,
      repository: c.recordRepository,
      baby: baby,
      timezone: zone,
      now: c.now,
      kind: record.recordKind,
      initial: record,
      growthMetric: record is BabyGrowthRecord
          ? record.metric
          : GrowthMetric.weight,
      chatFirstExperience: true,
    );
    if (saved != null && mounted && identical(c, widget.controller)) {
      await _refreshAfterMutation(record.recordKind);
    }
  }

  Future<void> _deleteRecord(BabyRecord record) async {
    final c = widget.controller;
    final baby = c.baby;
    if (baby == null || record.babyId != baby.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('记录会从当前页面移除，你可以在提示出现时立即恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('baby-record-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deletion = await c.recordRepository.delete(
        record.id,
        babyId: baby.id,
        expectedVersion: record.version,
      );
      if (!mounted || !identical(c, widget.controller)) return;
      final retainedRecord = _recordWithVersion(record, deletion.version);
      await _refreshAfterMutation(record.recordKind);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('记录已删除'),
          action: SnackBarAction(
            label: '恢复',
            onPressed: () => unawaited(
              _restoreRecord(retainedRecord, expectedVersion: deletion.version),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，记录未发生变化。')));
      }
    }
  }

  BabyRecord _recordWithVersion(BabyRecord record, int version) =>
      switch (record) {
        BabyFeedingRecord() => BabyFeedingRecord(
          id: record.id,
          babyId: record.babyId,
          version: version,
          occurredAt: record.occurredAt,
          method: record.method,
          side: record.side,
          volumeMl: record.volumeMl,
          durationMinutes: record.durationMinutes,
          note: record.note,
        ),
        BabySleepRecord() => BabySleepRecord(
          id: record.id,
          babyId: record.babyId,
          version: version,
          occurredAt: record.occurredAt,
          endedAt: record.endedAt,
          note: record.note,
        ),
        BabyDiaperRecord() => BabyDiaperRecord(
          id: record.id,
          babyId: record.babyId,
          version: version,
          occurredAt: record.occurredAt,
          kind: record.kind,
          color: record.color,
          consistency: record.consistency,
          signs: record.signs,
          note: record.note,
        ),
        BabyGrowthRecord() => BabyGrowthRecord(
          id: record.id,
          babyId: record.babyId,
          version: version,
          recordedOn: record.recordedOn,
          timezone: record.timezone,
          metric: record.metric,
          value: record.value,
          savedAt: record.savedAt,
          measurementSource: record.measurementSource,
        ),
        BabyDevelopmentRecord() => BabyDevelopmentRecord(
          id: record.id,
          babyId: record.babyId,
          version: version,
          recordedOn: record.recordedOn,
          timezone: record.timezone,
          itemId: record.itemId,
          status: record.status,
        ),
        BabyDailyStatusRecord() => BabyDailyStatusRecord(
          id: record.id,
          babyId: record.babyId,
          version: version,
          recordedOn: record.recordedOn,
          timezone: record.timezone,
          savedAt: record.savedAt,
          mentalState: record.mentalState,
          wetCount: record.wetCount,
          stoolCount: record.stoolCount,
          color: record.color,
          consistency: record.consistency,
        ),
      };

  Future<void> _restoreRecord(
    BabyRecord record, {
    required int expectedVersion,
  }) async {
    final c = widget.controller;
    final baby = c.baby;
    if (baby == null || record.babyId != baby.id) return;
    try {
      await c.recordRepository.restore(
        record.id,
        babyId: baby.id,
        expectedVersion: expectedVersion,
      );
      if (!mounted || !identical(c, widget.controller)) return;
      await _refreshAfterMutation(record.recordKind);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('记录已恢复')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('恢复失败，请刷新后重试。')));
      }
    }
  }

  List<BabyRecord> _managedRecords(BabyHomeController c) {
    final babyId = c.baby?.id;
    if (babyId == null) return const [];
    final byId = <String, BabyRecord>{};
    for (final record in [
      ...?c.recentRecords.value,
      ...?c.latestGrowth.value,
      ...?c.growthCurve.value,
    ]) {
      if (record.babyId == babyId) byId[record.id] = record;
    }
    final values = byId.values.toList();
    values.sort((a, b) => _recordSortTime(b).compareTo(_recordSortTime(a)));
    return values;
  }

  DateTime _recordSortTime(BabyRecord record) => switch (record) {
    TimedBabyRecord(:final occurredAt) => occurredAt,
    BabyDailyStatusRecord(:final savedAt) => savedAt,
    DatedBabyRecord(:final recordedOn) => DateTime.utc(
      recordedOn.year,
      recordedOn.month,
      recordedOn.day,
    ),
  };

  String _recordTitle(BabyRecord record) => switch (record) {
    BabyFeedingRecord() => '喂养记录',
    BabySleepRecord() => '睡眠记录',
    BabyDiaperRecord() => '尿布记录',
    BabyGrowthRecord(:final metric) => '${growthMetricLabelZh(metric)}记录',
    BabyDailyStatusRecord() => '每日状态',
    BabyDevelopmentRecord() => '发育观察',
  };

  String _recordFactsZh(BabyRecord record) => switch (record) {
    BabyFeedingRecord(
      :final method,
      :final side,
      :final volumeMl,
      :final durationMinutes,
    ) =>
      [
        switch (method) {
          BabyFeedingMethod.breastfeeding => '亲喂',
          BabyFeedingMethod.expressedMilk => '瓶喂母乳',
          BabyFeedingMethod.formula => '配方奶',
        },
        if (side != null)
          switch (side) {
            FeedingSide.left => '左侧',
            FeedingSide.right => '右侧',
            FeedingSide.both => '双侧',
          },
        if (volumeMl != null) '${babyNumber(volumeMl)} ml',
        if (durationMinutes != null) '$durationMinutes 分钟',
      ].join(' · '),
    BabySleepRecord(:final occurredAt, :final endedAt) =>
      endedAt == null
          ? '正在睡眠'
          : '${endedAt.difference(occurredAt).inMinutes} 分钟',
    BabyDiaperRecord(:final kind) => switch (kind) {
      DiaperKind.wet => '湿尿布',
      DiaperKind.dirty => '脏尿布',
      DiaperKind.both => '湿尿布和脏尿布',
    },
    BabyGrowthRecord(:final value, :final unit, :final recordedOn) =>
      '${babyNumber(value)} $unit · $recordedOn',
    BabyDailyStatusRecord(:final recordedOn) => '$recordedOn',
    BabyDevelopmentRecord(:final recordedOn) => '$recordedOn',
  };

  Widget _recordManagement(BabyHomeController c) {
    final records = _managedRecords(c);
    if (records.isEmpty) {
      return _notice('还没有可管理的记录', '保存记录后，可在这里编辑或删除。');
    }
    return _surface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < records.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            ListTile(
              key: ValueKey('baby-record-${records[index].id}'),
              title: Text(_recordTitle(records[index])),
              subtitle: Text(_recordFactsZh(records[index])),
              trailing: PopupMenuButton<String>(
                key: ValueKey('baby-record-menu-${records[index].id}'),
                tooltip: '管理记录',
                onSelected: (action) {
                  if (action == 'edit') {
                    unawaited(_editRecord(records[index]));
                  } else if (action == 'delete') {
                    unawaited(_deleteRecord(records[index]));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('chat-first-baby-details-page'),
    color: const Color(0xFFFFFDFA),
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final baby = c.baby;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
            children: [
              const Text(
                '宝宝记录与管理',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF322C33),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '仅显示当前账号保存的宝宝资料和记录。',
                style: TextStyle(fontSize: 13, color: Color(0xFF77717B)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('baby-details-knowledge'),
                  onPressed: () =>
                      showChatFirstBabyKnowledge(context, onAsk: widget.onAsk),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('照护知识'),
                ),
              ),
              const SizedBox(height: 20),
              if (c.profiles.loading && !c.profiles.hasValue)
                const Center(child: CircularProgressIndicator())
              else if (c.profiles.failure != null && !c.profiles.hasValue)
                _notice(
                  '暂时无法加载宝宝资料',
                  '请检查网络后重试，不会显示演示数据。',
                  action: TextButton(onPressed: _load, child: const Text('重试')),
                )
              else ...[
                if (c.profiles.failure != null)
                  _notice(
                    '宝宝资料更新失败',
                    '下方可能是之前保存的数据，请下拉重试。',
                    action: TextButton(
                      onPressed: _load,
                      child: const Text('重试'),
                    ),
                  ),
                if (baby == null)
                  _notice(
                    '当前账号还没有宝宝资料',
                    '添加宝宝资料后，就可以查看并记录对应宝宝的照护信息。',
                    action: FilledButton(
                      key: const ValueKey('baby-details-add-empty'),
                      onPressed: _editProfile,
                      child: const Text('添加宝宝资料'),
                    ),
                  )
                else ...[
                  _profileCard(c, baby),
                  const SizedBox(height: 24),
                  _sectionTitle('今日照护'),
                  const SizedBox(height: 11),
                  if (c.recentRecords.failure != null)
                    _notice(
                      '今日记录暂时无法读取',
                      '无法确认最新次数；请重试，不将读取失败当作没有记录。',
                      action: TextButton(
                        key: const ValueKey('baby-details-record-retry'),
                        onPressed: c.refreshRecords,
                        child: const Text('重试读取'),
                      ),
                    )
                  else if (!c.recentRecords.hasValue)
                    _notice('正在读取今日记录…', '请稍候。')
                  else
                    _todayRecords(c),
                  const SizedBox(height: 24),
                  _sectionTitle('生长记录'),
                  const SizedBox(height: 11),
                  if (c.latestGrowth.failure != null)
                    _notice(
                      '生长记录暂时无法读取',
                      '请重试，不会将读取失败显示为零。',
                      action: TextButton(
                        onPressed: c.refreshRecords,
                        child: const Text('重试读取'),
                      ),
                    )
                  else if (!c.latestGrowth.hasValue)
                    _notice('正在读取生长记录…', '请稍候。')
                  else
                    _growthRecords(c),
                  const SizedBox(height: 13),
                  BabyGrowthCurve(
                    baby: baby,
                    metric: _metric,
                    records: c.growthCurve,
                    onMetricChanged: (metric) =>
                        setState(() => _metric = metric),
                    onEditProfile: () => _editProfile(baby),
                    onRetry: c.refreshRecords,
                    chatFirstExperience: true,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('记录管理'),
                  const SizedBox(height: 11),
                  _recordManagement(c),
                ],
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _profileCard(BabyHomeController c, BabyProfile baby) => _surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                baby.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF322C33),
                ),
              ),
            ),
            if ((c.profiles.value?.length ?? 0) > 1)
              PopupMenuButton<String>(
                key: const ValueKey('baby-details-switch'),
                tooltip: '切换宝宝',
                enabled: !_selecting,
                onSelected: (id) => unawaited(_selectBaby(id)),
                itemBuilder: (context) => [
                  for (final profile in c.profiles.value!)
                    PopupMenuItem(value: profile.id, child: Text(profile.name)),
                ],
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          [
            switch (baby.sex) {
              BabySex.female => '女孩',
              BabySex.male => '男孩',
              BabySex.unspecified => '未填写出生时性别',
            },
            if (c.date != null && baby.ageDays(c.date!) != null)
              '出生 ${baby.ageDays(c.date!)} 天'
            else if (baby.birthDate == null)
              '未填写出生日期',
          ].join(' · '),
          style: const TextStyle(fontSize: 13, color: Color(0xFF77717B)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const ValueKey('baby-details-edit'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => _editProfile(baby),
              child: const Text('编辑宝宝资料'),
            ),
            TextButton(
              key: const ValueKey('baby-details-add'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _editProfile,
              child: const Text('添加另一个宝宝'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _todayRecords(BabyHomeController c) {
    final summary = c.summary;
    if (summary == null) return _notice('今日记录暂不可用', '请下拉重试。');
    return Column(
      children: [
        _recordRow(
          key: const ValueKey('baby-details-feeding'),
          title: '今天喂养 ${summary.feedingCount} 次',
          subtitle: '记录亲喂或瓶喂，仅展示当前宝宝的真实记录',
          icon: Icons.local_dining_outlined,
          onTap: () => _record(BabyRecordKind.feeding),
        ),
        const SizedBox(height: 9),
        _recordRow(
          key: const ValueKey('baby-details-mood'),
          title: '喂养后状态',
          subtitle: summary.latestMentalState == null
              ? '今天还没有记录'
              : babyMentalLabelsZh[summary.latestMentalState]!,
          icon: Icons.mood_outlined,
          onTap: () => _record(BabyRecordKind.dailyStatus),
        ),
        const SizedBox(height: 9),
        _recordRow(
          key: const ValueKey('baby-details-wet'),
          title: '今日湿尿布 ${summary.wetCount} 次',
          subtitle: '查看并更新今天的累计次数',
          icon: Icons.water_drop_outlined,
          onTap: () =>
              _record(BabyRecordKind.dailyStatus, diaper: DiaperKind.wet),
        ),
        const SizedBox(height: 9),
        _recordRow(
          key: const ValueKey('baby-details-dirty'),
          title: '今日脏尿布 ${summary.dirtyCount} 次',
          subtitle: '查看并更新今天的累计次数',
          icon: Icons.edit_note_outlined,
          onTap: () =>
              _record(BabyRecordKind.dailyStatus, diaper: DiaperKind.dirty),
        ),
        const SizedBox(height: 9),
        if (widget.onRecordSleep case final open?)
          _recordRow(
            key: const ValueKey('baby-details-sleep'),
            title: '今天睡眠 ${summary.sleepCount} 次',
            subtitle: '填写当前宝宝的睡眠时间',
            icon: Icons.bedtime_outlined,
            onTap: () {
              final babyId = c.baby?.id;
              if (babyId != null) unawaited(open(babyId));
            },
          )
        else
          _surface(
            child: Row(
              children: [
                const Icon(Icons.bedtime_outlined, color: Color(0xFF977A86)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('今天睡眠 ${summary.sleepCount} 次 · 可从对话首页记录'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _growthRecords(BabyHomeController c) => Column(
    children: [
      for (final metric in GrowthMetric.values) ...[
        if (metric != GrowthMetric.weight) const SizedBox(height: 9),
        _growthRow(c, metric),
      ],
    ],
  );

  Widget _growthRow(BabyHomeController c, GrowthMetric metric) {
    final latest = c.latestGrowth.value!
        .where(
          (record) => record.metric == metric && record.babyId == c.baby?.id,
        )
        .firstOrNull;
    return _recordRow(
      key: ValueKey('baby-details-growth-${metric.name}'),
      title: growthMetricLabelZh(metric),
      subtitle: latest == null
          ? '还没有保存的记录'
          : '${babyNumber(latest.value)} ${latest.unit} · ${latest.recordedOn}',
      icon: Icons.show_chart_rounded,
      onTap: () => _record(BabyRecordKind.growth, metric: metric),
    );
  }

  Widget _recordRow({
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) => _surface(
    padding: EdgeInsets.zero,
    child: Semantics(
      label: '$title，$subtitle，点按填写',
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF977A86), size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF77717B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF977A86),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _notice(String title, String description, {Widget? action}) =>
      _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF77717B)),
            ),
            if (action != null) ...[const SizedBox(height: 13), action],
          ],
        ),
      );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(17),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE9E8ED)),
      borderRadius: BorderRadius.circular(17),
    ),
    child: child,
  );
}
