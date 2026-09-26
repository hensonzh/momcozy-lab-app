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
