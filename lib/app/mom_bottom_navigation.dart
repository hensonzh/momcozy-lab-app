import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/design_system/momcozy_design_system.dart';

class MomCozyBottomNavigation extends StatelessWidget {
  const MomCozyBottomNavigation({super.key, required this.location});
  final String location;
  @override
  Widget build(BuildContext context) {
    final selected = location == '/'
        ? 2
        : location.startsWith('/baby')
        ? 1
        : location.startsWith('/schedule')
        ? 3
        : location.startsWith('/more')
        ? 4
        : location.startsWith('/me')
        ? 0
        : -1;
    const tabs = [
      (label: 'Me', path: '/me', icon: Icons.person_outline_rounded),
      (label: 'Baby', path: '/baby', icon: Icons.child_care_rounded),
      (label: 'Cozymate', path: '/', icon: Icons.auto_awesome_outlined),
      (
        label: 'Schedule',
        path: '/schedule',
        icon: Icons.calendar_today_outlined,
      ),
      (label: 'More', path: '/more', icon: Icons.more_horiz_rounded),
    ];
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(10) > 12;
    final labelLines = largeText ? 2 : 1;
    final width =
        MediaQuery.sizeOf(context).width.clamp(0.0, MomCozyLayout.maxAppWidth) /
        tabs.length;
    var labelHeight = 0.0;
    for (final tab in tabs) {
      final painter = TextPainter(
        text: TextSpan(
          text: tab.label,
          style: DefaultTextStyle.of(context).style.copyWith(
            fontSize: MomCozyTypography.microSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: labelLines,
      )..layout(maxWidth: width);
      if (painter.height > labelHeight) labelHeight = painter.height;
      painter.dispose();
    }
    final navigationHeight = largeText
        ? (61 + labelHeight).clamp(76.0, double.infinity)
        : 76.0;
    return Material(
      color: MomCozyColors.raised,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: MomCozyLayout.maxAppWidth,
            ),
            child: SizedBox(
              height: navigationHeight,
              child: Row(
                children: [
                  for (var index = 0; index < tabs.length; index++)
                    Expanded(
                      child: Semantics(
                        selected: selected == index,
                        child: InkWell(
                          key: ValueKey(
                            'bottom-nav-${tabs[index].label.toLowerCase()}',
                          ),
                          onTap: () => context.go(tabs[index].path),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (index == 2)
                                  Container(
                                    width: 42,
                                    height: 42,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected == index
                                            ? MomCozyColors.violet
                                            : MomCozyColors.violetSoft,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        MomCozyAssets.agentAvatar,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 42,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: selected == index
                                          ? MomCozyColors.violetSoft
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        MomCozyRadii.navigation,
                                      ),
                                    ),
                                    child: Icon(
                                      tabs[index].icon,
                                      size: 24,
                                      color: selected == index
                                          ? MomCozyColors.violet
                                          : MomCozyColors.navigationInactive,
                                    ),
                                  ),
                                if (index != 2) const SizedBox(height: 8),
                                const SizedBox(height: 3),
                                Text(
                                  tabs[index].label,
                                  maxLines: labelLines,
                                  textAlign: largeText
                                      ? TextAlign.center
                                      : TextAlign.start,
                                  style: TextStyle(
                                    fontSize: MomCozyTypography.microSize,
                                    fontWeight: FontWeight.w600,
                                    color: selected == index
                                        ? MomCozyColors.violet
                                        : MomCozyColors.navigationInactive,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
}
