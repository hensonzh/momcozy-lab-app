import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';

/// Service presentation primitives adopted from the mother-page Figma library.
class MomServicePrice extends StatelessWidget {
  const MomServicePrice({super.key, required this.package});
  final ServicePackage package;
  @override
  Widget build(BuildContext context) => Text(
    '${package.priceLabel}${package.currency == 'USD' ? ' USD' : ''}',
    style: MomHomeTokens.text(
      20,
      weight: FontWeight.w700,
      color: MomHomeTokens.rose,
    ),
  );
}

class MomServicePackageFacts extends StatelessWidget {
  const MomServicePackageFacts({super.key, required this.package});
  final ServicePackage package;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MomHomeTokens.mint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      spacing: 10,
      children: [
        _fact(
          MomCozyLineGlyph.users,
          '${package.sessions} online IBCLC consultations',
        ),
        _fact(
          MomCozyLineGlyph.calendar,
          '${package.durationDays} days of ongoing support',
        ),
      ],
    ),
  );
  Widget _fact(MomCozyLineGlyph icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MomCozyLineIcon(icon, size: 16, color: MomHomeTokens.teal),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: MomHomeTokens.text(12, color: MomHomeTokens.teal),
        ),
      ),
    ],
  );
}

/// A generic discovery image is separate from each provider's real identity.
class MomProviderTeamCard extends StatelessWidget {
  const MomProviderTeamCard({super.key, required this.providers});
  final List<CareProvider> providers;
  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          'IBCLC expert support',
          style: MomHomeTokens.text(18, weight: FontWeight.w700),
        ),
        Text(
          'Personalized expert care with ongoing AI support',
          style: MomHomeTokens.text(
            12,
            color: MomHomeTokens.secondary,
            height: 1.55,
          ),
        ),
      ],
    );
    final portrait = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.asset(
        MomHomeAssets.experts,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    );
    return MomSettingsCard(
      gradient: MomHomeTokens.expert,
      children: [
        MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 14,
                children: [content, portrait],
              )
            : Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 14),
                  portrait,
                ],
              ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            animationStyle: MomCozyMotion.animationStyle(context),
            barrierColor: const Color(0x472b2423),
            builder: (context) => _MomProviderTeamDialog(providers: providers),
          ),
          child: const Text('Meet the team'),
        ),
      ],
    );
  }
}

class MomProviderIdentity extends StatelessWidget {
  const MomProviderIdentity({super.key, this.provider});
  final CareProvider? provider;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MomHomeTokens.mint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: MomCozyLineIcon(
            MomCozyLineGlyph.users,
            color: MomHomeTokens.teal,
            size: 24,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Text(
              provider?.publicName ?? 'Consultant not assigned yet',
              style: MomHomeTokens.text(14, weight: FontWeight.w700),
            ),
            Text(
              provider == null
                  ? 'Confirm your consultant when booking'
                  : 'IBCLC',
              style: MomHomeTokens.text(11, color: MomHomeTokens.teal),
            ),
            if (provider != null && provider!.languages.isNotEmpty)
              Text(
                provider!.languageLabel,
                style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
              ),
          ],
        ),
      ),
    ],
  );
}

class _MomProviderTeamDialog extends StatelessWidget {
  const _MomProviderTeamDialog({required this.providers});
  final List<CareProvider> providers;
  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Dialog(
        alignment: Alignment.bottomCenter,
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: MomHomeTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: (MediaQuery.sizeOf(context).height * .86).clamp(0, 620),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Text(
                        'IBCLC team',
                        style: MomHomeTokens.text(20, weight: FontWeight.w700),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'IBCLC team',
                          style: MomHomeTokens.text(
                            20,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        Text(
                          'Your package is not assigned to a consultant in advance. After purchase, you can choose from consultants based on your needs and available times.',
                          style: MomHomeTokens.text(
                            13,
                            color: MomHomeTokens.secondary,
                            height: 1.55,
                          ),
                        ),
                        if (providers.isEmpty)
                          MomSettingsCard(
                            color: MomHomeTokens.neutralSurface,
                            children: [
                              Text(
                                'No consultants are available to book right now. Check back later.',
                                style: MomHomeTokens.text(
                                  13,
                                  color: MomHomeTokens.secondary,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        for (final provider in providers)
                          MomSettingsCard(
                            children: [
                              MomProviderIdentity(provider: provider),
                              Text(
                                provider.publicBio,
                                style: MomHomeTokens.text(
                                  12,
                                  color: MomHomeTokens.secondary,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        MomSettingsCard(
                          color: MomHomeTokens.mint,
                          children: [
                            Text(
                              'You will see and confirm your consultant before booking.',
                              style: MomHomeTokens.text(
                                12,
                                color: MomHomeTokens.teal,
                                height: 1.55,
                              ),
                            ),
                          ],
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
    ),
  );
}
