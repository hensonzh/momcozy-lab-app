import 'baby_motion.dart';
import 'package:flutter/material.dart';
import '../../../domain/shared/knowledge_article.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import 'baby_design.dart';
import '../application/baby_knowledge_content.dart';

Future<void> showBabyKnowledge(
  BuildContext context,
  KnowledgeArticle article,
  VoidCallback onAsk,
) => showBabySheet<void>(
  context,
  BabySheetBody(
    title: article.title,
    style: BabySheetStyle.knowledge,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        Text(
          article.summary,
          style: BabyDesign.text(13, line: 21, color: MomHomeTokens.secondary),
        ),
        for (var i = 0; i < article.points.length; i++)
          if (article ==
                  babyKnowledgeArticles[BabyKnowledgeTopic.feedingCues] &&
              i < 2)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(
                  i == 0 ? 'Might be hungry' : 'Might be full',
                  style: BabyDesign.text(14, line: 20, weight: FontWeight.w700),
                ),
                Text(article.points[i], style: BabyDesign.text(14, line: 22)),
              ],
            )
          else
            Text(
              article.points[i],
              style: BabyDesign.text(
                13,
                line: 21,
                color: MomHomeTokens.secondary,
              ),
            ),
        Text(
          'This information helps you understand your records. It does not assess your baby\'s health or development.',
          style: BabyDesign.text(11, line: 17, color: MomHomeTokens.secondary),
        ),
      ],
    ),
    footer: Builder(
      builder: (sheetContext) => BabyPressFeedback(
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: BabyDesign.text(15, line: 22, weight: FontWeight.w700),
          ),
          onPressed: () {
            Navigator.pop(sheetContext);
            onAsk();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/baby_figma/Cozymate.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const Flexible(
                child: Text('Ask Momcozy AI', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
