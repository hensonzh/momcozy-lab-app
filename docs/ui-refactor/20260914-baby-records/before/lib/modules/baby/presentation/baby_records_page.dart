import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../../../shared/zoned_time.dart';
import '../application/baby_records_controller.dart';
import 'baby_labels.dart';
import 'baby_record_editor.dart';

class BabyRecordsPage extends StatefulWidget {
  const BabyRecordsPage({
    super.key,
    required this.babyId,
    required this.profiles,
    required this.repository,
    required this.timezoneProvider,
    required this.now,
    required this.onBack,
    this.initialKind = BabyRecordKind.feeding,
    this.onPrivacy,
  });
  final String babyId;
  final BabyProfileRepository profiles;
  final BabyRecordRepository repository;
  final Future<String> Function() timezoneProvider;
  final DateTime Function() now;
  final VoidCallback onBack;
  final BabyRecordKind initialKind;
  final VoidCallback? onPrivacy;
  @override
  State<BabyRecordsPage> createState() => _BabyRecordsPageState();
}

class _BabyRecordsPageState extends State<BabyRecordsPage> {
  BabyRecordsController? _controller;
  ProductFailure? _failure;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant BabyRecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.babyId != widget.babyId ||
        !identical(oldWidget.repository, widget.repository)) {
      _controller?.dispose();
      _controller = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _failure = null);
    try {
      final data = await Future.wait<Object>([
        widget.profiles.list(),
        widget.timezoneProvider(),
      ]);
      if (!mounted || generation != _generation) return;
      final baby = (data[0] as List<BabyProfile>)
          .where((value) => value.id == widget.babyId)
          .firstOrNull;
      if (baby == null) {
        throw const ProductFailure(ProductFailureKind.forbidden);
      }
      final controller = BabyRecordsController(
        repository: widget.repository,
        baby: baby,
        timezone: data[1] as String,
        now: widget.now,
        kind: widget.initialKind,
      );
      setState(() => _controller = controller);
      await controller.load();
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _failure = error is ProductFailure
              ? error
              : const ProductFailure(ProductFailureKind.unavailable),
        );
      }
    }
  }

  Future<void> _edit([BabyRecord? record]) async {
    final c = _controller!;
    final result = await showBabyRecordEditor(
      context,
      repository: c.repository,
      baby: c.baby,
      timezone: c.timezone,
      now: c.now,
      kind: c.kind,
      initial: record,
    );
    if (!mounted) return;
    // Also refresh after an uncertain save was dismissed.
    if (identical(c, _controller)) await c.load();
    if (result != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('记录已保存')));
    }
  }

  Future<void> _delete(BabyRecord record) async {
    final c = _controller!;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('删除这条记录？'),
        content: Text(
          '${c.baby.name} · ${babyRecordFacts(record)}\n删除后可以在当前页面撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await c.delete(record);
  }

  Future<void> _month() async {
    final c = _controller!,
        today = dateInTimezone(widget.now(), _controller!.timezone);
    final value = await showMomCozyDatePicker(
      context: context,
      initialDate: DateTime(c.month.year, c.month.month),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: '选择要查看的记录月份',
    );
    if (value != null && mounted) {
      await c.select(month: LocalDate.fromDateTime(value));
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MomCozyColors.background,
    appBar: AppBar(
      backgroundColor: MomCozyColors.background,
      toolbarHeight: 44,
      leadingWidth: 80,
      leading: TextButton(
        onPressed: widget.onBack,
        child: const Text(
          '返回',
          style: TextStyle(fontSize: 12, color: MomCozyColors.mutedForeground),
        ),
      ),
    ),
    body: MomCozyPageBody(
      child: _failure != null
          ? SingleChildScrollView(
              child: ProductErrorView(failure: _failure!, onRetry: _load),
            )
          : _controller == null
          ? const ProductLoadingView()
          : AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) {
                final c = _controller!, values = _controller!.records.value;
                final today = dateInTimezone(c.now(), c.timezone);
                return RefreshIndicator(
                  onRefresh: c.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        '${c.baby.name} 的记录',
                        style: const TextStyle(
                          fontSize: 25,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: MomCozyColors.muted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final kind in BabyRecordKind.values)
                                Semantics(
                                  selected: c.kind == kind,
                                  child: TextButton(
                                    onPressed: c.canChange
                                        ? () => c.select(kind: kind)
                                        : null,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(60, 44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      backgroundColor: c.kind == kind
                                          ? MomCozyColors.raised
                                          : Colors.transparent,
                                      foregroundColor: c.kind == kind
                                          ? MomCozyColors.primaryDark
                                          : MomCozyColors.mutedForeground,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(fontSize: 12),
                                    ),
                                    child: Text(babyRecordLabels[kind]!),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.content),
                      Row(
                        children: [
                          IconButton(
                            tooltip: '上个月',
                            onPressed: c.canChange && c.month.year > 1900
                                ? () => c.select(month: c.month.addMonths(-1))
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: c.canChange ? _month : null,
                              child: Text(
                                '${c.month.year}年${c.month.month}月',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '下个月',
                            onPressed:
                                c.canChange &&
                                    c.month.addMonths(1).compareTo(today) <= 0
                                ? () => c.select(month: c.month.addMonths(1))
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      if (c.mutationFailure != null)
                        ProductErrorView(
                          failure: c.mutationFailure!,
                          onRetry: c.uncertainMutation
                              ? c.retryMutation
                              : c.load,
                        ),
                      if (c.uncertainMutation)
                        const Text('操作结果还未确认，请重试确认后再修改其他记录。'),
                      if (c.deletion != null)
                        Container(
                          padding: const EdgeInsets.all(MomCozySpacing.content),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: MomCozyColors.careSoft,
                            borderRadius: BorderRadius.circular(
                              MomCozyRadii.control,
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('记录已删除'),
                              TextButton(
                                onPressed: c.busy ? null : c.undo,
                                child: const Text('撤销删除'),
                              ),
                            ],
                          ),
                        ),
                      if (c.records.failure != null)
                        ProductErrorView(
                          failure: c.records.failure!,
                          onRetry: c.load,
                        ),
                      if (c.records.loading) const ProductLoadingView(),
                      if (values != null && values.isEmpty)
                        ProductEmptyView(
                          textAlign: TextAlign.start,
                          title: '本月还没有${babyRecordLabels[c.kind]}记录',
                          description: '没有记录不会计为 0，也可以切换月份查看。',
                          action: FilledButton(
                            onPressed: c.canChange ? _edit : null,
                            child: const Text('去记录'),
                          ),
                        ),
                      if (values != null && values.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '本月共 ${c.total} 条 · 手动记录',
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.6,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                        ),
                        for (final record in values)
                          _RecordCard(
                            record: record,
                            timezone: c.timezone,
                            onEdit: c.canChange ? () => _edit(record) : null,
                            onDelete: c.canChange
                                ? () => _delete(record)
                                : null,
                          ),
                        if (c.pageFailure != null)
                          ProductErrorView(
                            failure: c.pageFailure!,
                            onRetry:
                                c.pageFailure!.kind ==
                                    ProductFailureKind.conflict
                                ? c.load
                                : c.more,
                          ),
                        if (c.hasMore)
                          TextButton(
                            onPressed: c.loadingMore || !c.canChange
                                ? null
                                : c.more,
                            child: Text(c.loadingMore ? '正在载入…' : '加载更多'),
                          ),
                        const SizedBox(height: MomCozySpacing.content),
                        OutlinedButton.icon(
                          onPressed: c.canChange ? _edit : null,
                          icon: const Icon(Icons.add),
                          label: const Text('添加记录'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: MomCozyColors.card,
                          border: Border.all(color: MomCozyColors.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: const MomCozyLineIcon(
                              MomCozyLineGlyph.shield,
                              size: 20,
                              color: MomCozyColors.care,
                            ),
                            title: const Text(
                              '数据来源',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              '手动记录 · 查看隐私',
                              style: TextStyle(fontSize: 11),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              14,
                              0,
                              14,
                              12,
                            ),
                            children: [
                              const Text(
                                '此列表显示当前宝宝主动填写并保存的记录。没有记录不会计为 0。',
                                style: TextStyle(fontSize: 12, height: 1.6),
                              ),
                              TextButton(
                                onPressed: widget.onPrivacy,
                                child: const Text('隐私与授权'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.timezone,
    required this.onEdit,
    required this.onDelete,
  });
  final BabyRecord record;
  final String timezone;
  final VoidCallback? onEdit, onDelete;
  String _instant(DateTime value) =>
      '${dateInTimezone(value, timezone)} ${zonedClock(value, timezone)} ${inTimezone(value, timezone).timeZoneName}';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MomCozySpacing.statusGap),
    child: MomCozySurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 33,
                height: 33,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MomCozyColors.roseSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: MomCozyLineIcon(
                  switch (record.recordKind) {
                    BabyRecordKind.feeding => MomCozyLineGlyph.baby,
                    BabyRecordKind.sleep => MomCozyLineGlyph.moon,
                    BabyRecordKind.diaper => MomCozyLineGlyph.drop,
                    BabyRecordKind.growth => MomCozyLineGlyph.plan,
                    BabyRecordKind.development => MomCozyLineGlyph.spark,
                  },
                  size: 18,
                  color: MomCozyColors.primaryDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  babyRecordFacts(record),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MomCozyBadge(
                record is BabySleepRecord &&
                        (record as BabySleepRecord).endedAt == null
                    ? '记录中'
                    : '已保存',
                compact: true,
                color: MomCozyColors.care,
                background: MomCozyColors.careSoft,
              ),
            ],
          ),
          const SizedBox(height: MomCozySpacing.compact),
          Text(
            switch (record) {
              DatedBabyRecord(:final recordedOn) => recordedOn.toString(),
              BabySleepRecord(:final occurredAt, :final endedAt) =>
                '${_instant(occurredAt)}${endedAt == null ? '' : '\n至 ${_instant(endedAt)}'}',
              TimedBabyRecord(:final occurredAt) => _instant(occurredAt),
            },
            style: const TextStyle(
              fontSize: 11,
              height: 1.6,
              color: MomCozyColors.mutedForeground,
            ),
          ),
          if (record case TimedBabyRecord(:final note))
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: MomCozySpacing.compact),
                child: Text(
                  '备注：$note',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: MomCozySpacing.compact,
            children: [
              TextButton(onPressed: onEdit, child: const Text('编辑')),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: MomCozyColors.danger,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
