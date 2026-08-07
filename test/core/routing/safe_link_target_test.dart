import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/routing/safe_link_target.dart';

void main() {
  group('SafeLinkTarget', () {
    test('accepts app paths and preserves query parameters', () {
      final target = SafeLinkTarget.tryParse('/me?day=2026-07-11');

      expect(target, isNotNull);
      expect(target!.internalPath, '/me');
      expect(target.internalLocation, '/me?day=2026-07-11');
      expect(target.externalUri, isNull);
    });

    test('accepts absolute HTTP and HTTPS links without credentials', () {
      final https = SafeLinkTarget.tryParse(
        'https://www.who.int/health-topics/breastfeeding#guidance',
      );
      final http = SafeLinkTarget.tryParse('http://example.com/reference');

      expect(https?.externalUri?.scheme, 'https');
      expect(https?.externalUri?.host, 'www.who.int');
      expect(http?.externalUri?.scheme, 'http');
      expect(https?.internalPath, isNull);
    });

    test('rejects unsafe schemes and ambiguous locations', () {
      for (final value in const [
        'javascript:alert(1)',
        'data:text/html,hello',
        'file:///tmp/private',
        'intent://scan',
        '//example.com/path',
        'example.com/path',
        '/../../me',
        '/me\\settings',
        'https://user:password@example.com/private',
        'https://exa mple.com',
      ]) {
        expect(
          SafeLinkTarget.tryParse(value),
          isNull,
          reason: 'must reject $value',
        );
      }
    });
  });
}
