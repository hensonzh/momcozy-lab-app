import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';
import 'service_flow_theme.dart';
import 'service_purchase_dialog.dart';

class ServiceRenewPage extends StatefulWidget {
  const ServiceRenewPage({
    super.key,
    required this.repository,
    required this.onBack,
    required this.onBook,
    required this.onProgress,
    this.episodeId,
  });
  final CareRepository repository;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onBook, onProgress;
  final String? episodeId;
  @override
  State<ServiceRenewPage> createState() => _ServiceRenewPageState();
}

class _ServiceRenewPageState extends State<ServiceRenewPage> {
  late final controller = CareOverviewController(widget.repository);
  String? _selected;
  bool _opening = false;
  String? _openError;
  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _select(ServicePackage package) async {
    if (_opening || controller.loading) return;
    setState(() {
      _opening = true;
      _selected = package.id;
      _openError = null;
    });
    final ongoing = controller.overview!.episodes
        .where((e) => e.packageId == package.id && e.ongoing)
        .firstOrNull;
    if (ongoing != null) {
      widget.onProgress(ongoing);
      if (mounted) setState(() => _opening = false);
      return;
    }
    try {
      final pending = controller.overview!.orders
          .where((o) => o.packageId == package.id && o.canResume)
          .firstOrNull;
      final purchase = pending == null
          ? null
          : await widget.repository.purchase(pending.id);
      if (!mounted) return;
      final episode = await showServicePurchase(
        context,
        repository: widget.repository,
        package: package,
        catalog: controller.catalog!,
        purchase: purchase,
      );
      if (!mounted) return;
      await controller.load();
      if (mounted && episode != null) widget.onBook(episode);
    } catch (_) {
      if (mounted) setState(() => _openError = '暂时无法打开订单，请重新选择方案重试。');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ServiceFlowTheme(
    child: Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final selected =
                _selected ??
                controller.overview?.episodes
                    .where((e) => e.id == widget.episodeId)
                    .firstOrNull
                    ?.packageId;
            final catalog = controller.catalog;
            return RefreshIndicator(
              onRefresh: () async {
                if (!_opening) await controller.load();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: widget.onBack,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text(
                        '返回',
                        style: TextStyle(
                          fontSize: 12,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '继续支持',
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (controller.failure case final failure?)
                    ProductErrorView(failure: failure, onRetry: controller.load)
                  else if (catalog == null)
                    const ProductLoadingView(label: '正在读取支持方案')
                  else ...[
                    if (controller.loading)
                      const LinearProgressIndicator(minHeight: 2),
                    if (_openError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _openError!,
                          style: const TextStyle(
                            color: MomCozyColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (catalog.packages.isEmpty)
                      ProductEmptyView(
                        title: '暂无可选的支持方案',
                        description: '稍后再来看看，已有服务记录仍可查看。',
                        action: TextButton(
                          onPressed: controller.load,
                          child: const Text('刷新方案'),
                        ),
                      ),
                    for (final package in catalog.packages)
                      _RenewPackageCard(
                        package: package,
                        selected: package.id == selected,
                        enabled:
                            !_opening &&
                            !controller.loading &&
                            (catalog.paymentMode != PaymentMode.disabled ||
                                controller.overview!.episodes.any(
                                  (e) => e.packageId == package.id && e.ongoing,
                                )),
                        label:
                            controller.overview!.episodes.any(
                              (e) => e.packageId == package.id && e.ongoing,
                            )
                            ? '查看我的服务'
                            : catalog.paymentMode == PaymentMode.disabled
                            ? '暂未开放购买'
                            : controller.overview!.orders.any(
                                (o) => o.packageId == package.id && o.canResume,
                              )
                            ? '继续付款'
                            : '选择',
                        onSelect: () => _select(package),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _RenewPackageCard extends StatelessWidget {
  const _RenewPackageCard({
    required this.package,
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onSelect,
  });
  final ServicePackage package;
  final bool selected, enabled;
  final String label;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          package.name,
          style: const TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${package.durationDays} 天 · ${package.sessions} 次咨询',
          style: const TextStyle(
            fontSize: 11,
            color: MomCozyColors.mutedForeground,
          ),
        ),
      ],
    );
    final price = Text(
      package.priceLabel,
      style: const TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: MomCozyColors.primaryDark,
      ),
    );
    return Semantics(
      selected: selected,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: MomCozyColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? MomCozyColors.primary.withValues(alpha: .5)
                : MomCozyColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: MomCozyColors.primaryDark.withValues(
                alpha: selected ? .1 : .035,
              ),
              blurRadius: selected ? 25 : 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 20,
                top: 0,
                child: Container(
                  width: 86,
                  height: 3,
                  decoration: BoxDecoration(
                    color: MomCozyColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (large) ...[
                    title,
                    const SizedBox(height: 8),
                    price,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 14),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .32,
                          ),
                          child: price,
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: enabled ? onSelect : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(label, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
