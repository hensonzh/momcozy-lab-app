import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Route intent fixtures', () {
    test(
      'map native notification payloads to typed one-shot route intents',
      () {
        final fixture = readFixtureMap(
          'route_intents/native_notification_analysis_intents.json',
        );
        final input = Map<String, Object?>.from(fixture['input']! as Map);
        final payloads = List<Object?>.from(
          input['pendingNavigatePayloads']! as List,
        );
        final expected = List<Object?>.from(fixture['expectedIntents']! as List)
            .whereType<Map>()
            .map((value) => Map<String, Object?>.from(value))
            .toList(growable: false);

        final actual = routeIntentsFromNativePayloads(payloads);

        expect(
          actual.map((intent) => intent.type),
          expected.map((item) => item['type']),
        );
        expect(
          actual.map((intent) => intent.path),
          expected.map((item) => item['path']),
        );
        expect(actual.every((intent) => intent.payload.isNotEmpty), isTrue);
        expect(actual[2].payload, containsPair('requiresContextEvent', true));
        expect(actual[3].payload, containsPair('highlight', 'growth'));
      },
    );

    test(
      'reject unsafe routes and keep unknown same-origin routes recoverable',
      () {
        final fixture = readFixtureMap(
          'route_intents/malformed_and_unknown_route_fallbacks.json',
        );
        final input = Map<String, Object?>.from(fixture['input']! as Map);
        final cases = List<Object?>.from(input['cases']! as List)
            .whereType<Map>()
            .map((value) => Map<String, Object?>.from(value))
            .toList(growable: false);
        final expected = List<Object?>.from(fixture['expectedIntents']! as List)
            .whereType<Map>()
            .map((value) => Map<String, Object?>.from(value))
            .toList(growable: false);

        final actual = cases
            .map(routeIntentFromFallbackCase)
            .toList(growable: false);

        expect(
          actual.map((intent) => intent.type),
          expected.map((item) => item['type']),
        );
        expect(
          actual.first.payload,
          containsPair('reason', 'unsupported-scheme'),
        );
        expect(actual[1].path, '/unknown-old-page');
        expect(actual[1].payload, containsPair('fallback', 'AgentHub'));
        expect(actual[3].payload, containsPair('fallback', '/'));
        expect(actual[4].payload, containsPair('status', 'unknown'));
      },
    );
  });
}
