import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';
import 'service_catalog_page.dart';
import 'service_purchase_dialog.dart';

class ServicePackagePage extends StatefulWidget {
  const ServicePackagePage({
    super.key,
    required this.repository,
    required this.packageId,
    required this.onBack,
    required this.onBook,
    required this.onProgress,
  });
  final CareRepository repository;
  final String packageId;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onBook, onProgress;
  @override
  State<ServicePackagePage> createState() => _ServicePackagePageState();
}

class _ServicePackagePageState extends State<ServicePackagePage> {
  late final controller = CareOverviewController(widget.repository);
  bool _opening = false;
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

  Future<void> _purchase(ServicePackage package) async {
    if (_opening) return;
    _opening = true;
    final existing = controller.overview!.orders
        .where((order) => order.packageId == package.id && order.canResume)
        .firstOrNull;
    try {
      final purchase = existing == null
          ? null
          : await widget.repository.purchase(existing.id);
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
      if (episode != null && mounted) widget.onBook(episode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法打开订单，请稍后重试')));
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('专家支持方案'),
    ),
    body: MomCozyPageBody(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.catalog == null) {
            if (controller.failure case final failure?) {
              return ProductErrorView(
                failure: failure,
                onRetry: controller.load,
              );
            }
            return const ProductLoadingView();
          }
          final package = controller.catalog!.packages
              .where((item) => item.id == widget.packageId)
              .firstOrNull;
          if (package == null) {
            return const ProductEmptyView(title: '没有找到这个服务方案');
          }
          final episode = controller.overview!.episodes
              .where((value) => value.packageId == package.id && value.ongoing)
              .firstOrNull;
          final pending = controller.overview!.orders.any(
            (value) => value.packageId == package.id && value.canResume,
          );
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: MomCozyInsets.page,
                  children: [
                    Text(
                      '${package.name}服务包',
                      style: const TextStyle(
                        fontSize: MomCozyTypography.pageTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MomCozySpacing.content),
                    ProviderTeamTile(providers: controller.catalog!.providers),
                    const SizedBox(height: MomCozySpacing.page),
                    MomCozySurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            package.description,
                            style: const TextStyle(
                              fontSize: MomCozyTypography.bodySize,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: MomCozySpacing.card),
                          Text('${package.sessions} 次 IBCLC 在线咨询'),
                          const SizedBox(height: MomCozySpacing.statusGap),
                          Text('${package.durationDays} 天 · AI 与 App 持续陪伴和跟进'),
                        ],
                      ),
                    ),
                    const SizedBox(height: MomCozySpacing.section),
                    _DeliveryList(
                      title: 'IBCLC 服务',
                      icon: Icons.videocam_outlined,
                      items: package.expertServices,
                    ),
                    const SizedBox(height: MomCozySpacing.section),
                    _DeliveryList(
                      title: 'AI / App 持续服务',
                      icon: Icons.check_rounded,
                      items: package.continuousServices,
                    ),
                    if (episode != null)
                      TextButton(
                        onPressed: () => widget.onProgress(episode),
                        child: const Text('查看我的服务进度'),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(MomCozySpacing.card),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.priceLabel,
                          style: const TextStyle(
                            fontSize: MomCozyTypography.headingSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: episode != null
                            ? () => widget.onBook(episode)
                            : controller.catalog!.paymentMode ==
                                  PaymentMode.disabled
                            ? null
                            : () => _purchase(package),
                        child: Text(
                          episode != null
                              ? '开始预约'
                              : pending
                              ? '继续付款'
                              : controller.catalog!.paymentMode ==
                                    PaymentMode.disabled
                              ? '暂未开放购买'
                              : '购买',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DeliveryList extends StatelessWidget {
  const _DeliveryList({
    required this.title,
    required this.icon,
    required this.items,
  });
  final String title;
  final IconData icon;
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: MomCozyTypography.sectionSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: MomCozySpacing.page),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: MomCozyColors.care),
              const SizedBox(width: MomCozySpacing.statusGap),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: MomCozyTypography.bodySize,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
