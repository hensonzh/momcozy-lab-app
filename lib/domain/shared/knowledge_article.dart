final class KnowledgeArticle {
  const KnowledgeArticle({
    required this.title,
    required this.summary,
    required this.points,
    this.source,
  });
  final String title;
  final String summary;
  final List<String> points;
  final ({String label, String url})? source;
}
