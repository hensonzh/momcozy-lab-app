import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';

import '../support/fixture_reader.dart';

void main() {
  group('MomCozy route shell contract', () {
    test('registers every documented Flutter route shell path', () {
      final routePaths = momCozyRoutes.map((route) => route.path).toSet();

      expect(routePaths, containsAll(_documentedRoutePaths));
      expect(routePaths, isNot(contains('/status')));
    });

    test(
      'covers route intent fixture destinations except NotFound fallback',
      () {
        final routePaths = momCozyRoutes.map((route) => route.path).toSet();
        final expectedPaths = <String>{};

        for (final fixtureName in _routeIntentFixtures) {
          final fixture = readFixtureMap('route_intents/$fixtureName');
          final intents = List<Object?>.from(
            fixture['expectedIntents']! as List,
          );
          for (final intent in intents.whereType<Map>()) {
            final type = intent['type'];
            final path = intent['path'];
            if (type == 'NotFoundIntent' || path is! String) continue;
            if (!path.startsWith('/')) continue;
            expectedPaths.add(path.split('?').first);
          }
        }

        expect(routePaths, containsAll(expectedPaths));
      },
    );
  });
}

const _documentedRoutePaths = {
  '/',
  '/me',
  '/baby',
  '/calibration',
  '/pump',
  '/schedule',
  '/more',
  '/community',
  '/device',
  '/device/manage',
  '/device/user',
  '/w1',
  '/hospital-bag-cart',
  '/ibclc-chat.html',
  '/media-viewer',
};

const _routeIntentFixtures = [
  'agent_artifact_and_feature_navigation_intents.json',
  'malformed_and_unknown_route_fallbacks.json',
  'media_viewer_and_ibclc_return_intents.json',
  'native_notification_analysis_intents.json',
  'milk_plan_pending_intent.json',
  'pump_notification_intents.json',
];
