import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'momcozy_line_icon.dart';
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
  });
  final String label;
  final KnowledgeArticle article;
  final VoidCallback onOpen;
  final bool splitTitle;
  final bool reservePortraitSpace;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(MomCozyRadii.card),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Ink(
        decoration: const BoxDecoration(gradient: MomCozyGradients.knowledge),
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
                    ? const EdgeInsets.all(22).copyWith(left: 17, right: 17)
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
                          fontSize: (MediaQuery.sizeOf(context).width * .048)
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
}

Future<void> showKnowledgeArticle(
  BuildContext context, {
  required KnowledgeArticle article,
  required String boundary,
  required VoidCallback onAsk,
  String title = '每日知识',
  bool babyStyle = false,
}) => showDialog<void>(
  context: context,
  animationStyle: MomCozyMotion.animationStyle(context),
  barrierColor: const Color(0x472b2423),
  builder: (context) {
    final bodyColor = babyStyle
        ? MomCozyColors.knowledgeSecondary
        : MomCozyColors.mutedForeground;
    final lineColor = babyStyle
        ? MomCozyColors.agentBorder
        : MomCozyColors.border;
    final pad = babyStyle
        ? (MediaQuery.sizeOf(context).width < 359 ? 17.0 : 22.0)
        : 19.0;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Dialog(
        alignment: babyStyle ? Alignment.center : Alignment.bottomCenter,
        insetPadding: EdgeInsets.all(babyStyle ? 12 : 18),
        backgroundColor: babyStyle
            ? MomCozyColors.agentSurface
            : MomCozyColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
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
                  babyStyle ? 17 : 8,
                  8,
                  babyStyle ? 17 : 8,
                ),
                decoration: babyStyle
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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: babyStyle
                              ? MomCozyColors.agentInk
                              : MomCozyColors.foreground,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: bodyColor,
                        minimumSize: const Size(44, 44),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontFamily: MomCozyTypography.fontFamily,
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
                    babyStyle ? 22 : 8,
                    pad,
                    pad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        article.title,
                        style: TextStyle(
                          fontSize: babyStyle ? 22 : 21,
                          height: babyStyle ? 1.5 : 1.35,
                          fontWeight: FontWeight.w700,
                          color: babyStyle
                              ? MomCozyColors.agentInk
                              : MomCozyColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.summary,
                        style: TextStyle(
                          fontSize: babyStyle ? 13 : 12,
                          height: babyStyle ? 1.8 : 1.65,
                          color: bodyColor,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Divider(height: 1, color: lineColor),
                      for (
                        var index = 0;
                        index < article.points.length;
                        index++
                      ) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: babyStyle ? 15 : 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: babyStyle
                                      ? MomCozyColors.violetSoft
                                      : MomCozyColors.blueSoft,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: babyStyle
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
                                    fontSize: babyStyle ? 13 : 11,
                                    height: babyStyle ? 1.75 : 1.55,
                                    color: bodyColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: lineColor),
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
                            style: const TextStyle(fontSize: 11),
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
                                fontSize: babyStyle ? 11 : 10,
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
                    backgroundColor: babyStyle
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
                  child: Wrap(
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
                      const Text('问问 Cozymate'),
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
  },
);
