import 'package:flutter/material.dart';

class MomCozySpacing {
  const MomCozySpacing._();

  static const compact = 8.0;
  static const content = 12.0;
  static const page = 16.0;
  static const section = 24.0;
  static const xs = 4.0;
  static const card = 20.0;
  static const spacious = 32.0;

  // Shared roles from the approved product design; page-specific overrides
  // are documented in docs/ui-reference/common/design-system.md.
  static const pageGutter = 8.0;
  static const statusGap = 10.0;
  static const headingGap = 14.0;
  static const homeBottom = 28.0;
}

class MomCozyInsets {
  const MomCozyInsets._();
  static const page = EdgeInsets.fromLTRB(
    MomCozySpacing.pageGutter,
    MomCozySpacing.section,
    MomCozySpacing.pageGutter,
    MomCozySpacing.homeBottom,
  );
  static const home = EdgeInsets.fromLTRB(8, 27, 8, 32);
  static const card = EdgeInsets.all(MomCozySpacing.card);
  static const compactCard = EdgeInsets.all(MomCozySpacing.page);
  static const field = EdgeInsets.symmetric(
    horizontal: MomCozySpacing.page,
    vertical: MomCozySpacing.page,
  );
  static const dialog = EdgeInsets.all(MomCozySpacing.section);
  static const editorHeader = EdgeInsets.fromLTRB(
    MomCozySpacing.card,
    MomCozySpacing.content,
    MomCozySpacing.compact,
    MomCozySpacing.compact,
  );
  static const editorBody = EdgeInsets.fromLTRB(
    MomCozySpacing.card,
    MomCozySpacing.xs,
    MomCozySpacing.card,
    MomCozySpacing.card,
  );
}

class MomCozyTapTargets {
  const MomCozyTapTargets._();

  static const minimum = 44.0;
}

class MomCozyColors {
  // Service timeline: src/styles/me-service-progress.css.
  static const timelineBackground = Color(0xfffcfaf7);
  static const timelineSurface = Color(0xfffffefd);
  static const timelineBorder = Color(0xffe2e2dd);
  static const timelineLine = Color(0xffd7dedd);
  static const timelineAccent = Color(0xff456c79);
  static const timelineLatestBorder = Color(0xff7ea0a7);
  static const timelineMuted = Color(0xff777b76);
  const MomCozyColors._();

  // Momcozy AI palette from the approved me-agent.css reference.
  static const warmEditorHeader = Color(0xff3b2c23);
  static const warmEditorInk = Color(0xff49392f);
  static const warmEditorMuted = Color(0xff826f5e);
  static const warmEditorBright = Color(0xfffff8f1);
  static const warmEditorMeta = Color(0xffd1c1b3);
  static const warmEditorSelection = Color(0xffeadbcc);
  static const warmEditorSelectionBorder = Color(0xff9d8471);
  static const recordChoiceSurface = Color(0xfff1e7dd);
  static const recordChoiceBackground = Color(0xfffbf7f2);
  static const serviceTeamSurface = Color(0xfff7fbfb);
  static const summaryIntroStart = Color(0xfff2e7e3);
  static const summaryIntroEnd = Color(0xfffbf5f3);
  static const summaryTitle = Color(0xff5e4b50);
  static const summaryFocusBorder = Color(0xffdfc1c5);
  static const serviceTeamBorder = Color(0xffc8dde0);
  static const serviceTeamInk = Color(0xff456573);
  static const servicePurchasedSurface = Color(0xffedf7f2);
  static const servicePurchasedEnd = Color(0xfff7fbf9);
  static const servicePurchasedBorder = Color(0xffc7dfd4);
  static const servicePurchasedInk = Color(0xff426d5e);
  static const servicePeriodSurface = Color(0xffdfeee8);
  static const servicePeriodBorder = Color(0xffa9cdbf);
  static const servicePeriodInk = Color(0xff315e50);
  static const agentInk = Color(0xff352d40);
  static const agentAccent = Color(0xff9464cc);
  static const agentSoft = Color(0xfff0e7fa);
  static const agentTextMuted = Color(0xff7c7087);
  static const agentStrong = Color(0xff7943b5);
  static const agentMuted = Color(0xff887991);
  static const agentSurface = Color(0xfffcf9fc);
  static const agentSuggestionSurface = Color(0xfffffcff);
  static const agentLavender = Color(0xfff6effa);
  static const agentGlow = Color(0xffe6d2f8);
  static const agentPeach = Color(0xfffbe9e3);
  static const agentBubble = Color(0xf0fffcff);
  static const agentControl = Color(0xffeee7f4);
  static const agentBorder = Color(0xffe0d2ee);
  static const background = Color(0xfffaf7f3);
  static const transparentBackground = Color(0x00faf7f3);
  static const foreground = Color(0xff302a29);
  static const card = Color(0xfffffefc);
  static const raised = Color(0xfffffefc);
  static const primary = Color(0xffb45870);
  static const primaryDark = Color(0xff8e3f54);
  static const roseSoft = Color(0xfff6e7eb);
  static const secondary = Color(0xfff3eeea);
  static const muted = Color(0xfff3eeea);
  static const mutedForeground = Color(0xff786f6c);
  static const border = Color(0xffe5dad4);
  static const warm = Color(0xffdca47a);
  static const care = Color(0xff4d846f);
  static const careSoft = Color(0xffe6f1ec);
  static const deviceReadySurface = Color(0xfff7fbf9);
  static const deviceReadyBorder = Color(0xffc6ddd3);
  static const deviceErrorSurface = Color(0xfffff9f8);
  static const deviceErrorBorder = Color(0xffe5c2c1);
  static const amber = Color(0xffa7783a);
  static const amberSoft = Color(0xfff6eddc);
  static const violet = Color(0xff8752c7);
  static const violetSoft = Color(0xfff3ebf9);
  static const blue = Color(0xff587d9c);
  static const blueSoft = Color(0xffe8f0f6);
  static const recordValidationSurface = Color(0xfffbe6e6);
  static const recordValidationInk = Color(0xff923f3f);
  static const danger = Color(0xffb44b4f);
  static const appBackground = Color(0xfff5f1ed);
  static const badge = Color(0xffb44b4f);

  static const textPrimary = foreground;
  static const textSecondary = mutedForeground;
  static const textTertiary = Color(0xff857167);
  static const iconPrimary = Color(0xff685647);
  static const iconSecondary = mutedForeground;
  static const navigationInactive = Color(0xff8e8089);
  static const navigationSurface = Color(0xfffffcff);
  static const navigationBorder = Color(0xffeae0f1);
  static const navigationSelected = Color(0xfff1e8fb);
  static const navigationAvatar = Color(0xfff0e7f6);
  static const navigationAvatarRing = Color(0xffe8d8f7);
  static const navigationAvatarSelectedRing = Color(0xffbf9de1);
  static const expertDialogBarrier = Color(0x55202b31);
  static const expertAccent = Color(0xff416874);
  static const expertPreviewSurface = Color(0xfff4f9f9);
  static const expertPreviewBorder = Color(0xffc8dde0);
  static const expertSurface = Color(0xfffdfdfc);
  static const expertBorder = Color(0xffdde1e1);
  static const expertInk = Color(0xff303536);
  static const expertMuted = Color(0xff777c7d);
  static const expertSoft = Color(0xffedf1f1);
  static const expertCountdownSurface = Color(0xfff0f0ee);
  static const warmFormSurface = Color(0xfff8f3ed);
  static const warmFormField = Color(0xfffffaf6);
  static const warmFormBorder = Color(0xffe4d6c8);
  static const warmFormSelected = Color(0xff614735);
  static const warmFormTab = Color(0xffece2d7);
  static const warmMetricSurface = Color(0xfff1e9df);
  static const warmQuietSurface = Color(0xfff1e8de);
  static const warmBadge = Color(0xffefe6dc);
  static const warmIcon = Color(0xff8b7563);
  static const statusText = Color(0xff3b322b);
  static const statusSecondary = Color(0xff60544b);
  static const statusTertiary = Color(0xff817167);
  static const statusIcon = Color(0xff705b4a);
  static const knowledgeLabel = Color(0xff715487);
  static const knowledgeText = Color(0xff352d40);
  static const knowledgeSecondary = Color(0xff6b5c76);
  static const knowledgeAvatar = Color(0xffeee5f5);
  static const avatarBorder = Colors.white;
  static const surface = raised;
  static const disabled = secondary;
  static const divider = border;
  static const success = care;
  static const successSurface = careSoft;
  static const warning = amber;
  static const warningSurface = amberSoft;
  static const error = danger;
  static const errorSurface = roseSoft;
  static const info = blue;
  static const infoSurface = blueSoft;
  static const overlay = Colors.black54;

  // Existing Me lactation chart palette: preserve the dark trend surface.
  static const milkChartBackground = Color(0xff3b2c23);
  static const milkChartFade = Color(0x003b2c23);
  static const milkChartInk = Color(0xfffff8f1);
  static const milkChartMuted = Color(0xffcdbbae);
  static const milkChartSelection = Color(0x12fff4e5);
  static const milkChartBorder = Color(0xff9d8877);
  static const milkChartGrid = Color(0x73967c69);
  static const milkChartGlow = Color(0x80f2c49d);
  static const milkChartGlowFade = Color(0x00f2c49d);
  static const milkChartPoint = Color(0xffe9bb91);
  static const milkChartGuide = Color(0xffd9b394);
  static const milkChartLabel = Color(0xfff0c6a3);

  // Dark media and camera surfaces are visibility semantics, not product chrome.
  static const mediaBackground = Colors.black;
  static const onMediaDisabled = Color(0x61ffffff);
  // Camera skeleton signals retain their distinct high-visibility colors.
  static const motionLeft = Color(0xff51e1d2);
  static const motionRight = Color(0xffff79ae);
  static const motionCenter = Color(0xffffd166);
  static const motionPersonFirst = Color(0xffffa14a);
  static const motionPersonSecond = Color(0xffa993ff);
  static const motionWarning = Colors.orangeAccent;
  static const onMedia = Colors.white;
  static const mediaOverlay = Colors.black54;
  static const onMediaSecondary = Color(0xb3ffffff);
  static const mediaControlBackground = Color(0xa6000000);
  static const mediaCloseBackground = Color(0x99000000);
  static const mediaInactiveTrack = Color(0x66ffffff);
  static const mediaInteraction = Color(0x33ffffff);
  static const mediaStageBackground = Color(0xff2b373c);
  static const mediaRaised = Color(0xff43575f);
  static const onMediaMuted = Color(0xffe0e7ea);
  static const mediaBorder = Color(0xff849298);
}

class MomCozyRadii {
  const MomCozyRadii._();

  static const card = 18.0;
  static const compactCard = 14.0;
  static const control = 12.0;
  static const pill = 999.0;
  static const featured = 22.0;
  static const dialog = featured;
  static const sheet = featured;
  static const badge = 8.0;
  static const thumbnail = 8.0;
  static const navigation = 14.0;
}

class MomCozyBorders {
  const MomCozyBorders._();
  static const width = 1.0;
  static const focusWidth = 1.4;
  static const subtle = BorderSide(color: MomCozyColors.border, width: width);
}

class MomCozyIconSizes {
  const MomCozyIconSizes._();
  static const small = 16.0;
  static const medium = 20.0;
  static const standard = 24.0;
  static const feature = 32.0;
}

class MomCozyLayout {
  const MomCozyLayout._();

  static const maxAppWidth = 440.0;
  static const bottomNavHeight = 78.0;
  static const bottomNavCenterSize = 42.0;
  static const buttonHeight = 44.0;
  static const primaryButtonHeight = 48.0;
  static const headerHeight = 56.0;
  static const workbenchWidth = 1400.0;
}

class MomCozyAssets {
  const MomCozyAssets._();

  static const agentAvatar = 'assets/images/momcozy-agent.png';
  static const bottomNavMe = 'assets/images/nav_me.svg';
  static const bottomNavBaby = 'assets/images/nav_baby.svg';
  static const bottomNavSchedule = 'assets/images/nav_schedule.svg';
  static const bottomNavMore = 'assets/images/nav_more.svg';
  static const agentAwakenAvatar = 'assets/images/momcozy-agent-awaken.gif';
  static const agentThinkingAvatar = 'assets/images/momcozy-agent-thinking.mp4';
  static const pumpM9 = 'assets/images/M9.png';
  static const ibclcConsultantAvatar =
      'assets/images/ibclc-consultant-avatar.jpg';
  static const momcozyLogo = 'assets/images/momcozy_logo.png';
}

class MomCozyTypography {
  const MomCozyTypography._();

  static const displayFontFamily = 'Manrope';
  static const bodyFontFamily = 'DMSans';
  static const interfaceFontFamily = bodyFontFamily;
  static const fontFamily = bodyFontFamily;
  static const fontFamilyFallback = ['NotoSansSC', 'PingFang SC', 'Arial'];

  // Retained for workbench and explicit local component styles. User App
  // heading metrics are set separately by momCozyTheme.
  static const lineHeight = 1.43;
  static const letterSpacing = 0.25;

  static const microSize = 10.0;
  static const labelSize = 11.0;
  static const captionSize = 12.0;
  static const secondarySize = 13.0;
  static const bodySize = 14.0;
  static const titleSize = 16.0;
  static const bodyLargeSize = 17.0;
  static const sectionSize = 19.0;
  static const headingSize = 22.0;
  static const pageTitleSize = 26.0;
  static const metricSize = 34.0;
  static const heroMetricSize = 54.0;

  static const navigationLabel = TextStyle(
    fontSize: labelSize,
    height: 14 / 11,
    letterSpacing: 0,
    fontWeight: FontWeight.w500,
  );

  static const homeGreeting = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: pageTitleSize,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1.04,
  );
  static const homeStage = TextStyle(
    fontSize: secondarySize,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    letterSpacing: -.325,
    color: Color(0xff806d6a),
  );

  static const pageTitle = TextStyle(
    fontSize: pageTitleSize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w700,
  );
  static const heading = TextStyle(
    fontSize: headingSize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w700,
  );
  static const sectionTitle = TextStyle(
    fontSize: sectionSize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w700,
  );
  static const title = TextStyle(
    fontSize: titleSize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(fontSize: bodySize);
  static const secondaryText = TextStyle(
    fontSize: secondarySize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    color: MomCozyColors.mutedForeground,
  );
  static const caption = TextStyle(
    fontSize: captionSize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    color: MomCozyColors.mutedForeground,
  );
  static const label = TextStyle(
    fontSize: labelSize,
    height: lineHeight,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.w600,
  );
  static const micro = TextStyle(fontSize: microSize);
  static const metric = TextStyle(
    fontSize: metricSize,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );
}

class MomCozyShadows {
  // Retained page separation for the document viewer, not a raised UI card.
  static const documentPage = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 4,
    offset: Offset(0, 2),
  );
  const MomCozyShadows._();

  static const soft = [
    BoxShadow(
      color: Color(0x1f392832),
      blurRadius: 22,
      spreadRadius: -14,
      offset: Offset(0, 8),
    ),
  ];

  static const navigation = [
    BoxShadow(color: Color(0x0679548b), blurRadius: 20, offset: Offset(0, -4)),
  ];

  static List<BoxShadow> navigationAvatar({required bool selected}) => [
    BoxShadow(
      color: selected
          ? MomCozyColors.navigationAvatarSelectedRing
          : MomCozyColors.navigationAvatarRing,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: selected ? const Color(0x268752c7) : const Color(0x1a8752c7),
      blurRadius: selected ? 14 : 12,
      offset: const Offset(0, 3),
    ),
  ];

  static const knowledgeAvatar = [
    BoxShadow(color: Color(0x59ffffff), spreadRadius: 5),
    BoxShadow(color: Color(0x1f8752c7), blurRadius: 22, offset: Offset(0, 5)),
  ];
}

class MomCozyGradients {
  const MomCozyGradients._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MomCozyColors.primary, MomCozyColors.primaryDark],
  );
  static const rest = LinearGradient(
    colors: [Color(0xfff4eee6), Color(0xffefe6d9)],
  );
  static const body = LinearGradient(
    colors: [Color(0xfff5efe5), Color(0xfff7f0e6)],
  );
  static const mood = LinearGradient(
    colors: [Color(0xfff8ece6), Color(0xfff4e3dc)],
  );
  static const lactation = LinearGradient(
    colors: [Color(0xfff8eee7), Color(0xfff3e5df)],
  );
  static const knowledge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xfffcf9fc), MomCozyColors.violetSoft],
  );
  static const knowledgeTop = RadialGradient(
    center: Alignment.topRight,
    radius: 1.05,
    colors: [Color(0xffe5d4f5), Color(0x00e5d4f5)],
  );
  static const knowledgeBottom = RadialGradient(
    center: Alignment.bottomLeft,
    radius: 1,
    colors: [Color(0xfff9e7e2), Color(0x00f9e7e2)],
  );
}

class MomCozyDecorations {
  const MomCozyDecorations._();

  static BoxDecoration card({
    Color color = MomCozyColors.card,
    Color borderColor = MomCozyColors.border,
    double radius = MomCozyRadii.card,
    List<BoxShadow> shadows = const [],
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: MomCozyBorders.width),
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
