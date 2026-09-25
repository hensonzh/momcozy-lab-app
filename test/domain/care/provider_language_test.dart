import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';

void main() {
  test(
    'legacy provider languages use English labels without rewriting data',
    () {
      const provider = CareProvider(
        id: 'provider',
        displayName: 'Consultant',
        timezone: 'America/New_York',
        regions: ['US'],
        languages: ['English', '中文', 'Français'],
        bio: 'IBCLC support.',
        sandbox: false,
      );

      expect(provider.languageLabel, 'English · Chinese · French');
      expect(provider.languages, ['English', '中文', 'Français']);
    },
  );

  test('ISO codes and translated language names have natural English labels', () {
    const provider = CareProvider(
      id: 'coded',
      displayName: 'Consultant',
      timezone: 'UTC',
      regions: ['CA'],
      languages: [
        'en',
        'fr',
        'es-MX',
        'zh-CN',
        '普通话',
        'Español',
        'xx',
        'CozyMate',
      ],
      bio: '',
      sandbox: false,
    );
    expect(
      provider.languageLabel,
      'English · French · Spanish · Chinese · Mandarin Chinese · Spanish · Additional language · Additional language',
    );
    expect(provider.languages[0], 'en');
  });
}
