import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:momcozy_flutter_app/features/pump_session/domain/pump_workstate.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

const _internalDeviceDebugEnabled = bool.fromEnvironment(
  'MOMCOZY_INTERNAL_BUILD',
);

class MomCozyFeaturePage extends StatelessWidget {
  const MomCozyFeaturePage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;

  @override
  Widget build(BuildContext context) {
    return switch (path) {
      '/calibration' => _CalibrationPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/pump' => _PumpPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/records' => _RecordsPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/schedule' => _SchedulePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/status' => _StatusPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/community' => _CommunityPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/device' => _DevicePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/device/manage' => _DeviceManagePage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/device/user' => _DeviceUserPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/w1' => _W1Page(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/hospital-bag-cart' => _HospitalBagCartPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/ibclc-chat.html' => _IbclcPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      '/media-viewer' => _MediaViewerPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
      _ => _NotFoundPage(
        path: path,
        title: title,
        summary: summary,
        icon: icon,
        accent: accent,
      ),
    };
  }
}

class _FeaturePageFrame extends StatelessWidget {
  const _FeaturePageFrame({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.children,
    this.trailing,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      key: ValueKey('route-page-$path'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.08)),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: accent, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: MomCozyColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    summary,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.32,
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (trailing != null) ...[const SizedBox(height: 16), trailing!],
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10, left: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(icon: icon, accent: accent, size: 36, iconSize: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: MomCozyColors.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MomCozyColors.mutedForeground,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = accent ?? colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _IconBubble(icon: icon, accent: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                height: 1.35,
                                color: MomCozyColors.mutedForeground,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacySegmentedTabs extends StatelessWidget {
  const _LegacySegmentedTabs({
    super.key,
    required this.selected,
    required this.items,
    required this.onChanged,
    required this.accent,
    this.minItemWidth = 70,
    this.expand = false,
  });

  final String selected;
  final List<_LegacySegmentedTabItem> items;
  final ValueChanged<String> onChanged;
  final Color accent;
  final double minItemWidth;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final item in items)
        _LegacySegmentedTabButton(
          item: item,
          selected: item.value == selected,
          accent: accent,
          minWidth: minItemWidth,
          onTap: () => onChanged(item.value),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MomCozyColors.card.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: expand
            ? [for (final child in children) Expanded(child: child)]
            : children,
      ),
    );
  }
}

class _LegacySegmentedTabItem {
  const _LegacySegmentedTabItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;
}

class _LegacySegmentedTabButton extends StatelessWidget {
  const _LegacySegmentedTabButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.minWidth,
    required this.onTap,
  });

  final _LegacySegmentedTabItem item;
  final bool selected;
  final Color accent;
  final double minWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? accent : MomCozyColors.mutedForeground;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
    );

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 34),
        child: Material(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.control - 3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MomCozyRadii.control - 3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 15, color: foreground),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
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

class _GearStepper extends StatelessWidget {
  const _GearStepper({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  static const _min = 1;
  static const _max = 9;

  @override
  Widget build(BuildContext context) {
    final current = value.round().clamp(_min, _max);

    return SizedBox(
      width: 136,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GearStepButton(
                tooltip: '降低$label档位',
                icon: Icons.remove_rounded,
                enabled: current > _min,
                onTap: () => onChanged((current - 1).toDouble()),
              ),
              const SizedBox(width: 7),
              Container(
                width: 42,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                ),
                child: Text(
                  '$current',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _GearStepButton(
                tooltip: '提高$label档位',
                icon: Icons.add_rounded,
                enabled: current < _max,
                onTap: () => onChanged((current + 1).toDouble()),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var index = _min; index <= _max; index += 1)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1.4),
                    decoration: BoxDecoration(
                      color: index <= current
                          ? accent.withValues(alpha: 0.76)
                          : MomCozyColors.border.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GearStepButton extends StatelessWidget {
  const _GearStepButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? MomCozyColors.muted.withValues(alpha: 0.78)
            : MomCozyColors.muted.withValues(alpha: 0.34),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 16,
              color: enabled
                  ? MomCozyColors.foreground
                  : MomCozyColors.mutedForeground.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.accent,
    this.size = 38,
    this.iconSize = 21,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(size <= 28 ? 8 : 12),
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}

class _StatusPage extends StatefulWidget {
  const _StatusPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<_StatusPage> {
  String _view = 'mom';
  String _careStage = 'postpartum';
  bool _growthRecordAdded = false;
  MomCozyApiRuntime? _runtime;
  late Future<StatusOverview> _overviewFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _overviewFuture = runtime.statusRepository.fetchOverview(
        userId: runtime.userId,
      );
    }
  }

  void _reloadOverview() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _overviewFuture = runtime.statusRepository.fetchOverview(
        userId: runtime.userId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMom = _view == 'mom';

    return FutureBuilder<StatusOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        return _FeaturePageFrame(
          path: widget.path,
          title: widget.title,
          summary: widget.summary,
          icon: widget.icon,
          accent: widget.accent,
          trailing: _StatusIdentityTabs(
            selected: _view,
            momSubtitle: _careStage == 'pregnancy'
                ? '孕期档案'
                : _textOr(snapshot.data?.mom?.stage, '哺乳期档案'),
            babySubtitle: _textOr(
              snapshot.data?.baby?.nickname,
              _runtime?.babyId ?? '宝宝档案',
            ),
            onChanged: (next) => setState(() => _view = next),
          ),
          children: [
            const _SectionTitle('今日状态'),
            if (isMom)
              _CareStageSelector(
                selectedStage: _careStage,
                accent: widget.accent,
                onChanged: (stage) => setState(() => _careStage = stage),
              ),
            ..._overviewChildren(snapshot, isMom),
            const SizedBox(height: 18),
            const _SectionTitle('下一步'),
            _ActionTile(
              icon: isMom
                  ? Icons.edit_note_rounded
                  : Icons.monitor_weight_outlined,
              title: isMom
                  ? '补写孕期日记'
                  : (_growthRecordAdded ? '成长记录已添加' : '记录成长事件'),
              subtitle: isMom
                  ? '保留心情、体征和 Agent 分析上下文。'
                  : (_growthRecordAdded
                        ? '本地草稿已保存，同步恢复后会写入成长记录。'
                        : '记录身高、体重、睡眠和喂养变化。'),
              accent: widget.accent,
              onTap: isMom
                  ? () => context.go('/records')
                  : () => setState(() => _growthRecordAdded = true),
              trailing: isMom
                  ? const Icon(Icons.chevron_right_rounded)
                  : _StatusChip(
                      label: _growthRecordAdded ? '已记录' : '新增',
                      icon: _growthRecordAdded
                          ? Icons.check_circle_outline_rounded
                          : Icons.add_circle_outline_rounded,
                      accent: widget.accent,
                    ),
            ),
            _ActionTile(
              icon: Icons.fact_check_outlined,
              title: '今日待办',
              subtitle: '2 项待确认，提醒和 Agent 建议会在这里汇总。',
              accent: const Color(0xffb2773b),
              onTap: () => context.go('/schedule'),
              trailing: const _StatusChip(
                label: '2',
                icon: Icons.notifications_active_outlined,
                accent: Color(0xffb2773b),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _overviewChildren(
    AsyncSnapshot<StatusOverview> snapshot,
    bool isMom,
  ) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return [
        const _ActionTile(
          icon: Icons.sync_rounded,
          title: '正在同步状态',
          subtitle: '正在读取妈妈和宝宝状态。',
          accent: Color(0xff9f6378),
          trailing: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        _ActionTile(
          icon: Icons.cloud_off_outlined,
          title: '状态同步失败',
          subtitle: '检查后端连接或 token 后重试。',
          accent: const Color(0xff9f6378),
          trailing: IconButton(
            tooltip: '重试',
            onPressed: _reloadOverview,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ];
    }

    final overview = snapshot.data;
    if (overview == null || overview.isEmpty) {
      return const [
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: '暂无状态数据',
          subtitle: '完成妈妈/宝宝资料后这里会显示当前状态。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ];
    }

    return [
      _MetricWrap(
        children: isMom
            ? _momOverviewMetrics(overview.mom)
            : _babyOverviewMetrics(overview.baby),
      ),
    ];
  }

  List<Widget> _momOverviewMetrics(MomStatus? mom) {
    final isPregnancy = _careStage == 'pregnancy';

    return [
      _MetricTile(
        label: '阶段',
        value: isPregnancy ? '孕期' : _textOr(mom?.stage, '哺乳期'),
        icon: Icons.favorite_border_rounded,
        accent: widget.accent,
        note: isPregnancy
            ? '孕期重点：体征与日记'
            : (mom?.postpartumDay == null
                  ? null
                  : '产后第 ${mom!.postpartumDay} 天'),
      ),
      _MetricTile(
        label: '默认用户',
        value: _textOr(_runtime?.userId, '--'),
        icon: Icons.person_outline_rounded,
        accent: const Color(0xff43827b),
      ),
      const _MetricTile(
        label: '同步状态',
        value: '已连接',
        icon: Icons.cloud_done_outlined,
        accent: Color(0xff6b6da8),
      ),
    ];
  }

  List<Widget> _babyOverviewMetrics(BabyStatus? baby) {
    return [
      _MetricTile(
        label: '宝宝',
        value: _textOr(baby?.nickname, '未设置'),
        icon: Icons.child_care_rounded,
        accent: widget.accent,
        note: baby?.ageDays == null ? null : '${baby!.ageDays} 天',
      ),
      _MetricTile(
        label: '默认宝宝',
        value: _textOr(_runtime?.babyId, '--'),
        icon: Icons.badge_outlined,
        accent: const Color(0xff43827b),
      ),
      const _MetricTile(
        label: '同步状态',
        value: '已连接',
        icon: Icons.cloud_done_outlined,
        accent: Color(0xff6b6da8),
      ),
      _MetricTile(
        label: '成长记录',
        value: _growthRecordAdded ? '已添加' : '待记录',
        icon: Icons.trending_up_rounded,
        accent: const Color(0xffb2773b),
        note: _growthRecordAdded ? '本地草稿待同步' : null,
      ),
    ];
  }
}

class _CareStageSelector extends StatelessWidget {
  const _CareStageSelector({
    required this.selectedStage,
    required this.accent,
    required this.onChanged,
  });

  final String selectedStage;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPregnancy = selectedStage == 'pregnancy';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '护理阶段',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPregnancy ? '孕期档案优先关注体征、日记和待办。' : '哺乳期档案优先关注恢复、泵奶和喂养。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _LegacySegmentedTabs(
              selected: selectedStage,
              onChanged: onChanged,
              accent: accent,
              minItemWidth: 118,
              items: const [
                _LegacySegmentedTabItem(
                  value: 'pregnancy',
                  icon: Icons.pregnant_woman_rounded,
                  label: '孕期模式',
                ),
                _LegacySegmentedTabItem(
                  value: 'postpartum',
                  icon: Icons.favorite_border_rounded,
                  label: '哺乳期模式',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIdentityTabs extends StatelessWidget {
  const _StatusIdentityTabs({
    required this.selected,
    required this.momSubtitle,
    required this.babySubtitle,
    required this.onChanged,
  });

  final String selected;
  final String momSubtitle;
  final String babySubtitle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusIdentityTab(
            value: 'mom',
            title: '妈妈',
            subtitle: momSubtitle,
            asset: MomCozyAssets.momAvatar,
            selected: selected == 'mom',
            onTap: () => onChanged('mom'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusIdentityTab(
            value: 'baby',
            title: '宝宝',
            subtitle: babySubtitle,
            asset: MomCozyAssets.babyAvatar,
            selected: selected == 'baby',
            onTap: () => onChanged('baby'),
          ),
        ),
      ],
    );
  }
}

class _StatusIdentityTab extends StatelessWidget {
  const _StatusIdentityTab({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String title;
  final String subtitle;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? MomCozyColors.primary.withValues(alpha: 0.42)
        : MomCozyColors.border.withValues(alpha: 0.62);
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? MomCozyColors.raised.withValues(alpha: 0.72)
              : MomCozyColors.raised.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('status-identity-tab-$value'),
            onTap: onTap,
            child: Stack(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selected ? 1 : 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: MomCozyColors.primary,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(MomCozyRadii.pill),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? MomCozyColors.primary.withValues(alpha: 0.4)
                                : MomCozyColors.border,
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: AssetImage(asset),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: selected
                                        ? MomCozyColors.foreground
                                        : MomCozyColors.mutedForeground,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: selected
                                        ? MomCozyColors.mutedForeground
                                        : MomCozyColors.mutedForeground
                                              .withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _textOr(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

class _SchedulePage extends StatefulWidget {
  const _SchedulePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  bool _pumpReminderEnabled = true;
  bool _dailySummaryEnabled = true;
  final Map<String, bool> _taskDoneOverrides = {};
  final Map<String, List<ScheduleTask>> _localTasksByDay = {};
  final Set<String> _deletedTaskKeys = {};
  int _localTaskSequence = 0;
  MomCozyApiRuntime? _runtime;
  late DateTime _selectedDay;
  late Future<ScheduleDayPlan> _dayPlanFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _selectedDay = runtime.now();
      _dayPlanFuture = _fetchDayPlan(runtime);
    }
  }

  Future<ScheduleDayPlan> _fetchDayPlan(MomCozyApiRuntime runtime) {
    return runtime.scheduleRepository.fetchDayPlan(
      userId: runtime.userId,
      day: _selectedDay,
    );
  }

  void _reloadDayPlan() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _taskDoneOverrides.clear();
      _deletedTaskKeys.clear();
      _dayPlanFuture = _fetchDayPlan(runtime);
    });
  }

  void _selectDay(DateTime day) {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _selectedDay = day;
      _taskDoneOverrides.clear();
      _deletedTaskKeys.clear();
      _dayPlanFuture = _fetchDayPlan(runtime);
    });
  }

  void _toggleTask(ScheduleTask task, int index, bool? value) {
    final key = _taskScopedKey(task, index);
    setState(() {
      _taskDoneOverrides[key] = value ?? !_taskDone(task, index);
    });
  }

  void _addLocalTask() {
    final dayKey = _dayKey(_selectedDay);
    final localTasks = _localTasksByDay[dayKey] ?? const <ScheduleTask>[];
    _localTaskSequence += 1;
    final remindAt = DateTime.utc(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      21,
      30,
    );
    final task = ScheduleTask(
      id: 'local-$dayKey-$_localTaskSequence',
      title: '本地补充 ${localTasks.length + 1}',
      completed: false,
      remindAt: remindAt,
    );
    setState(() {
      _localTasksByDay[dayKey] = [...localTasks, task];
    });
  }

  void _deleteTask(ScheduleTask task, int index) {
    final key = _taskScopedKey(task, index);
    setState(() {
      _deletedTaskKeys.add(key);
      _taskDoneOverrides.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScheduleDayPlan>(
      future: _dayPlanFuture,
      builder: (context, snapshot) {
        final visibleTasks = snapshot.hasData
            ? _visibleTasks(snapshot.data!)
            : const <ScheduleTask>[];
        final taskCount = snapshot.hasData ? visibleTasks.length : null;
        final pendingTaskCount = visibleTasks
            .asMap()
            .entries
            .where((entry) => !_taskDone(entry.value, entry.key))
            .length;

        return _FeaturePageFrame(
          path: widget.path,
          title: widget.title,
          summary: widget.summary,
          icon: widget.icon,
          accent: widget.accent,
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _StatusChip(
                label: '今天',
                icon: Icons.today_outlined,
                accent: Color(0xffb2773b),
              ),
              _StatusChip(
                label: taskCount == null ? '同步中' : '$taskCount 项计划',
                icon: Icons.alarm_rounded,
                accent: const Color(0xff43827b),
              ),
              if (taskCount != null)
                _StatusChip(
                  label: '未完成 $pendingTaskCount',
                  icon: Icons.notification_important_outlined,
                  accent: const Color(0xff6b6da8),
                ),
            ],
          ),
          children: [
            _ScheduleDateStrip(
              selectedDay: _selectedDay,
              onSelected: _selectDay,
            ),
            const SizedBox(height: 14),
            _ScheduleContextCard(
              title: taskCount == null ? '计划同步中' : '稳奶计划执行中',
              subtitle: '产后阶段和当天记录会一起影响今日任务节奏。',
              completedCount: taskCount == null
                  ? 0
                  : taskCount - pendingTaskCount,
              totalCount: taskCount ?? 0,
              reminderEnabled: _pumpReminderEnabled,
              onReminderTap: () =>
                  setState(() => _pumpReminderEnabled = !_pumpReminderEnabled),
            ),
            const SizedBox(height: 14),
            _ScheduleNextTaskCard(
              subtitle: _nextTaskSubtitle(visibleTasks),
              task: _nextPendingTask(visibleTasks),
              onComplete: () {
                final next = _nextPendingTask(visibleTasks);
                if (next == null) return;
                final index = visibleTasks.indexOf(next);
                _toggleTask(next, index, true);
              },
            ),
            const SizedBox(height: 14),
            _ScheduleListToolbar(onAdd: _addLocalTask),
            ..._dayPlanChildren(snapshot),
            const SizedBox(height: 10),
            const _SectionTitle('提醒'),
            _ActionTile(
              icon: Icons.alarm_on_rounded,
              title: '泵奶提醒',
              subtitle: '需要 Android 通知权限和精确闹钟能力。',
              accent: widget.accent,
              trailing: Switch(
                value: _pumpReminderEnabled,
                onChanged: (value) =>
                    setState(() => _pumpReminderEnabled = value),
              ),
            ),
            _ActionTile(
              icon: Icons.summarize_outlined,
              title: '每日摘要',
              subtitle: '跨天时汇总计划、记录和 Agent 建议。',
              accent: const Color(0xff43827b),
              trailing: Switch(
                value: _dailySummaryEnabled,
                onChanged: (value) =>
                    setState(() => _dailySummaryEnabled = value),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _dayPlanChildren(AsyncSnapshot<ScheduleDayPlan> snapshot) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const [
        _ActionTile(
          icon: Icons.sync_rounded,
          title: '正在同步计划',
          subtitle: '正在读取当天任务和提醒。',
          accent: Color(0xffb2773b),
          trailing: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        _ActionTile(
          icon: Icons.cloud_off_outlined,
          title: '计划同步失败',
          subtitle: '检查后端连接或 token 后重试。',
          accent: widget.accent,
          trailing: IconButton(
            tooltip: '重试',
            onPressed: _reloadDayPlan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ];
    }

    final plan = snapshot.data;
    final tasks = plan == null ? const <ScheduleTask>[] : _visibleTasks(plan);
    if (tasks.isEmpty) {
      return const [
        _ActionTile(
          icon: Icons.event_available_outlined,
          title: '暂无计划',
          subtitle: '当天没有计划任务，可以从 Agent 或记录页创建。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.add_circle_outline_rounded),
        ),
      ];
    }

    return [
      for (final entry in tasks.asMap().entries)
        _ScheduleTaskRow(
          title: _textOr(entry.value.title, '未命名计划'),
          subtitle: _taskSubtitle(entry.value),
          timeLabel: _nullableTimeLabel(entry.value.remindAt),
          completed: _taskDone(entry.value, entry.key),
          accent: _taskAccent(entry.key),
          onTap: () => _toggleTask(entry.value, entry.key, null),
          onDelete: () => _deleteTask(entry.value, entry.key),
          onChanged: (value) => _toggleTask(entry.value, entry.key, value),
        ),
    ];
  }

  bool _taskDone(ScheduleTask task, int index) {
    return _taskDoneOverrides[_taskScopedKey(task, index)] ?? task.completed;
  }

  List<ScheduleTask> _visibleTasks(ScheduleDayPlan plan) {
    final dayKey = _dayKey(_selectedDay);
    final tasks = [...plan.tasks, ...?_localTasksByDay[dayKey]];
    return tasks
        .asMap()
        .entries
        .where(
          (entry) => !_deletedTaskKeys.contains(
            _taskScopedKey(entry.value, entry.key),
          ),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  ScheduleTask? _nextPendingTask(List<ScheduleTask> tasks) {
    final pending =
        tasks
            .asMap()
            .entries
            .where((entry) => !_taskDone(entry.value, entry.key))
            .map((entry) => entry.value)
            .where((task) => task.remindAt != null)
            .toList()
          ..sort((a, b) => a.remindAt!.compareTo(b.remindAt!));
    return pending.isEmpty ? null : pending.first;
  }

  String _nextTaskSubtitle(List<ScheduleTask> tasks) {
    final runtime = _runtime;
    final now = runtime?.now().toUtc() ?? DateTime.now().toUtc();
    final task = _nextPendingTask(tasks);
    if (task == null) return '没有待提醒任务。';

    final minutes = task.remindAt!.toUtc().difference(now).inMinutes;
    if (minutes <= 0) return '${_textOr(task.title, '下一项')} 已到提醒时间。';
    const minutesPerHour = 60;
    const minutesPerDay = 24 * minutesPerHour;
    final days = minutes ~/ minutesPerDay;
    final hours = (minutes % minutesPerDay) ~/ minutesPerHour;
    final remainingMinutes = minutes % minutesPerHour;
    if (days > 0) {
      return '${_textOr(task.title, '下一项')} 还有 $days 天 $hours 小时。';
    }
    if (hours > 0) {
      return '${_textOr(task.title, '下一项')} 还有 $hours 小时 $remainingMinutes 分钟。';
    }
    return '${_textOr(task.title, '下一项')} 还有 $remainingMinutes 分钟。';
  }

  String _taskScopedKey(ScheduleTask task, int index) {
    return '${_dayKey(_selectedDay)}:${_taskKey(task, index)}';
  }

  String _taskKey(ScheduleTask task, int index) {
    return task.id.isEmpty ? 'task-$index' : task.id;
  }
}

class _ScheduleDateStrip extends StatelessWidget {
  const _ScheduleDateStrip({
    required this.selectedDay,
    required this.onSelected,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            '${selectedDate.year}年${selectedDate.month}月',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: MomCozyDecorations.card(
            color: MomCozyColors.card.withValues(alpha: 0.82),
            shadows: MomCozyShadows.soft,
            radius: 14,
          ),
          child: Row(
            children: [
              _ScheduleWeekButton(
                icon: Icons.chevron_left_rounded,
                onTap: () =>
                    onSelected(selectedDate.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var offset = -3; offset <= 3; offset += 1)
                      _DatePill(
                        day: offset == 0
                            ? '今'
                            : _weekdayLabel(
                                selectedDate.add(Duration(days: offset)),
                              ),
                        date: selectedDate
                            .add(Duration(days: offset))
                            .day
                            .toString(),
                        selected: offset == 0,
                        onTap: () => onSelected(
                          selectedDate.add(Duration(days: offset)),
                        ),
                      ),
                  ],
                ),
              ),
              _ScheduleWeekButton(
                icon: Icons.chevron_right_rounded,
                onTap: () =>
                    onSelected(selectedDate.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleWeekButton extends StatelessWidget {
  const _ScheduleWeekButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 30,
          height: 42,
          child: Icon(icon, size: 19, color: MomCozyColors.mutedForeground),
        ),
      ),
    );
  }
}

class _ScheduleContextCard extends StatelessWidget {
  const _ScheduleContextCard({
    required this.title,
    required this.subtitle,
    required this.completedCount,
    required this.totalCount,
    required this.reminderEnabled,
    required this.onReminderTap,
  });

  final String title;
  final String subtitle;
  final int completedCount;
  final int totalCount;
  final bool reminderEnabled;
  final VoidCallback onReminderTap;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.72),
        radius: 22,
        shadows: MomCozyShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              tooltip: reminderEnabled ? '关闭计划提醒' : '开启计划提醒',
              onPressed: onReminderTap,
              icon: Icon(
                reminderEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: reminderEnabled
                    ? MomCozyColors.primary
                    : MomCozyColors.mutedForeground,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '今日任务',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: MomCozyColors.foreground.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$completedCount/$totalCount',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 10,
                    color: MomCozyColors.primary,
                    backgroundColor: MomCozyColors.secondary.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleNextTaskCard extends StatelessWidget {
  const _ScheduleNextTaskCard({
    required this.subtitle,
    required this.task,
    required this.onComplete,
  });

  final String subtitle;
  final ScheduleTask? task;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final task = this.task;
    final hasTask = task != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MomCozyColors.primary.withValues(alpha: 0.15),
            MomCozyColors.card.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MomCozyColors.primary.withValues(alpha: 0.18),
        ),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasTask ? '待执行任务' : '今天还没有待提醒任务',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MomCozyColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nullableTimeLabel(task?.remindAt),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: MomCozyColors.foreground,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _textOr(task?.title, subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MomCozyColors.foreground.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 86),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: MomCozyColors.amberSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MomCozyColors.amber.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  subtitle,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Color(0xff7d5730),
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (hasTask) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('手动完成'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleListToolbar extends StatelessWidget {
  const _ScheduleListToolbar({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '今日任务',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor: MomCozyColors.foreground,
              backgroundColor: MomCozyColors.card,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                side: BorderSide(
                  color: MomCozyColors.border.withValues(alpha: 0.7),
                ),
              ),
              textStyle: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('添加任务'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTaskRow extends StatelessWidget {
  const _ScheduleTaskRow({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.completed,
    required this.accent,
    required this.onTap,
    required this.onDelete,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final bool completed;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(
          color: completed
              ? const Color(0xfff0f7ee)
              : MomCozyColors.card.withValues(alpha: 0.94),
          borderColor: completed
              ? const Color(0xffc8dfc2)
              : MomCozyColors.border.withValues(alpha: 0.72),
          radius: 16,
          shadows: const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                fontWeight: FontWeight.w700,
                                height: 1.22,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '删除任务',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  Checkbox(value: completed, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.day,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String day;
  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? MomCozyColors.roseSoft : MomCozyColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? MomCozyColors.primary.withValues(alpha: 0.48)
                : MomCozyColors.border.withValues(alpha: 0.72),
          ),
          boxShadow: selected ? MomCozyShadows.soft : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      day,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? MomCozyColors.primary
                            : MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected
                            ? MomCozyColors.primary
                            : MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _taskSubtitle(ScheduleTask task) {
  final remindAt = task.remindAt;
  if (remindAt == null) return '暂无提醒时间，可稍后补充。';
  return '提醒 ${_timeLabel(remindAt)} · 可从通知直接进入相关页面。';
}

Color _taskAccent(int index) {
  return switch (index % 3) {
    0 => const Color(0xffb2773b),
    1 => const Color(0xff43827b),
    _ => const Color(0xff6b6da8),
  };
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _dayKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _weekdayLabel(DateTime value) {
  return switch (value.weekday) {
    DateTime.monday => '一',
    DateTime.tuesday => '二',
    DateTime.wednesday => '三',
    DateTime.thursday => '四',
    DateTime.friday => '五',
    DateTime.saturday => '六',
    _ => '日',
  };
}

class _DevicePage extends StatefulWidget {
  const _DevicePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<_DevicePage> {
  bool _isScanning = false;
  BlePlatform? _blePlatform;
  BlePermissionState _permissionState = BlePermissionState.unknown;
  List<BleDeviceSnapshot> _connectedDevices = const [];
  List<BleDeviceSnapshot> _scanResults = const [];
  String? _bleError;
  bool _scanAttempted = false;
  String? _runtimeUserId;
  StreamSubscription<BleDeviceSnapshot>? _scanSub;
  StreamSubscription<BleScanFailure>? _scanFailureSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final ble = runtime.blePlatform;
    final previousUserId = _runtimeUserId;
    final userChanged =
        previousUserId != null && previousUserId != runtime.userId;
    _runtimeUserId = runtime.userId;
    if (!identical(ble, _blePlatform)) {
      unawaited(_scanSub?.cancel());
      unawaited(_scanFailureSub?.cancel());
      _blePlatform = ble;
      _scanSub = ble.scanResults.listen(_handleScanResult);
      _scanFailureSub = ble.scanFailures.listen(_handleScanFailure);
      unawaited(_refreshBleState());
    }
    if (userChanged) unawaited(_clearDevicesForUserSwitch());
  }

  @override
  void dispose() {
    unawaited(_scanSub?.cancel());
    unawaited(_scanFailureSub?.cancel());
    super.dispose();
  }

  Future<void> _refreshBleState() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      final permission = await ble.permissionState();
      final connected = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _permissionState = permission;
        _connectedDevices = connected;
        _bleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bleError = 'BLE 状态读取失败';
      });
    }
  }

  Future<void> _clearDevicesForUserSwitch() async {
    final ble = _blePlatform;
    if (ble == null) return;
    final devices = _connectedDevices.isEmpty
        ? await ble.getConnectedDevices()
        : _connectedDevices;
    try {
      if (_isScanning) await ble.stopScan();
      for (final device in devices.where((device) => device.connected)) {
        await ble.disconnect(device.deviceId);
      }
    } catch (_) {
      // Best-effort local isolation; native cleanup is verified in device lab.
    }
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _connectedDevices = const [];
      _scanResults = const [];
      _scanAttempted = false;
      _bleError = '检测到用户切换，已隔离上一用户设备连接。';
    });
  }

  Future<void> _toggleScan() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      if (_isScanning) {
        await ble.stopScan();
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
        return;
      }

      final permission = await ble.requestPermission();
      if (permission != BlePermissionState.granted) {
        if (!mounted) return;
        setState(() {
          _permissionState = permission;
          _bleError = _permissionDeniedMessage(permission);
        });
        return;
      }

      await ble.startScan();
      if (!mounted) return;
      setState(() {
        _permissionState = permission;
        _isScanning = true;
        _scanAttempted = true;
        _scanResults = const [];
        _bleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = 'BLE 扫描启动失败';
      });
    }
  }

  void _handleScanResult(BleDeviceSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _scanResults = [
        snapshot,
        ..._scanResults.where((item) => item.deviceId != snapshot.deviceId),
      ];
      _bleError = null;
    });
  }

  void _handleScanFailure(BleScanFailure failure) {
    if (!mounted) return;
    setState(() {
      _bleError = failure.message;
      _isScanning = false;
    });
  }

  Future<void> _connectScanResult(BleDeviceSnapshot snapshot) async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      await ble.connect(snapshot.deviceId);
      await ble.stopScan();
      await _refreshBleState();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = '${snapshot.deviceName} 已连接';
      });
    } catch (_) {
      await ble.stopScan();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _bleError = '连接 ${snapshot.deviceName} 失败，请重试。';
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    final ble = _blePlatform;
    if (ble == null) return;
    if (_permissionState == BlePermissionState.permanentlyDenied) {
      await ble.openAppSettings();
    } else {
      await ble.openBluetoothSettings();
    }
    await _refreshBleState();
  }

  @override
  Widget build(BuildContext context) {
    final leftDevice = _deviceForSide('L') ?? _deviceForSide('left');
    final rightDevice = _deviceForSide('R') ?? _deviceForSide('right');

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _toggleScan,
            icon: Icon(_isScanning ? Icons.stop_rounded : Icons.search_rounded),
            label: Text(_isScanning ? '停止扫描' : '扫描'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/device/manage'),
            icon: const Icon(Icons.settings_remote_rounded),
            label: const Text('管理'),
          ),
        ],
      ),
      children: [
        _ActionTile(
          icon: _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
          title: _isScanning ? '正在扫描附近设备' : 'BLE 权限和扫描',
          subtitle:
              _bleError ??
              (_isScanning
                  ? '正在查找附近设备；超时或空结果会显示在这里。'
                  : '权限状态 ${_permissionLabel(_permissionState)}，已恢复 ${_connectedDevices.length} 台已连接设备。'),
          accent: widget.accent,
          trailing: _isScanning
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _permissionAction(),
        ),
        const _SectionTitle('左右设备'),
        _DeviceSideTile(
          side: '左侧',
          name: leftDevice?.deviceName ?? '等待连接',
          state: leftDevice?.connected == true ? '已连接' : '未连接',
          battery: _deviceBatteryLabel(leftDevice),
          accent: widget.accent,
        ),
        _DeviceSideTile(
          side: '右侧',
          name: rightDevice?.deviceName ?? '等待连接',
          state: rightDevice?.connected == true ? '已连接' : '未连接',
          battery: _deviceBatteryLabel(rightDevice),
          accent: const Color(0xff7f6a75),
        ),
        if (_scanAttempted) ...[
          const SizedBox(height: 8),
          const _SectionTitle('扫描结果'),
          if (_scanResults.isEmpty)
            const _ActionTile(
              icon: Icons.bluetooth_disabled_rounded,
              title: '暂无扫描结果',
              subtitle: '请确认设备已开机并靠近手机后重试。',
              accent: Color(0xff7f6a75),
              trailing: Icon(Icons.refresh_rounded),
            )
          else
            for (final device in _scanResults.take(3))
              _ActionTile(
                icon: Icons.bluetooth_searching,
                title: device.deviceName,
                subtitle: _scanResultSubtitle(device),
                accent: widget.accent,
                onTap: () => _connectScanResult(device),
                trailing: const Icon(Icons.link_rounded),
              ),
        ],
        const SizedBox(height: 8),
        const _SectionTitle('设备入口'),
        _ActionTile(
          icon: Icons.tune_rounded,
          title: '进入舒适校准',
          subtitle: '复用左右设备状态，保存后进入泵奶参数。',
          accent: const Color(0xff9b6b2f),
          onTap: () => context.go('/calibration'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        if (_internalDeviceDebugEnabled)
          _ActionTile(
            icon: Icons.bug_report_outlined,
            title: '内部调试参数',
            subtitle: '仅用于 QA/dev，正式包需要 feature flag 控制。',
            accent: const Color(0xff7f6a75),
            onTap: () => context.go('/device/user'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
      ],
    );
  }

  Widget _permissionAction() {
    if (_permissionState == BlePermissionState.permanentlyDenied) {
      return IconButton(
        tooltip: '打开系统设置',
        onPressed: _openPermissionSettings,
        icon: const Icon(Icons.settings_rounded),
      );
    }
    if (_permissionState == BlePermissionState.denied) {
      return IconButton(
        tooltip: '打开蓝牙设置',
        onPressed: _openPermissionSettings,
        icon: const Icon(Icons.bluetooth_disabled_rounded),
      );
    }
    return const Icon(Icons.chevron_right_rounded);
  }

  BleDeviceSnapshot? _deviceForSide(String side) {
    final normalized = side.toLowerCase();
    for (final device in _connectedDevices) {
      if (device.side.toLowerCase() == normalized) return device;
    }
    return null;
  }
}

String _deviceBatteryLabel(BleDeviceSnapshot? device) {
  final battery = device?.battery;
  if (battery == null) return '--';
  return '$battery%';
}

String _scanResultSubtitle(BleDeviceSnapshot device) {
  final details = <String>[
    device.side,
    device.deviceId,
    if (device.battery != null) '电量 ${device.battery}%',
    if (device.rssi != null) 'RSSI ${device.rssi}',
  ];
  return details.join(' · ');
}

String _permissionLabel(BlePermissionState state) {
  return switch (state) {
    BlePermissionState.granted => '已授权',
    BlePermissionState.denied => '未授权',
    BlePermissionState.permanentlyDenied => '永久拒绝',
    BlePermissionState.unknown => '未请求',
  };
}

String _permissionDeniedMessage(BlePermissionState state) {
  if (state == BlePermissionState.permanentlyDenied) {
    return 'BLE 权限已永久拒绝，请从系统设置重新开启。';
  }
  return 'BLE 权限未授权';
}

class _DeviceSideTile extends StatelessWidget {
  const _DeviceSideTile({
    required this.side,
    required this.name,
    required this.state,
    required this.battery,
    required this.accent,
  });

  final String side;
  final String name;
  final String state;
  final String battery;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: state == '已连接'
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      title: '$side $name',
      subtitle: '$state · $battery',
      accent: accent,
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _PumpDeviceThumbnail(connected: state == '已连接', size: 38),
          IconButton(
            tooltip: state == '已连接' ? '校准' : '连接',
            onPressed: () => state == '已连接'
                ? context.go('/calibration')
                : context.go('/device/manage'),
            icon: Icon(
              state == '已连接' ? Icons.tune_rounded : Icons.link_rounded,
            ),
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () => context.go('/device/manage'),
            icon: const Icon(Icons.more_horiz_rounded),
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _PumpDeviceThumbnail extends StatelessWidget {
  const _PumpDeviceThumbnail({this.connected = true, this.size = 46});

  final bool connected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: connected ? 1 : 0.52,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: connected
              ? MomCozyColors.raised
              : MomCozyColors.muted.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(
            color: MomCozyColors.border.withValues(alpha: 0.58),
          ),
        ),
        child: Image.asset(MomCozyAssets.pumpM9, fit: BoxFit.contain),
      ),
    );
  }
}

enum _PumpRunState { idle, running, paused }

class _PumpPage extends StatefulWidget {
  const _PumpPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<_PumpPage> {
  _PumpRunState _runState = _PumpRunState.idle;
  double _leftLevel = 5;
  double _rightLevel = 5;
  int _elapsedMinutes = 0;
  int _leftVolumeMl = 0;
  int _rightVolumeMl = 0;
  String? _sessionOwnerUserId;
  bool _completionUploadLocked = false;
  bool _duplicateCompletionBlocked = false;
  MomCozyApiRuntime? _runtime;
  PumpWorkstateReply? _lastReply;
  Object? _uploadError;
  String? _guardNotice;
  bool _isUploading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final previousRuntime = _runtime;
    if (previousRuntime != null &&
        previousRuntime.userId != runtime.userId &&
        _runState != _PumpRunState.idle) {
      _runState = _PumpRunState.idle;
      _isUploading = false;
      _elapsedMinutes = 0;
      _leftVolumeMl = 0;
      _rightVolumeMl = 0;
      _sessionOwnerUserId = null;
      _completionUploadLocked = false;
      _duplicateCompletionBlocked = false;
      _lastReply = null;
      _uploadError = null;
      _guardNotice = '检测到用户切换，已清空上一用户 session。';
    }
    _runtime = runtime;
  }

  void _changeRunState(_PumpRunState next) {
    if (next == _PumpRunState.idle && _completionUploadLocked) {
      setState(() {
        _duplicateCompletionBlocked = true;
        _guardNotice = '重复结束已拦截，本次 session 只保留一组结束上传。';
      });
      return;
    }

    setState(() {
      _applyLocalSessionTransition(next);
      _runState = next;
    });
    _uploadWorkstate(next);
  }

  void _applyLocalSessionTransition(_PumpRunState next) {
    final previous = _runState;
    if (previous == _PumpRunState.idle && next == _PumpRunState.running) {
      _sessionOwnerUserId = _runtime?.userId;
      _completionUploadLocked = false;
      _duplicateCompletionBlocked = false;
      _elapsedMinutes = 0;
      _leftVolumeMl = 0;
      _rightVolumeMl = 0;
      _guardNotice = '已绑定 ${_sessionOwnerUserId ?? '当前用户'}。';
      _advanceLocalProgress(minutes: 2);
      return;
    }

    if (previous == _PumpRunState.running && next == _PumpRunState.paused) {
      _advanceLocalProgress(minutes: 3);
      return;
    }

    if (previous == _PumpRunState.paused && next == _PumpRunState.running) {
      _advanceLocalProgress(minutes: 2);
      return;
    }

    if (next == _PumpRunState.idle && previous != _PumpRunState.idle) {
      _advanceLocalProgress(minutes: 1);
      _completionUploadLocked = true;
      _duplicateCompletionBlocked = false;
      _guardNotice = '结束上传已锁定：summary、milk record、Agent context 仅允许一次。';
    }
  }

  void _advanceLocalProgress({required int minutes}) {
    _elapsedMinutes += minutes;
    _leftVolumeMl += (_leftLevel * minutes).round();
    _rightVolumeMl += (_rightLevel * minutes * 0.8).round();
  }

  Future<void> _uploadWorkstate(_PumpRunState state) async {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final reply = await runtime.pumpWorkstateRepository.uploadWorkstate(
        userId: runtime.userId,
        left: PumpSideWorkstate(
          state: _pumpStateCode(state),
          mode: 'massage_expression',
          level: _leftLevel.round(),
        ),
        right: PumpSideWorkstate(
          state: _pumpStateCode(state),
          mode: 'expression',
          level: _rightLevel.round(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lastReply = reply;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadError = error;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _runState == _PumpRunState.running;
    final isPaused = _runState == _PumpRunState.paused;

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusChip(
            label: isRunning
                ? '进行中'
                : isPaused
                ? '已暂停'
                : '待开始',
            icon: isRunning
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            accent: widget.accent,
          ),
          const _StatusChip(
            label: '前台服务待验证',
            icon: Icons.notifications_active_outlined,
            accent: Color(0xffb2773b),
          ),
        ],
      ),
      children: [
        const _SectionTitle('Session 控制'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () => _changeRunState(_PumpRunState.running),
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.water_drop,
              ),
              label: Text(isPaused ? '恢复' : '开始'),
            ),
            OutlinedButton.icon(
              onPressed: isRunning
                  ? () => _changeRunState(_PumpRunState.paused)
                  : null,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('暂停'),
            ),
            OutlinedButton.icon(
              onPressed: _runState == _PumpRunState.idle
                  ? null
                  : () => _changeRunState(_PumpRunState.idle),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('结束'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Session 进度'),
        _MetricWrap(
          children: [
            _MetricTile(
              label: '运行时长',
              value: '$_elapsedMinutes 分钟',
              icon: Icons.timer_outlined,
              accent: widget.accent,
              note: _sessionOwnerUserId == null
                  ? '未绑定用户'
                  : '绑定 $_sessionOwnerUserId',
            ),
            _MetricTile(
              label: '左侧进度',
              value: '$_leftVolumeMl mL',
              icon: Icons.water_drop_outlined,
              accent: widget.accent,
              note: '档位 ${_leftLevel.round()}',
            ),
            _MetricTile(
              label: '右侧进度',
              value: '$_rightVolumeMl mL',
              icon: Icons.water_drop_outlined,
              accent: const Color(0xff43827b),
              note: '档位 ${_rightLevel.round()}',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('左右侧参数'),
        _PumpSideTile(
          label: '左侧',
          mode: '按摩 + 吸乳',
          level: _leftLevel,
          accent: widget.accent,
          onChanged: (value) => setState(() => _leftLevel = value),
        ),
        _PumpSideTile(
          label: '右侧',
          mode: '吸乳',
          level: _rightLevel,
          accent: const Color(0xff43827b),
          onChanged: (value) => setState(() => _rightLevel = value),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('结束保护'),
        _ActionTile(
          icon: _duplicateCompletionBlocked
              ? Icons.block_rounded
              : Icons.verified_outlined,
          title: _completionGuardTitle(),
          subtitle: _guardNotice ?? '开始后绑定当前用户，结束时锁定一次性上传标记。',
          accent: _duplicateCompletionBlocked
              ? const Color(0xffb2773b)
              : const Color(0xff43827b),
          trailing: _StatusChip(
            label: _completionUploadLocked ? '1/1' : '待结束',
            icon: _completionUploadLocked
                ? Icons.lock_outline_rounded
                : Icons.hourglass_empty_rounded,
            accent: _duplicateCompletionBlocked
                ? const Color(0xffb2773b)
                : const Color(0xff43827b),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('上传状态'),
        _ActionTile(
          icon: _uploadError == null
              ? Icons.cloud_sync_outlined
              : Icons.cloud_off_outlined,
          title: _uploadStatusTitle(),
          subtitle: _uploadStatusSubtitle(),
          accent: const Color(0xff6b6da8),
          trailing: _isUploading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: '重试同步',
                  onPressed: () => _uploadWorkstate(_runState),
                  icon: const Icon(Icons.refresh_rounded),
                ),
        ),
      ],
    );
  }

  String _uploadStatusTitle() {
    if (_isUploading) return '正在同步 workstate';
    if (_uploadError != null) return 'Workstate 同步失败';
    if (_lastReply != null) return 'Workstate 已同步';
    return 'Agent context 上传';
  }

  String _uploadStatusSubtitle() {
    if (_uploadError is String) return _uploadError! as String;
    if (_uploadError != null) return '检查后端连接或 token 后重试。';
    final reply = _lastReply;
    if (reply == null) return '结束后生成摘要、奶量记录和智能体上下文；重复上传会被自动拦截。';
    if (reply.output.isNotEmpty) return reply.output;
    return reply.needReply ? '后端需要处理设备状态回复。' : '后端已接收当前左右侧状态。';
  }

  String _completionGuardTitle() {
    if (_duplicateCompletionBlocked) return '重复结束已拦截';
    if (_completionUploadLocked) return '结束同步已锁定';
    if (_sessionOwnerUserId != null) return 'Session 用户已绑定';
    return 'Session 等待开始';
  }
}

int _pumpStateCode(_PumpRunState state) {
  return switch (state) {
    _PumpRunState.running => 1,
    _PumpRunState.paused => 2,
    _PumpRunState.idle => 0,
  };
}

class _PumpSideTile extends StatelessWidget {
  const _PumpSideTile({
    required this.label,
    required this.mode,
    required this.level,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final String mode;
  final double level;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.compress_rounded,
      title: '$label · $mode',
      subtitle: '档位 ${level.round()}，调整后会同步到当前连接设备。',
      accent: accent,
      trailing: _GearStepper(
        label: label,
        value: level,
        accent: accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _CalibrationPage extends StatefulWidget {
  const _CalibrationPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<_CalibrationPage> {
  double _leftComfort = 4;
  double _rightComfort = 4;
  BlePlatform? _blePlatform;
  List<BleDeviceSnapshot> _connectedDevices = const [];
  String? _deviceStatusError;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ble = MomCozyRuntimeScope.of(context).blePlatform;
    if (!identical(ble, _blePlatform)) {
      _blePlatform = ble;
      unawaited(_refreshCalibrationDevices());
    }
  }

  Future<void> _refreshCalibrationDevices() async {
    final ble = _blePlatform;
    if (ble == null) return;
    try {
      final devices = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = devices;
        _deviceStatusError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceStatusError = '设备状态同步失败，请稍后重试。';
      });
    }
  }

  void _setLeftComfort(double value) {
    setState(() {
      _leftComfort = value;
      _hasUnsavedChanges = true;
      _saveError = null;
    });
  }

  void _setRightComfort(double value) {
    setState(() {
      _rightComfort = value;
      _hasUnsavedChanges = true;
      _saveError = null;
    });
  }

  void _resetCalibrationChanges() {
    setState(() {
      _leftComfort = 4;
      _rightComfort = 4;
      _hasUnsavedChanges = false;
      _saveError = '已恢复默认校准档位，可安全退出。';
    });
  }

  Future<void> _saveAndEnterPump() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      await runtime.ensurePumpProtocolReady();
      await runtime.pumpProtocolPlatform.adjustGearForSide(
        PumpSide.left,
        _leftComfort.round(),
      );
      await runtime.pumpProtocolPlatform.adjustGearForSide(
        PumpSide.right,
        _rightComfort.round(),
      );
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = false;
      });
      context.go('/pump');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = _calibrationSaveErrorText(error);
      });
    }
  }

  void _exitCalibration() {
    if (_hasUnsavedChanges) {
      setState(() {
        _saveError = '有未保存校准更改，请先保存或恢复默认后再退出。';
      });
      return;
    }
    context.go('/device');
  }

  @override
  Widget build(BuildContext context) {
    final leftDevice = _deviceForSide('L') ?? _deviceForSide('left');
    final rightDevice = _deviceForSide('R') ?? _deviceForSide('right');

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: const _StatusChip(
        label: '左右独立',
        icon: Icons.compare_arrows_rounded,
        accent: Color(0xff9b6b2f),
      ),
      children: [
        const _SectionTitle('设备状态'),
        if (_deviceStatusError != null)
          _ActionTile(
            icon: Icons.bluetooth_disabled_rounded,
            title: '设备状态同步失败',
            subtitle: _deviceStatusError!,
            accent: Colors.red,
            trailing: IconButton(
              tooltip: '重试设备状态',
              onPressed: _refreshCalibrationDevices,
              icon: const Icon(Icons.refresh_rounded),
            ),
          )
        else ...[
          _CalibrationDeviceTile(
            label: '左侧',
            device: leftDevice,
            accent: widget.accent,
          ),
          _CalibrationDeviceTile(
            label: '右侧',
            device: rightDevice,
            accent: const Color(0xff43827b),
          ),
        ],
        const SizedBox(height: 8),
        const _SectionTitle('舒适档位'),
        _CalibrationSideTile(
          label: '左侧',
          value: _leftComfort,
          accent: widget.accent,
          onChanged: _setLeftComfort,
        ),
        _CalibrationSideTile(
          label: '右侧',
          value: _rightComfort,
          accent: const Color(0xff43827b),
          onChanged: _setRightComfort,
        ),
        const SizedBox(height: 8),
        const _SectionTitle('保存规则'),
        _ActionTile(
          icon: Icons.verified_user_outlined,
          title: '校准结果保存检查',
          subtitle: _saveError ?? '保存前会检查左右设备状态，并处理历史校准数据。',
          accent: _saveError == null ? const Color(0xff7f6a75) : Colors.red,
          trailing: _isSaving
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(
                  _saveError == null
                      ? Icons.rule_rounded
                      : Icons.error_outline_rounded,
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveAndEnterPump,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isSaving ? '保存中' : '保存并进入泵奶'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _exitCalibration,
              icon: const Icon(Icons.close_rounded),
              label: const Text('退出校准'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetCalibrationChanges,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('恢复默认'),
            ),
          ],
        ),
      ],
    );
  }

  BleDeviceSnapshot? _deviceForSide(String side) {
    final normalized = side.toLowerCase();
    for (final device in _connectedDevices) {
      if (device.side.toLowerCase() == normalized) return device;
    }
    return null;
  }

  String _calibrationSaveErrorText(Object error) {
    final text = '$error';
    if (text.contains('No BLE device') ||
        text.contains('No pump protocol state')) {
      return '未检测到左右设备连接，请先在设备页连接后再保存。';
    }
    if (text.contains('BLE permission')) {
      return '蓝牙权限未开启，请授权后重试。';
    }
    return '校准保存失败，请稍后重试。';
  }
}

class _CalibrationDeviceTile extends StatelessWidget {
  const _CalibrationDeviceTile({
    required this.label,
    required this.device,
    required this.accent,
  });

  final String label;
  final BleDeviceSnapshot? device;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final connected = device != null;
    return _ActionTile(
      icon: connected
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      title: '$label设备${connected ? '已连接' : '未连接'}',
      subtitle: connected
          ? '${device!.deviceName} · 电量 ${_deviceBatteryLabel(device)}'
          : '未检测到连接设备，保存时会提示重试。',
      accent: connected ? accent : const Color(0xff7f6a75),
      trailing: Icon(
        connected ? Icons.check_circle_outline_rounded : Icons.info_outline,
      ),
    );
  }
}

class _CalibrationSideTile extends StatelessWidget {
  const _CalibrationSideTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.tune_rounded,
      title: '$label 舒适档位 ${value.round()}',
      subtitle: '低档位用于找舒适点，高档位需二次确认。',
      accent: accent,
      trailing: _GearStepper(
        label: label,
        value: value,
        accent: accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _RecordsPage extends StatefulWidget {
  const _RecordsPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<_RecordsPage> {
  String _filter = 'pump';
  String _volumeUnit = 'mL';
  final List<PumpMilkRecord> _localPumpRecords = [];
  final Map<String, PumpMilkRecord> _editedPumpRecords = {};
  final Set<String> _deletedPumpRecordIds = {};
  int _localPumpRecordSequence = 0;
  MomCozyApiRuntime? _runtime;
  late DateTime _recordsDay;
  late Future<_RecordsOverview> _recordsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _recordsDay = runtime.now();
      _recordsFuture = _fetchRecords(runtime);
    }
  }

  Future<_RecordsOverview> _fetchRecords(MomCozyApiRuntime runtime) async {
    final repository = runtime.recordsRepository;
    final pump = await repository.fetchPumpMilkRecords(
      userId: runtime.userId,
      date: _recordsDay,
    );
    final feeding = await repository.fetchFeedingRecords(
      userId: runtime.userId,
      date: _recordsDay,
    );
    final growth = await repository.fetchGrowthRecords(
      userId: runtime.userId,
      babyId: runtime.babyId,
    );
    return _RecordsOverview(pump: pump, feeding: feeding, growth: growth);
  }

  void _reloadRecords() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _recordsFuture = _fetchRecords(runtime);
    });
  }

  void _shiftRecordsMonth(int delta) {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _recordsDay = DateTime.utc(
        _recordsDay.year,
        _recordsDay.month + delta,
        _recordsDay.day,
      );
      _recordsFuture = _fetchRecords(runtime);
    });
  }

  void _toggleVolumeUnit() {
    setState(() {
      _volumeUnit = _volumeUnit == 'mL' ? 'oz' : 'mL';
    });
  }

  void _addManualPumpRecord() {
    _localPumpRecordSequence += 1;
    final occurredAt = DateTime.utc(
      _recordsDay.year,
      _recordsDay.month,
      _recordsDay.day,
      21,
      45,
    );
    final record = PumpMilkRecord(
      id: 'local-pump-$_localPumpRecordSequence',
      title: '手动补录 $_localPumpRecordSequence',
      pumpSource: 9,
      amountMl: 90,
      occurredAt: occurredAt,
    );
    setState(() {
      _filter = 'pump';
      _localPumpRecords.insert(0, record);
    });
  }

  void _editPumpRecord(PumpMilkRecord record) {
    final edited = PumpMilkRecord(
      id: record.id,
      title: '已编辑 ${_textOr(record.title, '泵奶记录')}',
      pumpType: record.pumpType,
      pumpSource: record.pumpSource,
      amountMl: (record.amountMl ?? 0) + 10,
      occurredAt: record.occurredAt,
    );
    setState(() {
      _editedPumpRecords[record.id] = edited;
    });
  }

  void _deletePumpRecord(PumpMilkRecord record) {
    setState(() {
      _deletedPumpRecordIds.add(record.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RecordsOverview>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        final overview = snapshot.data == null
            ? null
            : _applyLocalRecordEdits(snapshot.data!);

        return ListView(
          key: ValueKey('route-page-${widget.path}'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _RecordsMonthHeader(
              day: _recordsDay,
              onPrevious: () => _shiftRecordsMonth(-1),
              onNext: () => _shiftRecordsMonth(1),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LegacySegmentedTabs(
                  key: const ValueKey('records-filter-segment'),
                  selected: _filter,
                  onChanged: (next) => setState(() => _filter = next),
                  accent: MomCozyColors.primary,
                  minItemWidth: 58,
                  items: const [
                    _LegacySegmentedTabItem(value: 'pump', label: '泵奶'),
                    _LegacySegmentedTabItem(value: 'feed', label: '喂养'),
                    _LegacySegmentedTabItem(value: 'growth', label: '成长'),
                  ],
                ),
                _LegacySegmentedTabs(
                  key: const ValueKey('records-unit-segment'),
                  selected: _volumeUnit,
                  onChanged: (next) => setState(() => _volumeUnit = next),
                  accent: MomCozyColors.primary,
                  minItemWidth: 52,
                  items: const [
                    _LegacySegmentedTabItem(value: 'mL', label: 'mL'),
                    _LegacySegmentedTabItem(value: 'oz', label: 'oz'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recordsDashboardChildren(snapshot, overview),
            if (overview != null && !snapshot.hasError) ...[
              const SizedBox(height: 18),
              _RecordsListToolbar(onAdd: _addManualPumpRecord),
              if (_filter == 'pump')
                _RecordsInventoryHeader(
                  totalLabel: _amountLabel(
                    overview.pumpTotalMl,
                    unit: _volumeUnit,
                  ),
                ),
              ..._recordChildren(overview),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _recordsDashboardChildren(
    AsyncSnapshot<_RecordsOverview> snapshot,
    _RecordsOverview? visibleOverview,
  ) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const [
        _ActionTile(
          icon: Icons.sync_rounded,
          title: '正在同步记录',
          subtitle: '正在读取泵奶、喂养和成长记录。',
          accent: Color(0xff6b6da8),
          trailing: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        _ActionTile(
          icon: Icons.cloud_off_outlined,
          title: '记录同步失败',
          subtitle: '弱网/离线时保留本地筛选，可点击重试。',
          accent: widget.accent,
          trailing: IconButton(
            tooltip: '重试',
            onPressed: _reloadRecords,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ];
    }

    final overview = visibleOverview ?? _RecordsOverview.empty;
    return [
      _RecordsDashboardCard(
        overview: overview,
        volumeUnit: _volumeUnit,
        accent: widget.accent,
        onToggleUnit: _toggleVolumeUnit,
      ),
    ];
  }

  List<Widget> _recordChildren(_RecordsOverview overview) {
    return switch (_filter) {
      'feed' => _feedingRecordChildren(overview.feeding),
      'growth' => _growthRecordChildren(overview.growth),
      _ => _pumpRecordChildren(overview.pump),
    };
  }

  List<Widget> _pumpRecordChildren(List<PumpMilkRecord> records) {
    if (records.isEmpty) return [_emptyRecordTile('暂无泵奶记录')];
    return [
      for (final record in records)
        _RecordsMilkRow(
          amountLabel: _amountLabel(record.amountMl, unit: _volumeUnit),
          title: _textOr(record.title, '泵奶记录'),
          subtitle:
              '来源 ${record.pumpSource ?? '--'}${_crossDaySuffix(record.occurredAt)}',
          timeLabel: _dateTimeLabel(record.occurredAt),
          icon: Icons.water_drop_rounded,
          accent: widget.accent,
          badges: [
            const _RecordsSourceBadge(
              label: '母乳',
              icon: Icons.favorite_border_rounded,
            ),
            _RecordsSourceBadge(
              label: record.pumpSource == 9 ? '手动' : '设备',
              icon: record.pumpSource == 9
                  ? Icons.edit_outlined
                  : Icons.phone_android_rounded,
            ),
          ],
          actions: [
            IconButton(
              tooltip: '编辑记录',
              onPressed: () => _editPumpRecord(record),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: '删除记录',
              onPressed: () => _deletePumpRecord(record),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
    ];
  }

  List<Widget> _feedingRecordChildren(List<FeedingRecord> records) {
    if (records.isEmpty) return [_emptyRecordTile('暂无喂养记录')];
    return [
      for (final record in records)
        _RecordsMilkRow(
          amountLabel: _amountLabel(record.amountMl, unit: _volumeUnit),
          title: _textOr(record.type, '喂养'),
          subtitle: '喂养记录',
          timeLabel: _dateTimeLabel(record.occurredAt),
          icon: Icons.child_friendly_rounded,
          accent: const Color(0xff43827b),
          badges: const [
            _RecordsSourceBadge(label: '瓶喂', icon: Icons.local_drink_outlined),
            _RecordsSourceBadge(label: '同步', icon: Icons.auto_awesome_rounded),
          ],
        ),
    ];
  }

  List<Widget> _growthRecordChildren(List<GrowthRecord> records) {
    if (records.isEmpty) return [_emptyRecordTile('暂无成长记录')];
    return [
      for (final record in records)
        _RecordsGrowthRow(
          dateLabel: _dateLabel(record.measuredAt),
          weightLabel: _weightLabel(record.weightGram),
          heightLabel: _heightLabel(record.heightCm),
        ),
    ];
  }

  Widget _emptyRecordTile(String title) {
    return _ActionTile(
      icon: Icons.info_outline_rounded,
      title: title,
      subtitle: '同步完成后仍没有对应记录。',
      accent: const Color(0xff7f6a75),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  _RecordsOverview _applyLocalRecordEdits(_RecordsOverview overview) {
    final pump = <PumpMilkRecord>[..._localPumpRecords, ...overview.pump]
        .where((record) => !_deletedPumpRecordIds.contains(record.id))
        .map((record) => _editedPumpRecords[record.id] ?? record)
        .toList(growable: false);
    return _RecordsOverview(
      pump: pump,
      feeding: overview.feeding,
      growth: overview.growth,
    );
  }

  String _crossDaySuffix(DateTime? occurredAt) {
    if (occurredAt == null) return '';
    final day = DateTime.utc(
      _recordsDay.year,
      _recordsDay.month,
      _recordsDay.day,
    );
    final recordDay = DateTime.utc(
      occurredAt.toUtc().year,
      occurredAt.toUtc().month,
      occurredAt.toUtc().day,
    );
    return recordDay == day ? '' : ' · 跨天记录';
  }
}

class _RecordsOverview {
  const _RecordsOverview({
    required this.pump,
    required this.feeding,
    required this.growth,
  });

  static const empty = _RecordsOverview(
    pump: <PumpMilkRecord>[],
    feeding: <FeedingRecord>[],
    growth: <GrowthRecord>[],
  );

  final List<PumpMilkRecord> pump;
  final List<FeedingRecord> feeding;
  final List<GrowthRecord> growth;

  int get pumpTotalMl {
    return pump.fold<int>(0, (total, record) => total + (record.amountMl ?? 0));
  }

  int get totalMilkMl {
    final feedingTotal = feeding.fold<int>(
      0,
      (total, record) => total + (record.amountMl ?? 0),
    );
    return pumpTotalMl + feedingTotal;
  }

  int get recordCount => pump.length + feeding.length + growth.length;

  DateTime? get latestAt {
    final dates = <DateTime>[
      for (final record in pump)
        if (record.occurredAt != null) record.occurredAt!,
      for (final record in feeding)
        if (record.occurredAt != null) record.occurredAt!,
      for (final record in growth)
        if (record.measuredAt != null) record.measuredAt!,
    ]..sort((a, b) => b.compareTo(a));
    return dates.isEmpty ? null : dates.first;
  }

  List<_MilkTrendPoint> get milkTrendPoints {
    final points = <_MilkTrendPoint>[
      for (final record in pump)
        if (record.amountMl != null)
          _MilkTrendPoint(
            label: _dateTimeLabel(record.occurredAt),
            amountMl: record.amountMl!,
          ),
      for (final record in feeding)
        if (record.amountMl != null)
          _MilkTrendPoint(
            label: _dateTimeLabel(record.occurredAt),
            amountMl: record.amountMl!,
          ),
    ];
    return points;
  }
}

class _RecordsMonthHeader extends StatelessWidget {
  const _RecordsMonthHeader({
    required this.day,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime day;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insights_rounded,
              size: 18,
              color: MomCozyColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '妈妈点滴',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Spacer(),
        _RecordsMonthButton(
          tooltip: '上个月',
          icon: Icons.chevron_left_rounded,
          onTap: onPrevious,
        ),
        Text(
          '${day.year}年${day.month}月',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: MomCozyColors.mutedForeground,
            fontWeight: FontWeight.w800,
          ),
        ),
        _RecordsMonthButton(
          tooltip: '下个月',
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _RecordsMonthButton extends StatelessWidget {
  const _RecordsMonthButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: MomCozyColors.mutedForeground),
      ),
    );
  }
}

class _RecordsDashboardCard extends StatelessWidget {
  const _RecordsDashboardCard({
    required this.overview,
    required this.volumeUnit,
    required this.accent,
    required this.onToggleUnit,
  });

  final _RecordsOverview overview;
  final String volumeUnit;
  final Color accent;
  final VoidCallback onToggleUnit;

  @override
  Widget build(BuildContext context) {
    final deviceSessions = overview.pump.length;
    final average = deviceSessions == 0
        ? 0
        : (overview.pumpTotalMl / deviceSessions).round();
    final points = overview.milkTrendPoints.take(7).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.raised.withValues(alpha: 0.72),
        borderColor: MomCozyColors.border.withValues(alpha: 0.76),
        radius: 18,
        shadows: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.local_florist_rounded,
                      size: 15,
                      color: MomCozyColors.primary.withValues(alpha: 0.78),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '今日吸奶器使用',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onToggleUnit,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: MomCozyColors.muted.withValues(alpha: 0.65),
                  foregroundColor: MomCozyColors.foreground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                  ),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(volumeUnit),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RecordsMiniStat(
                  icon: Icons.water_drop_rounded,
                  label: '吸奶器母乳量',
                  value: _amountLabel(overview.totalMilkMl, unit: volumeUnit),
                  accent: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RecordsMiniStat(
                  icon: Icons.schedule_rounded,
                  label: '吸奶次数',
                  value: '$deviceSessions 次',
                  accent: MomCozyColors.warm,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RecordsMiniStat(
                  icon: Icons.trending_up_rounded,
                  label: '单次均量',
                  value: _amountLabel(average, unit: volumeUnit),
                  accent: MomCozyColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: MomCozyColors.border.withValues(alpha: 0.55)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 15,
                      color: MomCozyColors.primary.withValues(alpha: 0.78),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '过去1周日补录奶量趋势',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: MomCozyColors.mutedForeground,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                points.isEmpty ? '暂无奶量趋势' : '波动正常，放轻松就好',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.mutedForeground.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 142,
            width: double.infinity,
            child: _RecordsTrendChart(points: points, accent: accent),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(MomCozyAssets.agentAvatar),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '←问问M.ai呀~\n最近记录保持稳定，继续按自己的节奏来就好。',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: MomCozyColors.primary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordsMiniStat extends StatelessWidget {
  const _RecordsMiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsTrendChart extends StatelessWidget {
  const _RecordsTrendChart({required this.points, required this.accent});

  final List<_MilkTrendPoint> points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RecordsTrendPainter(points: points, accent: accent),
      child: Align(
        alignment: Alignment.center,
        child: points.isEmpty
            ? Text(
                '暂无奶量趋势',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: MomCozyColors.mutedForeground,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _RecordsTrendPainter extends CustomPainter {
  const _RecordsTrendPainter({required this.points, required this.accent});

  final List<_MilkTrendPoint> points;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(30, 8, size.width - 70, size.height - 30);
    final gridPaint = Paint()
      ..color = MomCozyColors.border.withValues(alpha: 0.52)
      ..strokeWidth = 1;
    final stagePaint = Paint()..style = PaintingStyle.fill;
    final stageColors = [
      MomCozyColors.warm.withValues(alpha: 0.06),
      accent.withValues(alpha: 0.06),
      MomCozyColors.violet.withValues(alpha: 0.08),
    ];

    final stageHeight = chartRect.height / stageColors.length;
    for (var index = 0; index < stageColors.length; index += 1) {
      stagePaint.color = stageColors[index];
      canvas.drawRect(
        Rect.fromLTWH(
          chartRect.left,
          chartRect.top + index * stageHeight,
          chartRect.width,
          stageHeight,
        ),
        stagePaint,
      );
    }

    for (var index = 0; index <= 4; index += 1) {
      final y = chartRect.top + chartRect.height * index / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    if (points.isEmpty) return;

    final maxAmount = points
        .map((point) => point.amountMl)
        .fold<int>(1, (max, value) => value > max ? value : max);
    final step = points.length == 1
        ? chartRect.width
        : chartRect.width / (points.length - 1);
    final offsets = <Offset>[
      for (var index = 0; index < points.length; index += 1)
        Offset(
          chartRect.left + step * index,
          chartRect.bottom -
              chartRect.height * (points[index].amountMl / maxAmount),
        ),
    ];

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, chartRect.bottom)
      ..lineTo(offsets.first.dx, chartRect.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.02),
          ],
        ).createShader(chartRect),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final dotPaint = Paint()..color = accent;
    for (final point in offsets) {
      canvas.drawCircle(point, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RecordsTrendPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accent != accent;
  }
}

class _RecordsListToolbar extends StatelessWidget {
  const _RecordsListToolbar({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: MomCozyColors.primary.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 5),
                Text(
                  '今日记录',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor: MomCozyColors.primary,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('手动补录'),
          ),
        ],
      ),
    );
  }
}

class _RecordsInventoryHeader extends StatelessWidget {
  const _RecordsInventoryHeader({required this.totalLabel});

  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 17,
            color: MomCozyColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '可用母乳库存',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MomCozyColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            totalLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: MomCozyColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsMilkRow extends StatelessWidget {
  const _RecordsMilkRow({
    required this.amountLabel,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.icon,
    required this.accent,
    this.badges = const [],
    this.actions = const [],
  });

  final String amountLabel;
  final String title;
  final String subtitle;
  final String timeLabel;
  final IconData icon;
  final Color accent;
  final List<_RecordsSourceBadge> badges;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.card.withValues(alpha: 0.9),
          shadows: const [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              _IconBubble(icon: icon, accent: accent, size: 34, iconSize: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_drink_outlined,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              amountLabel,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: MomCozyColors.foreground,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                        ...badges,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$title · $subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsSourceBadge extends StatelessWidget {
  const _RecordsSourceBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: MomCozyColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MomCozyColors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsGrowthRow extends StatelessWidget {
  const _RecordsGrowthRow({
    required this.dateLabel,
    required this.weightLabel,
    required this.heightLabel,
  });

  final String dateLabel;
  final String weightLabel;
  final String heightLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.card.withValues(alpha: 0.9),
          shadows: const [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const _IconBubble(
                icon: Icons.monitor_weight_outlined,
                accent: Color(0xff6b6da8),
                size: 34,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dateLabel 成长记录',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$weightLabel · $heightLabel',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MomCozyColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilkTrendPoint {
  const _MilkTrendPoint({required this.label, required this.amountMl});

  final String label;
  final int amountMl;
}

String _amountLabel(int? amountMl, {String unit = 'mL'}) {
  if (amountMl == null) return '--';
  if (unit == 'oz') {
    return '${(amountMl / 29.5735).toStringAsFixed(1)} oz';
  }
  return '$amountMl mL';
}

String _weightLabel(int? weightGram) {
  if (weightGram == null) return '--';
  return '${(weightGram / 1000).toStringAsFixed(1)} kg';
}

String _heightLabel(double? heightCm) {
  return heightCm == null ? '--' : '${heightCm.toStringAsFixed(1)} cm';
}

String _dateTimeLabel(DateTime? value) {
  if (value == null) return '--';
  return _timeLabel(value);
}

String _nullableTimeLabel(DateTime? value) {
  if (value == null) return '--';
  return _timeLabel(value);
}

String _dateLabel(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day';
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.type, required this.accent});

  final String type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'image' => Icons.image_outlined,
      'video' => Icons.play_circle_outline_rounded,
      _ => Icons.picture_as_pdf_outlined,
    };
    final label = switch (type) {
      'image' => '图片预览',
      'video' => '视频预览',
      _ => 'PDF 预览',
    };

    return Container(
      height: 210,
      alignment: Alignment.center,
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconBubble(icon: icon, accent: accent, size: 58, iconSize: 30),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '选择资料后可在这里查看内容、进度和加载状态。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPage extends StatefulWidget {
  const _CommunityPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<_CommunityPage> {
  String? _lastActionStatus;
  String? _postingKey;

  Future<void> _openCommunityItem(String key, String label) async {
    if (_postingKey != null) return;
    setState(() {
      _postingKey = key;
      _lastActionStatus = null;
    });

    final sent = await _postFeatureClientEvent(
      context,
      eventType: 'community_item_opened',
      label: '打开社区内容：$label',
      metadata: {'item_key': key, 'source': 'community'},
    );
    if (!mounted) return;
    setState(() {
      _postingKey = null;
      _lastActionStatus = sent ? '已记录 $label。' : '本地已打开，稍后重试同步。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _StatusChip(
            label: '同城',
            icon: Icons.location_on_outlined,
            accent: Color(0xff6b6da8),
          ),
          _StatusChip(
            label: '哺乳支持',
            icon: Icons.volunteer_activism_outlined,
            accent: Color(0xff43827b),
          ),
        ],
      ),
      children: [
        const _SectionTitle('关注话题'),
        _ActionTile(
          icon: Icons.forum_outlined,
          title: '泵奶节奏调整',
          subtitle: '来自相同月龄妈妈的经验和已收藏讨论。',
          accent: const Color(0xff6b6da8),
          onTap: () => _openCommunityItem('pump_rhythm', '泵奶节奏调整'),
          trailing: _communityTrailing('pump_rhythm'),
        ),
        _ActionTile(
          icon: Icons.favorite_border_rounded,
          title: '产后恢复',
          subtitle: '查看收藏内容、精选讨论和恢复建议。',
          accent: const Color(0xff9f6378),
          onTap: () => _openCommunityItem('postpartum_recovery', '产后恢复'),
          trailing: _communityTrailing('postpartum_recovery'),
        ),
        const _SectionTitle('最新动态'),
        _ActionTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: '妈妈小组更新',
          subtitle: '3 条新回复，打开后会更新已读状态。',
          accent: const Color(0xff43827b),
          onTap: () => _openCommunityItem('group_updates', '妈妈小组更新'),
          trailing: _communityTrailing('group_updates'),
        ),
        if (_lastActionStatus != null)
          _ActionTile(
            icon: Icons.done_all_rounded,
            title: '社区状态',
            subtitle: _lastActionStatus!,
            accent: const Color(0xff43827b),
            trailing: const Icon(Icons.check_circle_outline_rounded),
          ),
      ],
    );
  }

  Widget _communityTrailing(String key) {
    if (_postingKey != key) return const Icon(Icons.chevron_right_rounded);
    return const SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}

class _DeviceManagePage extends StatefulWidget {
  const _DeviceManagePage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_DeviceManagePage> createState() => _DeviceManagePageState();
}

class _DeviceManagePageState extends State<_DeviceManagePage> {
  List<BleDeviceSnapshot> _connectedDevices = const [];
  bool _isRefreshing = false;
  String? _syncStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_refreshDevices());
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _isRefreshing = true;
      _syncStatus = null;
    });
    try {
      final devices = await MomCozyRuntimeScope.of(
        context,
      ).blePlatform.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = devices;
        _isRefreshing = false;
        _syncStatus = devices.isEmpty
            ? '当前没有已连接设备。'
            : '已同步 ${devices.length} 台设备。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _syncStatus = '设备状态同步失败，请稍后重试。';
      });
    }
  }

  Future<void> _disconnectAll() async {
    setState(() {
      _isRefreshing = true;
      _syncStatus = null;
    });
    try {
      final ble = MomCozyRuntimeScope.of(context).blePlatform;
      final devices = await ble.getConnectedDevices();
      for (final device in devices) {
        await ble.disconnect(device.deviceId);
      }
      final next = await ble.getConnectedDevices();
      if (!mounted) return;
      setState(() {
        _connectedDevices = next;
        _isRefreshing = false;
        _syncStatus = '已解绑 ${devices.length} 台设备。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _syncStatus = '解绑失败，请确认 session 已结束后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedSummary = _connectedDevices.isEmpty
        ? '暂无已连接设备'
        : _connectedDevices
              .map((device) => '${device.side} ${device.deviceName}')
              .join('、');

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      children: [
        const _SectionTitle('设备操作'),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: '固件和序列号',
          subtitle: connectedSummary,
          accent: widget.accent,
          trailing: const _PumpDeviceThumbnail(size: 42),
        ),
        const _ActionTile(
          icon: Icons.notifications_active_outlined,
          title: '设备提醒通道',
          subtitle: '管理设备消息、提醒声音和后台接收状态。',
          accent: Color(0xffb2773b),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        _ActionTile(
          icon: Icons.refresh_rounded,
          title: '重新同步设备状态',
          subtitle: _syncStatus ?? '刷新左右设备连接、电量和运行快照。',
          accent: const Color(0xff43827b),
          onTap: _isRefreshing ? null : _refreshDevices,
          trailing: _isRefreshing
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.sync_rounded),
        ),
        _ActionTile(
          icon: Icons.link_off_rounded,
          title: '解绑设备',
          subtitle: '解绑前需要确认后台 session 已结束。',
          accent: const Color(0xff9f6378),
          onTap: _connectedDevices.isEmpty || _isRefreshing
              ? null
              : _disconnectAll,
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DeviceUserPage extends StatefulWidget {
  const _DeviceUserPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_DeviceUserPage> createState() => _DeviceUserPageState();
}

class _DeviceUserPageState extends State<_DeviceUserPage> {
  bool _debugEvents = false;
  bool _useFixtureDevice = true;

  @override
  Widget build(BuildContext context) {
    final runtime = MomCozyRuntimeScope.of(context);
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      children: [
        const _SectionTitle('内部参数'),
        _ActionTile(
          icon: Icons.person_search_outlined,
          title: '当前用户',
          subtitle:
              '${runtime.userId} · baby ${runtime.babyId} · ${runtime.locale}',
          accent: widget.accent,
          trailing: const Icon(Icons.lock_outline_rounded),
        ),
        _ActionTile(
          icon: Icons.science_outlined,
          title: '使用测试设备',
          subtitle: '用于无真泵时验证页面状态，不写入生产数据。',
          accent: const Color(0xff43827b),
          trailing: Switch(
            value: _useFixtureDevice,
            onChanged: (value) => setState(() => _useFixtureDevice = value),
          ),
        ),
        _ActionTile(
          icon: Icons.terminal_rounded,
          title: '显示设备调试事件',
          subtitle: '正式包应隐藏，仅 QA/dev flavor 可见。',
          accent: const Color(0xff7f6a75),
          trailing: Switch(
            value: _debugEvents,
            onChanged: (value) => setState(() => _debugEvents = value),
          ),
        ),
      ],
    );
  }
}

class _W1Page extends StatefulWidget {
  const _W1Page({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_W1Page> createState() => _W1PageState();
}

class _W1PageState extends State<_W1Page> {
  bool _openingTutorial = false;

  Future<void> _openTutorial() async {
    if (_openingTutorial) return;
    setState(() => _openingTutorial = true);
    await _postFeatureClientEvent(
      context,
      eventType: 'w1_tutorial_opened',
      label: '打开 W1 使用教程',
      metadata: const {'source': 'w1', 'target': 'media-viewer'},
    );
    if (!mounted) return;
    context.go('/media-viewer');
  }

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: const _StatusChip(
        label: '产品内容',
        icon: Icons.workspace_premium_outlined,
        accent: Color(0xffb2773b),
      ),
      children: [
        const _W1PromoHero(),
        const _W1ProductSummary(),
        const _SectionTitle('核心亮点'),
        const _W1SellingPoint(
          icon: Icons.favorite_border_rounded,
          title: '妈妈身心关怀模式',
          subtitle: '内置心率感应与呼吸引导，吸乳时自动播放舒缓白噪音。',
          accent: MomCozyColors.primary,
        ),
        const _W1SellingPoint(
          icon: Icons.eco_outlined,
          title: '亲肤零压穿戴',
          subtitle: '医疗级液态硅胶和记忆棉衬垫，轻量机身更适合日常佩戴。',
          accent: Color(0xff43827b),
        ),
        const _W1SellingPoint(
          icon: Icons.bolt_rounded,
          title: '智能节律吸力',
          subtitle: 'M.ai 分析泌乳节奏，自动切换刺激和吸乳模式。',
          accent: Color(0xffb2773b),
        ),
        const _ActionTile(
          icon: Icons.shield_outlined,
          title: '全密封防回流',
          subtitle: '三重密封结构，降低漏奶和回流风险。',
          accent: Color(0xff6b6da8),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        const _ActionTile(
          icon: Icons.volume_down_outlined,
          title: '静音科技 ≤35dB',
          subtitle: '无刷电机和降噪腔体，夜间使用更安静。',
          accent: Color(0xff9f6378),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('教程'),
        _ActionTile(
          icon: Icons.play_circle_outline_rounded,
          title: '使用教程',
          subtitle: '打开视频、PDF 和图文教程。',
          accent: const Color(0xff6b6da8),
          onTap: _openTutorial,
          trailing: _openingTutorial
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _W1PromoHero extends StatelessWidget {
  const _W1PromoHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff4a2635), Color(0xff743448), Color(0xff4d2938)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: MomCozyColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: MomCozyShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            children: [
              Text(
                'Momcozy · New',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.background.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'W1',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: MomCozyColors.background,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Wellness & Well-being',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MomCozyColors.background.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '为妈妈的身心健康而生',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.background.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MomCozyColors.background.withValues(alpha: 0.12),
                    width: 2,
                  ),
                  color: MomCozyColors.background.withValues(alpha: 0.06),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 38,
                      color: MomCozyColors.background.withValues(alpha: 0.52),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'W1',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.background.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w900,
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
}

class _W1ProductSummary extends StatelessWidget {
  const _W1ProductSummary();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  const _IconBubble(
                    icon: Icons.favorite_border_rounded,
                    accent: MomCozyColors.primary,
                    size: 34,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Momcozy W1 穿戴式吸奶器',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '新一代身心关怀智能吸乳体验',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _W1SpecTile(label: '重量', value: '180g'),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _W1SpecTile(label: '噪音', value: '≤35dB'),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _W1SpecTile(label: '续航', value: '4h+'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _W1SpecTile extends StatelessWidget {
  const _W1SpecTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _W1SellingPoint extends StatelessWidget {
  const _W1SellingPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: accent,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

Future<bool> _postFeatureClientEvent(
  BuildContext context, {
  required String eventType,
  required String label,
  required Map<String, Object?> metadata,
}) async {
  try {
    final runtime = MomCozyRuntimeScope.of(context);
    final result = await runtime.clientEventClient.post(
      AgentStreamClientEventRequest(
        threadId: 'thread-${runtime.userId}',
        userId: runtime.userId,
        eventType: eventType,
        label: label,
        occurredAt: runtime.now().toIso8601String(),
        locale: runtime.locale,
        metadata: metadata,
      ),
    );
    return result.sent;
  } catch (_) {
    return false;
  }
}

class _HospitalBagCartPage extends StatefulWidget {
  const _HospitalBagCartPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_HospitalBagCartPage> createState() => _HospitalBagCartPageState();
}

class _HospitalBagCartPageState extends State<_HospitalBagCartPage> {
  bool _pumpPacked = true;
  bool _padsPacked = false;
  bool _babyClothesPacked = false;
  bool _isSyncing = false;
  String? _syncStatus;
  final Set<String> _removedItemIds = {};

  void _setPacked(String id, bool value) {
    setState(() {
      switch (id) {
        case 'pump':
          _pumpPacked = value;
          break;
        case 'pads':
          _padsPacked = value;
          break;
        case 'baby_clothes':
          _babyClothesPacked = value;
          break;
      }
    });
    unawaited(_syncCart());
  }

  void _resetCart() {
    setState(() {
      _pumpPacked = true;
      _padsPacked = false;
      _babyClothesPacked = false;
      _removedItemIds.clear();
    });
    unawaited(_syncCart());
  }

  void _deleteItem(String id) {
    setState(() {
      _removedItemIds.add(id);
      switch (id) {
        case 'pump':
          _pumpPacked = false;
          break;
        case 'pads':
          _padsPacked = false;
          break;
        case 'baby_clothes':
          _babyClothesPacked = false;
          break;
      }
    });
    unawaited(_syncCart());
  }

  Future<void> _syncCart() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final result = await runtime.hospitalBagCartRepository.syncCart(
        userId: runtime.userId,
        items: _hospitalBagItems(),
      );
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = result.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatus = '本地清单已更新，稍后重试同步。';
      });
    }
  }

  List<HospitalBagPackedItem> _hospitalBagItems() {
    return [
      HospitalBagPackedItem(id: 'pump', title: '吸奶器和配件', packed: _pumpPacked),
      HospitalBagPackedItem(id: 'pads', title: '产后护理用品', packed: _padsPacked),
      HospitalBagPackedItem(
        id: 'baby_clothes',
        title: '宝宝衣物',
        packed: _babyClothesPacked,
      ),
    ].where((item) => !_removedItemIds.contains(item.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _hospitalBagItems();
    final packed = items.where((item) => item.packed).length;

    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: _StatusChip(
        label: '$packed/${items.length} 已准备',
        icon: Icons.inventory_2_outlined,
        accent: widget.accent,
      ),
      children: [
        const _SectionTitle('清单'),
        if (!_removedItemIds.contains('pump'))
          _ChecklistTile(
            title: '吸奶器和配件',
            subtitle: '主机、阀门、储奶袋、充电线。',
            value: _pumpPacked,
            accent: widget.accent,
            onChanged: (value) => _setPacked('pump', value),
            onDelete: () => _deleteItem('pump'),
          ),
        if (!_removedItemIds.contains('pads'))
          _ChecklistTile(
            title: '产后护理用品',
            subtitle: '护理垫、湿巾、一次性用品。',
            value: _padsPacked,
            accent: const Color(0xff43827b),
            onChanged: (value) => _setPacked('pads', value),
            onDelete: () => _deleteItem('pads'),
          ),
        if (!_removedItemIds.contains('baby_clothes'))
          _ChecklistTile(
            title: '宝宝衣物',
            subtitle: '连体衣、包巾、帽子和备用衣物。',
            value: _babyClothesPacked,
            accent: const Color(0xff6b6da8),
            onChanged: (value) => _setPacked('baby_clothes', value),
            onDelete: () => _deleteItem('baby_clothes'),
          ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: _isSyncing ? Icons.sync_rounded : Icons.cloud_done_outlined,
          title: '购物车同步',
          subtitle: _syncStatus ?? '勾选变化会同步到待产包购物车状态。',
          accent: const Color(0xff43827b),
          trailing: _isSyncing
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.check_circle_outline_rounded),
        ),
        _ActionTile(
          icon: Icons.restore_rounded,
          title: '恢复默认清单',
          subtitle: '把待产包恢复为推荐清单，并同步购物车状态。',
          accent: const Color(0xff7f6a75),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _resetCart,
        ),
      ],
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
      title: title,
      subtitle: subtitle,
      accent: accent,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (next) => onChanged(next ?? false)),
          if (onDelete != null)
            IconButton(
              tooltip: '删除$title',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _IbclcPage extends StatefulWidget {
  const _IbclcPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_IbclcPage> createState() => _IbclcPageState();
}

class _IbclcPageState extends State<_IbclcPage> {
  bool _accepted = false;
  bool _consultStarted = false;
  bool _isStarting = false;
  String? _syncStatus;
  static const String _returnToPath = '/status';

  Future<void> _startConsult() async {
    if (!_accepted || _consultStarted || _isStarting) return;
    setState(() {
      _isStarting = true;
      _syncStatus = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final result = await runtime.clientEventClient.post(
        AgentStreamClientEventRequest(
          threadId: 'thread-${runtime.userId}',
          userId: runtime.userId,
          eventType: 'ibclc_consult_started',
          label: '用户进入 IBCLC 在线咨询队列',
          occurredAt: runtime.now().toIso8601String(),
          locale: runtime.locale,
          metadata: const {
            'consult_id': 'ibclc-flutter-default',
            'source': 'ibclc-chat',
            'handoff': 'vendor_h5_native',
            'return_to': _returnToPath,
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _consultStarted = true;
        _isStarting = false;
        _syncStatus = result.sent ? '咨询事件已同步。' : '本地已进入队列，稍后重试同步。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consultStarted = true;
        _isStarting = false;
        _syncStatus = '本地已进入队列，稍后重试同步。';
      });
    }
  }

  void _returnToStatus() {
    context.go(_returnToPath);
  }

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: _StatusChip(
        label: _consultStarted ? '咨询准备中' : '咨询入口',
        icon: Icons.health_and_safety_outlined,
        accent: const Color(0xff43827b),
      ),
      children: [
        const _SectionTitle('开始前'),
        const _IbclcConsultantCard(),
        _ActionTile(
          icon: Icons.privacy_tip_outlined,
          title: '咨询协议',
          subtitle: '勾选后才能进入顾问流程；返回后会停在离开前的位置。',
          accent: widget.accent,
          trailing: Checkbox(
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
          ),
        ),
        const _ActionTile(
          icon: Icons.question_answer_outlined,
          title: '常见问题',
          subtitle: '含乳头疼痛、堵奶、亲喂姿势和泵奶节奏。',
          accent: Color(0xff6b6da8),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        if (_consultStarted)
          _ActionTile(
            icon: Icons.support_agent_rounded,
            title: '顾问流程已打开',
            subtitle: _syncStatus ?? '正在保留本次咨询上下文，稍后可以继续查看。',
            accent: const Color(0xff43827b),
            trailing: IconButton(
              key: const ValueKey('ibclc-return-status-button'),
              tooltip: '返回状态页',
              onPressed: _returnToStatus,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        FilledButton.icon(
          onPressed: _accepted && !_consultStarted && !_isStarting
              ? _startConsult
              : null,
          icon: const Icon(Icons.chat_rounded),
          label: Text(
            _consultStarted
                ? '已进入咨询队列'
                : _isStarting
                ? '进入中'
                : '进入 IBCLC 咨询',
          ),
        ),
      ],
    );
  }
}

class _IbclcConsultantCard extends StatelessWidget {
  const _IbclcConsultantCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(shadows: MomCozyShadows.soft),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MomCozyColors.care.withValues(alpha: 0.22),
                    width: 2,
                  ),
                  image: const DecorationImage(
                    image: AssetImage(MomCozyAssets.ibclcConsultantAvatar),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IBCLC 顾问',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: const [
                        _StatusChip(
                          label: '国际认证',
                          icon: Icons.verified_user_outlined,
                          accent: MomCozyColors.care,
                        ),
                        _StatusChip(
                          label: '哺乳支持',
                          icon: Icons.favorite_border_rounded,
                          accent: MomCozyColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '含乳头疼痛、堵奶、亲喂姿势和泵奶节奏咨询。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w600,
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
}

class _MediaViewerPage extends StatefulWidget {
  const _MediaViewerPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  String _type = 'pdf';
  bool _isUploading = false;
  UploadedMediaFile? _uploadedFile;
  String? _uploadError;
  String _cacheStatus = '离线资料已缓存，网络不稳定时可继续查看并失败重试。';

  Future<void> _uploadSampleMedia() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final runtime = MomCozyRuntimeScope.of(context);
      final uploaded = await runtime.mediaRepository.uploadFile(
        userId: runtime.userId,
        file: _sampleMediaFile,
      );
      if (!mounted) return;
      setState(() {
        _uploadedFile = uploaded;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadError = _mediaUploadErrorText(error);
      });
    }
  }

  void _clearOfflineCache() {
    setState(() {
      _uploadedFile = null;
      _uploadError = null;
      _cacheStatus = '已清理离线缓存和临时上传结果。';
    });
  }

  void _returnFromMediaViewer() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: widget.path,
      title: widget.title,
      summary: widget.summary,
      icon: widget.icon,
      accent: widget.accent,
      trailing: _LegacySegmentedTabs(
        selected: _type,
        onChanged: (next) => setState(() => _type = next),
        accent: MomCozyColors.primary,
        expand: true,
        minItemWidth: 82,
        items: const [
          _LegacySegmentedTabItem(
            value: 'pdf',
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF',
          ),
          _LegacySegmentedTabItem(
            value: 'image',
            icon: Icons.image_outlined,
            label: '图片',
          ),
          _LegacySegmentedTabItem(
            value: 'video',
            icon: Icons.play_circle_outline_rounded,
            label: '视频',
          ),
        ],
      ),
      children: [
        const _SectionTitle('预览'),
        _MediaPreview(type: _type, accent: widget.accent),
        const SizedBox(height: 18),
        const _SectionTitle('操作'),
        _ActionTile(
          icon: Icons.download_for_offline_outlined,
          title: '离线缓存',
          subtitle: _cacheStatus,
          accent: widget.accent,
          trailing: IconButton(
            key: const ValueKey('media-clear-cache-button'),
            tooltip: '清理缓存',
            onPressed: _clearOfflineCache,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ),
        _ActionTile(
          icon: Icons.cloud_upload_outlined,
          title: _uploadedFile == null
              ? '上传示例资料'
              : '已上传 ${_uploadedFile!.name}',
          subtitle:
              _uploadError ??
              (_uploadedFile == null
                  ? '通过 /v1/files/upload 验证媒体上传合同。'
                  : '文件 ID ${_uploadedFile!.id}，${_uploadedFile!.sizeBytes} bytes。'),
          accent: _uploadError == null ? const Color(0xff846bd8) : Colors.red,
          trailing: _isUploading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : IconButton(
                  tooltip: '上传',
                  onPressed: _uploadSampleMedia,
                  icon: const Icon(Icons.cloud_upload_outlined),
                ),
        ),
        _ActionTile(
          icon: Icons.ios_share_rounded,
          title: '分享或返回',
          subtitle: '从 Agent artifact、IBCLC 和 W1 内容跳入时保留返回意图。',
          accent: const Color(0xff43827b),
          trailing: IconButton(
            key: const ValueKey('media-return-button'),
            tooltip: '返回上一页',
            onPressed: _returnFromMediaViewer,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ],
    );
  }

  String _mediaUploadErrorText(Object error) {
    if (error is ApiRequestCancelledException) return '上传已取消，预览内容已保留。';
    if (error is ApiRequestTimeoutException) return '上传超时，请稍后重试。';
    if (error is ApiHttpException) return '媒体服务暂不可用，请稍后重试。';
    return '上传失败，请稍后重试。';
  }
}

const _sampleMediaFile = ApiUploadFile(
  name: 'pump-display-fixture.png',
  mimeType: 'image/png',
  sizeBytes: 68,
  bytes: <int>[137, 80, 78, 71, 13, 10, 26, 10],
);

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _FeaturePageFrame(
      path: path,
      title: title,
      summary: summary,
      icon: icon,
      accent: accent,
      children: const [
        _ActionTile(
          icon: Icons.home_outlined,
          title: '返回主入口',
          subtitle: '这个入口暂不可用，可以返回主入口继续使用。',
          accent: Color(0xff7f6a75),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
