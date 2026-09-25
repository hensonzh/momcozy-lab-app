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
    if (_opening || !package.hasEnglishPurchaseDetails) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the order. Try again later.'),
          ),
        );
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
            ? 112
            : 56,
        leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 88 : 72,
        leading: TextButton(
          onPressed: widget.onBack,
          child: const Text('Back'),
        ),
        title: const Text(
          'Expert support',
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
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
                              'Loading service plan…',
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
                        'Could not find this service plan',
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
                              'My care plan',
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
                              '${package.publicName} package',
                              style: MomHomeTokens.text(
                                24,
                                weight: FontWeight.w700,
                              ),
                            ),
                            if (package.publicSubtitle.isNotEmpty)
                              Text(
                                package.publicSubtitle,
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
                                'Current stage · ${careStageLabels[episode.stage]}',
                                style: MomHomeTokens.text(
                                  13,
                                  color: MomHomeTokens.teal,
                                ),
                              ),
                              MomProviderIdentity(provider: provider),
                              Text(
                                '${episode.remainingSessions} of ${episode.totalSessions} consultations left',
                                style: MomHomeTokens.text(
                                  16,
                                  weight: FontWeight.w700,
                                  color: MomHomeTokens.teal,
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => widget.onProgress(episode),
                                child: const Text('View service progress'),
                              ),
                            ],
                            Text(
                              package.publicDescription,
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
                        if (!package.hasEnglishPurchaseDetails) ...[
                          const SizedBox(height: 14),
                          const MomSettingsCard(
                            color: MomHomeTokens.neutralSurface,
                            children: [
                              Text(
                                'Plan details need English review',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Purchase is paused until the included services are available in English.',
                                style: TextStyle(height: 1.5),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        _DeliveryList(
                          title: 'IBCLC support',
                          icon: MomCozyLineGlyph.consultation,
                          items: package.publicExpertServices,
                        ),
                        const SizedBox(height: 14),
                        _DeliveryList(
                          title: 'Ongoing AI & app support',
                          icon: MomCozyLineGlyph.calendar,
                          items: package.publicContinuousServices,
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
                                          PaymentMode.disabled ||
                                      !package.hasEnglishPurchaseDetails
                                ? null
                                : () => _purchase(package),
                            child: Text(
                              _opening
                                  ? 'Opening…'
                                  : episode != null
                                  ? 'Book an appointment'
                                  : pending
                                  ? 'Continue to payment'
                                  : controller.catalog!.paymentMode ==
                                        PaymentMode.disabled
                                  ? 'Not available to purchase yet'
                                  : 'Purchase',
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
