import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../design_system/mom_home_tokens.dart';
import 'mom_card_background.dart';
export 'mom_card_background.dart';

class MomHomeSectionHeader extends StatelessWidget {
  const MomHomeSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onTap,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: MomHomeTokens.text(18, weight: FontWeight.w700),
    );
    final button = action == null
        ? null
        : TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              foregroundColor: MomHomeTokens.rose,
              textStyle: MomHomeTokens.text(12),
            ),
            child: Text(action!),
          );
    return LayoutBuilder(
      builder: (context, c) => MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, ?button],
            )
          : SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(child: heading),
                  ?button,
                ],
              ),
            ),
    );
  }
}

class MomHomeSurface extends StatelessWidget {
  const MomHomeSurface({
    super.key,
    required this.child,
    required this.gradient,
    this.onTap,
    this.radius = 22,
    this.border,
    this.semanticLabel,
    this.borderInside = false,
    this.backgroundDecoration,
  });
  final Widget child;
  final Gradient gradient;
  final VoidCallback? onTap;
  final double radius;
  final Color? border;
  final String? semanticLabel;

  /// Paint the stroke inside the surface without adding it to content padding.
  final bool borderInside;
  final MomCardDecoration? backgroundDecoration;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: semanticLabel != null,
    onTap: semanticLabel == null ? null : onTap,
    button: onTap != null,
    child: Material(
      color: Colors.transparent,
      shape: borderInside
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: border ?? Colors.transparent),
            )
          : null,
      borderRadius: borderInside ? null : BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: border == null || borderInside
              ? null
              : Border.all(color: border!),
        ),
        child: InkWell(
          onTap: onTap,
          child: backgroundDecoration == null
              ? child
              : MomCardBackground(
                  decoration: backgroundDecoration!,
                  child: child,
                ),
        ),
      ),
    ),
  );
}

Widget momDecoration(String name, double width, double height) =>
    ExcludeSemantics(
      child: SvgPicture.asset(
        MomHomeAssets.exported(name),
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );

class MomExpertPlanEntry extends StatelessWidget {
  const MomExpertPlanEntry({
    super.key,
    required this.onTap,
    this.title = '让专业的人，陪你把问题解决',
    this.trailingGap = 5,
    this.settingsLayout = false,
  });
  final VoidCallback onTap;
  final String title;
  final double trailingGap;

  /// Settings component 122:41 has an inside stroke and 20/14 text leading.
  final bool settingsLayout;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: MomHomeTokens.expert,
    radius: 18,
    border: MomHomeTokens.border,
    borderInside: settingsLayout,
    onTap: onTap,
    child: Stack(
      children: [
        Positioned(
          right: settingsLayout ? -37 : -36,
          top: settingsLayout ? -28 : -29,
          child: momDecoration('imgDecorationExpertSupportHalo', 112, 112),
        ),
        Positioned(
          right: settingsLayout ? 13 : 14,
          top: settingsLayout ? 7 : 6,
          child: momDecoration('imgDecorationExpertSupportLeaves', 58, 65),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    foregroundDecoration: settingsLayout
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .92),
                              width: 1.5,
                            ),
                          )
                        : null,
                    child: Image.asset(
                      MomHomeAssets.experts,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MomHomeTokens.text(
                          14,
                          weight: FontWeight.w700,
                          height: settingsLayout ? 20 / 14 : 22 / 14,
                        ),
                      ),
                      Text(
                        '专家 + AI 持续服务，从分析问题到跟进改善，全程有人陪',
                        style: MomHomeTokens.text(
                          10,
                          color: settingsLayout
                              ? MomHomeTokens.secondary
                              : const Color(0xff80736e),
                          height: settingsLayout ? 1.4 : 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: trailingGap),
                momDecoration('imgIconExpertSupportArrow', 20, 20),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
