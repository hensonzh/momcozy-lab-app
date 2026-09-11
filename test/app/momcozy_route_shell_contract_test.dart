import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/mom_module_routes.dart';
import 'package:momcozy_flutter_app/app/baby_module_routes.dart';

import '../support/fixture_reader.dart';

void main() {
  group('MomCozy route shell contract', () {
    test('registers every documented Flutter route shell path', () {
      final routePaths = {
        ...momCozyRoutes.map((route) => route.path),
        ...momModuleRoutes.map((route) => route.path),
        ...babyModuleRoutes.map((route) => route.path),
      };

      expect(routePaths, containsAll(_documentedRoutePaths));
      expect(routePaths, isNot(contains('/status')));
      expect(routePaths, contains('/schedule'));
    });

    test('retired UI implementations and internal aliases stay removed', () {
      expect(
        File('lib/modules/profile/presentation/more_page.dart').existsSync(),
        isTrue,
      );
      expect(Directory('lib/features/status').existsSync(), isFalse);
      expect(Directory('lib/features/schedule').existsSync(), isFalse);
      expect(Directory('lib/features/pregnancy_plan').existsSync(), isFalse);

      final featurePages = File(
        'lib/features/app_pages/momcozy_feature_pages.dart',
      ).readAsStringSync();
      expect(
        featurePages,
        contains('modules/profile/presentation/more_page.dart'),
      );
      expect(
        Directory('lib/features/profile_overview/presentation').listSync(),
        isEmpty,
      );
    });

    test(
      'covers route intent fixture destinations except NotFound fallback',
      () {
        final routePaths = {
          ...momCozyRoutes.map((route) => route.path),
          ...momModuleRoutes.map((route) => route.path),
          ...babyModuleRoutes.map((route) => route.path),
        };
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
  '/schedule',
  '/more',
  '/media-viewer',
};

const _routeIntentFixtures = [
  'agent_artifact_and_feature_navigation_intents.json',
  'malformed_and_unknown_route_fallbacks.json',
  'media_viewer_and_ibclc_return_intents.json',
  'pump_notification_intents.json',
];
