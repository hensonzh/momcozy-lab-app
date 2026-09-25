/// The original conversation stays in storage; only the old assistant output
/// is replaced in the English UI. User-authored messages are never rewritten.
const legacyAssistantEnglishNotice =
    'This earlier reply is not available in English. Ask Momcozy AI again for an updated answer.';

final _unsupportedAssistantText = RegExp(
  r'[\u3400-\u9fff\u{20000}-\u{323af}\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u0400-\u052f\u0600-\u06ff\u0900-\u097f]|cozy[\s-]*mate',
  caseSensitive: false,
  unicode: true,
);

bool containsUnsupportedAssistantText(String text) =>
    _unsupportedAssistantText.hasMatch(text);

String assistantDisplayText(String text) =>
    containsUnsupportedAssistantText(text)
    ? legacyAssistantEnglishNotice
    : text;
