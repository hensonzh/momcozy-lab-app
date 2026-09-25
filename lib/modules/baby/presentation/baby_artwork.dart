import 'package:flutter/material.dart';
import '../../../domain/shared/knowledge_article.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import 'baby_design.dart';

/// Original Figma exports; these decorations never affect layout or hit testing.
class BabyArtwork extends StatelessWidget {
  const BabyArtwork({super.key, required this.kind, required this.child});
  final String kind;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                Widget at(
                  String name,
                  double x,
                  double y,
                  double width,
                  double height,
                ) => Positioned(
                  left: x,
                  top: y,
                  child: BabyDesign.asset(name, width: width, height: height),
                );
                return ClipRect(
                  child: Stack(
                    children: switch (kind) {
                      'knowledge' => [
                        at('DecorationLilac', w - 106, -30, 140, 140),
                        at('DecorationBlush', -38, h - 24, 150, 92),
                        at('DecorationSpark', w - 49, 78, 18, 18),
                      ],
                      'feeding' => [
                        at('DecorationBlush1', w - 83, -24, 125, 76.667),
                        at('DecorationDrop', w - 113, 5, 38, 44.333),
                        at('DecorationWave', w - 213, 50, 210, 64),
                      ],
                      'mental' => [
                        at('DecorationWarm', w - 64, h - 58, 90, 90),
                      ],
                      'wet' => [
                        at('DecorationWarm1', w - 55, h - 51, 82, 82),
                        at('DecorationDrop1', w - 38, 17, 34, 39.667),
                      ],
                      'stool' => [
                        at('DecorationBlush2', w - 74, h - 49, 108, 66.24),
                        at('DecorationWave1', w - 129, h - 46, 160, 48.762),
                      ],
                      'measurement' => [
                        at('DecorationWarm2', w - 40, h - 48, 76, 76),
                        at('DecorationRing', w - 46, h - 50, 64, 64),
                      ],
                      'chart' => [
                        at('DecorationMint', w - 69, -47, 118, 118),
                        at('DecorationRing1', w - 56, -25, 80, 80),
                      ],
                      _ => <Widget>[],
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class BabyKnowledgeBanner extends StatelessWidget {
  const BabyKnowledgeBanner({
    super.key,
    required this.article,
    required this.onOpen,
  });
  final KnowledgeArticle article;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: MomHomeTokens.ai,
    onTap: onOpen,
    child: BabyArtwork(
      kind: 'knowledge',
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    article.title,
                    style: BabyDesign.text(
                      18,
                      line: 25,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                ClipOval(
                  child: Image.asset(
                    'assets/images/baby_figma/OriginalCozymatePortrait.png',
                    width: 50,
                    height: 50,
                  ),
                ),
              ],
            ),
            Text(
              article.summary,
              style: BabyDesign.text(
                13,
                line: 18,
                color: MomHomeTokens.secondary,
              ),
            ),
            SizedBox(
              height: 31,
              child: Align(
                alignment: Alignment.centerRight,
                child: BabyDesign.asset(
                  'ChevronRightRounded',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BabySectionHeader extends StatelessWidget {
  const BabySectionHeader({
    super.key,
    required this.title,
    required this.onTap,
  });
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: BabyDesign.text(18, line: 25, weight: FontWeight.w700),
        ),
      ),
      SizedBox(
        width: 68,
        height: 44,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: BabyDesign.text(13, line: 18, weight: FontWeight.w700),
          ),
          child: const Text('Log'),
        ),
      ),
    ],
  );
}
