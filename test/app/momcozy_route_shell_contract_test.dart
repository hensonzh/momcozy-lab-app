import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';

import '../support/fixture_reader.dart';

void main() {
  group('MomCozy route shell contract', () {
    test('registers every documented Flutter route shell path', () {
      final routePaths = momCozyRoutes.map((route) => route.path).toSet();

      expect(routePaths, containsAll(_documentedRoutePaths));
      expect(routePaths, isNot(contains('/status')));
      expect(routePaths, isNot(contains('/schedule')));
    });

    test('retired UI implementations and internal aliases stay removed', () {
      expect(
        File('lib/features/more/presentation/more_page.dart').existsSync(),
        isFalse,
      );
      expect(Directory('lib/features/status').existsSync(), isFalse);
      expect(Directory('lib/features/schedule').existsSync(), isFalse);
      expect(Directory('lib/features/pregnancy_plan').existsSync(), isFalse);

      final featurePages = File(
        'lib/features/app_pages/momcozy_feature_pages.dart',
      ).readAsStringSync();
      final stageComponents = File(
        'lib/features/profile_overview/presentation/me_stage_components.dart',
      ).readAsStringSync();

      expect(featurePages, isNot(contains('more_page.dart')));
      expect(featurePages, isNot(contains('MorePage(')));
      expect(stageComponents, isNot(contains("context.go('/schedule')")));
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
  '/plan',
  '/more',
  '/community',
  '/more/body-profile',
  '/more/body-profile/edit',
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
  'pump_notification_intents.json',
];
