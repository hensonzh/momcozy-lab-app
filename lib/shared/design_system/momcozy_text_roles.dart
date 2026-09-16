import 'package:flutter/material.dart';

/// Reading copy has its own leading; controls retain their inherited metrics.
class MomCozyTextRoles extends ThemeExtension<MomCozyTextRoles> {
  const MomCozyTextRoles({this.paragraph = const TextStyle(height: 1.55)});

  final TextStyle paragraph;

  static TextStyle paragraphOf(BuildContext context) =>
      Theme.of(context).extension<MomCozyTextRoles>()?.paragraph ??
      const TextStyle();

  @override
  MomCozyTextRoles copyWith({TextStyle? paragraph}) =>
      MomCozyTextRoles(paragraph: paragraph ?? this.paragraph);

  @override
  MomCozyTextRoles lerp(covariant MomCozyTextRoles? other, double t) =>
      other == null
      ? this
      : MomCozyTextRoles(
          paragraph: TextStyle.lerp(paragraph, other.paragraph, t)!,
        );
}
