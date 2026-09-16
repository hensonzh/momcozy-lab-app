import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../shared/design_system/momcozy_design_system.dart';

class MomCozyBottomNavigation extends StatelessWidget {
  const MomCozyBottomNavigation({super.key, required this.location});

  final String location;

  static const _tabs = [
    (label: 'Me', path: '/me', asset: MomCozyAssets.bottomNavMe),
    (label: 'Baby', path: '/baby', asset: MomCozyAssets.bottomNavBaby),
    (label: 'Cozymate', path: '/', asset: null),
    (
      label: 'Schedule',
      path: '/schedule',
      asset: MomCozyAssets.bottomNavSchedule,
    ),
    (label: 'More', path: '/more', asset: MomCozyAssets.bottomNavMore),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: MomCozyShadows.navigation),
      child: Material(
        color: MomCozyColors.navigationSurface,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MomCozyLayout.maxAppWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScaler = MediaQuery.textScalerOf(context);
                  final largeText = textScaler.scale(11) > 13.2;
                  final labelLines = largeText ? 2 : 1;
                  final itemWidth = (constraints.maxWidth - 16) / _tabs.length;
                  var labelHeight = 14.0;
                  for (final tab in _tabs) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: tab.label,
                        style: DefaultTextStyle.of(context).style
                            .merge(MomCozyTypography.navigationLabel)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: textScaler,
                      maxLines: labelLines,
                    )..layout(maxWidth: itemWidth);
                    if (painter.height > labelHeight) {
                      labelHeight = painter.height;
                    }
                    painter.dispose();
                  }
                  // Keep the reference's 78px bar, growing only when scaled
                  // labels require more room. SafeArea adds the device inset.
                  final height = (62 + labelHeight).clamp(
                    MomCozyLayout.bottomNavHeight,
                    double.infinity,
                  );
                  return Container(
                    key: const ValueKey('bottom-nav-chrome'),
                    height: height,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: MomCozyColors.navigationBorder),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: _destination(
                              context,
                              label: tab.label,
                              path: tab.path,
                              asset: tab.asset,
                              labelLines: labelLines,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required String label,
    required String path,
    required String? asset,
    required int labelLines,
  }) {
    final selected = location == path;
    final color = selected
        ? MomCozyColors.violet
        : MomCozyColors.navigationInactive;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('bottom-nav-${label.toLowerCase()}'),
        borderRadius: BorderRadius.circular(MomCozySpacing.page),
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (asset == null)
                Container(
                  width: MomCozyLayout.bottomNavCenterSize,
                  height: MomCozyLayout.bottomNavCenterSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MomCozyColors.navigationAvatar,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: MomCozyShadows.navigationAvatar(
                      selected: selected,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      MomCozyAssets.agentAvatar,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? MomCozyColors.navigationSelected
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      MomCozyRadii.navigation,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    asset,
                    width: MomCozyIconSizes.standard,
                    height: MomCozyIconSizes.standard,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    excludeFromSemantics: true,
                  ),
                ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: labelLines,
                textAlign: TextAlign.center,
                style: MomCozyTypography.navigationLabel.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
