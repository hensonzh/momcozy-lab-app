import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

class AgentArtifactCardRegistry {
  const AgentArtifactCardRegistry._();

  static Widget? build({
    required AgentArtifactCardView card,
    ValueChanged<AgentArtifactActionView>? onAction,
  }) {
    return switch (card.presentationKind) {
      AgentArtifactPresentationKind.ibclcConsultCard => _IbclcConsultCard(
        key: ValueKey('ibclc:${card.id}'),
        card: card,
        onAction: onAction,
      ),
      AgentArtifactPresentationKind.milkPlanPreview => _MilkPlanPreviewCard(
        card: card,
      ),
      AgentArtifactPresentationKind.hospitalBagCart => _HospitalBagCartCard(
        card: card,
        onAction: onAction,
      ),
      _ => null,
    };
  }
}

class _ArtifactCardSurface extends StatelessWidget {
  const _ArtifactCardSurface({
    required this.card,
    required this.icon,
    required this.accent,
    required this.children,
    this.subtitle,
    this.trailing,
    this.showLogo = true,
  });

  final AgentArtifactCardView card;
  final IconData icon;
  final Color accent;
  final String? subtitle;
  final Widget? trailing;
  final bool showLogo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfffffdfc),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffeadfe5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12412a34),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(icon, color: accent, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: const Color(0xff2f1f29),
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xff8b7581),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (showLogo) ...[
                  const SizedBox(width: 8),
                  Image.asset(
                    MomCozyAssets.momcozyLogo,
                    width: 68,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ],
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _IbclcConsultCard extends StatefulWidget {
  const _IbclcConsultCard({super.key, required this.card, this.onAction});

  final AgentArtifactCardView card;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  State<_IbclcConsultCard> createState() => _IbclcConsultCardState();
}

class _IbclcConsultCardState extends State<_IbclcConsultCard> {
  bool _agreementAccepted = false;

  @override
  Widget build(BuildContext context) {
    final payload = widget.card.payload;
    final reason = _text(payload['reason']);
    final feedingContext = _text(
      payload['feeding_context'] ?? payload['feedingContext'],
    );
    final urgency = _urgencyLabel(_text(payload['urgency']));
    final language = _text(
      payload['preferred_language'] ?? payload['preferredLanguage'],
    );

    return KeyedSubtree(
      key: ValueKey('agent-artifact-ibclc-${widget.card.id}'),
      child: _ArtifactCardSurface(
        card: widget.card,
        icon: Icons.monitor_heart_outlined,
        accent: const Color(0xff177a89),
        showLogo: false,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Image.asset(
                  MomCozyAssets.ibclcConsultantAvatar,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emily Chen',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xff182b2a),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _ArtifactTag(
                      label: 'IBCLC 国际认证哺乳顾问',
                      color: Color(0xff1a6863),
                      background: Color(0xffe9f3f1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reason != null || feedingContext != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xffd6dde5)),
            const SizedBox(height: 12),
            if (reason != null) _LabelValueRow(label: '咨询原因', value: reason),
            if (reason != null && feedingContext != null)
              const SizedBox(height: 8),
            if (feedingContext != null)
              _LabelValueRow(label: '当前情况', value: feedingContext),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ArtifactTag(
                label: urgency,
                color: const Color(0xff177a89),
                background: const Color(0xffe9f3f1),
              ),
              if (language != null)
                _ArtifactTag(
                  label: language,
                  color: const Color(0xff7a4260),
                  background: const Color(0xfff4edf1),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xfff6fbfa),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffdbe7e4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      _agreementAccepted = !_agreementAccepted;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: ValueKey(
                            'agent-ibclc-agreement-${widget.card.id}',
                          ),
                          value: _agreementAccepted,
                          onChanged: (value) => setState(() {
                            _agreementAccepted = value ?? false;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              '我已阅读并同意《隐私政策》和《服务协议》',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xff586967),
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 44, top: 2),
                    child: Text(
                      '启动咨询后，会将本轮相关问题带入咨询页面。',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xff71807d),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              key: ValueKey('agent-ibclc-open-${widget.card.id}'),
              onPressed: _agreementAccepted && widget.onAction != null
                  ? _openConsult
                  : null,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('咨询 IBCLC'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff177a89),
                disabledBackgroundColor: const Color(0xffd7dfdd),
                disabledForegroundColor: const Color(0xff778683),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openConsult() {
    widget.onAction?.call(
      AgentArtifactActionView(
        label: '咨询 IBCLC',
        icon: Icons.chat_bubble_outline_rounded,
        kind: 'artifact',
        value: '/ibclc-chat.html',
        routePath: '/ibclc-chat.html',
        routeExtra: {
          'consultId': widget.card.id,
          'reason': widget.card.payload['reason'],
          'feedingContext':
              widget.card.payload['feeding_context'] ??
              widget.card.payload['feedingContext'],
        },
      ),
    );
  }
}

class _MilkPlanPreviewCard extends StatelessWidget {
  const _MilkPlanPreviewCard({required this.card});

  final AgentArtifactCardView card;

  @override
  Widget build(BuildContext context) {
    final payload = card.payload;
    final tasks = _objectList(payload['tasks']);
    final reminders = _objectList(payload['reminders']);
    final days = _text(payload['days']);
    final startDate = _text(payload['start_date'] ?? payload['startDate']);
    final direction = _directionLabel(_text(payload['direction']));

    return KeyedSubtree(
      key: ValueKey('agent-artifact-milk-preview-${card.id}'),
      child: _ArtifactCardSurface(
        card: card,
        icon: Icons.route_rounded,
        accent: const Color(0xff207d83),
        subtitle: _text(payload['summary']) ?? card.content,
        trailing: _ArtifactTag(
          label: direction,
          color: const Color(0xff2d5f51),
          background: const Color(0xfff0f8f4),
        ),
        children: [
          if (days != null || startDate != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (days != null)
                  _ArtifactMetric(label: '周期', value: '$days 天'),
                if (startDate != null)
                  _ArtifactMetric(label: '开始日期', value: startDate),
              ],
            ),
          if (tasks.isNotEmpty) ...[
            if (days != null || startDate != null) const SizedBox(height: 12),
            _ArtifactListSection(
              title: '计划任务',
              icon: Icons.checklist_rounded,
              items: tasks.map(_taskText).whereType<String>().toList(),
              tone: const Color(0xfff7fbf8),
              border: const Color(0xffd8e7dd),
            ),
          ],
          if (reminders.isNotEmpty) ...[
            if (tasks.isNotEmpty || days != null || startDate != null)
              const SizedBox(height: 10),
            _ArtifactListSection(
              title: '温馨提醒',
              icon: Icons.notifications_none_rounded,
              items: reminders.map(_taskText).whereType<String>().toList(),
              tone: const Color(0xfffff8fa),
              border: const Color(0xffead6df),
            ),
          ],
        ],
      ),
    );
  }
}

class _HospitalBagCartCard extends StatelessWidget {
  const _HospitalBagCartCard({required this.card, this.onAction});

  final AgentArtifactCardView card;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  Widget build(BuildContext context) {
    final cartUpdate = _map(
      card.payload['cart_update'] ?? card.payload['cartUpdate'],
    );
    final groups = _objectList(cartUpdate['groups']);
    final totals = _map(cartUpdate['totals']);
    final itemCount = _text(totals['item_count'] ?? totals['itemCount']);
    final total = _text(totals['total'] ?? totals['subtotal']);

    return KeyedSubtree(
      key: ValueKey('agent-artifact-cart-${card.id}'),
      child: _ArtifactCardSurface(
        card: card,
        icon: Icons.shopping_bag_outlined,
        accent: const Color(0xff9b6b2f),
        subtitle: _text(cartUpdate['message']) ?? card.content,
        children: [
          for (var index = 0; index < groups.length; index++) ...[
            _CartGroup(
              key: ValueKey(
                'cart-group:${_text(groups[index]['id']) ?? _text(groups[index]['title']) ?? index}',
              ),
              group: groups[index],
            ),
            if (index < groups.length - 1) const SizedBox(height: 8),
          ],
          if (itemCount != null || total != null) ...[
            if (groups.isNotEmpty) const SizedBox(height: 12),
            Row(
              children: [
                if (itemCount != null)
                  _ArtifactTag(
                    label: '共 $itemCount 件',
                    color: const Color(0xff7a5425),
                    background: const Color(0xfffff3df),
                  ),
                const Spacer(),
                if (total != null)
                  Text(
                    '合计 $total',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xff7a5425),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              key: ValueKey('agent-artifact-cart-open-${card.id}'),
              onPressed: onAction == null ? null : _openCart,
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('打开购物车'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff7a5425),
                side: const BorderSide(color: Color(0xffd9bd91)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCart() {
    final cartUpdate = _map(
      card.payload['cart_update'] ?? card.payload['cartUpdate'],
    );
    onAction?.call(
      AgentArtifactActionView(
        label: '打开购物车',
        icon: Icons.shopping_cart_outlined,
        kind: 'artifact',
        value: '/hospital-bag-cart',
        routePath: '/hospital-bag-cart',
        hospitalBagCartSeed: HospitalBagCartArtifactSeed.tryFromCartUpdate(
          artifactId: card.id,
          cartUpdate: cartUpdate,
        ),
      ),
    );
  }
}

class _CartGroup extends StatefulWidget {
  const _CartGroup({super.key, required this.group});

  final Map<String, Object?> group;

  @override
  State<_CartGroup> createState() => _CartGroupState();
}

class _CartGroupState extends State<_CartGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final title = _text(widget.group['title']) ?? '待产包';
    final items = _objectList(widget.group['items']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xff4b2638),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${items.length} 项',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xff8b7581),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: const Color(0xff8b7581),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xffc19058),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _text(item['name'] ?? item['label']) ?? '物品',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff5c4852),
                        height: 1.4,
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

class _ArtifactListSection extends StatelessWidget {
  const _ArtifactListSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.tone,
    required this.border,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color tone;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xff207d83)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xff3a2530),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            for (final item in items) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xffb98ca1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff5c4852),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArtifactMetric extends StatelessWidget {
  const _ArtifactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfff7fcfd),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffd7e6ea)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: const Color(0xff917c87)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xff33212b),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactTag extends StatelessWidget {
  const _ArtifactTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff71807d),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xff273b3a),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

String _urgencyLabel(String? urgency) {
  return switch (urgency?.trim().toLowerCase()) {
    'urgent' || 'immediate' => '建议立即咨询',
    'soon' => '建议尽快咨询',
    _ => '常规咨询',
  };
}

String _directionLabel(String? direction) {
  return switch (direction?.trim().toLowerCase()) {
    'increase' || 'up' => '逐步增加',
    'decrease' || 'down' => '适当减少',
    'maintain' || 'stable' => '维持当前节奏',
    _ => '个性化计划',
  };
}

String? _taskText(Map<String, Object?> item) {
  final title = _text(item['title'] ?? item['label']);
  final detail = _text(item['detail'] ?? item['description']);
  if (title == null) return detail;
  return detail == null ? title : '$title：$detail';
}

String? _text(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  if (value is num || value is bool) return value.toString();
  return null;
}

Map<String, Object?> _map(Object? value) {
  return value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}
