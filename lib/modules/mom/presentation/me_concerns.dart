import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../features/notifications/domain/notification_permission.dart';
import '../../../features/notifications/presentation/notification_scope.dart';
import '../application/me_controller.dart';
import '../domain/me_experience.dart';
import 'me_design.dart';

Future<bool?> showMeConcernFlow(
  BuildContext context,
  MeController controller, {
  MeConcern? initial,
}) => Navigator.of(context, rootNavigator: true).push<bool>(
  MaterialPageRoute(
    builder: (_) => MeConcernFlow(controller: controller, initial: initial),
  ),
);

class MeConcernFlow extends StatefulWidget {
  const MeConcernFlow({super.key, required this.controller, this.initial});
  final MeController controller;
  final MeConcern? initial;
  @override
  State<MeConcernFlow> createState() => _MeConcernFlowState();
}

class _MeConcernFlowState extends State<MeConcernFlow>
    with WidgetsBindingObserver {
  late final id = widget.initial?.id ?? const Uuid().v4();
  late final selected = <MeIssue>{...?widget.initial?.issues};
  late final note = TextEditingController(text: widget.initial?.note ?? '');
  late bool reminder = widget.initial?.reminder ?? true;
  bool confirmation = false, busy = false, failed = false;
  Completer<void>? resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    note.dispose();
    resumed?.complete();
    resumed = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumed?.complete();
      resumed = null;
    }
  }

  List<MeIssue> get issues => MeIssue.values.where(selected.contains).toList();
  Future<void> confirm() async {
    if (busy || selected.isEmpty) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.controller.saveConcern(
        MeConcern(
          id: id,
          issues: issues,
          note: selected.contains(MeIssue.other) ? note.text.trim() : '',
          reminder: reminder,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    final coordinator = NotificationScope.maybeOf(context);
    try {
      if (reminder && coordinator != null) {
        final permission = await coordinator.permission.refresh();
        if (!mounted) return;
        if (permission == NotificationPermission.notDetermined) {
          // Direct native authorization: no custom primer, and home stays behind this route.
          try {
            await coordinator.permission.platform.requestPermission();
            await coordinator.refresh();
          } catch (_) {
            /* A failed or cancelled request does not undo the saved concern. */
          }
        } else if (permission == NotificationPermission.denied) {
          final go = await showMeNotificationSettings(context);
          if (go == true && mounted) {
            resumed = Completer<void>();
            try {
              await coordinator.permission.platform.openSettings();
              await resumed?.future;
              await coordinator.refresh();
            } catch (_) {
              resumed = null;
            }
          }
        }
      }
    } catch (_) {
      // Permission lookup failure must not trap a successfully saved concern.
    }
    if (mounted) Navigator.pop(context, true);
  }

  void back() {
    if (busy) return;
    if (confirmation) {
      setState(() => confirmation = false);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !confirmation,
    onPopInvokedWithResult: (p, _) {
      if (!p) back();
    },
    child: MePage(
      title: '选择想改善的事',
      onBack: back,
      trailing: Text(
        confirmation ? '2 / 2' : '1 / 2',
        style: MeDesign.text(14, color: MeDesign.muted),
      ),
      footer: MeButton(
        confirmation ? '确认' : '下一步',
        busy: busy,
        onPressed: selected.isEmpty
            ? null
            : confirmation
            ? confirm
            : () => setState(() => confirmation = true),
      ),
      body: IgnorePointer(
        ignoring: busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!confirmation) ...[
              Text(
                '先选最接近的情况，可以多选。',
                style: MeDesign.text(14, color: MeDesign.muted, line: 22),
              ),
              const SizedBox(height: 20),
              for (final issue in MeIssue.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MeChoice(
                    issue.label,
                    selected: selected.contains(issue),
                    onTap: () => setState(
                      () => selected.contains(issue)
                          ? selected.remove(issue)
                          : selected.add(issue),
                    ),
                    height: 56,
                  ),
                ),
              if (selected.contains(MeIssue.other))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: note,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '写下你的困扰（选填）'),
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                decoration: MeDesign.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '你想改善的事',
                      style: MeDesign.text(11, color: MeDesign.rose, line: 18),
                    ),
                    const SizedBox(height: 10),
                    for (final issue in issues)
                      Text(
                        issue == MeIssue.other && note.text.trim().isNotEmpty
                            ? note.text.trim()
                            : issue.label,
                        style: MeDesign.text(
                          18,
                          weight: FontWeight.w700,
                          line: 28,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '为你搭配的记录项',
                style: MeDesign.text(16, weight: FontWeight.w700, line: 24),
              ),
              const SizedBox(height: 6),
              Text(
                '帮助了解当前变化',
                style: MeDesign.text(12, color: MeDesign.muted, line: 18),
              ),
              const SizedBox(height: 14),
              for (final metric in metricsFor(issues))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MeMetricRow(metric),
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                constraints: const BoxConstraints(minHeight: 52),
                decoration: MeDesign.card(radius: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '提醒我记录',
                        style: MeDesign.text(14, weight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      reminder ? '开启' : '关闭',
                      style: MeDesign.text(12, color: MeDesign.muted),
                    ),
                    const SizedBox(width: 12),
                    Transform.scale(
                      scale: .8,
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: reminder,
                        onChanged: (v) => setState(() => reminder = v),
                        activeTrackColor: MeDesign.rose,
                        activeThumbColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (failed) ...[const SizedBox(height: 16), const MeError()],
          ],
        ),
      ),
    ),
  );
}

Future<bool?> showMeNotificationSettings(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: MeDesign.surface,
      barrierColor: const Color(0xff27222b).withValues(alpha: .38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MeDesign.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6eaf1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: MeDesign.asset(
                      'IconBell.svg',
                      width: 26,
                      height: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '开启系统通知',
                      style: MeDesign.text(20, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '在系统设置中允许 MomCozy 发送通知，\n按你的设置接收记录提醒。',
                style: MeDesign.text(14, color: MeDesign.muted, line: 23),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: MeButton(
                  '去设置',
                  fontSize: 15,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: TextButton(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    '暂不开启',
                    style: MeDesign.text(14, color: MeDesign.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

class MeConcernsPage extends StatelessWidget {
  const MeConcernsPage({
    super.key,
    required this.controller,
    required this.onRecord,
  });
  final MeController controller;
  final Future<void> Function(MeMetric) onRecord;
  Future<void> add(BuildContext context, {MeConcern? initial}) async {
    final done = await showMeConcernFlow(context, controller, initial: initial);
    if (done == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final all = controller.state!.concerns;
      return MePage(
        title: '我的关注',
        body: all.isEmpty
            ? Column(
                children: [
                  const SizedBox(height: 44),
                  SizedBox(
                    width: 281,
                    height: 238,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 16,
                          top: 8,
                          child: MeDesign.asset(
                            'DecorationSoftHalo.svg',
                            width: 249,
                            height: 222,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 27,
                          child: MeDesign.asset(
                            'DecorationOrbit.svg',
                            width: 281,
                            height: 183,
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 111,
                          child: Opacity(
                            opacity: .84,
                            child: MeDesign.art(MeMetric.feed, 72),
                          ),
                        ),
                        Positioned(
                          left: 195,
                          top: 17,
                          child: Opacity(
                            opacity: .84,
                            child: MeDesign.art(MeMetric.energy, 69),
                          ),
                        ),
                        Positioned(
                          left: 72,
                          top: 55,
                          child: Opacity(
                            opacity: .84,
                            child: MeDesign.art(MeMetric.pain, 145),
                          ),
                        ),
                        Positioned(
                          left: 48,
                          top: 45,
                          child: MeDesign.asset(
                            'DecorationDot.svg',
                            width: 5,
                            height: 5,
                          ),
                        ),
                        Positioned(
                          left: 238,
                          top: 174,
                          child: MeDesign.asset(
                            'DecorationDot1.svg',
                            width: 6,
                            height: 6,
                          ),
                        ),
                        Positioned(
                          left: 92,
                          top: 223,
                          child: MeDesign.asset(
                            'DecorationDot2.svg',
                            width: 3,
                            height: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    '最近想改善什么？',
                    style: MeDesign.text(24, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    '从喂养不适、奶量担忧或返工安排开始，\n把这一阶段需要的记录放在一起。',
                    textAlign: TextAlign.center,
                    style: MeDesign.text(13, color: MeDesign.muted, line: 22),
                  ),
                  const SizedBox(height: 37),
                  MeButton('选择想改善的事', onPressed: () => add(context)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final concern in all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        onTap: () async {
                          final done = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => MeConcernDetail(
                                controller: controller,
                                concernId: concern.id,
                                onRecord: onRecord,
                              ),
                            ),
                          );
                          if (done == true && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: MeDesign.card(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                concern.ended ? '已结束' : '正在关注',
                                style: MeDesign.text(11, color: MeDesign.rose),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                concern.labels.join('\n'),
                                style: MeDesign.text(
                                  18,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  MeButton('选择想改善的事', onPressed: () => add(context)),
                ],
              ),
      );
    },
  );
}

class MeConcernDetail extends StatefulWidget {
  const MeConcernDetail({
    super.key,
    required this.controller,
    required this.concernId,
    required this.onRecord,
  });
  final MeController controller;
  final String concernId;
  final Future<void> Function(MeMetric) onRecord;
  @override
  State<MeConcernDetail> createState() => _MeConcernDetailState();
}

class _MeConcernDetailState extends State<MeConcernDetail> {
  bool busy = false, failed = false;
  MeConcern get concern => widget.controller.state!.concerns.firstWhere(
    (e) => e.id == widget.concernId,
  );
  Future<void> menu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final text in ['调整关注', '结束关注', '取消'])
              ListTile(
                title: Text(text, textAlign: TextAlign.center),
                onTap: () => Navigator.pop(context, text),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == '调整关注') {
      final done = await showMeConcernFlow(
        context,
        widget.controller,
        initial: concern,
      );
      if (done == true && mounted) Navigator.pop(context, true);
    } else if (choice == '结束关注') {
      final end = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('结束这项关注？'),
          content: const Text('已有记录会保留，你仍可以继续记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('结束关注'),
            ),
          ],
        ),
      );
      if (end != true || !mounted) return;
      setState(() => busy = true);
      try {
        await widget.controller.saveConcern(
          MeConcern(
            id: concern.id,
            issues: concern.issues,
            note: concern.note,
            reminder: false,
            ended: true,
          ),
        );
      } catch (_) {
        failed = true;
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final metrics = metricsFor(concern.issues);
      final observations = widget.controller.state!.records
          .where((r) => metrics.contains(r.kind))
          .toList();
      final comparable = metrics.any(
        (m) => observations.where((r) => r.kind == m).length >= 2,
      );
      return MePage(
        title: '关注详情',
        background: MeDesign.profileBackground,
        bodyPadding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        trailing: concern.ended
            ? null
            : SizedBox(
                width: 60,
                child: TextButton(
                  onPressed: busy ? null : menu,
                  child: Text(
                    '调整',
                    style: MeDesign.text(
                      13,
                      color: MeDesign.rose,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
        footer: MeButton(
          '去记录',
          fontSize: 13,
          weight: FontWeight.w500,
          onPressed: () => widget.onRecord(metrics.first),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 108),
              padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
              decoration: MeDesign.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    concern.ended ? '已结束' : '正在关注',
                    style: MeDesign.text(11, color: MeDesign.rose, line: 18),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    concern.issues.length == 1 &&
                            concern.issues.single == MeIssue.comfort
                        ? '关注喂奶或泵奶时的不适'
                        : '这一阶段想改善的事',
                    style: MeDesign.text(18, weight: FontWeight.w700, line: 28),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    concern.labels.join('\n'),
                    style: MeDesign.text(
                      12,
                      color: const Color(0xff70636b),
                      line: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '最近的变化',
              style: MeDesign.text(17, weight: FontWeight.w700, line: 26),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(minHeight: 100),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: MeDesign.card(radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comparable ? '结合记录了解变化' : '还没有可比较的记录',
                    style: MeDesign.text(16, weight: FontWeight.w700, line: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comparable
                        ? '已记录 ${observations.length} 次当前状态。\n可以结合记录时间回顾变化。'
                        : '这项关注刚刚开始。\n记录后，可以结合时间查看变化。',
                    style: MeDesign.text(
                      12,
                      color: const Color(0xff70636b),
                      line: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '相关记录',
              style: MeDesign.text(17, weight: FontWeight.w700, line: 26),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: MeDesign.card(),
              child: Column(
                children: [
                  for (final metric in metrics)
                    InkWell(
                      onTap: () => widget.onRecord(metric),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        decoration: metric == metrics.last
                            ? null
                            : const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xffeae2e7),
                                    width: .5,
                                  ),
                                ),
                              ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                metric.label,
                                style: MeDesign.text(
                                  12,
                                  color: const Color(0xff70636b),
                                  line: 20,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.controller.latest(metric)?.value ??
                                        '待记录',
                                    style: MeDesign.text(
                                      16,
                                      weight: FontWeight.w700,
                                      color:
                                          widget.controller.latest(metric) ==
                                              null
                                          ? const Color(0xff807975)
                                          : MeDesign.ink,
                                      line: 26,
                                    ),
                                  ),
                                  if (widget.controller.latest(metric)
                                      case final record?)
                                    Text(
                                      '今天 ${record.occurredAt.hour.toString().padLeft(2, '0')}:${record.occurredAt.minute.toString().padLeft(2, '0')}',
                                      style: MeDesign.text(
                                        11,
                                        color: const Color(0xff70636b),
                                        line: 17,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '接下来可以做什么',
              style: MeDesign.text(17, weight: FontWeight.w700, line: 26),
            ),
            const SizedBox(height: 10),
            Text(
              '从首页的相关记录开始，按需要记下当前状态。',
              style: MeDesign.text(
                12,
                color: const Color(0xff70636b),
                line: 18,
              ),
            ),
            if (failed) const MeError(),
          ],
        ),
      );
    },
  );
}
