import 'package:app/features/agent_hub/artifacts/agent_artifact_model.dart';

String? agentArtifactVoiceFallbackText(Iterable<AgentArtifactCardView> cards) {
  final cardList = cards.toList(growable: false);
  if (cardList.isEmpty || cardList.last.isUnsupported) return null;

  final card = cardList.last;
  final chunks = <String>[];

  void add(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || chunks.contains(text)) return;
    chunks.add(text);
  }

  add(card.title);
  add(card.content ?? card.description);
  return chunks.isEmpty ? null : chunks.join(' ');
}
