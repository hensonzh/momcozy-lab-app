import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../design_system/momcozy_design_system.dart';

/// Optical line drawings from the product design's UI.tsx / MeOverview.tsx.
enum MomCozyLineGlyph {
  status,
  support,
  grid,
  drop,
  heart,
  lock,
  arrow,
  users,
  calendar,
  consultation,
  chevronRight,
  moon,
  note,
  baby,
  spark,
  plan,
  shield,
  camera,
  image,
  file,
  chat,
}

class MomCozyLineIcon extends StatelessWidget {
  const MomCozyLineIcon(this.glyph, {super.key, this.size = 24, this.color});
  final MomCozyLineGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/ui_${glyph.name}.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? MomCozyColors.iconPrimary,
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}
