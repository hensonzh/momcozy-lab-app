import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Route intent fixtures', () {
    test(
      'keeps retired events generic and migrates old status links to Me',
      () {
        const retiredEvents = ['summary', 'mom_baby', 'health_issue'];

        for (final event in retiredEvents) {
          final actual = routeIntentFromNativeNotification({
            'path': '/',
            'notifyJson': '{"event":"$event","body":"retired"}',
          });

          expect(actual?.type, 'OpenAgentHub', reason: event);
          expect(actual?.path, '/', reason: event);
          expect(actual?.payload, isEmpty, reason: event);
        }

        final legacyStatus = routeIntentFromNativeNotification({
          'path': '/status?mmcNotify=growth',
          'notifyJson': '{"event":"grown"}',
        });

        expect(legacyStatus?.type, 'OpenMe');
        expect(legacyStatus?.path, '/me');
        expect(legacyStatus?.payload, const {'source': 'legacy-status-route'});
        expect(legacyStatus?.consume, 'once');
      },
    );

    test('maps native Plan navigation to the canonical Plan route', () {
      final intent = routeIntentFromNativeNotification({'path': '/plan'});

      expect(intent?.type, 'OpenPlan');
      expect(intent?.path, '/plan');
      expect(intent?.payload, const {'source': 'native-navigation'});
      expect(intent?.consume, 'once');
    });

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

        _expectIntentsMatchExpected(actual, expected);
        expect(
          actual.first.payload,
          containsPair('reason', 'unsupported-scheme'),
        );
        expect(actual[1].path, '/unknown-old-page');
        expect(actual[1].payload, containsPair('fallback', 'AgentHub'));
        expect(actual[3].type, 'ShowToast');
        expect(actual[4].payload, containsPair('fallback', '/'));
        expect(actual[5].payload, containsPair('status', 'unknown'));
      },
    );

    test('map pump pending navigation payloads to one-shot intents', () {
      final fixture = readFixtureMap(
        'route_intents/pump_notification_intents.json',
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

      _expectIntentsMatchExpected(actual, expected);
    });

    test('map agent and feature navigation events to typed intents', () {
      final fixture = readFixtureMap(
        'route_intents/agent_artifact_and_feature_navigation_intents.json',
      );
      final input = Map<String, Object?>.from(fixture['input']! as Map);
      final events = List<Object?>.from(input['events']! as List);
      final expected = List<Object?>.from(fixture['expectedIntents']! as List)
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(growable: false);

      final actual = routeIntentsFromAgentNavigationEvents(events);

      _expectIntentsMatchExpected(actual, expected);
    });

    test('map media viewer and IBCLC return inputs to typed intents', () {
      final fixture = readFixtureMap(
        'route_intents/media_viewer_and_ibclc_return_intents.json',
      );
      final input = Map<String, Object?>.from(fixture['input']! as Map);
      final expected = List<Object?>.from(fixture['expectedIntents']! as List)
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(growable: false);

      final actual = routeIntentsFromMediaAndIbclcInput(input);

      _expectIntentsMatchExpected(actual, expected);
    });
  });
}

void _expectIntentsMatchExpected(
  List<RouteIntent> actual,
  List<Map<String, Object?>> expected,
) {
  expect(actual, hasLength(expected.length));
  for (var i = 0; i < expected.length; i += 1) {
    final expectedIntent = expected[i];
    final actualIntent = actual[i];
    final reason = 'intent #$i ${expectedIntent['type']}';
    expect(actualIntent.type, expectedIntent['type'], reason: reason);
    expect(actualIntent.path, expectedIntent['path'], reason: reason);
    expect(
      actualIntent.payload,
      expectedIntent['payload'] ?? const <String, Object?>{},
      reason: reason,
    );
    expect(actualIntent.consume, expectedIntent['consume'], reason: reason);
  }
}
