import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../shared/design_system/momcozy_design_system.dart';

/// Shared navigation, calibrated against Figma 483:1058 / 691:116.
class MomCozyBottomNavigation extends StatelessWidget {
  const MomCozyBottomNavigation({super.key, required this.location});
  final String location;
  static const _surface = Color(0xfffffcfa);
  static const _assetRoot = 'assets/images/navigation_figma/';
  static const _tabs = [
    (label: 'Me', path: '/me', asset: 'ArtworkSoftMe.png'),
    (label: 'Baby', path: '/baby', asset: 'ArtworkSoftBaby.png'),
    (label: 'Momcozy AI', path: '/', asset: 'AvatarCozymateNav.png'),
    (label: 'Schedule', path: '/schedule', asset: 'ArtworkColorSchedule.svg'),
    (label: 'More', path: '/more', asset: 'ArtworkColorMore.svg'),
  ];

  TextStyle _labelStyle(String label, bool selected) {
    final weight = selected
        ? (label == 'Baby' ? FontWeight.w700 : FontWeight.w600)
        : FontWeight.w500;
    return TextStyle(
      fontFamily: 'DMSans',
      fontSize: 12,
      height: 16 / 12,
      fontWeight: weight,
      letterSpacing: 0,
      color: selected ? const Color(0xffa14d72) : const Color(0xff786d77),
      fontVariations: [
        const FontVariation('opsz', 14),
        FontVariation('wght', weight.value.toDouble()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.clamp(0.0, MomCozyLayout.maxAppWidth);
      final itemWidth = (width - 16) / _tabs.length;
      final scaler = MediaQuery.textScalerOf(context);
      final compactLabels =
          scaler.scale(1) > 1.3 &&
          _tabs.any(
            (tab) => tab.label.split(' ').any((word) {
              final painter = TextPainter(
                text: TextSpan(text: word, style: _labelStyle(tab.label, true)),
                textDirection: Directionality.of(context),
                textScaler: scaler,
              )..layout();
              final tooWide = painter.width > itemWidth - 2;
              painter.dispose();
              return tooWide;
            }),
          );
      var labelHeight = 16.0;
      var selectedLabelWidth = itemWidth;
      for (final tab in _tabs) {
        final painter = TextPainter(
          text: TextSpan(text: tab.label, style: _labelStyle(tab.label, true)),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: compactLabels ? double.infinity : itemWidth);
        if (painter.height > labelHeight) labelHeight = painter.height;
        if (tab.path == location && compactLabels) {
          selectedLabelWidth = (painter.width + 12).clamp(
            itemWidth,
            width - 16,
          );
        }
        painter.dispose();
      }
      final selectedIndex = _tabs.indexWhere((tab) => tab.path == location);
      final selectedLabelLeft = selectedIndex < 0
          ? 8.0
          : (8 + itemWidth * (selectedIndex + .5) - selectedLabelWidth / 2)
                .clamp(8.0, width - 8 - selectedLabelWidth);
      final extra = labelHeight - 16;
      // Keep the bar's height stable when the keyboard consumes bottom padding.
      final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
      // Reserve the raised avatar/shadow inside the hit region, so the entire
      // image is tappable. The colored chrome remains the design's 82px.
      return Material(
        color: Colors.transparent,
        child: SizedBox(
          height: 100 + extra + safeBottom,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 18,
                bottom: 0,
                child: ColoredBox(color: _surface),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 18,
                child: Container(
                  key: const ValueKey('bottom-nav-chrome'),
                  height: 82 + extra,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0x38c6b6c2), width: .5),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  height: 81 + extra,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                              labelHeight: labelHeight,
                              compactLabels: compactLabels,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (compactLabels && selectedIndex >= 0)
                Positioned(
                  top: 65,
                  left: selectedLabelLeft,
                  width: selectedLabelWidth,
                  height: labelHeight,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Text(
                        _tabs[selectedIndex].label,
                        key: const ValueKey('bottom-nav-selected-label'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: _labelStyle(_tabs[selectedIndex].label, true),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _destination(
    BuildContext context, {
    required String label,
    required String path,
    required String asset,
    required double labelHeight,
    required bool compactLabels,
  }) {
    final selected = location == path;
    final center = path == '/';
    return Semantics(
      label: compactLabels ? label : null,
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('bottom-nav-${label.toLowerCase()}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(path),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: center ? 4 : 26,
              left: 0,
              right: 0,
              child: Center(
                child: center
                    ? Container(
                        key: const ValueKey('bottom-nav-center-avatar'),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xffe9def5),
                          shape: BoxShape.circle,
                          border: Border.all(color: _surface, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1a7a5e91),
                              offset: Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          '$_assetRoot$asset',
                          width: 54,
                          height: 54,
                          excludeFromSemantics: true,
                        ),
                      )
                    : Container(
                        width: 42,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xfff8e8ef)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: asset.endsWith('.svg')
                            ? SvgPicture.asset(
                                '$_assetRoot$asset',
                                width: 28,
                                height: 28,
                                excludeFromSemantics: true,
                              )
                            : Image.asset(
                                '$_assetRoot$asset',
                                width: 28,
                                height: 28,
                                excludeFromSemantics: true,
                              ),
                      ),
              ),
            ),
            if (!compactLabels)
              Positioned(
                top: 65,
                left: 0,
                right: 0,
                height: labelHeight,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _labelStyle(label, selected),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
