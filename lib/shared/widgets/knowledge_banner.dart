import 'package:flutter/material.dart';
import '../../core/routing/external_url_launcher.dart';
import '../../domain/shared/knowledge_article.dart';
import '../design_system/momcozy_design_system.dart';

class KnowledgeBanner extends StatelessWidget {
  const KnowledgeBanner({
    super.key,
    required this.label,
    required this.article,
    required this.onOpen,
    this.compact = false,
  });
  final String label;
  final KnowledgeArticle article;
  final VoidCallback onOpen;
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? _CompactKnowledgeBanner(label: label, article: article, onOpen: onOpen)
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
                      padding: const EdgeInsets.fromLTRB(22, 25, 22, 27),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 72),
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
                            padding: const EdgeInsets.only(right: 24),
                            child: Text(
                              article.title.replaceAll('，', '，\n'),
                              style: const TextStyle(
                                fontSize: MomCozyTypography.sectionSize,
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
                      padding: const EdgeInsets.all(2),
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

class _CompactKnowledgeBanner extends StatelessWidget {
  const _CompactKnowledgeBanner({
    required this.label,
    required this.article,
    required this.onOpen,
  });
  final String label;
  final KnowledgeArticle article;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(MomCozyRadii.card),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(color: MomCozyColors.violetSoft),
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          gradient: MomCozyGradients.knowledge,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -38,
              top: -54,
              child: Container(
                width: 144,
                height: 144,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: MomCozyColors.raised,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 138),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 66, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: MomCozyTypography.microSize,
                        fontWeight: FontWeight.w700,
                        color: MomCozyColors.knowledgeLabel,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: MomCozyTypography.bodyLargeSize,
                        fontWeight: FontWeight.w700,
                        height: 1.34,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.summary,
                      style: const TextStyle(
                        fontSize: MomCozyTypography.microSize,
                        color: MomCozyColors.mutedForeground,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 15,
              top: 15,
              child: Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MomCozyColors.avatarBorder,
                  border: Border.all(color: MomCozyColors.violetSoft),
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
              right: 17,
              bottom: 15,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: MomCozyColors.knowledgeLabel,
                size: 22,
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
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '每日知识',
                    style: TextStyle(fontSize: MomCozyTypography.titleSize),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              article.title,
              style: const TextStyle(
                fontSize: MomCozyTypography.headingSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(article.summary),
            for (var index = 0; index < article.points.length; index++)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: MomCozyColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(article.points[index])),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (article.source case final source?)
              TextButton.icon(
                onPressed: () async {
                  var opened = false;
                  try {
                    opened = await const PlatformExternalUrlLauncher().open(
                      Uri.parse(source.url),
                    );
                  } catch (_) {
                    opened = false;
                  }
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('暂时无法打开来源链接')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(source.label),
              ),
            Text(
              boundary,
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                color: MomCozyColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onAsk();
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('问问 Cozymate'),
            ),
          ],
        ),
      ),
    ),
  ),
);
