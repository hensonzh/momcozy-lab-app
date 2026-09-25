import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/care/care_labels.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import 'mom_service_widgets.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';
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
    if (!package.hasEnglishPurchaseDetails) {
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
      if (mounted) {
        setState(
          () => _openError =
              'Could not open the order. Select a plan and try again.',
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
            ? 72
            : 64,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          color: MomHomeTokens.rose,
          icon: const Icon(Icons.chevron_left, size: 24),
        ),
        title: Text(
          'Continue care',
          style: MomHomeTokens.text(20, weight: FontWeight.w700),
        ),
      ),
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
                  if (controller.failure case final failure?)
                    ProductErrorView(
                      failure: failure,
                      onRetry: controller.load,
                      useMomStyle: true,
                    )
                  else if (catalog == null)
                    const _RenewCatalogState(loading: true)
                  else ...[
                    Text(
                      'Choose the support that fits your needs now',
                      style: MomHomeTokens.text(
                        13,
                        color: MomHomeTokens.secondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (controller.loading || _opening)
                      const LinearProgressIndicator(minHeight: 2),
                    if (catalog.packages.isEmpty)
                      _RenewCatalogState(onRefresh: controller.load),
                    for (final package in catalog.packages)
                      _RenewPackageCard(
                        package: package,
                        episode: controller.overview!.episodes
                            .where(
                              (e) => e.packageId == package.id && e.ongoing,
                            )
                            .firstOrNull,
                        providers: catalog.providers,
                        selected: package.id == selected,
                        error: package.id == _selected ? _openError : null,
                        enabled:
                            !_opening &&
                            !controller.loading &&
                            ((catalog.paymentMode != PaymentMode.disabled &&
                                    package.hasEnglishPurchaseDetails) ||
                                controller.overview!.episodes.any(
                                  (e) => e.packageId == package.id && e.ongoing,
                                )),
                        label:
                            controller.overview!.episodes.any(
                              (e) => e.packageId == package.id && e.ongoing,
                            )
                            ? 'View my services'
                            : catalog.paymentMode == PaymentMode.disabled
                            ? 'Not available to purchase yet'
                            : !package.hasEnglishPurchaseDetails
                            ? 'English details pending'
                            : controller.overview!.orders.any(
                                (o) => o.packageId == package.id && o.canResume,
                              )
                            ? 'Continue to payment'
                            : 'Select',
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
    this.error,
    required this.episode,
    required this.providers,
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onSelect,
  });
  final ServicePackage package;
  final CareEpisode? episode;
  final List<CareProvider> providers;
  final bool selected, enabled;
  final String label;
  final String? error;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final e = episode;
    return Semantics(
      selected: selected,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
            border: selected ? Border.all(color: MomHomeTokens.rose) : null,
          ),
          child: MomSettingsCard(
            color: e == null ? MomHomeTokens.surface : MomHomeTokens.mint,
            children: [
              Text(
                package.publicName,
                style: MomHomeTokens.text(20, weight: FontWeight.w700),
              ),
              if (e != null) ...[
                Text(
                  episodeStatusLabels[e.status]!,
                  style: MomHomeTokens.text(
                    12,
                    weight: FontWeight.w700,
                    color: MomHomeTokens.teal,
                  ),
                ),
                Text(
                  'Current stage · ${careStageLabels[e.stage]}',
                  style: MomHomeTokens.text(13, color: MomHomeTokens.teal),
                ),
                MomProviderIdentity(
                  provider: providers
                      .where((p) => p.id == e.assignedIbclcId)
                      .firstOrNull,
                ),
                Text(
                  '${e.remainingSessions} of ${e.totalSessions} consultations left',
                  style: MomHomeTokens.text(
                    16,
                    weight: FontWeight.w700,
                    color: MomHomeTokens.teal,
                  ),
                ),
                Text(
                  package.publicDescription,
                  style: MomHomeTokens.text(
                    12,
                    color: MomHomeTokens.secondary,
                    height: 1.55,
                  ),
                ),
                Text(
                  'Plan price · ${package.priceLabel}${package.currency == 'USD' ? ' USD' : ''}',
                  style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
                ),
              ] else ...[
                if (label == 'Continue to payment')
                  Text(
                    'Your order is not complete yet. Continue to payment.',
                    style: MomHomeTokens.text(
                      13,
                      color: MomHomeTokens.secondary,
                      height: 1.55,
                    ),
                  ),
                Text(
                  package.publicDescription,
                  style: MomHomeTokens.text(
                    13,
                    color: MomHomeTokens.secondary,
                    height: 1.55,
                  ),
                ),
                if (!package.hasEnglishPurchaseDetails)
                  Text(
                    'Plan details need English review before purchase.',
                    style: MomHomeTokens.text(
                      12,
                      color: MomHomeTokens.secondary,
                      height: 1.55,
                    ),
                  ),
                MomServicePackageFacts(package: package),
                MomServicePrice(package: package),
              ],
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: MomSettingsCard(
                    color: MomCozyColors.amberSoft,
                    children: [
                      Text(
                        error!,
                        style: MomHomeTokens.text(
                          13,
                          color: MomHomeTokens.secondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              FilledButton(
                onPressed: enabled ? onSelect : null,
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenewCatalogState extends StatelessWidget {
  const _RenewCatalogState({this.loading = false, this.onRefresh});
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      children: [
        Text(
          loading ? 'Loading care plans' : 'No care plans available',
          style: MomHomeTokens.text(18, weight: FontWeight.w700),
        ),
        Text(
          loading
              ? 'Please wait. You do not need to repeat this action.'
              : 'Check back later. You can still view your existing service records.',
          style: MomHomeTokens.text(
            13,
            color: MomHomeTokens.secondary,
            height: 1.55,
          ),
        ),
        if (loading)
          const LinearProgressIndicator(minHeight: 4)
        else
          TextButton(onPressed: onRefresh, child: const Text('Refresh plans')),
      ],
    ),
  );
}
