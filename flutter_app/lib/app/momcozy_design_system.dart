import 'package:flutter/material.dart';

class MomCozyColors {
  const MomCozyColors._();

  static const background = Color(0xfffbf6f4);
  static const foreground = Color(0xff392832);
  static const card = Color(0xfffdf9f7);
  static const raised = Color(0xffffffff);
  static const primary = Color(0xffa86172);
  static const primaryDark = Color(0xff8c4f62);
  static const roseSoft = Color(0xfff1e4e7);
  static const secondary = Color(0xffeddee1);
  static const muted = Color(0xfff4efeb);
  static const mutedForeground = Color(0xff836775);
  static const border = Color(0xffe3d3d7);
  static const warm = Color(0xffdca47a);
  static const care = Color(0xff3f9d90);
  static const careSoft = Color(0xffe1f5f0);
  static const amber = Color(0xffe1ab5b);
  static const amberSoft = Color(0xfffaefdc);
  static const violet = Color(0xff846dba);
  static const violetSoft = Color(0xffeee7f8);
  static const badge = Color(0xffe3405f);
}

class MomCozyRadii {
  const MomCozyRadii._();

  static const card = 16.0;
  static const control = 12.0;
  static const pill = 999.0;
}

class MomCozyLayout {
  const MomCozyLayout._();

  static const maxAppWidth = 430.0;
  static const bottomNavHeight = 84.0;
  static const bottomNavChromeHeight = 72.0;
  static const bottomNavCenterSize = 68.0;
}

class MomCozyAssets {
  const MomCozyAssets._();

  static const agentAvatar = 'assets/images/momcozy-agent.png';
  static const agentAwakenAvatar = 'assets/images/momcozy-agent-awaken.gif';
  static const momAvatar = 'assets/images/mom-avatar-felt.png';
  static const babyAvatar = 'assets/images/baby-avatar-felt.png';
  static const pumpM9 = 'assets/images/M9.png';
  static const ibclcConsultantAvatar =
      'assets/images/ibclc-consultant-avatar.jpg';
  static const postpartumRecoveryIcon =
      'assets/images/postpartum-recovery-icon.png';
  static const momcozyLogo = 'assets/images/momcozy_logo.png';
}

class MomCozyTypography {
  const MomCozyTypography._();

  static const fontFamily = 'Quicksand';
  static const fontFamilyFallback = ['NotoSansSC', 'PingFang SC', 'Arial'];
}

class MomCozyShadows {
  const MomCozyShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x24392832),
      blurRadius: 26,
      spreadRadius: -18,
      offset: Offset(0, 10),
    ),
  ];

  static const soft = [
    BoxShadow(
      color: Color(0x1f392832),
      blurRadius: 22,
      spreadRadius: -14,
      offset: Offset(0, 8),
    ),
  ];
}

class MomCozyGradients {
  const MomCozyGradients._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MomCozyColors.primary, Color(0xd9a86172)],
  );
}

class MomCozyDecorations {
  const MomCozyDecorations._();

  static BoxDecoration card({
    Color color = MomCozyColors.card,
    Color borderColor = MomCozyColors.border,
    double radius = MomCozyRadii.card,
    List<BoxShadow> shadows = MomCozyShadows.card,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor.withValues(alpha: 0.72)),
      boxShadow: shadows,
    );
  }

  static BoxDecoration softTint(Color accent) {
    return BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(MomCozyRadii.control),
    );
  }
}
