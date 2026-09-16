import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';
import 'mom_service_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../../../shared/care/care_labels.dart';
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
    setState(() => _opening = true);
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
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 96
            : 56,
        leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 88 : 72,
        leading: TextButton(onPressed: widget.onBack, child: const Text('返回')),
        title: const Text('专家支持方案'),
      ),
      body: ClipRect(
        child: MomCozyPageBody(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (controller.catalog == null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: controller.failure != null
                      ? ProductErrorView(
                          failure: controller.failure!,
                          onRetry: controller.load,
                        )
                      : MomSettingsCard(
                          children: [
                            Text(
                              '正在加载服务方案…',
                              style: MomHomeTokens.text(
                                16,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const LinearProgressIndicator(),
                          ],
                        ),
                );
              }
              final package = controller.catalog!.packages
                  .where((item) => item.id == widget.packageId)
                  .firstOrNull;
              if (package == null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MomSettingsCard(
                    children: [
                      Text(
                        '没有找到这个服务方案',
                        style: MomHomeTokens.text(16, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }
              final episode = controller.overview!.episodes
                  .where(
                    (value) => value.packageId == package.id && value.ongoing,
                  )
                  .firstOrNull;
              final pending = controller.overview!.orders.any(
                (value) => value.packageId == package.id && value.canResume,
              );
              final provider = controller.catalog!.providers
                  .where((value) => value.id == episode?.assignedIbclcId)
                  .firstOrNull;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (controller.loading) const LinearProgressIndicator(),
                        if (controller.failure case final failure?)
                          ProductErrorView(
                            failure: failure,
                            onRetry: controller.load,
                          ),
                        if (episode != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              '我的陪伴计划',
                              style: MomHomeTokens.text(
                                18,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        MomSettingsCard(
                          gradient: episode == null ? MomHomeTokens.milk : null,
                          color: episode == null
                              ? MomHomeTokens.surface
                              : MomHomeTokens.mint,
                          children: [
                            Text(
                              '${package.name}服务包',
                              style: MomHomeTokens.text(
                                24,
                                weight: FontWeight.w700,
                              ),
                            ),
                            if (package.subtitle.isNotEmpty)
                              Text(
                                package.subtitle,
                                style: MomHomeTokens.text(
                                  11,
                                  color: MomHomeTokens.secondary,
                                  height: 1.55,
                                ),
                              ),
                            if (episode != null) ...[
                              Text(
                                episodeStatusLabels[episode.status]!,
                                style: MomHomeTokens.text(
                                  12,
                                  weight: FontWeight.w700,
                                  color: MomHomeTokens.teal,
                                ),
                              ),
                              Text(
                                '当前阶段 · ${careStageLabels[episode.stage]}',
                                style: MomHomeTokens.text(
                                  13,
                                  color: MomHomeTokens.teal,
                                ),
                              ),
                              MomProviderIdentity(provider: provider),
                              Text(
                                '剩余 ${episode.remainingSessions} / ${episode.totalSessions} 次咨询',
                                style: MomHomeTokens.text(
                                  16,
                                  weight: FontWeight.w700,
                                  color: MomHomeTokens.teal,
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => widget.onProgress(episode),
                                child: const Text('查看我的服务进度'),
                              ),
                            ],
                            Text(
                              package.description,
                              style: MomHomeTokens.text(
                                13,
                                color: MomHomeTokens.secondary,
                                height: 1.55,
                              ),
                            ),
                            MomServicePackageFacts(package: package),
                          ],
                        ),
                        const SizedBox(height: 14),
                        MomProviderTeamCard(
                          providers: controller.catalog!.providers,
                        ),
                        const SizedBox(height: 14),
                        _DeliveryList(
                          title: 'IBCLC 服务',
                          icon: MomCozyLineGlyph.consultation,
                          items: package.expertServices,
                        ),
                        const SizedBox(height: 14),
                        _DeliveryList(
                          title: 'AI / App 持续服务',
                          icon: MomCozyLineGlyph.calendar,
                          items: package.continuousServices,
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: MomHomeTokens.surface,
                        border: Border(
                          top: BorderSide(color: MomHomeTokens.border),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final price = MomServicePrice(package: package);
                          final button = FilledButton(
                            onPressed:
                                _opening ||
                                    controller.loading ||
                                    controller.failure != null
                                ? null
                                : episode != null
                                ? () => widget.onBook(episode)
                                : controller.catalog!.paymentMode ==
                                      PaymentMode.disabled
                                ? null
                                : () => _purchase(package),
                            child: Text(
                              _opening
                                  ? '正在打开…'
                                  : episode != null
                                  ? '开始预约'
                                  : pending
                                  ? '继续付款'
                                  : controller.catalog!.paymentMode ==
                                        PaymentMode.disabled
                                  ? '暂未开放购买'
                                  : '购买',
                            ),
                          );
                          if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              spacing: 14,
                              children: [price, button],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: price),
                              const SizedBox(width: 14),
                              Expanded(child: button),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
  final MomCozyLineGlyph icon;
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: MomHomeTokens.text(18, weight: FontWeight.w700),
        ),
      ),
      MomSettingsCard(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: MomHomeTokens.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MomCozyLineIcon(icon, size: 18, color: MomHomeTokens.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: MomHomeTokens.text(13, height: 1.55),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ],
  );
}
