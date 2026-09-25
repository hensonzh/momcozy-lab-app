/// The original conversation stays in storage; only the old assistant output
/// is replaced when it uses the retired brand. User-authored messages are never rewritten.
const retiredBrandAssistantNotice =
    'This earlier reply used an outdated name. Ask Momcozy AI again for an updated answer.';

final _unsupportedAssistantText = RegExp(
  r'cozy[\s-]*mate',
  caseSensitive: false,
  unicode: true,
);

bool containsUnsupportedAssistantText(String text) =>
    _unsupportedAssistantText.hasMatch(text);

String assistantDisplayText(String text) =>
    containsUnsupportedAssistantText(text) ? retiredBrandAssistantNotice : text;
