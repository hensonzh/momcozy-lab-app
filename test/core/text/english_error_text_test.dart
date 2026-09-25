import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/text/english_error_text.dart';

void main() {
  const fallback = 'Please try again.';

  test('keeps useful English error details', () {
    expect(
      englishErrorText('Reset failed.', fallback: fallback),
      'Reset failed.',
    );
  });

  test('falls back for untranslated or retired-brand error details', () {
    for (final message in [
      'Cozymate is unavailable.',
      'Cozy Mate is unavailable.',
      '服务暂时不可用。',
      'The service is 暂时 unavailable.',
      '잠시 후 다시 시도해 주세요.',
      'Попробуйте позже.',
      'حاول مرة أخرى.',
      '  ',
      null,
    ]) {
      expect(englishErrorText(message, fallback: fallback), fallback);
    }
  });
}
