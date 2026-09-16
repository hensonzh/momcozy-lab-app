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
        _fact(MomCozyLineGlyph.users, '${package.sessions} 次 IBCLC 在线咨询'),
        _fact(MomCozyLineGlyph.calendar, '${package.durationDays} 天持续陪伴'),
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
          'IBCLC 专家团队服务',
          style: MomHomeTokens.text(18, weight: FontWeight.w700),
        ),
        Text(
          '真人专家 + AI 持续陪伴',
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
          child: const Text('了解团队'),
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
              provider?.displayName ?? '待分配专家',
              style: MomHomeTokens.text(14, weight: FontWeight.w700),
            ),
            Text(
              provider == null ? '预约时确认本次专家' : 'IBCLC',
              style: MomHomeTokens.text(11, color: MomHomeTokens.teal),
            ),
            if (provider != null && provider!.languages.isNotEmpty)
              Text(
                provider!.languages.join(' · '),
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
                        'IBCLC 专家团队',
                        style: MomHomeTokens.text(20, weight: FontWeight.w700),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'IBCLC 专家团队',
                          style: MomHomeTokens.text(
                            20,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
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
                          '服务包不会预先绑定某一位专家。购买后，我们会结合你的问题和可预约时间，提供可选的专家。',
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
                                '当前暂无可预约专家，请稍后再来查看。',
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
                                provider.bio,
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
                              '预约确认前，你会看到并确认本次具体专家。',
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
