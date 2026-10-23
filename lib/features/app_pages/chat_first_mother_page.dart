import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';

import 'data/chat_first_mother_repository.dart';
import 'chat_first_status_sheet.dart';

class ChatFirstMotherPage extends StatefulWidget {
  const ChatFirstMotherPage({
    super.key,
    required this.runtime,
    required this.role,
  });

  final MomCozyApiRuntime runtime;
  final FamilyRole role;

  @override
  State<ChatFirstMotherPage> createState() => _ChatFirstMotherPageState();
}

class _ChatFirstMotherPageState extends State<ChatFirstMotherPage>
    with WidgetsBindingObserver {
  Future<ChatFirstMotherSummary>? _summary;
  Future<ChatFirstPumpingToday>? _pumping;
  Future<({ChatFirstMilkTrend? value, bool failed})>? _trend;
  Future<({ChatFirstWellbeing? value, bool failed})>? _wellbeing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.runtime.recordRevision.addListener(_recordsChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant ChatFirstMotherPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime) {
      oldWidget.runtime.recordRevision.removeListener(_recordsChanged);
      widget.runtime.recordRevision.addListener(_recordsChanged);
    }
    if (oldWidget.runtime != widget.runtime ||
        oldWidget.role != widget.role ||
        oldWidget.runtime.currentSession.userId !=
            widget.runtime.currentSession.userId) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_load);
  }

  @override
  void dispose() {
    widget.runtime.recordRevision.removeListener(_recordsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _recordsChanged() {
    if (mounted) setState(_load);
  }

  void _load() {
    if (widget.role != FamilyRole.mother) {
      _summary = null;
      _pumping = null;
      _trend = null;
      _wellbeing = null;
      return;
    }
    final repository = ChatFirstMotherRepository(widget.runtime.jsonTransport);
    final now = widget.runtime.now();
    final timezone = widget.runtime.timezoneProvider();
    _summary = timezone.then((zone) => repository.get(now, timezone: zone));
    _pumping = timezone.then(
      (zone) => repository.getPumpingToday(now, timezone: zone),
    );
    _trend = _readTrend(repository, now);
    _wellbeing = _readWellbeing(repository, now);
  }

  void _reloadPumping() => setState(() {
    final repository = ChatFirstMotherRepository(widget.runtime.jsonTransport);
    final now = widget.runtime.now();
    _pumping = widget.runtime.timezoneProvider().then(
      (zone) => repository.getPumpingToday(now, timezone: zone),
    );
    _trend = _readTrend(repository, now);
  });

  void _reloadTrend() => setState(() {
    final repository = ChatFirstMotherRepository(widget.runtime.jsonTransport);
    _trend = _readTrend(repository, widget.runtime.now());
  });

  void _reloadWellbeing() => setState(() {
    _wellbeing = _readWellbeing(
      ChatFirstMotherRepository(widget.runtime.jsonTransport),
      widget.runtime.now(),
    );
  });

  Future<void> _addWellbeing() async {
    final runtime = widget.runtime;
    final ownerId = runtime.currentSession.userId;
    final saved = await showChatFirstStatusSheet(
      context,
      repository: ChatFirstMotherRepository(runtime.jsonTransport),
      now: runtime.now,
      isCurrentOwner: () =>
          mounted &&
          widget.role == FamilyRole.mother &&
          identical(runtime, widget.runtime) &&
          runtime.currentSession.userId == ownerId,
    );
    if (!mounted ||
        !identical(runtime, widget.runtime) ||
        runtime.currentSession.userId != ownerId) {
      return;
    }
    // A failed response may still have committed; read authoritative state
    // even if the user closed the sheet without an acknowledged response.
    _reloadWellbeing();
    if (saved != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('状态已保存到当前账号')));
    }
  }

  Future<({ChatFirstWellbeing? value, bool failed})> _readWellbeing(
    ChatFirstMotherRepository repository,
    DateTime now,
  ) async {
    try {
      return (
        value: await repository.getWellbeing(
          now,
          timezone: await widget.runtime.timezoneProvider(),
        ),
        failed: false,
      );
    } catch (_) {
      return (value: null, failed: true);
    }
  }

  Future<({ChatFirstMilkTrend? value, bool failed})> _readTrend(
    ChatFirstMotherRepository repository,
    DateTime now,
  ) async {
    try {
      return (
        value: await repository.getMilkTrend(
          now,
          timezone: await widget.runtime.timezoneProvider(),
        ),
        failed: false,
      );
    } catch (_) {
      // A route can be disposed before its lazy card is built. Do not leak an
      // unhandled failure; keep the maternal profile and offer an explicit retry.
      return (value: null, failed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != FamilyRole.mother) {
      return _message(
        '未填写妈妈资料',
        '当前账号以${widget.role.label}身份加入，尚未提供妈妈资料。这里不会显示演示用的分娩信息。',
      );
    }
    return ColoredBox(
      color: const Color(0xFFFFFDFA),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '妈妈',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              const Text(
                '记录自己的变化，也照顾好自己。这里只显示当前账号已保存的信息。',
                style: TextStyle(color: Color(0xFF786E6B)),
              ),
              const SizedBox(height: 20),
              _profileSection(),
              const SizedBox(height: 20),
              _wellbeingSection(),
              const SizedBox(height: 16),
              _pumpingSection(),
              const SizedBox(height: 16),
              _trendSection(),
              const SizedBox(height: 20),
              _concernsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pumpingSection() => Card(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFEDE6E3)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: FutureBuilder<ChatFirstPumpingToday>(
        future: _pumping,
        builder: (context, snapshot) {
          final today = snapshot.data;
          final String result;
          if (snapshot.connectionState != ConnectionState.done) {
            result = '正在读取今天的吸奶记录…';
          } else if (snapshot.hasError || today == null) {
            result = '暂时无法读取吸奶记录';
          } else if (today.count == 0) {
            result = '今天还没有吸奶记录';
          } else if (today.mayBeTruncated) {
            result = '今天至少 ${today.count} 次 · 数据可能不完整';
          } else if (today.measuredVolumeMl == null) {
            result = '今天 ${today.count} 次 · 部分记录未填写奶量';
          } else {
            result =
                '${_number(today.measuredVolumeMl!)} ml · ${today.count} 次';
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '今日吸奶记录',
                      style: TextStyle(fontSize: 13, color: Color(0xFF786E6B)),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('mother-pumping-refresh'),
                    tooltip: '刷新吸奶记录',
                    onPressed: _reloadPumping,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF322C33),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '这里读取首页「记录」使用的同一账号吸奶记录。',
                style: TextStyle(color: Color(0xFF786E6B)),
              ),
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasError)
                TextButton(onPressed: _reloadPumping, child: const Text('重试'))
              else if (snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError &&
                  today != null &&
                  today.count > 0)
                TextButton(
                  key: const ValueKey('mother-pumping-details'),
                  onPressed: () => _showPumpingDetails(today),
                  child: const Text('查看今天的记录'),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _trendSection() => SizedBox(
    width: double.infinity,
    child: Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEDE6E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: FutureBuilder<({ChatFirstMilkTrend? value, bool failed})>(
          future: _trend,
          builder: (context, snapshot) {
            final trend = snapshot.connectionState == ConnectionState.done
                ? snapshot.data?.value
                : null;
            final failed =
                snapshot.connectionState == ConnectionState.done &&
                snapshot.data?.failed == true;
            final String summary;
            if (snapshot.connectionState != ConnectionState.done) {
              summary = '正在读取近 7 天记录…';
            } else if (failed || trend == null) {
              summary = '暂时无法加载奶量趋势';
            } else if (!trend.hasCompleteWindow) {
              summary = '近 7 天记录未完整读取';
            } else if (!trend.hasSavedPumping) {
              summary = '近 7 天没有保存吸奶记录';
            } else {
              final savedDays = trend.days
                  .where((day) => day.pumpingCount > 0)
                  .length;
              summary = '近 7 天有 $savedDays 天保存吸奶记录';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '奶量趋势',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(summary, style: const TextStyle(color: Color(0xFF786E6B))),
                if (trend != null &&
                    trend.hasCompleteWindow &&
                    trend.hasSavedPumping)
                  _inlineMilkTrend(trend),
                if (snapshot.connectionState == ConnectionState.done && failed)
                  TextButton(
                    key: const ValueKey('mother-milk-trend-retry'),
                    onPressed: _reloadTrend,
                    child: const Text('重试'),
                  )
                else if (snapshot.connectionState == ConnectionState.done &&
                    trend != null &&
                    trend.days.isNotEmpty)
                  TextButton(
                    key: const ValueKey('mother-milk-trend'),
                    onPressed: () => _showMilkTrend(trend),
                    child: const Text('查看近 7 天记录'),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _inlineMilkTrend(ChatFirstMilkTrend trend) {
    final values = trend.days.reversed.toList();
    final maxVolume = values
        .where((day) => day.pumpingCount > 0 && day.measuredVolumeMl != null)
        .fold<double>(
          0,
          (max, day) =>
              day.measuredVolumeMl! > max ? day.measuredVolumeMl! : max,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近 7 天 · 已记录奶量',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final day in values)
            Padding(
              key: ValueKey(
                'mother-milk-row-${day.date.month}-${day.date.day}',
              ),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text('${day.date.month}/${day.date.day}'),
                  ),
                  Expanded(
                    child: day.pumpingCount == 0 || day.measuredVolumeMl == null
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: maxVolume == 0
                                  ? 0
                                  : (day.measuredVolumeMl! / maxVolume).clamp(
                                      .06,
                                      1.0,
                                    ),
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB54F78),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 102,
                    child: Text(
                      day.pumpingCount == 0
                          ? '未记录'
                          : day.measuredVolumeMl == null
                          ? '奶量未填全 · ${day.pumpingCount} 次'
                          : '${_number(day.measuredVolumeMl!)} ml · ${day.pumpingCount} 次',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            '未记录不代表没有吸奶；奶量未填全不计入精确均值。',
            style: TextStyle(fontSize: 12, color: Color(0xFF786E6B)),
          ),
        ],
      ),
    );
  }

  void _showMilkTrend(ChatFirstMilkTrend trend) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '近 7 天记录奶量',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('mother-milk-trend-close'),
                      tooltip: '关闭奶量趋势',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    const Text(
                      '仅统计当前账号保存的吸奶记录；未记录不代表没有吸奶。',
                      style: TextStyle(color: Color(0xFF786E6B)),
                    ),
                    if (trend.averageDailyMl case final average?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '按 7 天均摊已记录奶量 ${average.toStringAsFixed(1)} ml/天；未记录不代表没有吸奶。',
                        ),
                      )
                    else if (!trend.hasCompleteWindow || trend.hasSavedPumping)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('记录不完整或奶量未填写，无法计算准确的近 7 天均摊值。'),
                      ),
                    for (final day in trend.days.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${day.date.month}月${day.date.day}日'),
                        subtitle: Text(
                          !day.complete
                              ? '记录可能不完整'
                              : day.pumpingCount == 0
                              ? '未记录'
                              : day.measuredVolumeMl == null
                              ? '有记录 · 奶量未完整填写'
                              : '${_number(day.measuredVolumeMl!)} ml · ${day.pumpingCount} 次',
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

  Widget _wellbeingSection() => SizedBox(
    width: double.infinity,
    child: Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEDE6E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: FutureBuilder<({ChatFirstWellbeing? value, bool failed})>(
          future: _wellbeing,
          builder: (context, snapshot) {
            final status = snapshot.connectionState == ConnectionState.done
                ? snapshot.data?.value
                : null;
            final failed =
                snapshot.connectionState == ConnectionState.done &&
                snapshot.data?.failed == true;
            final String summary;
            if (snapshot.connectionState != ConnectionState.done) {
              summary = '正在读取已保存的状态记录…';
            } else if (failed || status == null) {
              summary = '暂时无法加载状态记录';
            } else if (status.recordCount == 0) {
              summary = '最近 2 天没有已保存状态记录';
            } else {
              summary = '最近 2 天有 ${status.recordCount} 条已保存状态记录';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '身体与状态',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(summary, style: const TextStyle(color: Color(0xFF786E6B))),
                if (status != null && status.recordCount > 0) ...[
                  const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final kind in [
                        MeMetric.sleep,
                        MeMetric.energy,
                        MeMetric.mood,
                      ])
                        Expanded(child: _recentStatus(status, kind)),
                    ],
                  ),
                ],
                if (snapshot.connectionState == ConnectionState.done && failed)
                  TextButton(
                    key: const ValueKey('mother-wellbeing-retry'),
                    onPressed: _reloadWellbeing,
                    child: const Text('重试'),
                  )
                else if (snapshot.connectionState == ConnectionState.done &&
                    status != null)
                  TextButton(
                    key: const ValueKey('mother-wellbeing'),
                    onPressed: () => _showWellbeing(status),
                    child: const Text('查看最近状态'),
                  ),
                TextButton.icon(
                  key: const ValueKey('mother-status-add'),
                  onPressed: _addWellbeing,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('记录我的状态'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _recentStatus(ChatFirstWellbeing status, MeMetric kind) {
    final recent = status.days.reversed
        .expand(
          (day) => day.records.map((record) => (day: day, record: record)),
        )
        .where((item) => item.record.kind == kind)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9F4F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _wellbeingLabel(kind),
                style: const TextStyle(fontSize: 12, color: Color(0xFF786E6B)),
              ),
              const SizedBox(height: 7),
              Text(
                recent == null ? '未记录' : _wellbeingValue(recent.record),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (recent != null)
                Text(
                  '${recent.day.date.month}/${recent.day.date.day} 记录',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF786E6B),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWellbeing(ChatFirstWellbeing status) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '最近 2 天身体与状态',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('mother-wellbeing-close'),
                      tooltip: '关闭身体与状态',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    const Text(
                      '仅展示当前账号保存的自述状态，不推断健康状况。',
                      style: TextStyle(color: Color(0xFF786E6B)),
                    ),
                    for (final day in status.days.reversed) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${day.date.month}月${day.date.day}日',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (day.records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('当天没有状态记录'),
                        )
                      else
                        for (final record in day.records)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_wellbeingLabel(record.kind)),
                            subtitle: Text(_wellbeingValue(record)),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _wellbeingLabel(MeMetric kind) => switch (kind) {
    MeMetric.energy => '精力',
    MeMetric.sleep => '睡眠',
    MeMetric.mood => '心情',
    MeMetric.pain => '哺乳疼痛',
    _ => '状态记录',
  };

  String _wellbeingValue(MeObservation record) {
    final value = record.displayValue;
    return switch (value) {
      'Energized' => '有力气',
      'Doing well' => '状态不错',
      'Managing' || 'Getting by' => '还撑得住',
      'Exhausted' || 'Feeling worn down' || 'Worn down' => '很疲惫',
      'Less than 3 hours' => '少于 3 小时',
      '3–4 hours' => '3–4 小时',
      '4–5 hours' => '4–5 小时',
      '5–6 hours' => '5–6 小时',
      'Over 6 hours' => '6 小时以上',
      'Not sure' => '不确定',
      'Having a hard day' => '不太好',
      'Okay' => '一般',
      'Good' => '不错',
      'Review saved record' => '记录内容需核对',
      _ when record.kind == MeMetric.pain => value,
      _ => '记录内容需核对',
    };
  }

  Widget _profileSection() => FutureBuilder<ChatFirstMotherSummary>(
    future: _summary,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _message(
          '暂时无法加载妈妈资料',
          '请检查网络后重试；已填写的资料仍保存在当前账号中。',
          onRetry: () => setState(
            () => _summary = widget.runtime.timezoneProvider().then(
              (zone) => ChatFirstMotherRepository(
                widget.runtime.jsonTransport,
              ).get(widget.runtime.now(), timezone: zone),
            ),
          ),
        );
      }
      final facts = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '妈妈资料',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFDFC), Color(0xFFFBEAF0)],
              ),
              border: Border.all(color: const Color(0xFFEDE6E3)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 13, left: 3),
                    child: Text(
                      '妈妈的空间',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF322C33),
                      ),
                    ),
                  ),
                  if (facts.postpartumDay case final day?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '产后第 $day 天',
                        key: const ValueKey('mother-postpartum-day'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB54F78),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileFact(
                        '年龄',
                        facts.age == null ? '未填写' : '${facts.age} 岁',
                      ),
                      _profileFact(
                        '生育次数',
                        facts.deliveryCount == null
                            ? '未填写'
                            : '第 ${facts.deliveryCount} 次',
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileFact('分娩日期', facts.deliveryDate ?? '未填写'),
                      _profileFact(
                        '分娩时孕周',
                        facts.gestationWeeks == null
                            ? '未填写'
                            : (facts.gestationDays ?? 0) > 0
                            ? '${facts.gestationWeeks} 周 + ${facts.gestationDays} 天'
                            : '${facts.gestationWeeks} 周',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _profileFact(
                        '这次的宝宝数量',
                        facts.babyCount?.toString() ?? '未填写',
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _concernsSection() => FutureBuilder<ChatFirstMotherSummary>(
    future: _summary,
    builder: (context, snapshot) {
      final facts = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      if (facts == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            '已保存的关注点',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          if (facts.concerns.isEmpty)
            const Text('暂未选择关注点', style: TextStyle(color: Color(0xFF786E6B)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final concern in facts.concerns)
                  Chip(
                    label: Text(concern),
                    backgroundColor: const Color(0xFFF6E9EC),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const Text(
            '旧版泌乳管理中的记录独立保存，不会与首页「记录」的吸奶数据合并。',
            style: TextStyle(fontSize: 12, color: Color(0xFF786E6B)),
          ),
          TextButton.icon(
            onPressed: () => context.go('/me/lactation'),
            icon: const Icon(Icons.favorite_outline),
            label: const Text('查看旧版泌乳管理'),
          ),
        ],
      );
    },
  );

  Future<void> _editPumping(PumpMilkRecord record) async {
    var draft = record.measuredVolumeMl?.toString() ?? '';
    try {
      final volume = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('编辑吸奶记录'),
          content: TextFormField(
            key: const ValueKey('pumping-edit-volume'),
            initialValue: draft,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => draft = value,
            decoration: const InputDecoration(
              labelText: '奶量',
              suffixText: 'ml',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('pumping-edit-save'),
              onPressed: () {
                final value = double.tryParse(draft.trim());
                if (value != null && value > 0 && value <= 3000) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (volume == null || !mounted) return;
      await RecordsApiRepository(
        transport: widget.runtime.jsonTransport,
      ).updatePumpMilkRecord(recordId: record.id, milkVolumeMl: volume);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.runtime.notifyRecordsChanged();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('吸奶记录已更新')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新失败，记录未发生变化。')));
      }
    }
  }

  Future<void> _deletePumping(PumpMilkRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条吸奶记录？'),
        content: const Text('删除后可在提示出现时立即恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('pumping-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repository = RecordsApiRepository(
        transport: widget.runtime.jsonTransport,
      );
      await repository.deletePumpMilkRecord(record.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.runtime.notifyRecordsChanged();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('吸奶记录已删除'),
            action: SnackBarAction(
              label: '恢复',
              onPressed: () => unawaited(_restorePumping(record.id)),
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

  Future<void> _restorePumping(String recordId) async {
    try {
      await RecordsApiRepository(
        transport: widget.runtime.jsonTransport,
      ).restorePumpMilkRecord(recordId);
      if (!mounted) return;
      widget.runtime.notifyRecordsChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('吸奶记录已恢复')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('恢复失败，请刷新后重试。')));
      }
    }
  }

  void _showPumpingDetails(ChatFirstPumpingToday today) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '今天的吸奶记录',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('mother-pumping-close'),
                    tooltip: '关闭吸奶记录',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (today.mayBeTruncated)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('仅显示最近 100 条记录。'),
                ),
              for (final record in today.records)
                ListTile(
                  key: ValueKey('pumping-record-${record.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    record.measuredVolumeMl == null
                        ? '未填写奶量'
                        : '${_number(record.measuredVolumeMl!)} ml',
                  ),
                  subtitle: Text(_time(record)),
                  trailing: PopupMenuButton<String>(
                    key: ValueKey('pumping-record-menu-${record.id}'),
                    onSelected: (action) {
                      if (action == 'edit') {
                        unawaited(_editPumping(record));
                      } else if (action == 'delete') {
                        unawaited(_deletePumping(record));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _time(PumpMilkRecord record) {
    final at = record.occurredAt?.toLocal();
    if (at == null) return '时间未提供';
    return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Widget _profileFact(String label, String value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF786E6B)),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    ),
  );

  Widget _message(String title, String description, {VoidCallback? onRetry}) =>
      ColoredBox(
        color: const Color(0xFFFFFDFA),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF786E6B), height: 1.5),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
}
