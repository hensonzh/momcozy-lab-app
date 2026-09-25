import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/care_episode.dart';
import '../../../shared/care/care_labels.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import 'mom_service_widgets.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
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

  CareEpisode? _episode(ServicePackage package) => controller.overview!.episodes
      .where((episode) => episode.packageId == package.id && episode.ongoing)
      .firstOrNull;
  bool _pending(ServicePackage package) => controller.overview!.orders.any(
    (order) => order.packageId == package.id && order.canResume,
  );
  Widget _package(ServicePackage package) {
    final episode = _episode(package);
    final pending = _pending(package);
    return _PackageCard(
      package: package,
      pending: pending,
      purchased: controller.overview!.orders.any(
        (order) =>
            order.packageId == package.id &&
            order.status == CareOrderStatus.paid,
      ),
      episode: pending ? null : episode,
      provider: controller.catalog!.providers
          .where((provider) => provider.id == episode?.assignedIbclcId)
          .firstOrNull,
      action: pending
          ? package.hasEnglishPurchaseDetails
                ? 'Continue to payment'
                : 'Review plan'
          : episode != null
          ? 'View my services'
          : 'View plans →',
      onSelect: () => widget.onSelect(package),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 88 : 72,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 112
            : 56,
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
                              'Loading service plans…',
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
              final catalog = controller.catalog!;
              final pending = catalog.packages.where(_pending).toList();
              final ongoing = catalog.packages
                  .where((p) => !_pending(p) && _episode(p) != null)
                  .toList();
              final available = catalog.packages
                  .where((p) => !_pending(p) && _episode(p) == null)
                  .toList();
              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (controller.loading) const LinearProgressIndicator(),
                    if (controller.failure case final failure?)
                      ProductErrorView(
                        failure: failure,
                        onRetry: controller.load,
                      ),
                    MomProviderTeamCard(providers: catalog.providers),
                    if (pending.isNotEmpty) ...[
                      const _CatalogHeading('Pending orders'),
                      for (final package in pending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _package(package),
                        ),
                    ],
                    if (ongoing.isNotEmpty) ...[
                      const _CatalogHeading('My care plan'),
                      for (final package in ongoing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _package(package),
                        ),
                    ],
                    const SizedBox(height: 14),
                    _ServiceDirections(count: catalog.packages.length),
                    if (available.isNotEmpty || catalog.packages.isEmpty) ...[
                      _CatalogHeading(
                        pending.isNotEmpty || ongoing.isNotEmpty
                            ? 'More care plans'
                            : 'Find support that fits you',
                      ),
                      Text(
                        'Personalized IBCLC support, with ongoing guidance through AI and the app.',
                        style: MomHomeTokens.text(
                          12,
                          color: MomHomeTokens.secondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (catalog.packages.isEmpty)
                      MomSettingsCard(
                        children: [
                          Text(
                            'No service plans available',
                            style: MomHomeTokens.text(
                              16,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'New plans will appear here when available.',
                            style: MomHomeTokens.text(
                              13,
                              color: MomHomeTokens.secondary,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    for (final package in available)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _package(package),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _CatalogHeading extends StatelessWidget {
  const _CatalogHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: MomHomeTokens.text(18, weight: FontWeight.w700),
      ),
    ),
  );
}

class _ServiceDirections extends StatelessWidget {
  const _ServiceDirections({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [_direction(true), _direction(false)],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Expanded(child: _direction(true)),
        Expanded(child: _direction(false)),
      ],
    );
  }

  Widget _direction(bool active) => Semantics(
    selected: active,
    enabled: active,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xfff8e8ec) : MomHomeTokens.neutralSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text(
            active ? 'Lactation support' : 'Postpartum recovery',
            style: MomHomeTokens.text(
              14,
              weight: FontWeight.w700,
              color: active ? MomHomeTokens.rose : MomHomeTokens.secondary,
            ),
          ),
          Text(
            active ? '$count plans' : 'Coming soon',
            style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
          ),
        ],
      ),
    ),
  );
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.purchased,
    required this.pending,
    required this.action,
    required this.onSelect,
    this.episode,
    this.provider,
  });
  final ServicePackage package;
  final bool purchased, pending;
  final String action;
  final VoidCallback onSelect;
  final CareEpisode? episode;
  final CareProvider? provider;
  @override
  Widget build(BuildContext context) {
    final e = episode;
    final price = MomServicePrice(package: package);
    final button = OutlinedButton(onPressed: onSelect, child: Text(action));
    return MomSettingsCard(
      color: e != null
          ? MomHomeTokens.mint
          : pending
          ? MomHomeTokens.neutralSurface
          : MomHomeTokens.surface,
      children: [
        Text(
          package.publicName,
          style: MomHomeTokens.text(20, weight: FontWeight.w700),
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
          MomProviderIdentity(provider: provider),
          Text(
            '${package.durationDays} days of support',
            style: MomHomeTokens.text(12, color: MomHomeTokens.teal),
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
          FilledButton(onPressed: onSelect, child: Text(action)),
        ] else if (pending) ...[
          Text(
            package.hasEnglishPurchaseDetails
                ? 'Your order is not complete yet. Continue to payment.'
                : 'This plan needs English details before payment can continue.',
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
          MomServicePackageFacts(package: package),
          price,
          FilledButton(onPressed: onSelect, child: Text(action)),
        ] else ...[
          if (purchased)
            Text(
              'Purchased',
              style: MomHomeTokens.text(12, color: MomHomeTokens.teal),
            ),
          Text(
            package.publicDescription,
            style: MomHomeTokens.text(
              13,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
          MomServicePackageFacts(package: package),
          MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [price, button],
                )
              : Row(
                  children: [
                    Expanded(child: price),
                    const SizedBox(width: 14),
                    button,
                  ],
                ),
        ],
      ],
    );
  }
}

/// Shared catalog/detail metadata, sourced from the existing catalog contract.
class ServicePackageFacts extends StatelessWidget {
  const ServicePackageFacts({super.key, required this.package});
  final ServicePackage package;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MomCozyLineIcon(
            MomCozyLineGlyph.users,
            size: 15,
            color: MomCozyColors.serviceTeamInk,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'IBCLC expert support  |  ${package.sessions} online consultations',
              style: const TextStyle(
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: MomCozyColors.serviceTeamInk,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MomCozyLineIcon(
            MomCozyLineGlyph.calendar,
            size: 14,
            color: MomCozyColors.serviceTeamInk,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${package.durationDays} days  |  Ongoing AI and app support',
              style: const TextStyle(
                fontSize: 10,
                height: 1.4,
                color: MomCozyColors.serviceTeamInk,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class ServicePrice extends StatelessWidget {
  const ServicePrice({super.key, required this.package});
  final ServicePackage package;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: package.priceLabel,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MomCozyColors.primaryDark,
          ),
        ),
        if (package.currency == 'USD')
          const TextSpan(
            text: ' USD',
            style: TextStyle(fontSize: 9, color: MomCozyColors.mutedForeground),
          ),
      ],
    ),
  );
}

class ProviderTeamTile extends StatelessWidget {
  const ProviderTeamTile({super.key, required this.providers});
  final List<CareProvider> providers;
  @override
  Widget build(BuildContext context) => Material(
    color: MomCozyColors.serviceTeamSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: const BorderSide(color: MomCozyColors.serviceTeamBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => showDialog<void>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        barrierColor: const Color(0x472b2423),
        builder: (context) => _ProviderTeamDialog(providers: providers),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            // The API has no portrait field. Use a neutral team mark, never a
            // design persona's photograph as a real provider's identity.
            const CircleAvatar(
              radius: 18,
              backgroundColor: MomCozyColors.card,
              child: MomCozyLineIcon(
                MomCozyLineGlyph.users,
                size: 22,
                color: MomCozyColors.serviceTeamInk,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Meet the IBCLC team',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MomCozyColors.serviceTeamInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Learn about the team',
              style: TextStyle(
                fontSize: 10,
                color: MomCozyColors.serviceTeamInk,
              ),
            ),
            const SizedBox(width: 2),
            const MomCozyLineIcon(
              MomCozyLineGlyph.arrow,
              size: 14,
              color: MomCozyColors.serviceTeamInk,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProviderTeamDialog extends StatelessWidget {
  const _ProviderTeamDialog({required this.providers});
  final List<CareProvider> providers;
  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
    child: Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: MomCozyColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
          bottom: Radius.circular(18),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: (MediaQuery.sizeOf(context).height * .86).clamp(0, 620),
        ),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'IBCLC team',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Your package is not assigned to a consultant in advance. After purchase, you can choose from consultants based on your needs and available times.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.55,
                          color: MomCozyColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 13),
                      if (providers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No consultants are available to book right now. Check back later.',
                          ),
                        ),
                      for (final provider in providers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: MomCozyColors.serviceTeamSurface,
                              border: Border.all(
                                color: MomCozyColors.serviceTeamBorder,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: MomCozyColors.card,
                                  child: MomCozyLineIcon(
                                    MomCozyLineGlyph.users,
                                    color: MomCozyColors.serviceTeamInk,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.publicName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: MomCozyColors.serviceTeamInk,
                                        ),
                                      ),
                                      const Text(
                                        'IBCLC',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: MomCozyColors.serviceTeamInk,
                                        ),
                                      ),
                                      Text(
                                        provider.languageLabel,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: MomCozyColors.mutedForeground,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        provider.publicBio,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          height: 1.45,
                                          color: MomCozyColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MomCozyColors.careSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MomCozyLineIcon(
                              MomCozyLineGlyph.shield,
                              size: 15,
                              color: MomCozyColors.care,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'You will see and confirm your consultant before booking.',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.45,
                                  color: MomCozyColors.serviceTeamInk,
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
            ],
          ),
        ),
      ),
    ),
  );
}
