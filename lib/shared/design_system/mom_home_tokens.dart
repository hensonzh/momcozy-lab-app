import 'package:flutter/material.dart';
import 'momcozy_design_system.dart';

/// Shared visual foundation from the approved mother-page Figma designs.
/// Adopted incrementally by screenshot-backed page redesigns.
abstract final class MomHomeTokens {
  static const background = Color(0xfffbf8f4);
  static const surface = Color(0xfffffdfc);
  static const neutralSurface = Color(0xfff2ebe5);
  static const inset = 16.0;
  static const ink = Color(0xff2b2826);
  static const secondary = Color(0xff776e69);
  static const muted = Color(0xff958a84);
  static const rose = Color(0xffb54f78);
  static const border = Color(0xffe9e1dc);
  static const mint = Color(0xffe8f3ef);
  static const teal = Color(0xff3e7180);
  static const cardRadius = 22.0;
  static const gap = 14.0;
  static const padding = EdgeInsets.fromLTRB(16, 18, 16, 28);
  static const ai = LinearGradient(
    colors: [Color(0xfffff3ee), Color(0xfff8f0f7), Color(0xffead9fb)],
    stops: [0, .48, 1],
  );
  static const milk = LinearGradient(
    colors: [Color(0xfffbece8), Color(0xfff7e5e1)],
  );
  static const body = LinearGradient(
    colors: [Color(0xfff7f1e7), Color(0xfff2e9db)],
  );
  static const sleep = LinearGradient(
    colors: [Color(0xfff8f2e9), Color(0xfff4eadb)],
  );
  static const mood = LinearGradient(
    colors: [Color(0xfffbece8), Color(0xfff7e3df)],
  );
  static const plan = LinearGradient(
    colors: [Color(0xfffffdfb), Color(0xfffff8f5), Color(0xfff3f8f5)],
    stops: [0, .62, 1],
  );
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double height = 1.4,
  }) => TextStyle(
    fontFamily: 'NotoSansSCHome',
    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: 0,
  );
}

abstract final class MomHomeAssets {
  static const root = 'assets/images/mom_home/';
  static const cozymate = '${root}cozymate_avatar.png';
  static String exported(String name) => '$root$name.svg';
}
