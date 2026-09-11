import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../application/care_overview_controller.dart';

class ServiceCatalogPage extends StatefulWidget {
  const ServiceCatalogPage({
    super.key,
    required this.repository,
    required this.onSelect,
    required this.onBack,
  });
  final CareRepository repository;
  final ValueChanged<ServicePackage> onSelect;
  final VoidCallback onBack;
  @override
  State<ServiceCatalogPage> createState() => _ServiceCatalogPageState();
}

class _ServiceCatalogPageState extends State<ServiceCatalogPage> {
  late final controller = CareOverviewController(widget.repository);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('专家支持'),
      leading: BackButton(onPressed: widget.onBack),
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
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: MomCozyInsets.page,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '泌乳支持',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('4 个方案'),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        enabled: false,
                        title: Text('产后康复'),
                        subtitle: Text('陆续开放'),
                      ),
                    ),
                  ],
                ),
                ProviderTeamTile(providers: controller.catalog!.providers),
                const SizedBox(height: MomCozySpacing.card),
                for (final package in controller.catalog!.packages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: MomCozySurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final title = Text(
                                package.name,
                                style: MomCozyTypography.sectionTitle,
                              );
                              final price = Text(
                                package.priceLabel,
                                style: MomCozyTypography.heading,
                              );
                              if (constraints.maxWidth < 320 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    const SizedBox(
                                      height: MomCozySpacing.compact,
                                    ),
                                    price,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: title),
                                  const SizedBox(width: MomCozySpacing.content),
                                  price,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: MomCozySpacing.content),
                          Text(
                            package.description,
                            style: const TextStyle(
                              fontSize: MomCozyTypography.secondarySize,
                              color: MomCozyColors.mutedForeground,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: MomCozySpacing.page),
                          Text(
                            '真人 IBCLC 专家支持 · ${package.sessions} 次在线咨询',
                            style: const TextStyle(
                              fontSize: MomCozyTypography.captionSize,
                            ),
                          ),
                          const SizedBox(height: MomCozySpacing.statusGap),
                          Text(
                            '${package.durationDays} 天 · 由 AI 与 App 持续陪伴和跟进',
                            style: const TextStyle(
                              fontSize: MomCozyTypography.captionSize,
                            ),
                          ),
                          const SizedBox(height: MomCozySpacing.page),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () => widget.onSelect(package),
                              child: Text(
                                controller.overview!.orders.any(
                                      (order) =>
                                          order.packageId == package.id &&
                                          order.canResume,
                                    )
                                    ? '继续付款'
                                    : controller.overview!.episodes.any(
                                        (episode) =>
                                            episode.packageId == package.id &&
                                            episode.ongoing,
                                      )
                                    ? '查看我的服务'
                                    : '查看方案 →',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class ProviderTeamTile extends StatelessWidget {
  const ProviderTeamTile({super.key, required this.providers});
  final List<CareProvider> providers;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(
      backgroundColor: MomCozyColors.violetSoft,
      child: Icon(Icons.people_outline_rounded, color: MomCozyColors.violet),
    ),
    title: const Text(
      'IBCLC 专家团队',
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: const Text('根据你的问题与时间，选择合适的专家'),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('认识专家团队'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('服务包不会预先绑定某一位专家。购买后，我们会结合你的问题和可预约时间，提供可选的专家。'),
                const SizedBox(height: MomCozySpacing.page),
                if (providers.isEmpty) const Text('当前暂无可预约专家，请稍后再来查看。'),
                for (final provider in providers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(provider.displayName),
                    subtitle: Text(
                      'IBCLC\n${provider.bio}\n${provider.languages.join(' · ')}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    ),
  );
}
