import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:app/app/momcozy_design_system.dart';

enum BabyStatusPanel { health, milestone, sleep }

Future<void> showBabyFeedingInfoDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => Dialog(
      key: const ValueKey('status-detail-baby-feed-info'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: MomCozyColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '今日摄入说明',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭详情',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: MomCozyColors.muted.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '妈妈实际记录的喂养数据，不包含亲喂',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showBabyStatusPanel(
  BuildContext context, {
  required BabyStatusPanel panel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => _BabyStatusPanelSheet(panel: panel),
  );
}

class _BabyStatusPanelSheet extends StatelessWidget {
  const _BabyStatusPanelSheet({required this.panel});

  final BabyStatusPanel panel;

  @override
  Widget build(BuildContext context) {
    final title = switch (panel) {
      BabyStatusPanel.health => '宝宝健康',
      BabyStatusPanel.milestone => '成长 milestone',
      BabyStatusPanel.sleep => '宝宝睡眠报告',
    };
    final detailKey = switch (panel) {
      BabyStatusPanel.health => const ValueKey('status-detail-baby-health'),
      BabyStatusPanel.milestone => const ValueKey(
        'status-detail-growth-milestone',
      ),
      BabyStatusPanel.sleep => const ValueKey('status-detail-baby-sleep'),
    };

    return Material(
      key: detailKey,
      color: MomCozyColors.card,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            math.max(18.0, MediaQuery.paddingOf(context).bottom + 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MomCozyColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭详情',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: switch (panel) {
                  BabyStatusPanel.health => const _BabyHealthPanel(),
                  BabyStatusPanel.milestone => const _BabyMilestonePanel(),
                  BabyStatusPanel.sleep => const _BabySleepPanel(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _healthItems = <String>[
  '自闭症风险筛查',
  '生长发育迟缓风险筛查',
  '消化系统风险筛查',
  '皮肤异常风险筛查',
  '认知互动风险筛查',
  '宝宝情绪跟踪',
];

class _BabyHealthPanel extends StatelessWidget {
  const _BabyHealthPanel();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 2),
      itemCount: _healthItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xfffbfffd),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffdcefea)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _healthItems[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffe5f7f0),
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                ),
                child: const Text(
                  '待开通',
                  style: TextStyle(
                    color: Color(0xff2f8a72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BabyMilestone {
  const _BabyMilestone({
    required this.title,
    required this.date,
    required this.detail,
  });

  final String title;
  final String date;
  final String detail;
}

const _milestones = <_BabyMilestone>[
  _BabyMilestone(
    title: '说出完整主谓短句',
    date: '2026.05.28',
    detail: '能说出带主语和动作的短句，语言组织能力继续发展。',
  ),
  _BabyMilestone(
    title: '独立上下低矮台阶',
    date: '2026.05.12',
    detail: '能自己上下低矮台阶，动作计划能力更成熟。',
  ),
  _BabyMilestone(
    title: '双脚离地原地跳跃',
    date: '2026.04.26',
    detail: '双脚能同时离地，腿部力量和协调性增强。',
  ),
  _BabyMilestone(
    title: '说出首个双字短句',
    date: '2026.04.08',
    detail: '能把两个词连在一起表达需求或发现。',
  ),
  _BabyMilestone(
    title: '首次双脚小跑',
    date: '2026.03.21',
    detail: '能双脚交替快速移动，运动稳定性进一步提升。',
  ),
  _BabyMilestone(
    title: '自主站立',
    date: '2026.03.02',
    detail: '短时间不用扶站立，平衡能力继续发展。',
  ),
  _BabyMilestone(
    title: '四点手足爬行',
    date: '2026.02.12',
    detail: '能用手和膝盖协调前进，探索范围变大。',
  ),
  _BabyMilestone(
    title: '无支撑独自坐稳',
    date: '2026.01.25',
    detail: '不用扶也能坐稳一段时间，核心控制更成熟。',
  ),
  _BabyMilestone(
    title: '首次叫爸爸',
    date: '2026.01.08',
    detail: '能发出接近“爸爸”的音节，表达欲更明显。',
  ),
  _BabyMilestone(
    title: '首次叫妈妈',
    date: '2025.12.22',
    detail: '发出接近“妈妈”的音节，开始把声音和人联系起来。',
  ),
  _BabyMilestone(
    title: '首次完整自主翻身',
    date: '2025.12.04',
    detail: '能从仰卧翻到俯卧，身体协调性继续提升。',
  ),
  _BabyMilestone(
    title: '出生后首次自主抬头',
    date: '2025.11.18',
    detail: '趴卧时能短暂抬起头，开始建立颈肩控制。',
  ),
];

class _BabyMilestonePanel extends StatelessWidget {
  const _BabyMilestonePanel();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('status-baby-milestone-list'),
      padding: const EdgeInsets.only(right: 2, bottom: 2),
      itemCount: _milestones.length,
      itemBuilder: (context, index) => _MilestoneRow(
        milestone: _milestones[index],
        index: index,
        isLast: index == _milestones.length - 1,
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.index,
    required this.isLast,
  });

  final _BabyMilestone milestone;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final denominator = math.max(1, _milestones.length - 1);
    final recency = 1 - index / denominator;
    final accent = Color.lerp(
      const Color(0xff9fd8c6),
      const Color(0xff4fa98c),
      recency,
    )!;
    final soft = Color.lerp(
      const Color(0xfff4fcf9),
      const Color(0xffe7f8f2),
      recency,
    )!;
    final dotSize = 10 + recency * 8;

    return Stack(
      children: [
        Positioned(
          left: 13,
          top: index == 0 ? 16 : 0,
          bottom: isLast ? 16 : 0,
          child: Container(
            width: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xffdcf7ed), Color(0xff76c7ad)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 48,
                child: Center(
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: soft,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, soft],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.36)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          MomCozyAssets.babyAvatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                Text(
                                  milestone.title,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: MomCozyColors.foreground,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                Text(
                                  milestone.date,
                                  style: const TextStyle(
                                    color: Color(0xff9a8fa5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              milestone.detail,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xff6f617a),
                                    fontWeight: FontWeight.w500,
                                    height: 1.45,
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
      ],
    );
  }
}

class _SleepSummary {
  const _SleepSummary({
    required this.title,
    required this.value,
    required this.icon,
    required this.peach,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool peach;
}

const _sleepSummaries = <_SleepSummary>[
  _SleepSummary(
    title: '总睡眠',
    value: '4h 57min',
    icon: Icons.nightlight_round,
    peach: true,
  ),
  _SleepSummary(
    title: '最长睡眠',
    value: '3h 08min',
    icon: Icons.timer_outlined,
    peach: false,
  ),
  _SleepSummary(
    title: '哭闹',
    value: '0次',
    icon: Icons.sentiment_dissatisfied_outlined,
    peach: false,
  ),
  _SleepSummary(
    title: '活动',
    value: '26次',
    icon: Icons.directions_run_outlined,
    peach: true,
  ),
];

class _SleepChartPoint {
  const _SleepChartPoint({
    required this.period,
    required this.sleepMinutes,
    required this.activityMinutes,
    required this.cryMinutes,
  });

  final String period;
  final int sleepMinutes;
  final int activityMinutes;
  final int cryMinutes;
}

const _sleepChart = <_SleepChartPoint>[
  _SleepChartPoint(
    period: '00:00',
    sleepMinutes: 74,
    activityMinutes: 28,
    cryMinutes: 0,
  ),
  _SleepChartPoint(
    period: '02:00',
    sleepMinutes: 76,
    activityMinutes: 34,
    cryMinutes: 0,
  ),
  _SleepChartPoint(
    period: '04:00',
    sleepMinutes: 68,
    activityMinutes: 24,
    cryMinutes: 0,
  ),
  _SleepChartPoint(
    period: '06:00',
    sleepMinutes: 0,
    activityMinutes: 52,
    cryMinutes: 8,
  ),
  _SleepChartPoint(
    period: '08:00',
    sleepMinutes: 0,
    activityMinutes: 46,
    cryMinutes: 0,
  ),
  _SleepChartPoint(
    period: '10:00',
    sleepMinutes: 0,
    activityMinutes: 33,
    cryMinutes: 0,
  ),
];

class _BabySleepPanel extends StatelessWidget {
  const _BabySleepPanel();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('status-baby-sleep-scroll'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        decoration: BoxDecoration(
          color: const Color(0xfffffdf8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SleepDateButton(
                  buttonKey: const ValueKey('status-baby-sleep-previous-day'),
                  label: '前一天',
                ),
                Text(
                  '11-16',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _SleepDateButton(
                  buttonKey: const ValueKey('status-baby-sleep-next-day'),
                  label: '后一天',
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sleepSummaries.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 10,
                mainAxisExtent: 134,
              ),
              itemBuilder: (context, index) =>
                  _SleepSummaryTile(summary: _sleepSummaries[index]),
            ),
            const SizedBox(height: 18),
            Text(
              '宝宝睡眠记录',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '按时段看睡眠、活动和哭闹时长',
              style: const TextStyle(
                color: Color(0xff8a767f),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: [
                _SleepLegend(label: '睡眠', color: Color(0xff25d6a3)),
                _SleepLegend(label: '活动', color: Color(0xffe6b65c)),
                _SleepLegend(label: '哭闹', color: Color(0xff8c78c8)),
              ],
            ),
            const SizedBox(height: 12),
            const _BabySleepChart(),
          ],
        ),
      ),
    );
  }
}

class _SleepDateButton extends StatelessWidget {
  const _SleepDateButton({required this.buttonKey, required this.label});

  final Key buttonKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      onPressed: null,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xfffff1c9),
        disabledForegroundColor: const Color(
          0xffc68b36,
        ).withValues(alpha: 0.55),
        minimumSize: const Size(52, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xffc68b36).withValues(alpha: 0.55),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SleepSummaryTile extends StatelessWidget {
  const _SleepSummaryTile({required this.summary});

  final _SleepSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 34, 12, 12),
              decoration: BoxDecoration(
                color: summary.peach
                    ? const Color(0xffffdccc)
                    : const Color(0xfffff4e8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14a86172),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    summary.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xffff9677),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      summary.value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: MomCozyColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -24,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xffffe8df),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14a86172),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                summary.icon,
                color: const Color(0xffff9677),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepLegend extends StatelessWidget {
  const _SleepLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: MomCozyColors.mutedForeground,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BabySleepChart extends StatelessWidget {
  const _BabySleepChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 28,
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('90m', style: _axisStyle),
                Text('60m', style: _axisStyle),
                Text('30m', style: _axisStyle),
                Text('0', style: _axisStyle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 112,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _SleepGridPainter()),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final point in _sleepChart)
                              Expanded(child: _SleepBarGroup(point: point)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final point in _sleepChart)
                      Expanded(
                        child: Text(
                          point.period,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xff9a8170),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _axisStyle = TextStyle(
  color: Color(0xffb99f86),
  fontSize: 9,
  fontWeight: FontWeight.w700,
);

class _SleepBarGroup extends StatelessWidget {
  const _SleepBarGroup({required this.point});

  final _SleepChartPoint point;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = math.min(7.0, math.max(3.0, constraints.maxWidth / 4));
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SleepBar(
              width: barWidth,
              minutes: point.sleepMinutes,
              color: const Color(0xff25d6a3),
            ),
            const SizedBox(width: 1),
            _SleepBar(
              width: barWidth,
              minutes: point.activityMinutes,
              color: const Color(0xffe6b65c),
            ),
            const SizedBox(width: 1),
            _SleepBar(
              width: barWidth,
              minutes: point.cryMinutes,
              color: const Color(0xff8c78c8),
            ),
          ],
        );
      },
    );
  }
}

class _SleepBar extends StatelessWidget {
  const _SleepBar({
    required this.width,
    required this.minutes,
    required this.color,
  });

  final double width;
  final int minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: math.max(4.0, minutes / 90 * 112),
      decoration: BoxDecoration(
        color: color.withValues(alpha: minutes > 0 ? 1.0 : 0.16),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
    );
  }
}

class _SleepGridPainter extends CustomPainter {
  const _SleepGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = const Color(0xffefdccc)
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 1 / 3, 2 / 3]) {
      final y = size.height * fraction;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width), y),
          dashedPaint,
        );
      }
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = const Color(0xffead5c2)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SleepGridPainter oldDelegate) => false;
}
