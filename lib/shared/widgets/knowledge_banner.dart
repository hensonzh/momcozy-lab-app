import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'momcozy_line_icon.dart';
import 'mom_companion_widgets.dart';
import '../design_system/mom_home_tokens.dart';
import '../design_system/mom_settings_theme.dart';
import '../../core/routing/external_url_launcher.dart';
import '../../domain/shared/knowledge_article.dart';
import '../design_system/momcozy_design_system.dart';

class KnowledgeBanner extends StatelessWidget {
  const KnowledgeBanner({
    super.key,
    required this.label,
    required this.article,
    required this.onOpen,
    this.splitTitle = true,
    this.reservePortraitSpace = false,
    this.useMomStyle = false,
    this.backgroundDecoration,
  });
  final String label;
  final KnowledgeArticle article;
  final VoidCallback onOpen;
  final bool useMomStyle;
  final MomCardDecoration? backgroundDecoration;
  final bool splitTitle;
  final bool reservePortraitSpace;
  @override
  Widget build(BuildContext context) => useMomStyle
      ? _momBanner(context)
      : Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: MomCozyGradients.knowledge,
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: MomCozyGradients.knowledgeTop,
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: MomCozyGradients.knowledgeBottom,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 224),
                    child: Padding(
                      padding: MediaQuery.sizeOf(context).width < 359
                          ? const EdgeInsets.all(
                              22,
                            ).copyWith(left: 17, right: 17)
                          : const EdgeInsets.fromLTRB(22, 25, 22, 27),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              right: reservePortraitSpace ? 66 : 48,
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: MomCozyTypography.labelSize,
                                color: MomCozyColors.knowledgeLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: EdgeInsets.only(
                              right: reservePortraitSpace ? 66 : 24,
                            ),
                            child: Text(
                              splitTitle
                                  ? article.title.replaceAll('，', '，\n')
                                  : article.title,
                              style: TextStyle(
                                fontSize:
                                    (MediaQuery.sizeOf(context).width * .048)
                                        .clamp(18, 21),
                                letterSpacing: -.65,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                                color: MomCozyColors.knowledgeText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FractionallySizedBox(
                            widthFactor: .87,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              article.summary,
                              style: const TextStyle(
                                fontSize: MomCozyTypography.captionSize,
                                color: MomCozyColors.knowledgeSecondary,
                                height: 1.75,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 19,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MomCozyColors.knowledgeAvatar,
                        border: Border.all(
                          color: MomCozyColors.avatarBorder,
                          width: 2,
                        ),
                        boxShadow: MomCozyShadows.knowledgeAvatar,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          MomCozyAssets.agentAvatar,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 18,
                    bottom: 20,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: MomCozyColors.violet,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  Widget _momBanner(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final labelWidget = Text(
      label,
      style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
    );
    final titleWidget = Text(
      article.title,
      style: MomHomeTokens.text(18, weight: FontWeight.w700),
    );
    final portrait = ClipOval(
      child: Image.asset(
        MomCozyAssets.agentAvatar,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      ),
    );
    return MomHomeSurface(
      backgroundDecoration: backgroundDecoration,
      gradient: MomHomeTokens.ai,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: large
                      ? labelWidget
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            labelWidget,
                            const SizedBox(height: 8),
                            titleWidget,
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                portrait,
              ],
            ),
            if (large) ...[const SizedBox(height: 12), titleWidget],
            const SizedBox(height: 12),
            Text(
              article.summary,
              style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: MomHomeTokens.rose,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showKnowledgeArticle(
  BuildContext context, {
  required KnowledgeArticle article,
  required String boundary,
  required VoidCallback onAsk,
  String title = '每日知识',
  bool babyStyle = false,
  bool useMomStyle = false,
}) => showDialog<void>(
  context: context,
  animationStyle: MomCozyMotion.animationStyle(context),
  barrierColor: const Color(0x472b2423),
  builder: (context) {
    final bodyColor = useMomStyle
        ? MomHomeTokens.secondary
        : babyStyle
        ? MomCozyColors.knowledgeSecondary
        : MomCozyColors.mutedForeground;
    final lineColor = useMomStyle
        ? MomHomeTokens.border
        : babyStyle
        ? MomCozyColors.agentBorder
        : MomCozyColors.border;
    final pad = useMomStyle
        ? 16.0
        : babyStyle
        ? (MediaQuery.sizeOf(context).width < 359 ? 17.0 : 22.0)
        : 19.0;
    final dialog = BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Dialog(
        alignment: babyStyle ? Alignment.center : Alignment.bottomCenter,
        insetPadding: EdgeInsets.all(babyStyle ? 12 : 18),
        backgroundColor: useMomStyle
            ? MomHomeTokens.surface
            : babyStyle
            ? MomCozyColors.agentSurface
            : MomCozyColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: useMomStyle
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(
                  top: Radius.circular(26),
                  bottom: Radius.circular(18),
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: math.min(
              MediaQuery.sizeOf(context).height * .88,
              babyStyle ? 700 : 620,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  useMomStyle
                      ? 16
                      : babyStyle
                      ? 17
                      : 8,
                  8,
                  useMomStyle
                      ? 16
                      : babyStyle
                      ? 17
                      : 8,
                ),
                decoration: babyStyle && !useMomStyle
                    ? const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MomCozyColors.agentPeach,
                            MomCozyColors.agentGlow,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      )
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: useMomStyle ? 20 : 18,
                          fontWeight: FontWeight.w700,
                          color: useMomStyle
                              ? MomHomeTokens.ink
                              : babyStyle
                              ? MomCozyColors.agentInk
                              : MomCozyColors.foreground,
                        ),
                      ),
                    ),
                    if (useMomStyle)
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: MomHomeTokens.rose,
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: bodyColor,
                          minimumSize: const Size(44, 44),
                          textStyle: TextStyle(
                            fontSize: 13,
                            fontFamily: useMomStyle
                                ? 'NotoSansSCHome'
                                : MomCozyTypography.fontFamily,
                            fontFamilyFallback:
                                MomCozyTypography.fontFamilyFallback,
                          ),
                        ),
                        child: const Text('关闭'),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    pad,
                    useMomStyle
                        ? 16
                        : babyStyle
                        ? 22
                        : 8,
                    pad,
                    pad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        article.title,
                        style: TextStyle(
                          fontSize: useMomStyle
                              ? 20
                              : babyStyle
                              ? 22
                              : 21,
                          height: useMomStyle
                              ? 1.4
                              : babyStyle
                              ? 1.5
                              : 1.35,
                          fontWeight: FontWeight.w700,
                          color: useMomStyle
                              ? MomHomeTokens.ink
                              : babyStyle
                              ? MomCozyColors.agentInk
                              : MomCozyColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.summary,
                        style: TextStyle(
                          fontSize: useMomStyle
                              ? 14
                              : babyStyle
                              ? 13
                              : 12,
                          height: useMomStyle
                              ? 1.4
                              : babyStyle
                              ? 1.8
                              : 1.65,
                          color: bodyColor,
                        ),
                      ),
                      const SizedBox(height: 17),
                      if (!useMomStyle) Divider(height: 1, color: lineColor),
                      for (
                        var index = 0;
                        index < article.points.length;
                        index++
                      ) ...[
                        Container(
                          margin: useMomStyle
                              ? const EdgeInsets.only(bottom: 12)
                              : null,
                          decoration: useMomStyle
                              ? BoxDecoration(
                                  color: MomHomeTokens.background,
                                  borderRadius: BorderRadius.circular(16),
                                )
                              : null,
                          padding: useMomStyle
                              ? const EdgeInsets.all(14)
                              : EdgeInsets.symmetric(
                                  vertical: babyStyle ? 15 : 12,
                                ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: useMomStyle
                                    ? 22 *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1)
                                    : 22,
                                height: useMomStyle
                                    ? 22 *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1)
                                    : 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: useMomStyle
                                      ? MomHomeTokens.mint
                                      : babyStyle
                                      ? MomCozyColors.violetSoft
                                      : MomCozyColors.blueSoft,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: useMomStyle ? 14 : 10,
                                    fontWeight: FontWeight.w800,
                                    color: useMomStyle
                                        ? MomHomeTokens.teal
                                        : babyStyle
                                        ? MomCozyColors.agentStrong
                                        : MomCozyColors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  article.points[index],
                                  style: TextStyle(
                                    fontSize: useMomStyle
                                        ? 14
                                        : babyStyle
                                        ? 13
                                        : 11,
                                    height: useMomStyle
                                        ? 1.4
                                        : babyStyle
                                        ? 1.75
                                        : 1.55,
                                    color: bodyColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!useMomStyle) Divider(height: 1, color: lineColor),
                      ],
                      if (article.source case final source?)
                        TextButton.icon(
                          onPressed: () async {
                            var opened = false;
                            try {
                              opened = await const PlatformExternalUrlLauncher()
                                  .open(Uri.parse(source.url));
                            } catch (_) {
                              opened = false;
                            }
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                const SnackBar(content: Text('暂时无法打开来源链接')),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: bodyColor,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: Text(
                            source.label,
                            style: TextStyle(fontSize: useMomStyle ? 12 : 11),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MomCozyLineIcon(
                            MomCozyLineGlyph.shield,
                            size: 15,
                            color: MomCozyColors.care,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              boundary,
                              style: TextStyle(
                                fontSize: useMomStyle
                                    ? 12
                                    : babyStyle
                                    ? 11
                                    : 10,
                                height: babyStyle ? 1.7 : 1.5,
                                color: bodyColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, babyStyle ? 8 : 0, pad, pad),
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onAsk();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: useMomStyle
                        ? MomHomeTokens.rose
                        : babyStyle
                        ? MomCozyColors.agentStrong
                        : MomCozyColors.foreground,
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: useMomStyle
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                '问问 Cozymate',
                                textAlign: TextAlign.center,
                                style: MomHomeTokens.text(
                                  13,
                                  color: Colors.white,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const MomCozyLineIcon(
                              MomCozyLineGlyph.arrow,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white),
                              ),
                              child: Image.asset(
                                MomCozyAssets.agentAvatar,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Text(
                              '问问 Cozymate',
                              style: useMomStyle
                                  ? MomHomeTokens.text(
                                      13,
                                      color: Colors.white,
                                      weight: FontWeight.w700,
                                    )
                                  : null,
                            ),
                            const MomCozyLineIcon(
                              MomCozyLineGlyph.arrow,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return useMomStyle
        ? Theme(data: momSettingsTheme(Theme.of(context)), child: dialog)
        : dialog;
  },
);
