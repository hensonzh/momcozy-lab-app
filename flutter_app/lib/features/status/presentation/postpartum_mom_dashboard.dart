import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/domain/postpartum_mom.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

class PostpartumMomDashboard extends StatefulWidget {
  const PostpartumMomDashboard({
    super.key,
    required this.milkTrends,
    required this.now,
    required this.windowDays,
    required this.onWindowDaysChanged,
    required this.onAgentPrompt,
  });

  final ValueListenable<StatusResource<List<MilkTrendDay>>> milkTrends;
  final DateTime Function() now;
  final int windowDays;
  final ValueChanged<int> onWindowDaysChanged;
  final ValueChanged<String> onAgentPrompt;

  @override
  State<PostpartumMomDashboard> createState() => _PostpartumMomDashboardState();
}

class _PostpartumMomDashboardState extends State<PostpartumMomDashboard> {
  var _trendExpanded = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusResource<List<MilkTrendDay>>>(
      valueListenable: widget.milkTrends,
      builder: (context, resource, _) {
        final projection = PostpartumMilkProjection.fromTrendDays(
          days: resource.data ?? const <MilkTrendDay>[],
          now: widget.now(),
        );
        return Column(
          children: [
            _MomModuleGrid(
              children: [
                _DashboardModuleCard(
                  key: const ValueKey('status-module-milk-output'),
                  title: '母乳产出',
                  tone: _ModuleTone.rose,
                  icon: const Icon(Icons.water_drop_outlined, size: 17),
                  metrics: [
                    _ModuleMetric(
                      label: '今日产出',
                      value: _todayVolumeLabel(resource, projection.today),
                      helpKey: const ValueKey('status-milk-output-info-button'),
                      onHelp: () => _showInfo(
                        id: 'milk-info',
                        title: '今日产出说明',
                        text: '使用吸奶器产出的奶量，不含亲喂',
                      ),
                    ),
                    _ModuleMetric(
                      label: '今日吸奶',
                      value: _todayCountLabel(resource, projection.today),
                    ),
                  ],
                ),
                _DashboardModuleCard(
                  key: const ValueKey('status-module-breast-health'),
                  title: '乳房健康',
                  tone: _ModuleTone.peach,
                  icon: const Icon(Icons.favorite_border_rounded, size: 17),
                  body: const TextSpan(text: '最近出现涨奶和硬块，伴随按压疼痛'),
                  action: '查看《乳房健康日记》',
                  helpKey: const ValueKey('status-breast-health-info-button'),
                  onHelp: () => _showInfo(
                    id: 'breast-info',
                    title: '乳房健康说明',
                    text: '通过您和智能体的日常对话采集的乳房健康记录',
                  ),
                  onTap: _showBreastHealthSheet,
                ),
                _DashboardModuleCard(
                  key: const ValueKey('status-module-postpartum-recovery'),
                  title: '产后恢复',
                  tone: _ModuleTone.mint,
                  icon: Image.asset(
                    MomCozyAssets.postpartumRecoveryIcon,
                    width: 19,
                    height: 19,
                    fit: BoxFit.contain,
                  ),
                  body: const TextSpan(text: '正在执行盆底肌康复训练'),
                  action: '查看计划',
                  onTap: _showPostpartumRecoverySheet,
                ),
                _DashboardModuleCard(
                  key: const ValueKey('status-module-rest-nutrition'),
                  title: '补能与休息',
                  tone: _ModuleTone.amber,
                  icon: const Icon(Icons.local_cafe_outlined, size: 17),
                  body: const TextSpan(
                    children: [
                      TextSpan(text: '待开通 '),
                      TextSpan(
                        text: '睡眠',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' 与 '),
                      TextSpan(
                        text: '营养',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' 功能'),
                    ],
                  ),
                  helpKey: const ValueKey('status-rest-info-button'),
                  onHelp: () => _showInfo(
                    id: 'rest-info',
                    title: '补能与休息说明',
                    text: '所有信息来自智能体的收集。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MilkTrendPanel(
              resource: resource,
              projection: projection,
              windowDays: widget.windowDays,
              expanded: _trendExpanded,
              onToggle: () {
                setState(() => _trendExpanded = !_trendExpanded);
              },
              onWindowDaysChanged: widget.onWindowDaysChanged,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInfo({
    required String id,
    required String title,
    required String text,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭$title',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              key: ValueKey('status-detail-$id'),
              color: MomCozyColors.card,
              elevation: 18,
              shadowColor: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭详情',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: MomCozyColors.muted.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBreastHealthSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return _StatusBottomSheet(
          key: const ValueKey('status-detail-breast-health'),
          title: '乳房健康日记',
          onClose: () => Navigator.of(sheetContext).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _StatusTimeline(
                color: Color(0xffb96f55),
                softColor: Color(0xffffd9c8),
                cardColor: Color(0xfffff8f1),
                records: [
                  _TimelineRecord(
                    time: '今天',
                    title: '涨奶硬块',
                    detail: '最近出现涨奶和硬块，伴随按压疼痛。',
                  ),
                  _TimelineRecord(
                    time: '昨天 上午',
                    title: '发现硬块',
                    detail: '左侧外上区域摸到硬块，按压时有疼痛感。',
                  ),
                  _TimelineRecord(
                    time: '三天前 晚间',
                    title: '轻微涨奶',
                    detail: '右侧乳房有胀感，吸奶后明显缓解。',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AgentActionButton(
                label: '让我了解更多',
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  widget.onAgentPrompt('我想了解乳房健康情况，最近有涨奶和硬块，按压会疼');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPostpartumRecoverySheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return _PostpartumRecoverySheet(
          key: const ValueKey('status-detail-postpartum-recovery'),
          onClose: () => Navigator.of(sheetContext).pop(),
        );
      },
    );
  }
}

String _todayVolumeLabel(
  StatusResource<List<MilkTrendDay>> resource,
  MilkTrendDay? today,
) {
  if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
    return '加载中';
  }
  if (today == null) return '待记录';
  return '${_formatVolume(today.pumpedMilkVolumeMl)}mL';
}

String _todayCountLabel(
  StatusResource<List<MilkTrendDay>> resource,
  MilkTrendDay? today,
) {
  if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
    return '加载中';
  }
  if (today == null) return '待同步';
  return '${math.max(0, today.pumpingCount)}次';
}

String _formatVolume(double value) {
  final safe = math.max(0, value);
  return safe == safe.roundToDouble()
      ? safe.round().toString()
      : safe.toStringAsFixed(1);
}

class _MomModuleGrid extends StatelessWidget {
  const _MomModuleGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const ValueKey('status-postpartum-mom-module-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 144,
      ),
      itemBuilder: (context, index) => children[index],
    );
  }
}

enum _ModuleTone {
  rose(
    accent: Color(0xffb86f91),
    colors: [Color(0xfffff9fc), Color(0xfffff2f8)],
  ),
  peach(
    accent: Color(0xffb96f55),
    colors: [Color(0xfffffbf8), Color(0xfffff0e8)],
  ),
  mint(
    accent: Color(0xff388b72),
    colors: [Color(0xfff6fffc), Color(0xffe8faf5)],
  ),
  amber(
    accent: Color(0xffb9792a),
    colors: [Color(0xfffffcf5), Color(0xfffff3dc)],
  );

  const _ModuleTone({required this.accent, required this.colors});

  final Color accent;
  final List<Color> colors;
}

class _DashboardModuleCard extends StatelessWidget {
  const _DashboardModuleCard({
    super.key,
    required this.title,
    required this.tone,
    required this.icon,
    this.metrics = const <_ModuleMetric>[],
    this.body,
    this.action,
    this.helpKey,
    this.onHelp,
    this.onTap,
  });

  final String title;
  final _ModuleTone tone;
  final Widget icon;
  final List<_ModuleMetric> metrics;
  final InlineSpan? body;
  final String? action;
  final Key? helpKey;
  final VoidCallback? onHelp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone.colors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: const Color(0xff35212c),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                              ),
                        ),
                      ),
                      if (onHelp != null)
                        _HelpButton(key: helpKey, onPressed: onHelp!),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: tone.accent),
                    child: icon,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: metrics.isNotEmpty
                  ? _ModuleMetrics(metrics: metrics)
                  : Align(
                      alignment: Alignment.topLeft,
                      child: RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xff7a5b68),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                          children: [body ?? const TextSpan()],
                        ),
                      ),
                    ),
            ),
            if (action != null)
              _ModuleAction(
                label: action!,
                color: tone.accent,
                onPressed: onTap,
              ),
          ],
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? card : InkWell(onTap: onTap, child: card),
    );
  }
}

class _ModuleMetric {
  const _ModuleMetric({
    required this.label,
    required this.value,
    this.helpKey,
    this.onHelp,
  });

  final String label;
  final String value;
  final Key? helpKey;
  final VoidCallback? onHelp;
}

class _ModuleMetrics extends StatelessWidget {
  const _ModuleMetrics({required this.metrics});

  final List<_ModuleMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final metric in metrics)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        metric.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xff7a5b68),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (metric.onHelp != null)
                      _HelpButton(
                        key: metric.helpKey,
                        size: 16,
                        onPressed: metric.onHelp!,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xff35212c),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({super.key, required this.onPressed, this.size = 18});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '说明',
      child: InkResponse(
        onTap: onPressed,
        radius: 16,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.help_outline_rounded,
            size: size - 3,
            color: const Color(0xff8d6f7d),
          ),
        ),
      ),
    );
  }
}

class _ModuleAction extends StatelessWidget {
  const _ModuleAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MilkTrendPanel extends StatelessWidget {
  const _MilkTrendPanel({
    required this.resource,
    required this.projection,
    required this.windowDays,
    required this.expanded,
    required this.onToggle,
    required this.onWindowDaysChanged,
  });

  final StatusResource<List<MilkTrendDay>> resource;
  final PostpartumMilkProjection projection;
  final int windowDays;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onWindowDaysChanged;

  @override
  Widget build(BuildContext context) {
    final window = projection.window(windowDays);
    return Container(
      key: const ValueKey('status-milk-trend-preview'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffffaf0), Colors.white, Color(0xfffff1d6)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xfff0dfc4)),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            toggled: expanded,
            child: InkWell(
              key: const ValueKey('status-milk-trend-toggle'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xffffe4b8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gps_fixed_rounded,
                        size: 14,
                        color: Color(0xffb9792a),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '母乳趋势',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0 : 0.5,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MilkTrendLegend(
                                supportsEstimate: window.supportsEstimate,
                                supportsReference: window.supportsReference,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _TrendWindowControl(
                              selectedDays: windowDays,
                              onChanged: onWindowDaysChanged,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _trendBody(context, window),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _trendBody(BuildContext context, MilkTrendWindow window) {
    if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
      return const _ChartMessage(text: '正在加载最近一个月泌乳数据…');
    }
    if (resource.hasError && resource.data == null) {
      return const _ChartMessage(text: '母乳趋势暂时无法同步，请稍后重试。');
    }
    if (!window.hasMeasurements) {
      return const _ChartMessage(text: '暂无母乳趋势数据，可多日记录产量后在本页查看。');
    }
    return MilkTrendChart(window: window, weekly: windowDays == 7);
  }
}

class _ChartMessage extends StatelessWidget {
  const _ChartMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: MomCozyColors.mutedForeground,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _MilkTrendLegend extends StatelessWidget {
  const _MilkTrendLegend({
    required this.supportsEstimate,
    required this.supportsReference,
  });

  final bool supportsEstimate;
  final bool supportsReference;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 5,
      children: [
        const _LegendItem(label: '吸乳总量', color: Color(0xffb9792a)),
        Opacity(
          opacity: supportsEstimate ? 1 : 0.38,
          child: const _LegendItem(
            label: '含亲喂估算',
            color: Color(0xff8a5f7d),
            dashed: true,
          ),
        ),
        Opacity(
          opacity: supportsReference ? 1 : 0.38,
          child: const _LegendItem(
            label: '目标参考区间',
            color: Color(0xffdff4e8),
            band: true,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    this.dashed = false,
    this.band = false,
  });

  final String label;
  final Color color;
  final bool dashed;
  final bool band;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(12, band ? 8 : 2),
          painter: _LegendPainter(color: color, dashed: dashed, band: band),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xff8a6742),
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _LegendPainter extends CustomPainter {
  const _LegendPainter({
    required this.color,
    required this.dashed,
    required this.band,
  });

  final Color color;
  final bool dashed;
  final bool band;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = band ? PaintingStyle.fill : PaintingStyle.stroke;
    if (band) {
      canvas.drawRect(Offset.zero & size, paint);
    } else if (dashed) {
      canvas.drawLine(Offset.zero, Offset(4, 0), paint);
      canvas.drawLine(const Offset(7, 0), Offset(size.width, 0), paint);
    } else {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashed != dashed ||
        oldDelegate.band != band;
  }
}

class _TrendWindowControl extends StatelessWidget {
  const _TrendWindowControl({
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xfffff1d6),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrendWindowOption(
            key: const ValueKey('status-milk-trend-segment-周'),
            label: '周',
            selected: selectedDays == 7,
            onTap: () => onChanged(7),
          ),
          _TrendWindowOption(
            key: const ValueKey('status-milk-trend-segment-月'),
            label: '月',
            selected: selectedDays == 30,
            onTap: () => onChanged(30),
          ),
        ],
      ),
    );
  }
}

class _TrendWindowOption extends StatelessWidget {
  const _TrendWindowOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        child: Container(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xffb9792a) : Colors.transparent,
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? Colors.white : const Color(0xff8a6742),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class MilkTrendChart extends StatefulWidget {
  const MilkTrendChart({super.key, required this.window, required this.weekly});

  final MilkTrendWindow window;
  final bool weekly;

  @override
  State<MilkTrendChart> createState() => _MilkTrendChartState();
}

class _MilkTrendChartState extends State<MilkTrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant MilkTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window.points.length != widget.window.points.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '母乳趋势图，共 ${widget.window.points.length} 天',
      child: SizedBox(
        key: const ValueKey('status-milk-trend-chart'),
        height: 188,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final geometry = _ChartGeometry(size, widget.window.points);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _select(details.localPosition, geometry),
              onHorizontalDragUpdate: (details) =>
                  _select(details.localPosition, geometry),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MilkTrendChartPainter(
                        points: widget.window.points,
                        weekly: widget.weekly,
                        selectedIndex: _selectedIndex,
                      ),
                    ),
                  ),
                  if (_selectedIndex case final index?)
                    _TrendTooltip(
                      point: widget.window.points[index],
                      x: geometry.xFor(index),
                      maxWidth: size.width,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _select(Offset position, _ChartGeometry geometry) {
    if (!geometry.plotRect.inflate(12).contains(position)) {
      setState(() => _selectedIndex = null);
      return;
    }
    setState(() => _selectedIndex = geometry.nearestMeasuredIndex(position.dx));
  }
}

class _TrendTooltip extends StatelessWidget {
  const _TrendTooltip({
    required this.point,
    required this.x,
    required this.maxWidth,
  });

  static const width = 174.0;

  final MilkTrendPoint point;
  final double x;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final left = (x - width / 2)
        .clamp(0.0, math.max(0, maxWidth - width))
        .toDouble();
    return Positioned(
      key: const ValueKey('status-milk-trend-tooltip'),
      left: left,
      top: 4,
      width: width,
      child: IgnorePointer(
        child: Material(
          color: MomCozyColors.card,
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DefaultTextStyle(
              style: Theme.of(
                context,
              ).textTheme.labelSmall!.copyWith(fontSize: 10, height: 1.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullDate(point.date),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '吸乳总量：${_formatVolume(point.actualMl)}mL',
                    style: const TextStyle(color: Color(0xffb9792a)),
                  ),
                  if (point.estimatedMl case final estimate?)
                    Text(
                      '含亲喂估算：${_formatVolume(estimate)}mL',
                      style: const TextStyle(color: Color(0xff8a5f7d)),
                    ),
                  if (point.referenceLowerMl case final lower?)
                    if (point.referenceUpperMl case final upper?)
                      Text(
                        '参考区间：${_formatVolume(lower)}mL - ${_formatVolume(upper)}mL',
                        style: const TextStyle(
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartGeometry {
  _ChartGeometry(this.size, this.points)
    : plotRect = Rect.fromLTWH(46, 6, size.width - 58, size.height - 34);

  final Size size;
  final List<MilkTrendPoint> points;
  final Rect plotRect;

  double xFor(int index) {
    if (points.length <= 1) return plotRect.center.dx;
    return plotRect.left + plotRect.width * index / (points.length - 1);
  }

  int nearestMeasuredIndex(double x) {
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index += 1) {
      if (!points[index].hasMeasurement) continue;
      final distance = (xFor(index) - x).abs();
      if (distance < nearestDistance) {
        nearest = index;
        nearestDistance = distance;
      }
    }
    return nearest;
  }
}

class _MilkTrendChartPainter extends CustomPainter {
  const _MilkTrendChartPainter({
    required this.points,
    required this.weekly,
    required this.selectedIndex,
  });

  final List<MilkTrendPoint> points;
  final bool weekly;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final geometry = _ChartGeometry(size, points);
    final rect = geometry.plotRect;
    final maxValue = _maxChartValue(points);
    final gridPaint = Paint()
      ..color = const Color(0xffcfe8d8)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xffb9792a)
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index += 1) {
      final y = rect.top + rect.height * index / 4;
      _drawDashedLine(
        canvas,
        Offset(rect.left, y),
        Offset(rect.right, y),
        gridPaint,
      );
      _paintText(
        canvas,
        '${_formatAxis(maxValue * (4 - index) / 4)} mL',
        Offset(0, y - 6),
        width: 40,
        align: TextAlign.right,
      );
    }

    final tickIndexes = _tickIndexes(points.length, weekly ? 7 : 7);
    for (final index in tickIndexes) {
      final x = geometry.xFor(index);
      _drawDashedLine(
        canvas,
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        gridPaint,
      );
      _paintText(
        canvas,
        _shortDate(points[index].date),
        Offset(x - 18, rect.bottom + 9),
        width: 36,
        align: TextAlign.center,
      );
    }

    canvas.drawLine(rect.topLeft, rect.bottomLeft, axisPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, axisPaint);

    if (points.any(
      (point) =>
          point.referenceLowerMl != null && point.referenceUpperMl != null,
    )) {
      final band = Path();
      var started = false;
      for (var index = 0; index < points.length; index += 1) {
        final value = points[index].referenceUpperMl;
        if (value == null) continue;
        final offset = Offset(
          geometry.xFor(index),
          _valueY(value, rect, maxValue),
        );
        if (!started) {
          band.moveTo(offset.dx, offset.dy);
          started = true;
        } else {
          band.lineTo(offset.dx, offset.dy);
        }
      }
      for (var index = points.length - 1; index >= 0; index -= 1) {
        final value = points[index].referenceLowerMl;
        if (value == null) continue;
        band.lineTo(geometry.xFor(index), _valueY(value, rect, maxValue));
      }
      if (started) {
        band.close();
        canvas.drawPath(
          band,
          Paint()
            ..color = const Color(0xffdff4e8).withValues(alpha: 0.75)
            ..style = PaintingStyle.fill,
        );
      }
    }

    final estimatedPaths = _linePaths(
      geometry,
      rect,
      maxValue,
      (point) => point.hasMeasurement ? point.estimatedMl : null,
    );
    for (final estimatedPath in estimatedPaths) {
      _drawDashedPath(
        canvas,
        estimatedPath,
        Paint()
          ..color = const Color(0xff8a5f7d)
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final actualPaths = _linePaths(
      geometry,
      rect,
      maxValue,
      (point) => point.hasMeasurement ? point.actualMl : null,
    );
    for (final actualPath in actualPaths) {
      canvas.drawPath(
        actualPath,
        Paint()
          ..color = const Color(0xffb9792a)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var index = 0; index < points.length; index += 1) {
      if (!points[index].hasMeasurement) continue;
      final point = Offset(
        geometry.xFor(index),
        _valueY(points[index].actualMl, rect, maxValue),
      );
      final radius = weekly ? 3.0 : 2.0;
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = const Color(0xfffffaf0),
      );
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = const Color(0xffb9792a)
          ..strokeWidth = weekly ? 2 : 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    if (selectedIndex case final index?) {
      final x = geometry.xFor(index);
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        Paint()
          ..color = const Color(0xffb9792a).withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(x, _valueY(points[index].actualMl, rect, maxValue)),
        5,
        Paint()..color = const Color(0xffb9792a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MilkTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.weekly != weekly ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

double _maxChartValue(List<MilkTrendPoint> points) {
  var maxValue = 0.0;
  for (final point in points) {
    maxValue = math.max(maxValue, point.actualMl);
    maxValue = math.max(maxValue, point.estimatedMl ?? 0);
    maxValue = math.max(maxValue, point.referenceUpperMl ?? 0);
  }
  final padded = math.max(100, maxValue * 1.1);
  return (padded / 100).ceil() * 100;
}

double _valueY(double value, Rect rect, double maxValue) {
  final ratio = (math.max(0, value) / maxValue).clamp(0.0, 1.0);
  return rect.bottom - rect.height * ratio;
}

List<Path> _linePaths(
  _ChartGeometry geometry,
  Rect rect,
  double maxValue,
  double? Function(MilkTrendPoint point) valueFor,
) {
  final paths = <Path>[];
  var offsets = <Offset>[];
  for (var index = 0; index < geometry.points.length; index += 1) {
    final value = valueFor(geometry.points[index]);
    if (value == null) {
      if (offsets.isNotEmpty) {
        paths.add(_pathForOffsets(offsets));
        offsets = <Offset>[];
      }
      continue;
    }
    offsets.add(Offset(geometry.xFor(index), _valueY(value, rect, maxValue)));
  }
  if (offsets.isNotEmpty) paths.add(_pathForOffsets(offsets));
  return paths;
}

Path _pathForOffsets(List<Offset> offsets) {
  final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
  for (var index = 1; index < offsets.length; index += 1) {
    final previous = offsets[index - 1];
    final current = offsets[index];
    final control = (current.dx - previous.dx) / 3;
    path.cubicTo(
      previous.dx + control,
      previous.dy,
      current.dx - control,
      current.dy,
      current.dx,
      current.dy,
    );
  }
  return path;
}

void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + 4, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += 7;
    }
  }
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  final vertical = (start.dx - end.dx).abs() < 0.1;
  var cursor = vertical ? start.dy : start.dx;
  final limit = vertical ? end.dy : end.dx;
  while (cursor < limit) {
    final next = math.min(cursor + 3, limit);
    canvas.drawLine(
      vertical ? Offset(start.dx, cursor) : Offset(cursor, start.dy),
      vertical ? Offset(end.dx, next) : Offset(next, end.dy),
      paint,
    );
    cursor += 7;
  }
}

List<int> _tickIndexes(int length, int count) {
  if (length <= count) return List<int>.generate(length, (index) => index);
  return <int>{
    for (var index = 0; index < count; index += 1)
      (index * (length - 1) / (count - 1)).round(),
  }.toList()..sort();
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  required double width,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xff9c7651),
        fontSize: 8,
        fontFamily: MomCozyTypography.fontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: width);
  painter.paint(canvas, offset);
}

String _formatAxis(double value) {
  return value.round().toString();
}

String _shortDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _fullDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

class _StatusBottomSheet extends StatelessWidget {
  const _StatusBottomSheet({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomCozyColors.card,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            math.max(28, MediaQuery.paddingOf(context).bottom + 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭详情',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRecord {
  const _TimelineRecord({
    required this.time,
    required this.title,
    required this.detail,
  });

  final String time;
  final String title;
  final String detail;
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({
    required this.color,
    required this.softColor,
    required this.cardColor,
    required this.records,
  });

  final Color color;
  final Color softColor;
  final Color cardColor;
  final List<_TimelineRecord> records;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 12,
          bottom: 12,
          left: 9,
          child: ColoredBox(color: softColor, child: const SizedBox(width: 1)),
        ),
        Column(
          children: [
            for (var index = 0; index < records.length; index += 1) ...[
              _TimelineRow(
                record: records[index],
                current: index == 0,
                color: color,
                softColor: softColor,
                cardColor: cardColor,
              ),
              if (index < records.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.record,
    required this.current,
    required this.color,
    required this.softColor,
    required this.cardColor,
  });

  final _TimelineRecord record;
  final bool current;
  final Color color;
  final Color softColor;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current ? softColor : MomCozyColors.card,
            border: Border.all(color: current ? color : softColor, width: 2),
            boxShadow: current
                ? [
                    BoxShadow(
                      color: softColor.withValues(alpha: 0.58),
                      spreadRadius: 4,
                    ),
                  ]
                : const [],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: softColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.time,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xff6f5560),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AgentActionButton extends StatelessWidget {
  const _AgentActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: ClipOval(
          child: Image.asset(
            MomCozyAssets.agentAvatar,
            width: 20,
            height: 20,
            fit: BoxFit.cover,
          ),
        ),
        label: Text(label),
      ),
    );
  }
}

class _PostpartumRecoverySheet extends StatefulWidget {
  const _PostpartumRecoverySheet({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<_PostpartumRecoverySheet> createState() =>
      _PostpartumRecoverySheetState();
}

class _PostpartumRecoverySheetState extends State<_PostpartumRecoverySheet> {
  Timer? _hintTimer;
  var _hintVisible = false;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StatusBottomSheet(
      title: '盆底肌康复训练',
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RecoveryCourse(
            time: '第 1-2 天',
            status: '已完成',
            title: '盆底肌唤醒练习',
            detail: '呼吸配合轻收缩，建立盆底肌发力感',
          ),
          const SizedBox(height: 8),
          const _RecoveryCourse(
            time: '第 3-5 天',
            status: '进行中',
            title: '骨盆稳定训练',
            detail: '低强度核心稳定动作，帮助恢复骨盆控制',
          ),
          const SizedBox(height: 8),
          const _RecoveryCourse(
            time: '第 6-7 天',
            title: '腰背与肩颈放松',
            detail: '照护和吸奶后的短时拉伸，缓解腰背疲劳',
          ),
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topRight,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('status-postpartum-continue-button'),
                  onPressed: _showHint,
                  icon: ClipOval(
                    child: Image.asset(
                      MomCozyAssets.agentAvatar,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                    ),
                  ),
                  label: const Text('继续训练'),
                ),
              ),
              if (_hintVisible)
                Positioned(
                  top: -42,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: const ValueKey('status-postpartum-training-hint'),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 180),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 6 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff35212c).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(
                            MomCozyRadii.pill,
                          ),
                        ),
                        child: const Text(
                          '暂未开通此功能',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHint() {
    _hintTimer?.cancel();
    setState(() => _hintVisible = true);
    _hintTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }
}

class _RecoveryCourse extends StatelessWidget {
  const _RecoveryCourse({
    required this.time,
    required this.title,
    required this.detail,
    this.status,
  });

  final String time;
  final String? status;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MomCozyColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xff2f8a72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffdcf7ed),
                    borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                  ),
                  child: Text(
                    status!,
                    style: const TextStyle(
                      color: Color(0xff2f8a72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
