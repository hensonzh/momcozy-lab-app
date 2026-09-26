import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';

/// Schedule Page 567:1133, approved month/week frames 214:1108 / 788:8.
abstract final class ScheduleDesign {
  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xfff4f0fb),
      Color(0xfffbf5f6),
      Color(0xfffbf8f4),
      Color(0xfffbf8f4),
    ],
    stops: [0, .31991, .50948, 1],
  );
  static const calendar = LinearGradient(
    colors: [Color(0xfffbecf1), Color(0xffeee9f9)],
  );
  static const calendarShadow = [
    BoxShadow(color: Color(0x0f664059), offset: Offset(0, 6), blurRadius: 20),
  ];
  static const cardShadow = [
    BoxShadow(color: Color(0x0c664059), offset: Offset(0, 3), blurRadius: 12),
  ];
  static const fabShadow = [
    BoxShadow(color: Color(0x388c3b63), offset: Offset(0, 5), blurRadius: 14),
  ];
  static TextStyle text(
    double size, {
    bool bold = false,
    Color color = MomHomeTokens.ink,
    double? lineHeight,
  }) => MomHomeTokens.text(
    size,
    weight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
    height: (lineHeight ?? size * 1.4) / size,
  );
}

enum ScheduleCardKind {
  personal(
    Color(0xfffdf4ed),
    Color(0xfffae5d6),
    Color(0xff8f5e47),
    Color(0xffd6a88c),
  );

  const ScheduleCardKind(this.tint, this.chip, this.ink, this.accent);
  final Color tint, chip, ink, accent;
}
