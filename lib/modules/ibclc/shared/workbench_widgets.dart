import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

class WorkbenchPageBody extends StatelessWidget {
  const WorkbenchPageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        constraints.maxWidth >= 900
            ? MomCozySpacing.spacious
            : MomCozySpacing.page,
        MomCozySpacing.section,
        constraints.maxWidth >= 900
            ? MomCozySpacing.spacious
            : MomCozySpacing.page,
        MomCozySpacing.spacious,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MomCozyLayout.workbenchWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class WorkbenchHeading extends StatelessWidget {
  const WorkbenchHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MomCozySpacing.section),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MomCozySpacing.page,
      runSpacing: MomCozySpacing.content,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: MomCozyTypography.pageTitle),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: MomCozySpacing.xs),
                child: Text(
                  subtitle!,
                  style: const TextStyle(
                    color: MomCozyColors.mutedForeground,
                    fontSize: MomCozyTypography.secondarySize,
                  ),
                ),
              ),
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: MomCozySpacing.compact,
            runSpacing: MomCozySpacing.compact,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
      ],
    ),
  );
}

class WorkbenchPagination extends StatelessWidget {
  const WorkbenchPagination({
    super.key,
    required this.total,
    required this.offset,
    required this.limit,
    required this.onPage,
    this.loading = false,
  });
  final int total, offset, limit;
  final bool loading;
  final void Function(int direction) onPage;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MomCozySpacing.content),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: MomCozySpacing.compact,
      spacing: 18,
      children: [
        Text(
          '显示 ${total == 0 ? 0 : offset + 1}–${(offset + limit).clamp(0, total)} / $total',
          style: const TextStyle(
            fontSize: MomCozyTypography.captionSize,
            color: MomCozyColors.mutedForeground,
          ),
        ),
        Wrap(
          spacing: MomCozySpacing.compact,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: !loading && offset > 0 ? () => onPage(-1) : null,
              child: const Text('上一页'),
            ),
            Text(
              '第 ${offset ~/ limit + 1} 页',
              style: const TextStyle(fontSize: 12),
            ),
            OutlinedButton(
              onPressed: !loading && offset + limit < total
                  ? () => onPage(1)
                  : null,
              child: const Text('下一页'),
            ),
          ],
        ),
      ],
    ),
  );
}

class WorkbenchBadge extends StatelessWidget {
  const WorkbenchBadge(
    this.label, {
    super.key,
    this.color = MomCozyColors.mutedForeground,
    this.background = MomCozyColors.muted,
  });
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: MomCozySpacing.compact,
      vertical: MomCozySpacing.xs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(MomCozyRadii.badge),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: MomCozyTypography.labelSize,
      ),
    ),
  );
}
