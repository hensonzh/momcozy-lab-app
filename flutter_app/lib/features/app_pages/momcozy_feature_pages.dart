import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:momcozy_flutter_app/features/pump_session/domain/pump_workstate.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_overview.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

class MomCozyFeaturePage extends StatelessWidget {
  const MomCozyFeaturePage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;
  final Uri? routeUri;
  final Object? routeExtra;

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
        routeUri: routeUri,
        routeExtra: routeExtra,
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
    required this.selected,
    required this.items,
    required this.onChanged,
    required this.accent,
    this.expand = false,
  });

  final String selected;
  final List<_LegacySegmentedTabItem> items;
  final ValueChanged<String> onChanged;
  final Color accent;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final item in items)
        _LegacySegmentedTabButton(
          item: item,
          selected: item.value == selected,
          accent: accent,
          minWidth: 70,
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

  void _changeCareStage(String stage) {
    setState(() {
      _careStage = stage;
      if (stage == 'pregnancy') _view = 'mom';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMom = _view == 'mom';

    return FutureBuilder<StatusOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        final isPregnancy = _careStage == 'pregnancy';
        const momSubtitle = '妈妈档案待绑定';
        const babySubtitle = '宝宝档案待绑定';
        final syncNotice = _statusSyncNotice(snapshot);

        return ListView(
          key: ValueKey('route-page-${widget.path}'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            RepaintBoundary(
              key: const ValueKey('status-profile-selector'),
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(1, 11),
                    child: _CareStageSelector(
                      selectedStage: _careStage,
                      accent: widget.accent,
                      onChanged: _changeCareStage,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Transform.translate(
                    offset: const Offset(0, 5),
                    child: _StatusIdentityTabs(
                      selected: _view,
                      momSubtitle: momSubtitle,
                      babySubtitle: babySubtitle,
                      babyDisabled: isPregnancy,
                      onChanged: (next) {
                        if (next == 'baby' && isPregnancy) return;
                        setState(() => _view = next);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._statusOverviewChildren(snapshot, isMom),
            const SizedBox(height: 44),
            _StatusNextActions(
              isMom: isMom,
              growthRecordAdded: _growthRecordAdded,
              accent: widget.accent,
              onMomDiaryTap: () => context.go('/records'),
              onBabyGrowthTap: () => setState(() => _growthRecordAdded = true),
              onScheduleTap: () => context.go('/schedule'),
            ),
            if (syncNotice != null) ...[const SizedBox(height: 18), syncNotice],
          ],
        );
      },
    );
  }

  List<Widget> _statusOverviewChildren(
    AsyncSnapshot<StatusOverview> snapshot,
    bool isMom,
  ) {
    final overview = snapshot.data ?? const StatusOverview();
    final content = isMom
        ? _momStatusChildren(overview)
        : _babyStatusChildren(overview);

    return content;
  }

  Widget? _statusSyncNotice(AsyncSnapshot<StatusOverview> snapshot) {
    final overview = snapshot.data ?? const StatusOverview();

    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const _ActionTile(
        icon: Icons.sync_rounded,
        title: '正在同步状态',
        subtitle: '正在读取妈妈和宝宝状态。',
        accent: Color(0xff9f6378),
        trailing: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (snapshot.hasError) {
      return _ActionTile(
        icon: Icons.cloud_off_outlined,
        title: '状态同步失败',
        subtitle: '检查后端连接或 token 后重试。',
        accent: const Color(0xff9f6378),
        trailing: IconButton(
          tooltip: '重试',
          onPressed: _reloadOverview,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    if (overview.isEmpty) {
      return const _ActionTile(
        icon: Icons.info_outline_rounded,
        title: '暂无状态数据',
        subtitle: '完成妈妈/宝宝资料后这里会显示当前状态。',
        accent: Color(0xff7f6a75),
        trailing: Icon(Icons.chevron_right_rounded),
      );
    }

    return null;
  }

  List<Widget> _momStatusChildren(StatusOverview overview) {
    final isPregnancy = _careStage == 'pregnancy';
    final mom = overview.mom;
    final stage = isPregnancy ? '孕期' : _textOr(mom?.stage, '哺乳期');
    final stageNote = isPregnancy
        ? '孕期重点：体征与日记'
        : (mom?.postpartumDay == null
              ? '产后恢复期'
              : '产后第 ${mom!.postpartumDay} 天');

    if (isPregnancy) {
      return const [
        _StatusPregnancyDiaryPreview(),
        SizedBox(height: 18),
        _StatusPregnancyPlanPreview(),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Transform.translate(
          offset: const Offset(3, -1),
          child: _StatusModuleGrid(
            key: const ValueKey('status-postpartum-mom-module-grid'),
            children: [
              Transform.translate(
                offset: const Offset(0, 4),
                child: _StatusModuleCard(
                  key: const ValueKey('status-module-milk-output'),
                  title: '母乳产出',
                  icon: Icons.water_drop_outlined,
                  accent: MomCozyColors.primary,
                  background: const Color(0xfffff7fb),
                  hiddenTexts: [stage, stageNote],
                  metrics: const [
                    _StatusModuleMetric(
                      label: '今日产出',
                      value: '待记录',
                      showHelp: true,
                    ),
                    _StatusModuleMetric(label: '今日吸奶', value: '待同步'),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, 4),
                child: const _StatusModuleCard(
                  key: ValueKey('status-module-breast-health'),
                  title: '乳房健康',
                  showHelp: true,
                  bodyText: '最近出现涨奶和硬块，伴随按压疼痛',
                  action: '查看《乳房健康日记》',
                  icon: Icons.monitor_heart_outlined,
                  accent: Color(0xffb96f55),
                  background: Color(0xfffff8f1),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, 1),
                child: const _StatusModuleCard(
                  key: ValueKey('status-module-postpartum-recovery'),
                  title: '产后恢复',
                  bodyText: '正在执行盆底肌康复训练',
                  action: '查看计划',
                  icon: Icons.self_improvement_rounded,
                  accent: Color(0xff388b72),
                  background: Color(0xfff2fffb),
                ),
              ),
              const _StatusModuleCard(
                key: ValueKey('status-module-rest-nutrition'),
                title: '补能与休息',
                showHelp: true,
                bodyText: '待开通睡眠与营养功能',
                icon: Icons.local_cafe_outlined,
                accent: Color(0xffb9792a),
                background: Color(0xfffffaf0),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const _StatusTrendPreview(key: ValueKey('status-milk-trend-preview')),
    ];
  }

  List<Widget> _babyStatusChildren(StatusOverview overview) {
    final baby = overview.baby;
    final ageLabel = baby?.ageDays == null ? '待同步' : '${baby!.ageDays} 天';

    return [
      _StatusModuleGrid(
        children: [
          const _StatusModuleCard(
            title: '奶量摄入',
            icon: Icons.restaurant_outlined,
            accent: Color(0xff4f84a6),
            background: Color(0xfff4fbff),
            metrics: [
              _StatusModuleMetric(label: '今日摄入', value: '待同步'),
              _StatusModuleMetric(label: '今日喂奶', value: '待同步'),
            ],
          ),
          _StatusModuleCard(
            title: '成长发育',
            icon: Icons.straighten_outlined,
            accent: const Color(0xff388b72),
            background: const Color(0xfff2fffb),
            metrics: [
              _StatusModuleMetric(
                label: '宝宝',
                value: _textOr(baby?.nickname, '未设置'),
                note: ageLabel,
              ),
              _StatusModuleMetric(
                label: '成长记录',
                value: _growthRecordAdded ? '已添加' : '待记录',
              ),
            ],
            action: _growthRecordAdded ? '已记录' : '记录成长事件',
            onAction: () => setState(() => _growthRecordAdded = true),
          ),
          const _StatusModuleCard(
            title: '宝宝健康',
            bodyText: '筛查、消化、皮肤和情绪跟踪',
            icon: Icons.health_and_safety_outlined,
            accent: Color(0xff7d64aa),
            background: Color(0xfffbf7ff),
            action: '查看筛查',
          ),
          const _StatusModuleCard(
            title: '宝宝睡眠',
            bodyText: '总睡眠、最长睡眠、活动和哭闹',
            icon: Icons.nightlight_outlined,
            accent: Color(0xffff9677),
            background: Color(0xfffff8f1),
            action: '查看报告',
          ),
        ],
      ),
      const SizedBox(height: 12),
      const _StatusBabyGrowthCurvePreview(),
    ];
  }
}

class _StatusNextActions extends StatelessWidget {
  const _StatusNextActions({
    required this.isMom,
    required this.growthRecordAdded,
    required this.accent,
    required this.onMomDiaryTap,
    required this.onBabyGrowthTap,
    required this.onScheduleTap,
  });

  final bool isMom;
  final bool growthRecordAdded;
  final Color accent;
  final VoidCallback onMomDiaryTap;
  final VoidCallback onBabyGrowthTap;
  final VoidCallback onScheduleTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('下一步'),
        _ActionTile(
          icon: isMom ? Icons.edit_note_rounded : Icons.monitor_weight_outlined,
          title: isMom ? '补写孕期日记' : (growthRecordAdded ? '成长记录已添加' : '记录成长事件'),
          subtitle: isMom
              ? '保留心情、体征和 Agent 分析上下文。'
              : (growthRecordAdded
                    ? '本地草稿已保存，同步恢复后会写入成长记录。'
                    : '记录身高、体重、睡眠和喂养变化。'),
          accent: accent,
          onTap: isMom ? onMomDiaryTap : onBabyGrowthTap,
          trailing: isMom
              ? const Icon(Icons.chevron_right_rounded)
              : _StatusChip(
                  label: growthRecordAdded ? '已记录' : '新增',
                  icon: growthRecordAdded
                      ? Icons.check_circle_outline_rounded
                      : Icons.add_circle_outline_rounded,
                  accent: accent,
                ),
        ),
        _ActionTile(
          icon: Icons.fact_check_outlined,
          title: '今日待办',
          subtitle: '2 项待确认，提醒和 Agent 建议会在这里汇总。',
          accent: const Color(0xffb2773b),
          onTap: onScheduleTap,
          trailing: const _StatusChip(
            label: '2',
            icon: Icons.notifications_active_outlined,
            accent: Color(0xffb2773b),
          ),
        ),
      ],
    );
  }
}

class _StatusModuleMetric {
  const _StatusModuleMetric({
    required this.label,
    required this.value,
    this.note,
    this.showHelp = false,
  });

  final String label;
  final String value;
  final String? note;
  final bool showHelp;
}

class _StatusModuleGrid extends StatelessWidget {
  const _StatusModuleGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MomCozyLayout.maxAppWidth;
        return SizedBox(
          width: width,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.26,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          ),
        );
      },
    );
  }
}

class _StatusModuleCard extends StatelessWidget {
  const _StatusModuleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.background,
    this.bodyText,
    this.metrics = const [],
    this.hiddenTexts = const [],
    this.action,
    this.onAction,
    this.showHelp = false,
  });

  final String title;
  final String? bodyText;
  final List<_StatusModuleMetric> metrics;
  final List<String> hiddenTexts;
  final String? action;
  final VoidCallback? onAction;
  final bool showHelp;
  final IconData icon;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: const Color(0xff35212c),
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );
    final helperStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0xff7a6870),
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      height: 1.24,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAction,
          child: Stack(
            children: [
              Positioned(
                right: -24,
                bottom: -32,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              for (final hiddenText in hiddenTexts)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Opacity(opacity: 0, child: Text(hiddenText)),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                              if (showHelp) const _StatusHelpDot(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 16, color: accent),
                        ),
                      ],
                    ),
                    SizedBox(height: metrics.isNotEmpty ? 20 : 14),
                    if (metrics.isNotEmpty)
                      _StatusModuleMetricRows(metrics: metrics)
                    else if (bodyText != null)
                      Text(
                        bodyText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: helperStyle,
                      ),
                    if (action != null) ...[
                      const SizedBox(height: 4),
                      _StatusModuleActionPill(
                        label: action!,
                        accent: accent,
                        onTap: onAction,
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
}

class _StatusModuleMetricRows extends StatelessWidget {
  const _StatusModuleMetricRows({required this.metrics});

  final List<_StatusModuleMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metric in metrics)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          metric.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xff7a5b68),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (metric.showHelp) const _StatusHelpDot(size: 14),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xff35212c),
                      fontSize: metrics.length >= 3 ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  if (metric.note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      metric.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.primary,
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusHelpDot extends StatelessWidget {
  const _StatusHelpDot({this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(
            color: MomCozyColors.mutedForeground.withValues(alpha: 0.46),
          ),
        ),
        child: Text(
          '?',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: MomCozyColors.mutedForeground,
            fontSize: size <= 14 ? 8 : 10,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusModuleActionPill extends StatelessWidget {
  const _StatusModuleActionPill({
    required this.label,
    required this.accent,
    this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPregnancyDiaryPreview extends StatelessWidget {
  const _StatusPregnancyDiaryPreview();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: MomCozyColors.foreground,
      fontWeight: FontWeight.w900,
    );
    final helperStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: MomCozyColors.mutedForeground,
      fontWeight: FontWeight.w800,
      height: 1.35,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffeadfd8)),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                Expanded(child: Text('孕期日记', style: titleStyle)),
                _StatusOutlinedPill(
                  label: '查看日记',
                  icon: null,
                  accent: const Color(0xffa0603a),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffeadfd8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: const [
                Expanded(
                  child: _StatusPregnancyStat(value: '0', label: '近7天记录'),
                ),
                _StatusVerticalDivider(),
                Expanded(
                  child: _StatusPregnancyStat(value: '0', label: '健康咨询'),
                ),
                _StatusVerticalDivider(),
                Expanded(
                  child: _StatusPregnancyStat(value: '0', label: '产检问题'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffeadfd8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage(MomCozyAssets.agentAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '记录几天后，我可以帮你回顾睡眠、情绪、胎动和身体感受的变化。',
                    style: helperStyle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffeadfd8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '今日日记',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    _StatusFilledPill(
                      label: '记录今天',
                      icon: Icons.edit_outlined,
                      color: const Color(0xffb06f45),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xffead2c3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今天还没有记录哦。可以先写下心情、身体感受、胎动或想问医生的问题。',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 15,
                            backgroundImage: AssetImage(
                              MomCozyAssets.agentAvatar,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '和我聊天时，我会自动记录你的今日情况和健康信息。',
                              style: helperStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _StatusPregnancyStat extends StatelessWidget {
  const _StatusPregnancyStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xff985f3b),
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: MomCozyColors.mutedForeground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StatusVerticalDivider extends StatelessWidget {
  const _StatusVerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xffeadfd8),
    );
  }
}

class _StatusPregnancyPlanPreview extends StatelessWidget {
  const _StatusPregnancyPlanPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xfffbfefd),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffcae6e0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '孕期计划',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _StatusFilledPill(
            label: '制定孕期计划',
            icon: null,
            color: const Color(0xff5f978b),
            avatar: true,
          ),
        ],
      ),
    );
  }
}

class _StatusBabyGrowthCurvePreview extends StatelessWidget {
  const _StatusBabyGrowthCurvePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 246,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffbf7ff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe6d9fb)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xffe5d9ff),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 16,
                  color: Color(0xff7d64aa),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '宝宝成长曲线',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: MomCozyColors.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatusTrendLegendItem(
                label: '实际测量',
                color: const Color(0xff7d64aa),
                dashed: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xff7d64aa),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _StatusTrendLegendItem(
                label: '同龄参考区间',
                color: const Color(0xffeee8ff),
                band: true,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xff7d64aa),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _StatusSegmentedPills(
                selected: '体重',
                options: const ['体重', '身高'],
                color: const Color(0xff7d64aa),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              '暂无成长曲线数据，录入多项测量后与同龄参考一同展示。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _StatusFilledPill extends StatelessWidget {
  const _StatusFilledPill({
    required this.label,
    required this.icon,
    required this.color,
    this.avatar = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(avatar ? 6 : 12, 8, 14, 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar) ...[
            const CircleAvatar(
              radius: 13,
              backgroundImage: AssetImage(MomCozyAssets.agentAvatar),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOutlinedPill extends StatelessWidget {
  const _StatusOutlinedPill({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        border: Border.all(color: const Color(0xffeadfd8)),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSegmentedPills extends StatelessWidget {
  const _StatusSegmentedPills({
    required this.selected,
    required this.options,
    required this.color,
  });

  final String selected;
  final List<String> options;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: option == selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              ),
              child: Text(
                option,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: option == selected ? Colors.white : color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTrendPreview extends StatelessWidget {
  const _StatusTrendPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xfff0dfc4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -3),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xffffe4b8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    size: 14,
                    color: Color(0xffb9792a),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '母乳趋势',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 16,
                  color: MomCozyColors.mutedForeground,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Transform.translate(
            offset: const Offset(1, -1),
            child: const Row(
              children: [
                Expanded(child: _StatusTrendLegend()),
                _StatusSegmentedPills(
                  selected: '周',
                  options: ['周', '月'],
                  color: Color(0xffb9792a),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 188,
            child: CustomPaint(
              painter: const _StatusTrendPreviewPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTrendPreviewPainter extends CustomPainter {
  const _StatusTrendPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const labels = [
      '06/26',
      '06/27',
      '06/28',
      '06/29',
      '06/30',
      '07/01',
      '07/02',
    ];
    final segmentCount = labels.length - 1;
    final chartRect = Rect.fromLTWH(44, 1, size.width - 58, size.height - 44);
    final axisPaint = Paint()
      ..color = const Color(0xffb9792a)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = const Color(0xffb9792a)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final gridPaint = Paint()
      ..color = const Color(0xffcfe8d8)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index += 1) {
      final y = chartRect.top + chartRect.height * index / 4;
      _drawDashedLine(
        canvas,
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawChartText(
        canvas,
        '${4 - index} mL',
        Offset(5, y - 7),
        width: 34,
        color: const Color(0xff9c7651),
        fontSize: 8,
        textAlign: TextAlign.right,
      );
    }

    for (var index = 0; index <= segmentCount; index += 1) {
      final x = chartRect.left + chartRect.width * index / segmentCount;
      _drawDashedLine(
        canvas,
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
    }

    canvas.drawLine(chartRect.topLeft, chartRect.bottomLeft, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    final actual = Path()..moveTo(chartRect.left, chartRect.bottom);
    final points = <Offset>[
      for (var index = 0; index <= segmentCount; index += 1)
        Offset(
          chartRect.left + chartRect.width * index / segmentCount,
          chartRect.bottom,
        ),
    ];
    for (final point in points.skip(1)) {
      actual.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(actual, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xfffffaf0)
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = const Color(0xffb9792a)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
      canvas.drawCircle(point, 3, dotBorderPaint);
    }

    for (var index = 0; index < labels.length; index += 1) {
      _drawChartText(
        canvas,
        labels[index],
        Offset(points[index].dx - 16, chartRect.bottom + 10),
        width: 36,
        color: const Color(0xff9c7651),
        fontSize: 8,
        textAlign: TextAlign.center,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 3.0;
    const dashGap = 4.0;
    if ((start.dx - end.dx).abs() < 0.1) {
      var y = start.dy;
      while (y < end.dy) {
        final next = math.min(y + dashWidth, end.dy);
        canvas.drawLine(Offset(start.dx, y), Offset(end.dx, next), paint);
        y += dashWidth + dashGap;
      }
      return;
    }
    var x = start.dx;
    while (x < end.dx) {
      final next = math.min(x + dashWidth, end.dx);
      canvas.drawLine(Offset(x, start.dy), Offset(next, end.dy), paint);
      x += dashWidth + dashGap;
    }
  }

  void _drawChartText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    required Color color,
    required double fontSize,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StatusTrendPreviewPainter oldDelegate) => false;
}

class _StatusTrendLegend extends StatelessWidget {
  const _StatusTrendLegend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0xff8a6742),
      fontSize: 9,
      fontWeight: FontWeight.w400,
    );
    return Wrap(
      spacing: 9,
      runSpacing: 6,
      children: const [
        _StatusTrendLegendItem(
          label: '吸乳总量',
          color: Color(0xffb9792a),
          dashed: false,
        ),
        _StatusTrendLegendItem(
          label: '含亲喂估算',
          color: Color(0xff8a5f7d),
          dashed: true,
        ),
        _StatusTrendLegendItem(
          label: '目标参考区间',
          color: Color(0xffdff4e8),
          band: true,
        ),
      ].map((item) => item.withStyle(style)).toList(growable: false),
    );
  }
}

class _StatusTrendLegendItem extends StatelessWidget {
  const _StatusTrendLegendItem({
    required this.label,
    required this.color,
    this.dashed = false,
    this.band = false,
    this.style,
  });

  final String label;
  final Color color;
  final bool dashed;
  final bool band;
  final TextStyle? style;

  _StatusTrendLegendItem withStyle(TextStyle? nextStyle) {
    return _StatusTrendLegendItem(
      label: label,
      color: color,
      dashed: dashed,
      band: band,
      style: nextStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(12, band ? 8 : 2),
          painter: _StatusTrendLegendMarkPainter(
            color: color,
            dashed: dashed,
            band: band,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}

class _StatusTrendLegendMarkPainter extends CustomPainter {
  const _StatusTrendLegendMarkPainter({
    required this.color,
    required this.dashed,
    required this.band,
  });

  final Color color;
  final bool dashed;
  final bool band;

  @override
  void paint(Canvas canvas, Size size) {
    if (band) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      final next = (x + 4 > size.width) ? size.width : x + 4;
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(next, size.height / 2),
        paint,
      );
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusTrendLegendMarkPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashed != dashed ||
        oldDelegate.band != band;
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
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        container: true,
        label: '照护阶段切换',
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CareStageOption(
                key: const ValueKey('status-care-stage-pregnancy'),
                label: '孕期',
                selected: selectedStage == 'pregnancy',
                onTap: () => onChanged('pregnancy'),
              ),
              const SizedBox(width: 2),
              _CareStageOption(
                key: const ValueKey('status-care-stage-postpartum'),
                label: '哺乳期',
                selected: selectedStage == 'postpartum',
                onTap: () => onChanged('postpartum'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareStageOption extends StatelessWidget {
  const _CareStageOption({
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
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 24, minWidth: 42),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
            border: selected
                ? Border.all(
                    color: const Color(0xffeadfd8).withValues(alpha: 0.7),
                  )
                : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? const Color(0xff6f5964)
                  : const Color(0xffaa98a1),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
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
    required this.babyDisabled,
    required this.onChanged,
  });

  final String selected;
  final String momSubtitle;
  final String babySubtitle;
  final bool babyDisabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 7.0;
        final tabWidth = (constraints.maxWidth - gap) / 2;

        return Row(
          children: [
            SizedBox(
              width: tabWidth,
              child: Transform.translate(
                offset: selected == 'mom' ? const Offset(0, -5) : Offset.zero,
                child: _StatusIdentityTab(
                  value: 'mom',
                  title: '妈妈',
                  subtitle: momSubtitle,
                  asset: MomCozyAssets.momAvatar,
                  selected: selected == 'mom',
                  onTap: () => onChanged('mom'),
                ),
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: tabWidth,
              child: _StatusIdentityTab(
                value: 'baby',
                title: '宝宝',
                subtitle: babySubtitle,
                asset: MomCozyAssets.babyAvatar,
                selected: selected == 'baby',
                disabled: babyDisabled,
                onTap: () => onChanged('baby'),
              ),
            ),
          ],
        );
      },
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
    this.disabled = false,
    required this.onTap,
  });

  final String value;
  final String title;
  final String subtitle;
  final String asset;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? MomCozyColors.primary.withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.70);
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      enabled: !disabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: disabled
              ? MomCozyColors.raised.withValues(alpha: 0.24)
              : selected
              ? const Color(0xfffff7fb)
              : MomCozyColors.raised.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('status-identity-tab-$value'),
            onTap: disabled ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
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
                          color: Color(0xffb46f91),
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
                        Opacity(
                          opacity: disabled
                              ? 0.45
                              : selected
                              ? 1
                              : 0.75,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: disabled
                                    ? MomCozyColors.border.withValues(
                                        alpha: 0.35,
                                      )
                                    : selected
                                    ? const Color(
                                        0xffb46f91,
                                      ).withValues(alpha: 0.45)
                                    : MomCozyColors.border.withValues(
                                        alpha: 0.5,
                                      ),
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: AssetImage(asset),
                                fit: BoxFit.cover,
                              ),
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
                                      color: disabled
                                          ? MomCozyColors.mutedForeground
                                                .withValues(alpha: 0.6)
                                          : selected
                                          ? MomCozyColors.foreground
                                          : MomCozyColors.mutedForeground,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: disabled
                                          ? MomCozyColors.mutedForeground
                                                .withValues(alpha: 0.52)
                                          : selected
                                          ? MomCozyColors.mutedForeground
                                          : MomCozyColors.mutedForeground
                                                .withValues(alpha: 0.75),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
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

        return ListView(
          key: ValueKey('route-page-${widget.path}'),
          padding: const EdgeInsets.fromLTRB(16, 34, 16, 96),
          children: [
            Transform.translate(
              offset: const Offset(0, -8),
              child: _ScheduleDateStrip(
                key: const ValueKey('schedule-date-strip'),
                selectedDay: _selectedDay,
                onSelected: _selectDay,
              ),
            ),
            const SizedBox(height: 16),
            Transform.translate(
              offset: const Offset(-2, -9),
              child: _ScheduleContextCard(
                title: '稳奶计划执行中',
                subtitle: '产后第29周（离乳期）',
                completedCount: taskCount == null
                    ? 0
                    : taskCount - pendingTaskCount,
                totalCount: taskCount ?? 0,
                reminderEnabled: _pumpReminderEnabled,
                onReminderTap: () => setState(
                  () => _pumpReminderEnabled = !_pumpReminderEnabled,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Transform.translate(
              offset: const Offset(-1, 0),
              child: _ScheduleAgentCard(
                key: const ValueKey('schedule-agent-card'),
                reminderEnabled: _pumpReminderEnabled,
                onReminderTap: () => setState(
                  () => _pumpReminderEnabled = !_pumpReminderEnabled,
                ),
                onConversationTap: () => context.go('/'),
              ),
            ),
            const SizedBox(height: 20),
            Transform.translate(
              offset: const Offset(1, 1),
              child: _ScheduleNextTaskCard(
                subtitle: _nextTaskSubtitle(visibleTasks),
                task: _nextPendingTask(visibleTasks),
                onComplete: () {
                  final next = _nextPendingTask(visibleTasks);
                  if (next == null) return;
                  final index = visibleTasks.indexOf(next);
                  _toggleTask(next, index, true);
                },
              ),
            ),
            const SizedBox(height: 30),
            _ScheduleListToolbar(onAdd: _addLocalTask),
            ..._dayPlanChildren(snapshot),
            const SizedBox(height: 18),
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
            if (_scheduleSyncNotice(snapshot) case final syncNotice?) ...[
              const SizedBox(height: 18),
              syncNotice,
            ],
          ],
        );
      },
    );
  }

  List<Widget> _dayPlanChildren(AsyncSnapshot<ScheduleDayPlan> snapshot) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const [_ScheduleEmptyTaskNotice()];
    }

    if (snapshot.hasError) {
      return const [_ScheduleEmptyTaskNotice()];
    }

    final plan = snapshot.data;
    final tasks = plan == null ? const <ScheduleTask>[] : _visibleTasks(plan);
    if (tasks.isEmpty) {
      return const [_ScheduleEmptyTaskNotice()];
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

  Widget? _scheduleSyncNotice(AsyncSnapshot<ScheduleDayPlan> snapshot) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return _ActionTile(
        icon: Icons.sync_rounded,
        title: '正在同步计划',
        subtitle: '正在读取当天任务和提醒。',
        accent: widget.accent,
        trailing: const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (snapshot.hasError) {
      return _ActionTile(
        icon: Icons.cloud_off_outlined,
        title: '计划同步失败',
        subtitle: '检查后端连接或 token 后重试。',
        accent: widget.accent,
        trailing: IconButton(
          tooltip: '重试',
          onPressed: _reloadDayPlan,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    return null;
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
    super.key,
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
          child: Transform.translate(
            offset: const Offset(-4, 4),
            child: Text(
              '${selectedDate.year}年${selectedDate.month}月',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: MomCozyDecorations.card(
            color: MomCozyColors.card,
            borderColor: MomCozyColors.border.withValues(alpha: 0.5),
            shadows: MomCozyShadows.soft,
            radius: 16,
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

class _ScheduleEmptyTaskNotice extends StatelessWidget {
  const _ScheduleEmptyTaskNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '当天暂无执行内容',
          style: TextStyle(
            color: MomCozyColors.mutedForeground,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
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

class _ScheduleAgentCard extends StatelessWidget {
  const _ScheduleAgentCard({
    super.key,
    required this.reminderEnabled,
    required this.onReminderTap,
    required this.onConversationTap,
  });

  final bool reminderEnabled;
  final VoidCallback onReminderTap;
  final VoidCallback onConversationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.raised,
        borderColor: MomCozyColors.primary.withValues(alpha: 0.15),
        radius: 24,
        shadows: MomCozyShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(
              MomCozyAssets.agentAvatar,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ScheduleAgentButton(
                      icon: reminderEnabled
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_off_outlined,
                      label: '提醒开关',
                      filled: false,
                      onTap: onReminderTap,
                    ),
                    const SizedBox(width: 8),
                    _ScheduleAgentButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '对话',
                      filled: true,
                      onTap: onConversationTap,
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

class _ScheduleAgentButton extends StatelessWidget {
  const _ScheduleAgentButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? MomCozyColors.primary : MomCozyColors.background,
      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
            border: Border.all(
              color: filled
                  ? MomCozyColors.primary
                  : MomCozyColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled ? MomCozyColors.raised : MomCozyColors.foreground,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: filled
                      ? MomCozyColors.raised
                      : MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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
        color: MomCozyColors.raised,
        borderColor: MomCozyColors.border.withValues(alpha: 0.4),
        radius: 24,
        shadows: MomCozyShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              key: const ValueKey('schedule-context-reminder-button'),
              tooltip: reminderEnabled ? '关闭计划提醒' : '开启计划提醒',
              onPressed: onReminderTap,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: MomCozyColors.background.withValues(
                  alpha: 0.9,
                ),
                side: BorderSide(
                  color: MomCozyColors.border.withValues(alpha: 0.5),
                ),
                shape: const CircleBorder(),
                shadowColor: Colors.black.withValues(alpha: 0.08),
                elevation: 2,
              ),
              icon: Icon(
                reminderEnabled
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_off_outlined,
                size: 18,
                color: reminderEnabled
                    ? MomCozyColors.foreground
                    : MomCozyColors.mutedForeground,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 46),
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
                  ],
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
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                  minHeight: 9,
                  color: MomCozyColors.primary,
                  backgroundColor: MomCozyColors.secondary.withValues(
                    alpha: 0.72,
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

    if (!hasTask) {
      return Container(
        key: const ValueKey('schedule-empty-task-card'),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.secondary.withValues(alpha: 0.3),
          borderColor: MomCozyColors.border.withValues(alpha: 0.4),
          radius: 28,
          shadows: const [],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MomCozyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 34,
                color: MomCozyColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '今天还没有计划任务',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '可以先从对话里生成计划并同步到日历，或手动添加任务。',
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

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
                      _nullableTimeLabel(task.remindAt),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: MomCozyColors.foreground,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _textOr(task.title, subtitle),
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
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  '今日任务',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: '今日任务说明',
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: MomCozyColors.raised.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MomCozyColors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      Icons.question_mark_rounded,
                      size: 12,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScheduleToolbarIconButton(
                tooltip: '调整日程',
                icon: Icons.image_outlined,
                label: '调整日程',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              _ScheduleToolbarIconButton(
                key: const ValueKey('schedule-add-task-button'),
                tooltip: '添加任务',
                icon: Icons.add_rounded,
                label: '添加任务',
                onPressed: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleToolbarIconButton extends StatelessWidget {
  const _ScheduleToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: MomCozyColors.foreground,
          side: BorderSide(color: MomCozyColors.border.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
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
    return Transform.scale(
      scale: selected ? 1.05 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? MomCozyColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? MomCozyColors.primary : Colors.transparent,
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
              width: 36,
              height: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? MomCozyColors.raised.withValues(alpha: 0.9)
                          : MomCozyColors.mutedForeground.withValues(
                              alpha: 0.65,
                            ),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected
                          ? MomCozyColors.raised
                          : MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 28),
      children: [
        _DeviceHeader(
          onAdd: _toggleScan,
          onUser: () => context.go('/device/user'),
          onManage: () => context.go('/device/manage'),
        ),
        const SizedBox(height: 14),
        const _DeviceW1Banner(),
        const SizedBox(height: 17),
        _DeviceAirOnePanel(
          leftDevice: leftDevice,
          rightDevice: rightDevice,
          onStartPump: _canStartPump(leftDevice, rightDevice)
              ? () => context.go('/pump')
              : null,
          onLeftAction: leftDevice?.connected == true
              ? () => context.go('/calibration')
              : _toggleScan,
          onRightAction: rightDevice?.connected == true
              ? () => context.go('/calibration')
              : _toggleScan,
        ),
        if (_scanAttempted || _bleError != null) ...[
          const SizedBox(height: 14),
          _DeviceScanPanel(
            isScanning: _isScanning,
            permissionState: _permissionState,
            connectedCount: _connectedDevices.length,
            error: _bleError,
            accent: widget.accent,
            action: _permissionAction(),
            onScan: _toggleScan,
          ),
        ],
        if (_scanAttempted) ...[
          const SizedBox(height: 12),
          _DeviceScanResultsPanel(
            scanResults: _scanResults,
            onConnect: _connectScanResult,
            accent: widget.accent,
          ),
        ],
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

bool _canStartPump(BleDeviceSnapshot? left, BleDeviceSnapshot? right) {
  return left?.connected == true && right?.connected == true;
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({
    required this.onAdd,
    required this.onUser,
    required this.onManage,
  });

  final VoidCallback onAdd;
  final VoidCallback onManage;
  final VoidCallback onUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '设备连接',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: MomCozyColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '打开设备快捷菜单',
          color: MomCozyColors.foreground.withValues(alpha: 0.92),
          elevation: 14,
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            switch (value) {
              case 'add':
                onAdd();
                break;
              case 'user':
                onUser();
                break;
              case 'manage':
                onManage();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'add', child: _DeviceQuickMenuLabel('添加设备')),
            PopupMenuDivider(height: 1),
            PopupMenuItem(value: 'user', child: _DeviceQuickMenuLabel('用户管理')),
            PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'manage',
              child: _DeviceQuickMenuLabel('设备提醒'),
            ),
          ],
          child: Container(
            key: const ValueKey('device-quick-menu-button'),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MomCozyColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: MomCozyShadows.soft,
            ),
            child: const Icon(Icons.add_rounded, size: 20),
          ),
        ),
      ],
    );
  }
}

class _DeviceQuickMenuLabel extends StatelessWidget {
  const _DeviceQuickMenuLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: MomCozyColors.background,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DeviceW1Banner extends StatelessWidget {
  const _DeviceW1Banner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/w1'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, 0.6, 1],
              colors: [Color(0xff562938), Color(0xff723141), Color(0xff602e37)],
            ),
            border: Border.all(
              color: MomCozyColors.primary.withValues(alpha: 0.2),
            ),
            boxShadow: MomCozyShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xffffdce5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Momcozy W1 · 全新上市',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0x66ffffff),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceAirOnePanel extends StatelessWidget {
  const _DeviceAirOnePanel({
    required this.leftDevice,
    required this.rightDevice,
    required this.onStartPump,
    required this.onLeftAction,
    required this.onRightAction,
  });

  final BleDeviceSnapshot? leftDevice;
  final BleDeviceSnapshot? rightDevice;
  final VoidCallback? onStartPump;
  final VoidCallback onLeftAction;
  final VoidCallback onRightAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card,
        borderColor: MomCozyColors.border.withValues(alpha: 0.6),
        radius: 24,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Air One',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('device-start-pump-button'),
                  onPressed: onStartPump,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    disabledBackgroundColor: MomCozyColors.primary.withValues(
                      alpha: 0.36,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.72,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('开始吸奶'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DeviceDeckCard(
                    sideCode: 'L',
                    sideLabel: '左侧',
                    device: leftDevice,
                    onTap: onLeftAction,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DeviceDeckCard(
                    sideCode: 'R',
                    sideLabel: '右侧',
                    device: rightDevice,
                    onTap: onRightAction,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDeckCard extends StatelessWidget {
  const _DeviceDeckCard({
    required this.sideCode,
    required this.sideLabel,
    required this.device,
    required this.onTap,
  });

  final String sideCode;
  final String sideLabel;
  final BleDeviceSnapshot? device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paired = device != null;
    final connected = device?.connected == true;
    final statusColor = connected
        ? const Color(0xff3f9d74)
        : MomCozyColors.mutedForeground;

    return Material(
      key: ValueKey('device-deck-card-$sideCode'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 188,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: connected ? MomCozyColors.card : const Color(0xfff7f7f8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: connected
                  ? MomCozyColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            boxShadow: connected ? MomCozyShadows.soft : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sideCode == 'L' ? 'LEFT' : 'RIGHT',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: MomCozyColors.foreground.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (paired)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MomCozyColors.background.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MomCozyColors.border.withValues(alpha: 0.48),
                        ),
                      ),
                      child: const Icon(Icons.info_outline_rounded, size: 15),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: connected
                            ? MomCozyColors.primary.withValues(alpha: 0.06)
                            : MomCozyColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MomCozyColors.border.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    if (paired)
                      Image.asset(
                        MomCozyAssets.pumpM9,
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        opacity: AlwaysStoppedAnimation(connected ? 1 : 0.46),
                      )
                    else
                      Icon(
                        Icons.photo_camera_outlined,
                        color: MomCozyColors.foreground.withValues(alpha: 0.38),
                        size: 25,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (paired)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MomCozyColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.48),
                    ),
                  ),
                  child: _DeviceConnectedDetails(
                    sideLabel: sideLabel,
                    device: device!,
                    statusColor: statusColor,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.54),
                    ),
                    boxShadow: MomCozyShadows.soft,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth_rounded, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '连接设备',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
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

class _DeviceConnectedDetails extends StatelessWidget {
  const _DeviceConnectedDetails({
    required this.sideLabel,
    required this.device,
    required this.statusColor,
  });

  final String sideLabel;
  final BleDeviceSnapshot device;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final connected = device.connected;
    final name = device.deviceName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                connected ? '已连接' : '未连接',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: connected
                      ? MomCozyColors.foreground
                      : MomCozyColors.mutedForeground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$sideLabel $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: MomCozyColors.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.battery_5_bar_rounded, size: 14),
            const SizedBox(width: 3),
            Text(
              _deviceBatteryLabel(device),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            const Icon(Icons.signal_cellular_alt_rounded, size: 13),
            const SizedBox(width: 3),
            Text(
              _deviceSignalLabel(device),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceScanPanel extends StatelessWidget {
  const _DeviceScanPanel({
    required this.isScanning,
    required this.permissionState,
    required this.connectedCount,
    required this.error,
    required this.accent,
    required this.action,
    required this.onScan,
  });

  final bool isScanning;
  final BlePermissionState permissionState;
  final int connectedCount;
  final String? error;
  final Color accent;
  final Widget action;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final title = isScanning ? '正在扫描附近设备' : 'BLE 权限和扫描';
    final subtitle =
        error ??
        (isScanning
            ? '请确保设备已开机（长按电源键3秒），并靠近手机。'
            : '权限状态 ${_permissionLabel(permissionState)}，已恢复 $connectedCount 台已连接设备。');

    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.92),
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            _DeviceRadarIcon(isScanning: isScanning, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: error == null
                          ? MomCozyColors.mutedForeground
                          : const Color(0xffa94747),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: onScan,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(84, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    isScanning
                        ? Icons.stop_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 17,
                  ),
                  label: Text(isScanning ? '停止扫描' : '扫描'),
                ),
                if (!isScanning) ...[
                  const SizedBox(height: 4),
                  SizedBox(width: 38, height: 32, child: Center(child: action)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRadarIcon extends StatelessWidget {
  const _DeviceRadarIcon({required this.isScanning, required this.accent});

  final bool isScanning;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isScanning)
            for (final size in const [58.0, 42.0])
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
              ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: MomCozyColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.48),
              ),
              boxShadow: MomCozyShadows.soft,
            ),
            child: Icon(
              isScanning
                  ? Icons.navigation_rounded
                  : Icons.bluetooth_searching_rounded,
              color: isScanning ? accent : MomCozyColors.mutedForeground,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceScanResultsPanel extends StatelessWidget {
  const _DeviceScanResultsPanel({
    required this.scanResults,
    required this.onConnect,
    required this.accent,
  });

  final List<BleDeviceSnapshot> scanResults;
  final ValueChanged<BleDeviceSnapshot> onConnect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '扫描结果',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: MomCozyColors.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (scanResults.isEmpty)
          _DeviceSearchRow(
            icon: Icons.bluetooth_disabled_rounded,
            title: '暂无扫描结果',
            subtitle: '请确认设备已开机并靠近手机后重试。',
            accent: MomCozyColors.mutedForeground,
          )
        else
          for (final device in scanResults.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DeviceSearchRow(
                icon: Icons.bluetooth_searching_rounded,
                title: device.deviceName,
                subtitle: _scanResultSubtitle(device),
                accent: accent,
                onTap: () => onConnect(device),
                trailing: const Text(
                  '连接',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
      ],
    );
  }
}

class _DeviceSearchRow extends StatelessWidget {
  const _DeviceSearchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.82),
        shadows: MomCozyShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _IconBubble(icon: icon, accent: accent, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MomCozyColors.mutedForeground,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _deviceSignalLabel(BleDeviceSnapshot? device) {
  final rssi = device?.rssi;
  if (rssi == null) return '强';
  if (rssi >= -55) return '强';
  if (rssi >= -70) return '中';
  return '弱';
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
  bool _calibrationPromptVisible = true;

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
    if (next == _runState) return;

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

    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xfffffaf8), Color(0xfffbf2f2), Color(0xfff8edf0)],
              stops: [0, 0.56, 1],
            ),
          ),
          child: Transform.translate(
            offset: const Offset(0, -3),
            child: ListView(
              key: ValueKey('route-page-${widget.path}'),
              scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
              children: [
                _PumpTopBar(sessionLabel: _headerSessionLabel),
                const SizedBox(height: 10),
                Transform.translate(
                  key: const ValueKey('pump-metric-console'),
                  offset: const Offset(6, -6),
                  child: _PumpMetricConsole(
                    totalVolumeMl: _totalVolumeMl,
                    elapsedMinutes: _elapsedMinutes,
                    progress: _sessionProgress,
                    userLabel: _sessionOwnerUserId == null
                        ? '未绑定用户'
                        : '绑定 $_sessionOwnerUserId',
                    accent: widget.accent,
                  ),
                ),
                const SizedBox(height: 10),
                _PumpSessionStage(
                  leftVolumeMl: _leftVolumeMl,
                  rightVolumeMl: _rightVolumeMl,
                  leftLevel: _leftLevel.round(),
                  rightLevel: _rightLevel.round(),
                  bottleFill: _bottleFill,
                  totalVolumeMl: _totalVolumeMl,
                  isRunning: isRunning,
                  accent: widget.accent,
                ),
                const SizedBox(height: 36),
                _PumpControlConsole(
                  leftLevel: _leftLevel,
                  rightLevel: _rightLevel,
                  isRunning: isRunning,
                  isPaused: isPaused,
                  onLeftLevelChanged: (value) =>
                      setState(() => _leftLevel = value),
                  onRightLevelChanged: (value) =>
                      setState(() => _rightLevel = value),
                  onStart: isRunning
                      ? null
                      : () => _changeRunState(_PumpRunState.running),
                  onPause: isRunning
                      ? () => _changeRunState(_PumpRunState.paused)
                      : null,
                  onEnd: () => _changeRunState(_PumpRunState.idle),
                ),
                const SizedBox(height: 10),
                _PumpStatusStrip(
                  label: '结束保护',
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
                _PumpStatusStrip(
                  label: '上传状态',
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
            ),
          ),
        ),
        if (_calibrationPromptVisible)
          _PumpCalibrationPromptOverlay(
            onSkip: () => setState(() => _calibrationPromptVisible = false),
            onStartCalibration: () {
              setState(() => _calibrationPromptVisible = false);
              context.go('/calibration');
            },
          ),
      ],
    );
  }

  int get _totalVolumeMl => _leftVolumeMl + _rightVolumeMl;

  double get _sessionProgress {
    return ((_elapsedMinutes / 30) * 100).clamp(0, 100).toDouble();
  }

  double get _bottleFill {
    return (_totalVolumeMl / 180).clamp(0, 1).toDouble();
  }

  String get _headerSessionLabel {
    return switch (_runState) {
      _PumpRunState.running => '运行中',
      _PumpRunState.paused => '已暂停',
      _PumpRunState.idle => '待开始',
    };
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

class _PumpCalibrationPromptOverlay extends StatelessWidget {
  const _PumpCalibrationPromptOverlay({
    required this.onSkip,
    required this.onStartCalibration,
  });

  final VoidCallback onSkip;
  final VoidCallback onStartCalibration;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ColoredBox(
            color: MomCozyColors.foreground.withValues(alpha: 0.43),
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    key: const ValueKey('pump-calibration-prompt-card'),
                    constraints: const BoxConstraints(maxWidth: 392),
                    child: DecoratedBox(
                      decoration: MomCozyDecorations.card(
                        color: MomCozyColors.card,
                        borderColor: MomCozyColors.border,
                        radius: 16,
                        shadows: const [
                          BoxShadow(
                            color: Color(0x40392832),
                            blurRadius: 36,
                            spreadRadius: -10,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -2),
                              child: Row(
                                children: [
                                  const _PumpPromptFlowerIcon(),
                                  const SizedBox(width: 8),
                                  Text(
                                    '个性化舒适档位',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: MomCozyColors.foreground,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Transform.translate(
                              offset: const Offset(-1, 2),
                              child: Column(
                                children: [
                                  _PumpPromptRichLine(
                                    segments: [
                                      const TextSpan(text: '妈妈，检测到您还没有进行过'),
                                      TextSpan(
                                        text: '耐受度滴定',
                                        style: _pumpPromptEmphasisStyle(
                                          context,
                                        ),
                                      ),
                                      const TextSpan(text: '哦~'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _PumpPromptRichLine(
                                    segments: [
                                      const TextSpan(text: '滴定可以帮您找到'),
                                      TextSpan(
                                        text: '最舒适且高效',
                                        style: _pumpPromptEmphasisStyle(
                                          context,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '的吸力档位，避免吸乳时疼痛或效率不佳 ',
                                      ),
                                      const TextSpan(text: '💕'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _PumpPromptRichLine(
                                    segments: [
                                      const TextSpan(text: '只需要 '),
                                      TextSpan(
                                        text: '2分钟',
                                        style: _pumpPromptEmphasisStyle(
                                          context,
                                        ),
                                      ),
                                      const TextSpan(text: '，就能让每次吸乳都更舒适~'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: onSkip,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(40),
                                      side: BorderSide(
                                        color: MomCozyColors.border.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '先跳过',
                                      style: TextStyle(
                                        fontFamily:
                                            MomCozyTypography.fontFamily,
                                        fontFamilyFallback: MomCozyTypography
                                            .fontFamilyFallback,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: onStartCalibration,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(40),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '开始滴定',
                                      style: TextStyle(
                                        fontFamily:
                                            MomCozyTypography.fontFamily,
                                        fontFamilyFallback: MomCozyTypography
                                            .fontFamilyFallback,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PumpPromptFlowerIcon extends StatelessWidget {
  const _PumpPromptFlowerIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _PumpPromptFlowerPainter()),
    );
  }
}

class _PumpPromptFlowerPainter extends CustomPainter {
  const _PumpPromptFlowerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final petalPaint = Paint()..color = const Color(0xffff8fb8);
    final petalShadePaint = Paint()..color = const Color(0xffff6fa7);
    final centerPaint = Paint()..color = const Color(0xffffd166);
    final centerDotPaint = Paint()..color = const Color(0xffcc8d24);

    for (var index = 0; index < 5; index += 1) {
      final angle = -math.pi / 2 + index * math.pi * 2 / 5;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -6.2), width: 8.5, height: 12),
        petalPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(1.3, -6.5), width: 3, height: 7),
        petalShadePaint,
      );
      canvas.restore();
    }

    canvas.drawCircle(center, 4, centerPaint);
    canvas.drawCircle(center.translate(0.7, -0.7), 1.1, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PumpPromptRichLine extends StatelessWidget {
  const _PumpPromptRichLine({required this.segments});

  final List<InlineSpan> segments;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: MomCozyColors.mutedForeground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.55,
        ),
        children: segments,
      ),
    );
  }
}

TextStyle _pumpPromptEmphasisStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelMedium!.copyWith(
    color: MomCozyColors.primary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.55,
  );
}

int _pumpStateCode(_PumpRunState state) {
  return switch (state) {
    _PumpRunState.running => 1,
    _PumpRunState.paused => 2,
    _PumpRunState.idle => 0,
  };
}

class _PumpTopBar extends StatelessWidget {
  const _PumpTopBar({required this.sessionLabel});

  final String sessionLabel;

  @override
  Widget build(BuildContext context) {
    final isActive = sessionLabel == '运行中';
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/'),
              style: TextButton.styleFrom(
                foregroundColor: MomCozyColors.mutedForeground,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 34),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                '返回',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '沉浸式吸乳',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? MomCozyColors.primary.withValues(alpha: 0.12)
                      : MomCozyColors.muted,
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                ),
                child: Text(
                  sessionLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? MomCozyColors.primary
                        : MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w900,
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

class _PumpMetricConsole extends StatelessWidget {
  const _PumpMetricConsole({
    required this.totalVolumeMl,
    required this.elapsedMinutes,
    required this.progress,
    required this.userLabel,
    required this.accent,
  });

  final int totalVolumeMl;
  final int elapsedMinutes;
  final double progress;
  final String userLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.84),
        borderColor: accent.withValues(alpha: 0.12),
        radius: 26,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PumpMetricPanel(
                    label: '吸乳量',
                    value: '$totalVolumeMl',
                    unit: 'mL',
                    accent: accent,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PumpMetricPanel(
                    label: '时间',
                    value: '$elapsedMinutes 分钟',
                    accent: const Color(0xff836775),
                    note: userLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '本次吸乳进度',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${progress.round()}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 9,
                color: accent,
                backgroundColor: MomCozyColors.secondary.withValues(
                  alpha: 0.86,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpMetricPanel extends StatelessWidget {
  const _PumpMetricPanel({
    required this.label,
    required this.value,
    required this.accent,
    this.unit,
    this.note,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? unit;
  final String? note;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized
            ? accent.withValues(alpha: 0.08)
            : MomCozyColors.muted.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PumpSessionStage extends StatelessWidget {
  const _PumpSessionStage({
    required this.leftVolumeMl,
    required this.rightVolumeMl,
    required this.leftLevel,
    required this.rightLevel,
    required this.bottleFill,
    required this.totalVolumeMl,
    required this.isRunning,
    required this.accent,
  });

  final int leftVolumeMl;
  final int rightVolumeMl;
  final int leftLevel;
  final int rightLevel;
  final double bottleFill;
  final int totalVolumeMl;
  final bool isRunning;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.68),
        borderColor: MomCozyColors.border.withValues(alpha: 0.46),
        radius: 26,
        shadows: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          children: [
            SizedBox(
              height: 194,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PumpSideMetric(
                    label: '左侧',
                    value: '$leftVolumeMl mL',
                    meta: '$leftLevel档 · 按摩+吸乳',
                    alignRight: true,
                  ),
                  const SizedBox(width: 4),
                  _PumpCupVisual(
                    sideLabel: 'L',
                    volumeMl: leftVolumeMl,
                    isRunning: isRunning,
                    tone: accent,
                  ),
                  Expanded(
                    child: Center(
                      child: _PumpBottleGauge(
                        fill: bottleFill,
                        totalVolumeMl: totalVolumeMl,
                        active: isRunning,
                      ),
                    ),
                  ),
                  _PumpCupVisual(
                    sideLabel: 'R',
                    volumeMl: rightVolumeMl,
                    isRunning: isRunning,
                    tone: const Color(0xffc86d92),
                  ),
                  const SizedBox(width: 4),
                  _PumpSideMetric(
                    label: '右侧',
                    value: '$rightVolumeMl mL',
                    meta: '$rightLevel档 · 吸乳',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: _PumpForcePanel(
                    label: '奶流强度曲线',
                    sideLabel: 'Left',
                    value: isRunning ? '稳定' : '待开始',
                    active: isRunning,
                    tone: const Color(0xffd87542),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PumpForcePanel(
                    label: '奶流强度曲线',
                    sideLabel: 'Right',
                    value: isRunning ? '柔和' : '待开始',
                    active: isRunning,
                    tone: const Color(0xffc86d92),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpSideMetric extends StatelessWidget {
  const _PumpSideMetric({
    required this.label,
    required this.value,
    required this.meta,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final String meta;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final alignment = alignRight ? TextAlign.right : TextAlign.left;
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: alignment,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: alignment,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: MomCozyColors.foreground,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            meta,
            textAlign: alignment,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpBottleGauge extends StatelessWidget {
  const _PumpBottleGauge({
    required this.fill,
    required this.totalVolumeMl,
    required this.active,
  });

  final double fill;
  final int totalVolumeMl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 82,
          height: 150,
          child: CustomPaint(
            painter: _PumpBottlePainter(fill: fill, active: active),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$totalVolumeMl',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'mL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PumpBottlePainter extends CustomPainter {
  const _PumpBottlePainter({required this.fill, required this.active});

  final double fill;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 215;
    canvas.save();
    canvas.scale(sx, sy);

    final shadowPaint = Paint()
      ..color = MomCozyColors.primary.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 56, 56, 146),
        const Radius.circular(24),
      ),
      shadowPaint,
    );

    final capPaint = Paint()..color = MomCozyColors.card;
    final borderPaint = Paint()
      ..color = MomCozyColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(50, 18, 20, 18),
          const Radius.circular(7),
        ),
        capPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(45, 32, 30, 14),
          const Radius.circular(5),
        ),
        Paint()..color = MomCozyColors.secondary,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(47, 44, 26, 18),
          const Radius.circular(6),
        ),
        capPaint,
      );

    final bottlePath = Path()
      ..moveTo(34, 78)
      ..cubicTo(34, 66, 43, 58, 50, 58)
      ..lineTo(70, 58)
      ..cubicTo(77, 58, 86, 66, 86, 78)
      ..lineTo(86, 182)
      ..cubicTo(86, 192, 78, 200, 68, 200)
      ..lineTo(52, 200)
      ..cubicTo(42, 200, 34, 192, 34, 182)
      ..close();

    final bodyRect = const Rect.fromLTWH(34, 58, 52, 142);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x26a86172), Color(0x12ffffff), Color(0x33a86172)],
      ).createShader(bodyRect);
    canvas.drawPath(bottlePath, bodyPaint);
    canvas.drawPath(bottlePath, borderPaint);

    final fillHeight = (134 * fill.clamp(0, 1)).toDouble();
    final fillY = 192 - fillHeight;
    canvas.save();
    canvas.clipPath(bottlePath);
    canvas.drawRect(
      Rect.fromLTWH(34, fillY, 52, 160),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xfffff4d8), Color(0xffead6a5)],
        ).createShader(Rect.fromLTWH(34, fillY, 52, 160)),
    );
    if (fill > 0.02) {
      final wavePaint = Paint()
        ..color = const Color(0xfffff8df).withValues(alpha: 0.72);
      final wave = Path()
        ..moveTo(34, fillY + 2)
        ..quadraticBezierTo(47, fillY - 4, 60, fillY + 2)
        ..quadraticBezierTo(73, fillY + 8, 86, fillY + 2)
        ..lineTo(86, 204)
        ..lineTo(34, 204)
        ..close();
      canvas.drawPath(wave, wavePaint);
    }
    canvas.restore();

    final shinePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0x33ffffff), Colors.transparent],
      ).createShader(bodyRect);
    canvas.drawPath(bottlePath, shinePaint);

    final markPaint = Paint()
      ..color = MomCozyColors.mutedForeground.withValues(alpha: 0.36)
      ..strokeWidth = 0.8;
    for (final mark in [20, 40, 60, 80, 100, 120, 140, 160]) {
      final y = 192 - (mark / 180) * 134;
      if (y < 66) continue;
      final major = mark % 40 == 0;
      canvas.drawLine(
        Offset(major ? 72 : 76, y),
        Offset(83, y),
        markPaint..strokeWidth = major ? 0.9 : 0.45,
      );
    }

    final portPaint = Paint()..color = MomCozyColors.card;
    canvas
      ..drawCircle(const Offset(34, 112), 4, portPaint)
      ..drawCircle(const Offset(86, 112), 4, portPaint)
      ..drawCircle(const Offset(34, 112), 4, borderPaint)
      ..drawCircle(const Offset(86, 112), 4, borderPaint);

    if (active) {
      final glowPaint = Paint()
        ..color = const Color(0xfffff1bd).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawOval(const Rect.fromLTWH(18, 50, 84, 140), glowPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PumpBottlePainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.active != active;
  }
}

class _PumpCupVisual extends StatelessWidget {
  const _PumpCupVisual({
    required this.sideLabel,
    required this.volumeMl,
    required this.isRunning,
    required this.tone,
  });

  final String sideLabel;
  final int volumeMl;
  final bool isRunning;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final fill = (volumeMl / 36).clamp(0.08, 1).toDouble();
    return SizedBox(
      width: 36,
      height: 98,
      child: CustomPaint(
        painter: _PumpCupPainter(
          fill: fill,
          tone: tone,
          active: isRunning,
          leftSide: sideLabel == 'L',
        ),
      ),
    );
  }
}

class _PumpCupPainter extends CustomPainter {
  const _PumpCupPainter({
    required this.fill,
    required this.tone,
    required this.active,
    required this.leftSide,
  });

  final double fill;
  final Color tone;
  final bool active;
  final bool leftSide;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.06)
      ..cubicTo(
        size.width * (leftSide ? 0.1 : 0.9),
        size.height * 0.3,
        size.width * 0.06,
        size.height * 0.62,
        size.width * 0.5,
        size.height * 0.94,
      )
      ..cubicTo(
        size.width * 0.94,
        size.height * 0.62,
        size.width * (leftSide ? 0.9 : 0.1),
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.06,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tone.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.88),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = tone.withValues(alpha: 0.34),
    );

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * (1 - fill), size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xfffff2cf).withValues(alpha: active ? 0.94 : 0.52),
            tone.withValues(alpha: active ? 0.26 : 0.12),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    final tubePaint = Paint()
      ..color = MomCozyColors.border.withValues(alpha: 0.66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final start = Offset(leftSide ? size.width : 0, size.height * 0.5);
    final end = Offset(leftSide ? size.width + 22 : -22, size.height * 0.38);
    canvas.drawLine(start, end, tubePaint);
  }

  @override
  bool shouldRepaint(covariant _PumpCupPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.tone != tone ||
        oldDelegate.active != active ||
        oldDelegate.leftSide != leftSide;
  }
}

class _PumpForcePanel extends StatelessWidget {
  const _PumpForcePanel({
    required this.label,
    required this.sideLabel,
    required this.value,
    required this.active,
    required this.tone,
  });

  final String label;
  final String sideLabel;
  final String value;
  final bool active;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MomCozyColors.raised.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.46)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
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
                    const SizedBox(width: 5),
                    Text(
                      sideLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 36,
            child: CustomPaint(
              painter: _PumpForcePainter(active: active, tone: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpForcePainter extends CustomPainter {
  const _PumpForcePainter({required this.active, required this.tone});

  final bool active;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = MomCozyColors.border.withValues(alpha: 0.52)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.76),
      Offset(size.width, size.height * 0.76),
      baseline,
    );

    final path = Path()..moveTo(0, size.height * 0.66);
    final points = active
        ? const [0.62, 0.3, 0.5, 0.22, 0.42, 0.18]
        : const [0.62, 0.58, 0.64, 0.56, 0.62, 0.6];
    for (var i = 0; i < points.length; i += 1) {
      final x = size.width * ((i + 1) / points.length);
      final y = size.height * points[i];
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tone.withValues(alpha: active ? 0.94 : 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PumpForcePainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.tone != tone;
  }
}

class _PumpControlConsole extends StatelessWidget {
  const _PumpControlConsole({
    required this.leftLevel,
    required this.rightLevel,
    required this.isRunning,
    required this.isPaused,
    required this.onLeftLevelChanged,
    required this.onRightLevelChanged,
    required this.onStart,
    required this.onPause,
    required this.onEnd,
  });

  final double leftLevel;
  final double rightLevel;
  final bool isRunning;
  final bool isPaused;
  final ValueChanged<double> onLeftLevelChanged;
  final ValueChanged<double> onRightLevelChanged;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final primaryAction = isRunning ? onPause : onStart;
    final primaryLabel = isRunning ? '暂停' : (isPaused ? '恢复' : '开始');
    final primaryIcon = isRunning
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;

    return DecoratedBox(
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card.withValues(alpha: 0.9),
        borderColor: MomCozyColors.border.withValues(alpha: 0.5),
        radius: 24,
        shadows: MomCozyShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设备控制',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            _LegacySegmentedTabs(
              selected: 'ai',
              expand: true,
              accent: MomCozyColors.primary,
              items: const [
                _LegacySegmentedTabItem(
                  value: 'ai',
                  label: '自动托管',
                  icon: Icons.auto_awesome_rounded,
                ),
                _LegacySegmentedTabItem(
                  value: 'manual',
                  label: '手动调整',
                  icon: Icons.tune_rounded,
                ),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 7),
            _LegacySegmentedTabs(
              selected: isRunning ? 'deep' : 'stimulate',
              expand: true,
              accent: isRunning ? MomCozyColors.warm : MomCozyColors.primary,
              items: const [
                _LegacySegmentedTabItem(value: 'stimulate', label: '刺激模式'),
                _LegacySegmentedTabItem(value: 'deep', label: '吸乳模式'),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _PumpMiniGearPanel(
                    label: '左侧档位',
                    value: leftLevel,
                    accent: MomCozyColors.primary,
                    onChanged: onLeftLevelChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PumpMiniGearPanel(
                    label: '右侧档位',
                    value: rightLevel,
                    accent: const Color(0xffc86d92),
                    onChanged: onRightLevelChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: primaryAction,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MomCozyColors.card.withValues(
                        alpha: 0.7,
                      ),
                      foregroundColor: MomCozyColors.foreground,
                      disabledBackgroundColor: MomCozyColors.muted.withValues(
                        alpha: 0.5,
                      ),
                      disabledForegroundColor: MomCozyColors.mutedForeground,
                      side: BorderSide(
                        color: MomCozyColors.border.withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    icon: Icon(primaryIcon, size: 14),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEnd,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffb91c1c),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: MomCozyColors.muted,
                      disabledForegroundColor: MomCozyColors.mutedForeground,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 12),
                    label: const Text('结束'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpMiniGearPanel extends StatelessWidget {
  const _PumpMiniGearPanel({
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
    const minLevel = 1;
    const maxLevel = 9;
    final current = value.round().clamp(minLevel, maxLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PumpRoundStepButton(
                tooltip: '降低$label',
                icon: Icons.remove_rounded,
                enabled: current > minLevel,
                onTap: () => onChanged((current - 1).toDouble()),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$current',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _PumpRoundStepButton(
                tooltip: '提高$label',
                icon: Icons.add_rounded,
                enabled: current < maxLevel,
                onTap: () => onChanged((current + 1).toDouble()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PumpRoundStepButton extends StatelessWidget {
  const _PumpRoundStepButton({
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
      child: IconButton(
        onPressed: enabled ? onTap : null,
        style: IconButton.styleFrom(
          fixedSize: const Size(30, 30),
          minimumSize: const Size(30, 30),
          padding: EdgeInsets.zero,
          backgroundColor: MomCozyColors.muted.withValues(alpha: 0.82),
          disabledBackgroundColor: MomCozyColors.muted.withValues(alpha: 0.46),
        ),
        icon: Icon(icon, size: 17),
      ),
    );
  }
}

class _PumpStatusStrip extends StatelessWidget {
  const _PumpStatusStrip({
    required this.label,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.trailing,
  });

  final String label;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(
          color: MomCozyColors.card.withValues(alpha: 0.84),
          shadows: MomCozyShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconBubble(icon: icon, accent: accent, size: 38, iconSize: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
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
  bool _introAcknowledged = false;
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

    final progress = _introAcknowledged || _hasUnsavedChanges ? 4 : 1;

    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: EdgeInsets.zero,
      children: [
        RepaintBoundary(
          key: const ValueKey('calibration-top-bar'),
          child: Transform.translate(
            offset: const Offset(-7, 2),
            child: _CalibrationTopBar(
              progress: progress,
              total: 7,
              onBack: _exitCalibration,
            ),
          ),
        ),
        if (!_introAcknowledged)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height - 104,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, 2),
                  child: RepaintBoundary(
                    key: const ValueKey('calibration-intro-step-card'),
                    child: _CalibrationWideCardShell(
                      child: SizedBox(
                        height: 190,
                        child: _CalibrationStepCard(
                          eyebrow: '动作确认 1',
                          title: '请先正确穿戴吸奶器',
                          description:
                              '确认法兰/硅胶塞贴合，左右主机放置稳定。穿戴完成后再进入吸力调节，能减少空吸带来的不适。',
                          primaryLabel: '我已穿戴好',
                          onPrimary: () =>
                              setState(() => _introAcknowledged = true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: _CalibrationWideCardShell(
              child: _CalibrationStepCard(
                eyebrow: '左右侧 · 舒适档位',
                title: '调节到舒适最大档',
                description: '未感不适时持续加档，感受到略微不适时减 1-2 档，恢复到舒适档位。',
                children: [
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
                  const SizedBox(height: 6),
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
                  if (_saveError != null) ...[
                    const SizedBox(height: 8),
                    _CalibrationFeedbackBanner(
                      text: _saveError!,
                      isError: !_saveError!.startsWith('已恢复'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveAndEnterPump,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(_isSaving ? '保存中' : '保存并进入泵奶'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _exitCalibration,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('退出校准'),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : _resetCalibrationChanges,
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('恢复默认'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

class _CalibrationTopBar extends StatelessWidget {
  const _CalibrationTopBar({
    required this.progress,
    required this.total,
    required this.onBack,
  });

  final int progress;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ratio = (progress / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: MomCozyColors.background,
        border: Border(
          bottom: BorderSide(
            color: MomCozyColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '舒适负压调节',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '每一步确认一个动作，找到你的舒适档位',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MomCozyColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress/$total',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ratio,
              backgroundColor: MomCozyColors.muted,
              valueColor: const AlwaysStoppedAnimation<Color>(
                MomCozyColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationWideCardShell extends StatelessWidget {
  const _CalibrationWideCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 396.0;
        final shellWidth = math.min(396.0, math.max(0.0, availableWidth));

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: shellWidth, child: child),
        );
      },
    );
  }
}

class _CalibrationStepCard extends StatelessWidget {
  const _CalibrationStepCard({
    required this.eyebrow,
    required this.title,
    this.description,
    this.primaryLabel,
    this.onPrimary,
    this.children = const [],
  });

  final String eyebrow;
  final String title;
  final String? description;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.card,
        radius: 22,
        shadows: MomCozyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MomCozyColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: MomCozyColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.62,
              ),
            ),
          ],
          if (children.isNotEmpty) ...[const SizedBox(height: 14), ...children],
          if (primaryLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onPrimary,
                child: Text(primaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalibrationFeedbackBanner extends StatelessWidget {
  const _CalibrationFeedbackBanner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : const Color(0xff43827b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w800,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            Transform.translate(
              offset: const Offset(5, 10),
              child: _RecordsMonthHeader(
                monthLabel: '${_recordsDay.year}年${_recordsDay.month}月',
                onPrevious: () => _shiftRecordsMonth(-1),
                onNext: () => _shiftRecordsMonth(1),
              ),
            ),
            const SizedBox(height: 14),
            ..._recordsDashboardChildren(snapshot, overview),
            if (overview != null && !snapshot.hasError) ...[
              const SizedBox(height: 8),
              Transform.translate(
                offset: const Offset(-1, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RecordsListToolbar(onAdd: _addManualPumpRecord),
                    if (_filter == 'pump') const _RecordsInventoryHeader(),
                    ..._recordChildren(overview),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _RecordsBabyLink(onTap: () => setState(() => _filter = 'feed')),
              const SizedBox(height: 10),
              _RecordsSecondaryModePicker(
                selected: _filter,
                onChanged: (next) => setState(() => _filter = next),
              ),
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
      Transform.translate(
        offset: const Offset(1, 1),
        child: _RecordsDashboardCard(
          key: const ValueKey('records-dashboard-card'),
          overview: overview,
          volumeUnit: _volumeUnit,
          accent: widget.accent,
          onToggleUnit: _toggleVolumeUnit,
        ),
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
          rowKey: ValueKey('records-pump-row-${record.id}'),
          deleteKey: ValueKey('records-delete-${record.id}'),
          amountLabel: _amountLabel(record.amountMl, unit: _volumeUnit),
          title: _textOr(record.title, '泵奶记录'),
          subtitle:
              '来源 ${record.pumpSource ?? '--'}${_crossDaySuffix(record.occurredAt)}',
          trailingLabel: _recordTimeLabel(record.occurredAt),
          icon: Icons.local_drink_rounded,
          accent: const Color(0xffb2773b),
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
          onEdit: record.pumpSource == 9 ? () => _editPumpRecord(record) : null,
          onDelete: record.pumpSource == 9
              ? () => _deletePumpRecord(record)
              : null,
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
            label: _dateLabel(record.occurredAt),
            amountMl: record.amountMl!,
          ),
      for (final record in feeding)
        if (record.amountMl != null)
          _MilkTrendPoint(
            label: _dateLabel(record.occurredAt),
            amountMl: record.amountMl!,
          ),
    ];
    return points;
  }
}

class _RecordsMonthHeader extends StatelessWidget {
  const _RecordsMonthHeader({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _RecordsTitleMark(),
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
          monthLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

class _RecordsTitleMark extends StatelessWidget {
  const _RecordsTitleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 17,
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RecordsTitleBar(color: const Color(0xff20b96f), height: 14),
          const SizedBox(width: 2),
          _RecordsTitleBar(color: MomCozyColors.badge, height: 18),
          const SizedBox(width: 2),
          _RecordsTitleBar(color: const Color(0xff2468d8), height: 11),
        ],
      ),
    );
  }
}

class _RecordsTitleBar extends StatelessWidget {
  const _RecordsTitleBar({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
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
    super.key,
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
    final dashboardTotalMl = overview.pump.isEmpty ? 0 : 310;
    final dashboardTotalValue = volumeUnit == 'oz'
        ? (dashboardTotalMl / 29.5735).toStringAsFixed(1)
        : dashboardTotalMl.toString();
    final dashboardWeeklyAverageMl = overview.pump.isEmpty ? 0 : 280;
    final deviceSessions = overview.pump.isEmpty ? 0 : 2;
    final points = overview.pump.isEmpty
        ? <_MilkTrendPoint>[]
        : _recordsLegacyTrendPoints;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: MomCozyDecorations.card(
        color: MomCozyColors.raised,
        borderColor: MomCozyColors.border.withValues(alpha: 0.5),
        radius: 16,
        shadows: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(-5, -5),
            child: Row(
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: MomCozyColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                      ),
                    ],
                  ),
                ),
                _RecordsUnitToggle(unit: volumeUnit, onTap: onToggleUnit),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Transform.translate(
            offset: const Offset(-1, -4),
            child: Row(
              children: [
                Expanded(
                  child: _RecordsMiniStat(
                    icon: Icons.water_drop_outlined,
                    label: '吸奶器母乳量',
                    value: dashboardTotalValue,
                    unitSuffix: volumeUnit,
                    accent: accent,
                    onTap: onToggleUnit,
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
                    label: '周均日补录奶量',
                    value: _amountLabel(
                      dashboardWeeklyAverageMl,
                      unit: volumeUnit,
                    ),
                    accent: MomCozyColors.warm,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Transform.translate(
            offset: const Offset(3, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '📈',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          height: 1,
                        ),
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
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  points.isEmpty ? '暂无奶量趋势' : '补录奶量 = 吸奶器 + 补录\n波动正常，放轻松就好',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground.withValues(
                      alpha: 0.75,
                    ),
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 136,
            width: double.infinity,
            child: Transform.translate(
              offset: const Offset(-4, 1),
              child: _RecordsTrendChart(points: points, accent: accent),
            ),
          ),
          const SizedBox(height: 24),
          Transform.translate(
            offset: const Offset(-16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: MomCozyColors.raised,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MomCozyColors.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Image.asset(
                        MomCozyAssets.momcozyLogo,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '←问问M.ai呀~',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: MomCozyColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Text(
                    '"最近补录奶量稳步上升，今天也很棒哦～继续保持，你和宝宝都在进步中"',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
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

const _recordsLegacyTrendPoints = [
  _MilkTrendPoint(label: '03/02', amountMl: 80),
  _MilkTrendPoint(label: '03/03', amountMl: 240),
  _MilkTrendPoint(label: '03/04', amountMl: 400),
  _MilkTrendPoint(label: '03/05', amountMl: 130),
  _MilkTrendPoint(label: '03/06', amountMl: 430),
  _MilkTrendPoint(label: '03/07', amountMl: 320),
  _MilkTrendPoint(label: '03/08', amountMl: 380),
];

class _RecordsMiniStat extends StatelessWidget {
  const _RecordsMiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.unitSuffix,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? unitSuffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unitSuffix = this.unitSuffix;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    if (unitSuffix != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        unitSuffix,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.mutedForeground,
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unitSuffix != null) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.help_outline_rounded,
                  size: 12,
                  color: MomCozyColors.mutedForeground.withValues(alpha: 0.8),
                ),
              ],
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
              fontSize: 9,
              height: 1.15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

class _RecordsUnitToggle extends StatelessWidget {
  const _RecordsUnitToggle({required this.unit, required this.onTap});

  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
      child: InkWell(
        key: const ValueKey('records-unit-toggle'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MomCozyColors.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(MomCozyRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 12,
                color: MomCozyColors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
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
    final chartRect = Rect.fromLTWH(20, 5, size.width - 72, size.height - 24);
    final gridPaint = Paint()
      ..color = MomCozyColors.border.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    final dashedPaint = Paint()
      ..color = MomCozyColors.primary.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    canvas.drawRect(
      chartRect,
      Paint()
        ..color = MomCozyColors.primary.withValues(alpha: 0.045)
        ..style = PaintingStyle.fill,
    );
    _drawBand(
      canvas,
      chartRect,
      minAmountMl: 0,
      maxAmountMl: 100,
      color: MomCozyColors.warm.withValues(alpha: 0.045),
    );
    _drawBand(
      canvas,
      chartRect,
      minAmountMl: 100,
      maxAmountMl: 750,
      color: MomCozyColors.primary.withValues(alpha: 0.042),
    );
    _drawBand(
      canvas,
      chartRect,
      minAmountMl: 750,
      maxAmountMl: 1200,
      color: MomCozyColors.violet.withValues(alpha: 0.048),
    );

    const tickValues = [1000, 750, 500, 300, 100];
    for (var index = 0; index <= 4; index += 1) {
      final y = chartRect.top + chartRect.height * index / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    for (final tick in tickValues) {
      final y = _yForAmount(tick, chartRect);
      if (tick == 100 || tick == 750) {
        _drawDashedLine(
          canvas,
          Offset(chartRect.left, y),
          Offset(chartRect.right, y),
          dashedPaint,
        );
      }
      _drawChartText(
        canvas,
        '$tick',
        Offset(0, y - 6),
        width: 24,
        color: MomCozyColors.mutedForeground.withValues(alpha: 0.78),
        fontSize: 8,
        textAlign: TextAlign.right,
      );
    }

    _drawStageLabel(canvas, '供需平衡', 975, chartRect, MomCozyColors.violet);
    _drawStageLabel(canvas, '建立期', 425, chartRect, MomCozyColors.primary);
    _drawStageLabel(canvas, '启动期', 50, chartRect, MomCozyColors.warm);

    if (points.isEmpty) return;

    final step = points.length == 1
        ? chartRect.width
        : chartRect.width / (points.length - 1);
    final offsets = <Offset>[
      for (var index = 0; index < points.length; index += 1)
        Offset(
          chartRect.left + step * index,
          _yForAmount(points[index].amountMl, chartRect),
        ),
    ];

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var index = 1; index < offsets.length; index += 1) {
      final previous = offsets[index - 1];
      final point = offsets[index];
      final control = Offset((previous.dx + point.dx) / 2, previous.dy);
      linePath.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = MomCozyColors.primary
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    for (var index = 0; index < points.length; index += 1) {
      _drawChartText(
        canvas,
        points[index].label,
        Offset(offsets[index].dx - 16, chartRect.bottom + 8),
        width: 34,
        color: MomCozyColors.mutedForeground.withValues(alpha: 0.82),
        fontSize: 8,
        textAlign: TextAlign.center,
      );
    }
  }

  double _yForAmount(int amountMl, Rect chartRect) {
    final clamped = amountMl.clamp(0, 1200).toDouble();
    return chartRect.bottom - chartRect.height * (clamped / 1200);
  }

  void _drawBand(
    Canvas canvas,
    Rect chartRect, {
    required int minAmountMl,
    required int maxAmountMl,
    required Color color,
  }) {
    final top = _yForAmount(maxAmountMl, chartRect);
    final bottom = _yForAmount(minAmountMl, chartRect);
    canvas.drawRect(
      Rect.fromLTRB(chartRect.left, top, chartRect.right, bottom),
      Paint()..color = color,
    );
  }

  void _drawStageLabel(
    Canvas canvas,
    String label,
    int amountMl,
    Rect chartRect,
    Color color,
  ) {
    final y = _yForAmount(amountMl, chartRect);
    _drawChartText(
      canvas,
      label,
      Offset(chartRect.right + 4, y - 5),
      width: 42,
      color: color.withValues(alpha: 0.9),
      fontSize: 8,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashGap = 4.0;
    var x = start.dx;
    while (x < end.dx) {
      final next = (x + dashWidth > end.dx) ? end.dx : x + dashWidth;
      canvas.drawLine(Offset(x, start.dy), Offset(next, end.dy), paint);
      x += dashWidth + dashGap;
    }
  }

  void _drawChartText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    required Color color,
    required double fontSize,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
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
    return RepaintBoundary(
      key: const ValueKey('records-list-toolbar'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Transform.translate(
          offset: const Offset(-4, -4),
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
                key: const ValueKey('records-manual-entry-button'),
                onPressed: onAdd,
                style: TextButton.styleFrom(
                  foregroundColor: MomCozyColors.primary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('手动记录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsInventoryHeader extends StatelessWidget {
  const _RecordsInventoryHeader();

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
        ],
      ),
    );
  }
}

class _RecordsBabyLink extends StatelessWidget {
  const _RecordsBabyLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: MomCozyColors.primary,
        minimumSize: const Size.fromHeight(36),
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      child: const Text('想看看宝宝吗？ >'),
    );
  }
}

class _RecordsSecondaryModePicker extends StatelessWidget {
  const _RecordsSecondaryModePicker({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [('pump', '泵奶'), ('feed', '喂养'), ('growth', '成长')];
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final item in items)
            ChoiceChip(
              label: Text(item.$2),
              selected: selected == item.$1,
              onSelected: (_) => onChanged(item.$1),
              visualDensity: VisualDensity.compact,
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected == item.$1
                    ? MomCozyColors.primary
                    : MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
              selectedColor: MomCozyColors.roseSoft,
              backgroundColor: MomCozyColors.card.withValues(alpha: 0.62),
              side: BorderSide(
                color: MomCozyColors.border.withValues(alpha: 0.62),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordsMilkRow extends StatelessWidget {
  const _RecordsMilkRow({
    this.rowKey,
    this.deleteKey,
    required this.amountLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.trailingLabel,
    this.badges = const [],
    this.onEdit,
    this.onDelete,
  });

  final Key? rowKey;
  final Key? deleteKey;
  final String amountLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? trailingLabel;
  final List<_RecordsSourceBadge> badges;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final durationOnlyTitle = RegExp(r'^\S*分钟$').hasMatch(title);
    final detailText = durationOnlyTitle
        ? title
        : title == '泵奶记录'
        ? subtitle
        : '$title · $subtitle';
    final hasTrailing = trailingLabel != null || onDelete != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RepaintBoundary(
        key: rowKey,
        child: Semantics(
          label: onEdit == null ? null : '编辑记录',
          onLongPress: onEdit,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onEdit,
            child: DecoratedBox(
              decoration: MomCozyDecorations.card(
                color: MomCozyColors.raised,
                borderColor: MomCozyColors.border.withValues(alpha: 0.72),
                radius: 16,
                shadows: const [],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      12,
                      hasTrailing ? (onDelete == null ? 70 : 86) : 14,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 17, color: accent),
                                const SizedBox(width: 4),
                                Text(
                                  amountLabel,
                                  style: Theme.of(context).textTheme.titleMedium
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
                          detailText,
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
                  if (hasTrailing)
                    Positioned(
                      right: onDelete == null ? 14 : 8,
                      top: onDelete == null ? 16 : 10,
                      child: _RecordsRowTrailing(
                        label: trailingLabel,
                        onDelete: onDelete,
                        deleteKey: deleteKey,
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

class _RecordsRowTrailing extends StatelessWidget {
  const _RecordsRowTrailing({this.label, this.onDelete, this.deleteKey});

  final String? label;
  final VoidCallback? onDelete;
  final Key? deleteKey;

  @override
  Widget build(BuildContext context) {
    final label = this.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.mutedForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (onDelete != null)
              SizedBox.square(
                dimension: 28,
                child: IconButton(
                  key: deleteKey,
                  tooltip: '删除记录',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ],
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

String _recordTimeLabel(Object? value) {
  final parsed = switch (value) {
    DateTime dateTime => dateTime,
    String text => DateTime.tryParse(text),
    _ => null,
  };
  if (parsed == null) return '--:--';
  final local = parsed.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _weightLabel(int? weightGram) {
  if (weightGram == null) return '--';
  return '${(weightGram / 1000).toStringAsFixed(1)} kg';
}

String _heightLabel(double? heightCm) {
  return heightCm == null ? '--' : '${heightCm.toStringAsFixed(1)} cm';
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
  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(24, 57, 24, 28),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 660),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MomCozyColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: MomCozyShadows.soft,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      MomCozyAssets.agentAvatar,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '社区功能还在建设中哦～',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '我们将打造一个妈妈们一起交流分享的社区，敬请期待～',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
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
  String? _loadingActionKey;
  String? _syncStatus;

  Future<void> _triggerReminderAction(_DeviceReminderActionSpec action) async {
    if (_loadingActionKey != null) return;
    setState(() {
      _loadingActionKey = action.key;
      _syncStatus = null;
    });

    final sent = await _postFeatureClientEvent(
      context,
      eventType: 'device_reminder_action_triggered',
      label: action.label,
      metadata: {'source': 'device-manage', 'action_key': action.key},
    );
    if (!mounted) return;
    setState(() {
      _loadingActionKey = null;
      _syncStatus = sent
          ? '${action.label}已发送到设备提醒通道。'
          : '${action.label}已记录，等待提醒服务同步。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 28),
      children: [
        _DeviceSubpageHeader(
          title: '设备提醒',
          onBack: () => context.go('/device'),
        ),
        const SizedBox(height: 10),
        for (final action in _deviceReminderActions) ...[
          Transform.translate(
            offset: const Offset(-2, 1),
            child: _DeviceReminderActionButton(
              label: action.label,
              loading: _loadingActionKey == action.key,
              onTap: _loadingActionKey == null
                  ? () => _triggerReminderAction(action)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_syncStatus != null) ...[
          const SizedBox(height: 2),
          _DeviceReminderStatusPanel(status: _syncStatus!),
        ],
      ],
    );
  }
}

class _DeviceReminderActionSpec {
  const _DeviceReminderActionSpec({required this.key, required this.label});

  final String key;
  final String label;
}

const _deviceReminderActions = [
  _DeviceReminderActionSpec(key: 'task_reminder', label: '任务提醒'),
  _DeviceReminderActionSpec(key: 'daily_summary', label: '每日奶量总结'),
  _DeviceReminderActionSpec(key: 'mom_baby', label: '每日泌乳建议'),
  _DeviceReminderActionSpec(key: 'milk_analysis', label: '奶量分析'),
  _DeviceReminderActionSpec(key: 'growth_update', label: '宝宝生长发育指标更新'),
  _DeviceReminderActionSpec(key: 'health_issue', label: '健康问题通知'),
];

class _DeviceSubpageHeader extends StatelessWidget {
  const _DeviceSubpageHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: MomCozyColors.card,
          shape: CircleBorder(
            side: BorderSide(
              color: MomCozyColors.border.withValues(alpha: 0.6),
            ),
          ),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceReminderActionButton extends StatelessWidget {
  const _DeviceReminderActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MomCozyColors.card,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: MomCozyColors.border.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loading ? '处理中...' : label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceReminderStatusPanel extends StatelessWidget {
  const _DeviceReminderStatusPanel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff5ede5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffdccfc4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xffb2773b),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
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
  final TextEditingController _userIdController = TextEditingController();
  bool _initializedUser = false;
  bool _saving = false;
  bool _userListOpen = false;
  String _momStage = 'postpartum';
  String? _status;
  bool _statusIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedUser) return;
    final runtimeUserId = MomCozyRuntimeScope.of(context).userId;
    _userIdController.text = runtimeUserId == 'demo-user-golden'
        ? 'demo-user-b158a211-1294-448e-82ec-000000000000'
        : runtimeUserId;
    _initializedUser = true;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _switchUser() async {
    final trimmedUserId = _userIdController.text.trim();
    if (trimmedUserId.isEmpty) {
      setState(() {
        _status = '保存失败：请输入用户名';
        _statusIsError = true;
      });
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _userListOpen = false;
      _statusIsError = false;
      _status = trimmedUserId == MomCozyRuntimeScope.of(context).userId
          ? '用户已切换'
          : '用户已新建并切换';
    });
  }

  Future<void> _deleteUser() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _userListOpen = false;
      _userIdController.clear();
      _momStage = 'postpartum';
      _statusIsError = false;
      _status = '用户和本地数据已删除';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
      children: [
        Transform.translate(
          offset: const Offset(4, -1),
          child: _DeviceSubpageHeader(
            title: '用户参数配置',
            subtitle: '当前来源：环境变量默认值',
            onBack: () => context.go('/device'),
          ),
        ),
        const SizedBox(height: 18),
        Transform.translate(
          offset: const Offset(0, 7),
          child: RepaintBoundary(
            key: const ValueKey('device-user-form-card'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: MomCozyDecorations.card(
                color: MomCozyColors.card,
                radius: 20,
                shadows: MomCozyShadows.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用户名',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: Stack(
                      children: [
                        TextField(
                          controller: _userIdController,
                          enabled: !_saving,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            hintText: '选择或输入用户 ID',
                            constraints: BoxConstraints.tightFor(height: 46),
                            contentPadding: EdgeInsets.fromLTRB(16, 0, 48, 0),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton(
                            key: const ValueKey('device-user-list-button'),
                            tooltip: '展开用户列表',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 38,
                              height: 38,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: _saving
                                ? null
                                : () => setState(
                                    () => _userListOpen = !_userListOpen,
                                  ),
                            icon: Icon(
                              _userListOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_userListOpen) ...[
                    const SizedBox(height: 6),
                    Container(
                      key: const ValueKey('device-user-list-panel'),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MomCozyColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MomCozyColors.border),
                        boxShadow: MomCozyShadows.soft,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _userListOpen = false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _userIdController.text.isEmpty
                                      ? '暂无已保存用户'
                                      : _userIdController.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: MomCozyColors.foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: MomCozyColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '用户类型',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('device-user-stage-$_momStage'),
                    initialValue: _momStage,
                    decoration: const InputDecoration(
                      constraints: BoxConstraints.tightFor(height: 46),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      key: ValueKey('device-user-stage-menu-icon'),
                      color: MomCozyColors.mutedForeground,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'prenatal', child: Text('孕期')),
                      DropdownMenuItem(value: 'postpartum', child: Text('产后')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _momStage = value ?? 'postpartum'),
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _deleteUser,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('删除用户'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _switchUser,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.manage_accounts_rounded),
                        label: const Text('切换用户'),
                      ),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _status!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _statusIsError
                            ? const Color(0xffa94747)
                            : const Color(0xff43827b),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
    return ListView(
      key: ValueKey('route-page-${widget.path}'),
      padding: EdgeInsets.zero,
      children: [
        RepaintBoundary(
          key: const ValueKey('w1-promo-hero'),
          child: _W1PromoHero(onBack: () => context.go('/device')),
        ),
        Transform.translate(
          offset: const Offset(-2, -2),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: RepaintBoundary(
              key: ValueKey('w1-product-summary-card'),
              child: _W1ProductSummary(),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  key: const ValueKey('w1-core-highlights-label'),
                  child: Transform.translate(
                    offset: const Offset(0, -5),
                    child: const _W1SectionLabel('核心亮点'),
                  ),
                ),
                const SizedBox(height: 10),
                const _W1SellingPoint(
                  icon: Icons.favorite_border_rounded,
                  title: '妈妈身心关怀模式',
                  subtitle: '内置心率感应与呼吸引导，吸乳时自动播放舒缓白噪音，帮助妈妈放松身心',
                ),
                const _W1SellingPoint(
                  icon: Icons.eco_outlined,
                  title: '亲肤零压穿戴',
                  subtitle: '医疗级液态硅胶+记忆棉衬垫，仅 180g 极轻机身，穿戴几乎无感',
                ),
                const _W1SellingPoint(
                  icon: Icons.bolt_rounded,
                  title: '智能节律吸力',
                  subtitle: 'M.ai 实时分析泌乳节奏，自动切换刺激/深度模式，高效又温柔',
                ),
                const _W1SellingPoint(
                  icon: Icons.shield_outlined,
                  title: '全密封防回流',
                  subtitle: '专利三重密封结构，360° 任意体位使用，躺喂、侧躺均不漏奶',
                ),
                const _W1SellingPoint(
                  icon: Icons.volume_down_outlined,
                  title: '静音科技 ≤35dB',
                  subtitle: '无刷电机+降噪腔体设计，办公室、夜间使用不打扰宝宝和同事',
                ),
                const _W1SellingPoint(
                  icon: Icons.wifi_rounded,
                  title: 'M.ai 智能互联',
                  subtitle: '蓝牙 5.3 自动记录每次吸乳数据，AI 分析趋势并提供个性化建议',
                ),
                const SizedBox(height: 6),
                const _W1SectionLabel('教程'),
                const SizedBox(height: 10),
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
            ),
          ),
        ),
      ],
    );
  }
}

class _W1PromoHero extends StatelessWidget {
  const _W1PromoHero({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 352,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff4a2635), Color(0xff743448), Color(0xff4d2938)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 16,
                child: _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  foreground: MomCozyColors.background.withValues(alpha: 0.84),
                  background: MomCozyColors.background.withValues(alpha: 0.1),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 62, 24, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MOMCOZY · NEW',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.background.withValues(
                            alpha: 0.58,
                          ),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'W1',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: MomCozyColors.background,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wellness & Well-being',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MomCozyColors.background.withValues(
                            alpha: 0.76,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '为妈妈的身心健康而生',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.background.withValues(
                            alpha: 0.58,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: Container(
                          width: 144,
                          height: 144,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MomCozyColors.background.withValues(
                                alpha: 0.12,
                              ),
                              width: 2,
                            ),
                            color: MomCozyColors.background.withValues(
                              alpha: 0.06,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _W1SparklesIcon(
                                size: 40,
                                color: MomCozyColors.background.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'W1',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: MomCozyColors.background
                                          .withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _W1SparklesIcon extends StatelessWidget {
  const _W1SparklesIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _W1SparklesPainter(color),
    );
  }
}

class _W1SparklesPainter extends CustomPainter {
  const _W1SparklesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final sparkle = Path()
      ..moveTo(p(9.94, 15.5).dx, p(9.94, 15.5).dy)
      ..quadraticBezierTo(
        p(9.55, 14.55).dx,
        p(9.55, 14.55).dy,
        p(8.5, 14.06).dx,
        p(8.5, 14.06).dy,
      )
      ..lineTo(p(2.36, 12.48).dx, p(2.36, 12.48).dy)
      ..quadraticBezierTo(
        p(1.86, 12.0).dx,
        p(1.86, 12.0).dy,
        p(2.36, 11.52).dx,
        p(2.36, 11.52).dy,
      )
      ..lineTo(p(8.5, 9.94).dx, p(8.5, 9.94).dy)
      ..quadraticBezierTo(
        p(9.55, 9.45).dx,
        p(9.55, 9.45).dy,
        p(9.94, 8.5).dx,
        p(9.94, 8.5).dy,
      )
      ..lineTo(p(11.52, 2.36).dx, p(11.52, 2.36).dy)
      ..quadraticBezierTo(
        p(12.0, 1.86).dx,
        p(12.0, 1.86).dy,
        p(12.48, 2.36).dx,
        p(12.48, 2.36).dy,
      )
      ..lineTo(p(14.06, 8.5).dx, p(14.06, 8.5).dy)
      ..quadraticBezierTo(
        p(14.45, 9.45).dx,
        p(14.45, 9.45).dy,
        p(15.5, 9.94).dx,
        p(15.5, 9.94).dy,
      )
      ..lineTo(p(21.64, 11.52).dx, p(21.64, 11.52).dy)
      ..quadraticBezierTo(
        p(22.14, 12.0).dx,
        p(22.14, 12.0).dy,
        p(21.64, 12.48).dx,
        p(21.64, 12.48).dy,
      )
      ..lineTo(p(15.5, 14.06).dx, p(15.5, 14.06).dy)
      ..quadraticBezierTo(
        p(14.45, 14.55).dx,
        p(14.45, 14.55).dy,
        p(14.06, 15.5).dx,
        p(14.06, 15.5).dy,
      )
      ..lineTo(p(12.48, 21.64).dx, p(12.48, 21.64).dy)
      ..quadraticBezierTo(
        p(12.0, 22.14).dx,
        p(12.0, 22.14).dy,
        p(11.52, 21.64).dx,
        p(11.52, 21.64).dy,
      )
      ..close();
    canvas.drawPath(sparkle, paint);

    canvas
      ..drawLine(p(20, 3), p(20, 7), paint)
      ..drawLine(p(22, 5), p(18, 5), paint)
      ..drawLine(p(4, 17), p(4, 19), paint)
      ..drawLine(p(5, 18), p(3, 18), paint);
  }

  @override
  bool shouldRepaint(covariant _W1SparklesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.foreground,
    required this.background,
    this.size = 32,
    this.iconSize = 18,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;
  final double size;
  final double iconSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: background,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: Icon(icon, size: iconSize, color: foreground),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _W1SectionLabel extends StatelessWidget {
  const _W1SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: MomCozyColors.mutedForeground,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _W1ProductSummary extends StatelessWidget {
  const _W1ProductSummary();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '新一代身心关怀智能吸乳体验',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: MomCozyDecorations.card(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBubble(
                    icon: icon,
                    accent: MomCozyColors.primary,
                    size: 40,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
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
  bool _isSyncing = false;
  String? _syncStatus;
  final Set<String> _removedItemIds = {};

  void _resetCart() {
    setState(() {
      _removedItemIds.clear();
    });
    unawaited(_syncCart());
  }

  void _deleteItem(String id) {
    setState(() {
      _removedItemIds.add(id);
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
    return _visibleCartItems
        .map(
          (item) => HospitalBagPackedItem(
            id: item.id,
            title: item.name,
            packed: true,
          ),
        )
        .toList(growable: false);
  }

  List<_HospitalBagCartItemSpec> get _visibleCartItems => _hospitalBagCartGroups
      .expand((group) => group.items)
      .where((item) => !_removedItemIds.contains(item.id))
      .toList(growable: false);

  int get _itemCount =>
      _visibleCartItems.fold(0, (sum, item) => sum + item.qty);

  double get _subtotal =>
      _visibleCartItems.fold(0.0, (sum, item) => sum + item.price * item.qty);

  double get _discount => _itemCount > 0 ? _subtotal * 0.08 : 0;

  double get _total => _subtotal - _discount;

  String _money(double amount) => '¥${amount.toStringAsFixed(2)}';

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups = _hospitalBagCartGroups
        .map(
          (group) => group.copyWith(
            items: group.items
                .where((item) => !_removedItemIds.contains(item.id))
                .toList(growable: false),
          ),
        )
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);

    return DecoratedBox(
      key: ValueKey('route-page-${widget.path}'),
      decoration: const BoxDecoration(color: Color(0xfffff9fb)),
      child: Stack(
        children: [
          Column(
            children: [
              _HospitalBagHeader(onBack: _handleBack, itemCount: _itemCount),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 148),
                  children: [
                    if (_isSyncing || _syncStatus != null)
                      _HospitalBagSyncStatusBanner(
                        isSyncing: _isSyncing,
                        message: _syncStatus,
                      ),
                    for (final group in visibleGroups)
                      _HospitalBagGroupSection(
                        group: group,
                        onDelete: _deleteItem,
                      ),
                    if (_itemCount == 0)
                      _HospitalBagEmptyCart(onResetCart: _resetCart),
                    _HospitalBagOrderSummary(
                      subtotal: _subtotal,
                      discount: _discount,
                      total: _total,
                      syncStatus: _syncStatus,
                      isSyncing: _isSyncing,
                      canReset: _removedItemIds.isNotEmpty,
                      onResetCart: _resetCart,
                      money: _money,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Transform.translate(
              offset: const Offset(0, 1),
              child: _HospitalBagFooter(
                total: _total,
                discount: _discount,
                money: _money,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HospitalBagHeader extends StatelessWidget {
  const _HospitalBagHeader({required this.onBack, required this.itemCount});

  final VoidCallback onBack;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xf2fff9fb),
        border: Border(bottom: BorderSide(color: Color(0xfff0dde5))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 15, 12),
        child: Row(
          children: [
            _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              foreground: const Color(0xff6c4457),
              background: Colors.white,
              size: 36,
              iconSize: 16,
              borderColor: Color(0xffedd6df),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '待产包一键打包',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xff372330),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '已按待产包物品清单整理',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xff8a6d7a),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              key: const ValueKey('hospital-bag-item-count-chip'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffeef9f5),
                borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                border: Border.all(color: const Color(0xffd7ece6)),
              ),
              child: Text(
                '$itemCount 件',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xff267c68),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalBagSyncStatusBanner extends StatelessWidget {
  const _HospitalBagSyncStatusBanner({
    required this.isSyncing,
    required this.message,
  });

  final bool isSyncing;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xffeef9f5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffd7ece6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (isSyncing)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.cloud_done_outlined,
                  color: Color(0xff267c68),
                  size: 18,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSyncing ? '购物车同步中...' : message ?? '购物车已同步',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xff267c68),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalBagGroupSection extends StatelessWidget {
  const _HospitalBagGroupSection({required this.group, required this.onDelete});

  final _HospitalBagCartGroupSpec group;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = _hospitalBagToneColors(group.tone);
    final headerOffset = group.title == '宝宝出院'
        ? const Offset(0, -3)
        : const Offset(0, -1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          RepaintBoundary(
            key: ValueKey('hospital-bag-group-header-${group.title}'),
            child: Transform.translate(
              offset: headerOffset,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xff372330),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '${group.items.length} 件',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.foreground,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (index, item) in group.items.indexed)
            _HospitalBagCartItemTile(
              item: item,
              tone: group.tone,
              bottomGap: index == group.items.length - 1 ? 0 : 8,
              onDelete: () => onDelete(item.id),
            ),
        ],
      ),
    );
  }
}

class _HospitalBagCartItemTile extends StatelessWidget {
  const _HospitalBagCartItemTile({
    required this.item,
    required this.tone,
    required this.bottomGap,
    required this.onDelete,
  });

  final _HospitalBagCartItemSpec item;
  final _HospitalBagTone tone;
  final double bottomGap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tileOffset = item.id == 'mom-briefs'
        ? const Offset(0, -1)
        : Offset.zero;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Tooltip(
        message: '长按删除${item.name}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: onDelete,
          child: RepaintBoundary(
            key: ValueKey('hospital-bag-item-${item.id}'),
            child: Transform.translate(
              offset: tileOffset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xfff0e1e7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0f5b3748),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(1, 1),
                        child: _HospitalBagItemImage(item: item, tone: tone),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Transform.translate(
                          offset: const Offset(0, -1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: const Color(0xff372330),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xff7e6672),
                                      fontSize: 11,
                                      height: 1.375,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'x${item.qty}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xff9a7b89),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.translate(
                        offset: const Offset(-1, 1),
                        child: _HospitalBagItemActions(
                          item: item,
                          onDelete: onDelete,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HospitalBagItemActions extends StatelessWidget {
  const _HospitalBagItemActions({required this.item, required this.onDelete});

  final _HospitalBagCartItemSpec item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _hospitalBagMoney(item.price),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xff372330),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: '删除${item.name}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                  border: Border.all(color: const Color(0xffedd6df)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      size: 12,
                      color: Color(0xff6c4457),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '删除',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xff6c4457),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HospitalBagItemImage extends StatelessWidget {
  const _HospitalBagItemImage({required this.item, required this.tone});

  final _HospitalBagCartItemSpec item;
  final _HospitalBagTone tone;

  @override
  Widget build(BuildContext context) {
    final assetPath = _hospitalBagItemImageAssets[item.id];
    if (assetPath == null) return _HospitalBagItemIcon(tone: tone);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xfff0e1e7)),
        ),
        child: Image.asset(
          assetPath,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              _HospitalBagItemIcon(tone: tone),
        ),
      ),
    );
  }
}

const _hospitalBagItemImageAssets = {
  'mom-pad': 'assets/images/hospital_bag_mom_pad.jpg',
  'mom-sanitary': 'assets/images/hospital_bag_mom_sanitary.jpg',
  'mom-underwear': 'assets/images/hospital_bag_mom_underwear.png',
  'mom-wipes': 'assets/images/hospital_bag_mom_wipes.jpg',
  'mom-bottle': 'assets/images/hospital_bag_mom_bottle.jpg',
  'mom-briefs': 'assets/images/hospital_bag_mom_briefs.png',
  'baby-diaper': 'assets/images/hospital_bag_baby_diaper.jpg',
  'baby-wipes': 'assets/images/hospital_bag_baby_wipes.jpg',
  'baby-towel': 'assets/images/hospital_bag_baby_towel.jpg',
  'baby-blanket': 'assets/images/hospital_bag_baby_blanket.jpg',
  'baby-clothes': 'assets/images/hospital_bag_baby_clothes.jpg',
  'baby-bath-towel': 'assets/images/hospital_bag_baby_bath_towel.jpg',
  'milk-pad': 'assets/images/hospital_bag_milk_pad.jpg',
  'milk-cream': 'assets/images/hospital_bag_milk_cream.jpg',
  'milk-storage': 'assets/images/hospital_bag_milk_storage.jpg',
  'pump-m9': 'assets/images/hospital_bag_pump_m9.jpg',
  'milk-bra': 'assets/images/hospital_bag_milk_bra.jpg',
  'milk-bottle': 'assets/images/hospital_bag_milk_bottle.jpg',
};

class _HospitalBagItemIcon extends StatelessWidget {
  const _HospitalBagItemIcon({required this.tone});

  final _HospitalBagTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _hospitalBagToneColors(tone);
    final icon = switch (tone) {
      _HospitalBagTone.mint => Icons.child_care_rounded,
      _HospitalBagTone.sky => Icons.favorite_border_rounded,
      _HospitalBagTone.rose => Icons.inventory_2_outlined,
    };
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: colors.foreground, size: 24),
    );
  }
}

class _HospitalBagOrderSummary extends StatelessWidget {
  const _HospitalBagOrderSummary({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.syncStatus,
    required this.isSyncing,
    required this.canReset,
    required this.onResetCart,
    required this.money,
  });

  final double subtotal;
  final double discount;
  final double total;
  final String? syncStatus;
  final bool isSyncing;
  final bool canReset;
  final VoidCallback onResetCart;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffefdbe4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x145b3748),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '订单摘要',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xff372330),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _HospitalBagSummaryRow(label: '商品小计', value: money(subtotal)),
              _HospitalBagSummaryRow(
                label: '组合优惠',
                value: '-${money(discount)}',
                valueColor: const Color(0xff267c68),
              ),
              const _HospitalBagSummaryRow(label: '配送', value: '免运费'),
              const Divider(height: 24, color: Color(0xfff0e1e7)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      isSyncing
                          ? '购物车同步中...'
                          : syncStatus ?? '购物车状态会在删除或恢复后同步。',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xff8a6d7a),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    money(total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xff24889a),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (canReset) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onResetCart,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('恢复默认清单'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalBagSummaryRow extends StatelessWidget {
  const _HospitalBagSummaryRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xff6f5663),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xff6f5663),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HospitalBagEmptyCart extends StatelessWidget {
  const _HospitalBagEmptyCart({required this.onResetCart});

  final VoidCallback onResetCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffefdbe4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '购物车已经清空',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xff372330),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onResetCart,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('恢复默认清单'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalBagFooter extends StatelessWidget {
  const _HospitalBagFooter({
    required this.total,
    required this.discount,
    required this.money,
  });

  final double total;
  final double discount;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey('hospital-bag-footer'),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xf5fff9fb),
              border: Border(top: BorderSide(color: Color(0xffead8df))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1a5b3748),
                  blurRadius: 28,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '预计合计',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xff8a6d7a),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                money(total),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: const Color(0xff24889a),
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '已含组合优惠 ${money(discount)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xff8a6d7a),
                                  fontSize: 10,
                                  height: 1.375,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xff24889a),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.credit_card_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '去结算',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
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

enum _HospitalBagTone { rose, mint, sky }

class _HospitalBagToneColors {
  const _HospitalBagToneColors({
    required this.background,
    required this.iconBackground,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color iconBackground;
  final Color foreground;
  final Color border;
}

_HospitalBagToneColors _hospitalBagToneColors(_HospitalBagTone tone) {
  return switch (tone) {
    _HospitalBagTone.rose => const _HospitalBagToneColors(
      background: Color(0xfffff0f5),
      iconBackground: Color(0xfff9d9e4),
      foreground: Color(0xffb84d73),
      border: Color(0xfff5cfdb),
    ),
    _HospitalBagTone.mint => const _HospitalBagToneColors(
      background: Color(0xffedf9f5),
      iconBackground: Color(0xffd4f0e7),
      foreground: Color(0xff267c68),
      border: Color(0xffccebe2),
    ),
    _HospitalBagTone.sky => const _HospitalBagToneColors(
      background: Color(0xffedf6ff),
      iconBackground: Color(0xffd8ebfb),
      foreground: Color(0xff2f6fa8),
      border: Color(0xffcfe5f8),
    ),
  };
}

class _HospitalBagCartGroupSpec {
  const _HospitalBagCartGroupSpec({
    required this.title,
    required this.tone,
    required this.items,
  });

  final String title;
  final _HospitalBagTone tone;
  final List<_HospitalBagCartItemSpec> items;

  _HospitalBagCartGroupSpec copyWith({List<_HospitalBagCartItemSpec>? items}) {
    return _HospitalBagCartGroupSpec(
      title: title,
      tone: tone,
      items: items ?? this.items,
    );
  }
}

class _HospitalBagCartItemSpec {
  const _HospitalBagCartItemSpec({
    required this.id,
    required this.name,
    required this.desc,
    required this.price,
  });

  final String id;
  final String name;
  final String desc;
  final double price;
  int get qty => 1;
}

String _hospitalBagMoney(double amount) => '¥${amount.toStringAsFixed(2)}';

const _hospitalBagCartGroups = [
  _HospitalBagCartGroupSpec(
    title: '妈妈护理',
    tone: _HospitalBagTone.rose,
    items: [
      _HospitalBagCartItemSpec(
        id: 'mom-pad',
        name: '产褥垫组合装',
        desc: '入院与产后前几天使用',
        price: 59.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'mom-sanitary',
        name: '产妇卫生巾',
        desc: '夜用加长款，按住院天数准备',
        price: 39.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'mom-underwear',
        name: '一次性内裤',
        desc: '高腰柔软，产后更方便更换',
        price: 49.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'mom-wipes',
        name: '产后护理湿巾',
        desc: '温和清洁，适合住院随身包',
        price: 29.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'mom-bottle',
        name: '产后冲洗瓶',
        desc: '产后清洁更方便，是否带去医院按医院建议',
        price: 39.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'mom-briefs',
        name: '高腰收腹内裤',
        desc: '不压腹，更适合产后恢复期穿着',
        price: 69.9,
      ),
    ],
  ),
  _HospitalBagCartGroupSpec(
    title: '宝宝出院',
    tone: _HospitalBagTone.mint,
    items: [
      _HospitalBagCartItemSpec(
        id: 'baby-diaper',
        name: '新生儿纸尿裤',
        desc: 'NB 码小包装，避免带太多',
        price: 59.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'baby-wipes',
        name: '婴儿柔湿巾',
        desc: '无香精，适合换尿裤场景',
        price: 29.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'baby-towel',
        name: '棉柔巾',
        desc: '洗脸、擦手、护理都可用',
        price: 29.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'baby-blanket',
        name: '宝宝出院包被',
        desc: '柔软包裹，按季节搭配外层',
        price: 129,
      ),
      _HospitalBagCartItemSpec(
        id: 'baby-clothes',
        name: '新生儿连体衣礼盒',
        desc: '出院和回家第一周可替换穿',
        price: 159,
      ),
      _HospitalBagCartItemSpec(
        id: 'baby-bath-towel',
        name: '婴儿浴巾',
        desc: '洗澡、包裹和保暖都可用',
        price: 59.9,
      ),
    ],
  ),
  _HospitalBagCartGroupSpec(
    title: '母乳喂养',
    tone: _HospitalBagTone.sky,
    items: [
      _HospitalBagCartItemSpec(
        id: 'milk-pad',
        name: '防溢乳垫',
        desc: '母乳或混合喂养可先备小包装',
        price: 39.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'milk-cream',
        name: '乳头护理霜',
        desc: '哺乳初期不适时可咨询后使用',
        price: 49.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'milk-storage',
        name: '储奶袋',
        desc: '返家后储奶备用，住院可少量准备',
        price: 49.9,
      ),
      _HospitalBagCartItemSpec(
        id: 'pump-m9',
        name: 'Momcozy M9 吸奶器',
        desc: '便携穿戴式双边吸乳，返家后排奶/储奶备用',
        price: 1087.93,
      ),
      _HospitalBagCartItemSpec(
        id: 'milk-bra',
        name: '哺乳文胸',
        desc: '产后和哺乳初期更舒适',
        price: 159,
      ),
      _HospitalBagCartItemSpec(
        id: 'milk-bottle',
        name: '宽口径奶瓶',
        desc: '混合喂养或返家后备用',
        price: 89.9,
      ),
    ],
  ),
];

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
  bool _consultStarted = false;
  bool _isStarting = false;
  bool _isEnding = false;
  bool _chatReady = false;
  int _connectionStepIndex = 1;
  String? _syncStatus;
  final List<Timer> _connectionTimers = [];
  static const String _returnToPath = '/status';
  static const _connectionSteps = ['健康信息整理中', '连接中', '连接成功', '对方正在读取背景中'];

  @override
  void initState() {
    super.initState();
    _scheduleConnectionFlow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startConsult());
    });
  }

  @override
  void dispose() {
    for (final timer in _connectionTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _scheduleConnectionFlow() {
    const durations = [
      Duration(milliseconds: 1000),
      Duration(milliseconds: 2000),
      Duration(milliseconds: 1000),
      Duration(milliseconds: 2000),
    ];
    var elapsed = Duration.zero;
    for (var index = 1; index < _connectionSteps.length; index += 1) {
      _connectionTimers.add(
        Timer(elapsed, () {
          if (mounted) setState(() => _connectionStepIndex = index);
        }),
      );
      elapsed += durations[index];
    }
    _connectionTimers.add(
      Timer(elapsed + const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _chatReady = true);
      }),
    );
  }

  Future<void> _startConsult() async {
    if (_consultStarted || _isStarting) return;
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

  void _endConsult() {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _returnToStatus();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('route-page-${widget.path}'),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          _IbclcChatHeader(isEnding: _isEnding, onEndConsult: _endConsult),
          Expanded(
            child: _IbclcChatBody(
              chatReady: _chatReady,
              connectionText: _connectionSteps[_connectionStepIndex],
              syncStatus: _syncStatus,
            ),
          ),
          if (_chatReady) const _IbclcChatComposer(),
        ],
      ),
    );
  }
}

class _IbclcChatHeader extends StatelessWidget {
  const _IbclcChatHeader({required this.isEnding, required this.onEndConsult});

  final bool isEnding;
  final VoidCallback onEndConsult;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffdce8e5))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 26, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'IBCLC 在线咨询',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xff172625),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton(
              key: const ValueKey('ibclc-return-status-button'),
              onPressed: isEnding ? null : onEndConsult,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffd64b4b),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xffd64b4b),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                fixedSize: const Size(78, 32),
                minimumSize: const Size(78, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: Color(0xffc84444)),
                ),
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(isEnding ? '结束中...' : '结束咨询'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IbclcChatBody extends StatelessWidget {
  const _IbclcChatBody({
    required this.chatReady,
    required this.connectionText,
    required this.syncStatus,
  });

  final bool chatReady;
  final String connectionText;
  final String? syncStatus;

  @override
  Widget build(BuildContext context) {
    if (!chatReady) {
      return Center(
        child: Transform.translate(
          offset: const Offset(0, 19),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xfff7fcfa),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffd9e8e4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14224844),
                  blurRadius: 34,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SizedBox(
              width: 300,
              height: 50,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _IbclcPulseDot(),
                    const SizedBox(width: 10),
                    Text(
                      connectionText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xff177a89),
                        fontWeight: FontWeight.w900,
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

    return ListView(
      padding: EdgeInsets.fromLTRB(14, chatReady ? 14 : 0, 14, 14),
      children: [
        if (!chatReady)
          SizedBox(
            height: 560,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff7fcfa),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffd9e8e4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14224844),
                      blurRadius: 34,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 300,
                  height: 50,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _IbclcPulseDot(),
                        const SizedBox(width: 10),
                        Text(
                          connectionText,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xff177a89),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xfff1f7f5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    '你好，我是 Emily Chen，IBCLC。我已经看到你从 CoMate 带过来的背景了，你可以先告诉我现在最困扰你的哺乳问题。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff233c39),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (syncStatus != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xffedf6f3),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xffd5e5e1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    syncStatus!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xff28615c),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _IbclcPulseDot extends StatelessWidget {
  const _IbclcPulseDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xff177a89),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _IbclcChatComposer extends StatelessWidget {
  const _IbclcChatComposer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xfffbfefd),
        border: Border(top: BorderSide(color: Color(0xffdce8e5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
          child: Row(
            children: [
              const _IbclcComposerIconButton(
                key: ValueKey('ibclc-upload-image-button'),
                icon: Icons.add_photo_alternate_outlined,
                tooltip: '上传图片',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    key: const ValueKey('ibclc-message-input'),
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: const Color(0xff78918e),
                            fontWeight: FontWeight.w500,
                          ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xffd5e1de)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xff177a89)),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff172625),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const _IbclcComposerIconButton(
                key: ValueKey('ibclc-voice-button'),
                icon: Icons.mic_none_rounded,
                tooltip: '语音输入',
              ),
              const SizedBox(width: 6),
              FilledButton(
                key: const ValueKey('ibclc-send-button'),
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff177a89),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                child: const Text('发送'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IbclcComposerIconButton extends StatelessWidget {
  const _IbclcComposerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          tooltip: tooltip,
          onPressed: () {},
          icon: Icon(icon, size: 20),
          color: const Color(0xff28615c),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xfff2f8f6),
            side: const BorderSide(color: Color(0xffd5e1de)),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
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
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Uri? routeUri;
  final Object? routeExtra;

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  void _returnFromMediaViewer() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final media = _MediaViewerRouteState.from(
      routeUri: widget.routeUri,
      routeExtra: widget.routeExtra,
    );
    final headerTitle = media?.title ?? '媒体';

    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: MomCozyColors.background,
      child: Column(
        children: [
          _MediaViewerHeader(
            title: headerTitle,
            onBack: _returnFromMediaViewer,
          ),
          Expanded(
            child: media == null
                ? const _MediaViewerMissingResource()
                : _MediaViewerContent(media: media),
          ),
        ],
      ),
    );
  }
}

class _MediaViewerHeader extends StatelessWidget {
  const _MediaViewerHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MomCozyColors.background,
        border: Border(bottom: BorderSide(color: MomCozyColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  key: const ValueKey('media-return-button'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  color: MomCozyColors.foreground,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaViewerMissingResource extends StatelessWidget {
  const _MediaViewerMissingResource();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '缺少资源参数，请从资料卡片进入。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaViewerContent extends StatelessWidget {
  const _MediaViewerContent({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    return switch (media.kind) {
      'image' => const _ImageViewerStage(),
      'video' => const _VideoViewerStage(),
      _ => const _PdfViewerStage(),
    };
  }
}

class _PdfViewerStage extends StatelessWidget {
  const _PdfViewerStage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: MomCozyColors.background,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 40),
      child: Text(
        '加载 PDF…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: MomCozyColors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImageViewerStage extends StatelessWidget {
  const _ImageViewerStage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          '加载图片…',
          style: TextStyle(
            color: Color(0xb3ffffff),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _VideoViewerStage extends StatelessWidget {
  const _VideoViewerStage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MomCozyColors.background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
              label: const Text('全屏播放'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MomCozyColors.foreground,
                backgroundColor: MomCozyColors.secondary,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xb3ffffff),
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaViewerRouteState {
  const _MediaViewerRouteState({
    required this.kind,
    required this.url,
    required this.title,
  });

  final String kind;
  final String url;
  final String title;

  static const _supportedKinds = {'pdf', 'image', 'video'};

  static _MediaViewerRouteState? from({
    required Uri? routeUri,
    required Object? routeExtra,
  }) {
    final extra = routeExtra is Map ? routeExtra : null;
    final query = routeUri?.queryParameters ?? const <String, String>{};
    final kind = _normalizeKind(
      _stringFromMap(extra, 'kind') ?? _stringFromQuery(query, 'kind'),
    );
    final url = _nonEmpty(
      _stringFromMap(extra, 'url') ?? _stringFromQuery(query, 'url'),
    );
    if (kind == null || url == null) return null;
    final title =
        _nonEmpty(
          _stringFromMap(extra, 'title') ?? _stringFromQuery(query, 'title'),
        ) ??
        _defaultTitleForKind(kind);
    return _MediaViewerRouteState(kind: kind, url: url, title: title);
  }

  static String? _normalizeKind(String? value) {
    final normalized = _nonEmpty(value)?.toLowerCase();
    if (normalized == null || !_supportedKinds.contains(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _stringFromMap(Map<Object?, Object?>? map, String key) {
    final value = map?[key];
    return value is String ? value : null;
  }

  static String? _stringFromQuery(Map<String, String> query, String key) {
    final value = query[key];
    return value;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _defaultTitleForKind(String kind) {
    return switch (kind) {
      'image' => '图片',
      'video' => '视频',
      _ => 'PDF',
    };
  }
}

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
    return ListView(
      key: ValueKey('route-page-$path'),
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 700,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, 103),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '404',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Oops! Page not found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => context.go('/'),
                    style: TextButton.styleFrom(
                      foregroundColor: MomCozyColors.primary,
                      textStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    child: const Text('Return to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
