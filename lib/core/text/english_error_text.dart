/// Keeps historic, untranslated server error copy out of the English UI.
/// The original exception and response remain available to callers and logs.
String englishErrorText(String? message, {required String fallback}) {
  final text = message?.trim();
  if (text == null || text.isEmpty || _unsupportedText.hasMatch(text)) {
    return fallback;
  }
  return text;
}

final _unsupportedText = RegExp(
  r'[\u3400-\u9fff\u{20000}-\u{323af}\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u0400-\u052f\u0600-\u06ff\u0900-\u097f]|cozy[\s-]*mate',
  caseSensitive: false,
  unicode: true,
);
