import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';

import '../../support/fixture_reader.dart';

const requiredDomains = <String>[
  'user_profile',
  'pump',
  'mom_baby',
  'plan',
  'pregnancy_diary',
  'notify',
  'media',
];

const requiredVariants = <String>[
  'success',
  'business_error',
  'http_error',
  'empty',
  'partial',
  'legacy_alias',
];

void main() {
  group('API contract fixtures', () {
    test('provide every required variant for each Flutter API domain', () {
      for (final domain in requiredDomains) {
        for (final variant in requiredVariants) {
          final fixture = readFixtureMap('api/$domain/$variant.json');

          expect(fixture['domain'], domain, reason: '$domain/$variant');
          expect(fixture['variant'], variant, reason: '$domain/$variant');
          expect(
            fixture['endpoint'],
            isA<String>(),
            reason: '$domain/$variant',
          );
          expect(fixture['method'], isA<String>(), reason: '$domain/$variant');
          expect(
            fixture.containsKey('request'),
            isTrue,
            reason: '$domain/$variant',
          );
          expect(
            fixture.containsKey('response'),
            isTrue,
            reason: '$domain/$variant',
          );
        }
      }
    });

    test(
      'unwrap success envelopes and keep business errors distinct from HTTP errors',
      () {
        for (final domain in requiredDomains) {
          final success = responseFor(domain, 'success');
          final businessError = responseFor(domain, 'business_error');
          final httpError = responseFor(domain, 'http_error');

          expect(isApiEnvelope(success), isTrue, reason: '$domain/success');
          expect(() => unwrapApiEnvelope(success), returnsNormally);
          expect(
            () => unwrapApiEnvelope(businessError),
            throwsA(isA<ApiBusinessException>()),
            reason: '$domain/business_error',
          );
          expect(
            isHttpErrorBody(httpError),
            isTrue,
            reason: '$domain/http_error',
          );
        }
      },
    );

    test(
      'accept legacy snake/camel aliases without adding secret-shaped values',
      () {
        final fixture = readFixtureMap('api/user_profile/legacy_alias.json');
        final response = Map<String, Object?>.from(fixture['response']! as Map);
        final data = Map<String, Object?>.from(
          unwrapApiEnvelope(response)! as Map,
        );
        final payload = requiredDomains
            .expand(
              (domain) => requiredVariants.map(
                (variant) => readFixtureMap('api/$domain/$variant.json'),
              ),
            )
            .toList(growable: false)
            .toString();

        expect(aliasString(data, 'display_name', 'displayName'), 'Demo User');
        expect(
          aliasString(data, 'current_care_stage', 'currentCareStage'),
          'postpartum',
        );
        expect(
          payload,
          isNot(contains(RegExp('Bearer\\s+', caseSensitive: false))),
        );
        expect(
          payload,
          isNot(contains(RegExp('Authorization', caseSensitive: false))),
        );
      },
    );
  });
}

Map<String, Object?> responseFor(String domain, String variant) {
  final fixture = readFixtureMap('api/$domain/$variant.json');
  return Map<String, Object?>.from(fixture['response']! as Map);
}
