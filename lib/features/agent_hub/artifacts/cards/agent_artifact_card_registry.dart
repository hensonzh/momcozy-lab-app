import 'package:flutter/material.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:app/features/agent_hub/presentation/ibclc_consult_store_scope.dart';
import 'package:app/features/hospital_bag/domain/hospital_bag_cart.dart';

class AgentArtifactCardRegistry {
  const AgentArtifactCardRegistry._();

  static Widget? build({
    required AgentArtifactCardView card,
    ValueChanged<AgentArtifactActionView>? onAction,
  }) {
    return switch (card.presentationKind) {
      AgentArtifactPresentationKind.ibclcConsultCard =>
        card.specializedView is AgentIbclcConsultCardView
            ? _IbclcConsultCard(
                key: ValueKey('ibclc:${card.id}'),
                card: card,
                data: card.specializedView! as AgentIbclcConsultCardView,
                onAction: onAction,
              )
            : null,
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
  });

  final AgentArtifactCardView card;
  final IconData icon;
  final Color accent;
  final String? subtitle;
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
                const SizedBox(width: 8),
                Image.asset(
                  MomCozyAssets.momcozyLogo,
                  width: 68,
                  height: 40,
                  fit: BoxFit.contain,
                ),
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
  const _IbclcConsultCard({
    super.key,
    required this.card,
    required this.data,
    this.onAction,
  });

  final AgentArtifactCardView card;
  final AgentIbclcConsultCardView data;
  final ValueChanged<AgentArtifactActionView>? onAction;

  @override
  State<_IbclcConsultCard> createState() => _IbclcConsultCardState();
}

class _IbclcConsultCardState extends State<_IbclcConsultCard> {
  bool _agreementAccepted = false;

  @override
  void didUpdateWidget(covariant _IbclcConsultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.consultId != widget.data.consultId) {
      _agreementAccepted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final completed =
        IbclcConsultStoreScope.maybeOf(context)?.isCompleted(data.consultId) ??
        false;
    final textTheme = Theme.of(context).textTheme;

    return KeyedSubtree(
      key: ValueKey('agent-artifact-ibclc-${widget.card.id}'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfffbfdfc),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffd6dde5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0d000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    size: 22,
                    color: Color(0xff177a89),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: const Color(0xff142726),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                key: ValueKey('agent-ibclc-consultant-${widget.card.id}'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffd6dde5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ClipOval(
                          child: Image.asset(
                            MomCozyAssets.ibclcConsultantAvatar,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            semanticLabel: data.consultantName,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.consultantName,
                              style: textTheme.titleMedium?.copyWith(
                                color: const Color(0xff182b2a),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _IbclcConsultantTag(
                                  label: data.consultantCredentials,
                                  color: const Color(0xff1a6863),
                                  background: const Color(0xffe9f3f1),
                                ),
                                if (data.consultantExperience != null)
                                  _IbclcConsultantTag(
                                    label: data.consultantExperience!,
                                    color: const Color(0xff7a4260),
                                    background: const Color(0xfff4edf1),
                                  ),
                              ],
                            ),
                            if (data.consultantBio != null) ...[
                              const SizedBox(height: 7),
                              Text(
                                data.consultantBio!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xff60706e),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!completed) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  key: ValueKey('agent-ibclc-consent-${widget.card.id}'),
                  decoration: BoxDecoration(
                    color: const Color(0xfff6fbfa),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffdbe7e4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            _agreementAccepted = !_agreementAccepted;
                          }),
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: Checkbox(
                                    key: ValueKey(
                                      'agent-ibclc-agreement-${widget.card.id}',
                                    ),
                                    value: _agreementAccepted,
                                    onChanged: (value) => setState(() {
                                      _agreementAccepted = value ?? false;
                                    }),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    activeColor: const Color(0xff177a89),
                                    side: const BorderSide(
                                      color: Color(0xffb9cbc8),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '我已阅读并同意《隐私政策》和《服务协议》',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: const Color(0xff586967),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 6),
                          child: Text(
                            data.chatNote,
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(0xff71807d),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: FilledButton(
                  key: ValueKey('agent-ibclc-open-${widget.card.id}'),
                  onPressed:
                      !completed &&
                          _agreementAccepted &&
                          widget.onAction != null
                      ? _openConsult
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff177a89),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xffd7dfdd),
                    disabledForegroundColor: const Color(0xff778683),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(completed ? '咨询结束' : data.chatLabel),
                ),
              ),
            ],
          ),
        ),
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
        routeExtra: IbclcConsultRouteDraft(
          consultId: widget.data.consultId,
          sourceArtifactId: widget.data.sourceArtifactId,
          consultantName: widget.data.consultantName,
          consultantCredentials: widget.data.consultantCredentials,
          consultantExperience: widget.data.consultantExperience ?? '',
          consultantBio: widget.data.consultantBio ?? '',
          chatLabel: widget.data.chatLabel,
          chatNote: widget.data.chatNote,
          reason: widget.data.reason ?? '',
          feedingContext: widget.data.feedingContext ?? '',
          urgency: widget.data.urgency,
          preferredLanguage: widget.data.preferredLanguage ?? '',
        ),
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

class _IbclcConsultantTag extends StatelessWidget {
  const _IbclcConsultantTag({
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
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
