import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/mom_module_routes.dart';
import 'package:momcozy_flutter_app/app/baby_module_routes.dart';

import '../support/fixture_reader.dart';

void main() {
  testWidgets('primary tabs do not jump when the keyboard appears', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const MaterialApp(
        home: MomCozyRouteShell(
          location: '/',
          child: TextField(key: ValueKey('nav-keyboard-input')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nav = find.byType(MomCozyBottomNavigation);
    final selectedTab = find.byKey(const ValueKey('bottom-nav-momcozy ai'));
    final initialTop = tester.getTopLeft(selectedTab).dy;
    final initialHeight = tester.getSize(nav).height;

    await tester.tap(find.byKey(const ValueKey('nav-keyboard-input')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(selectedTab).dy, initialTop);
    expect(tester.getSize(nav).height, initialHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary navigation is hidden on secondary pages', (
    tester,
  ) async {
    for (final location in [
      '/me',
      '/baby',
      '/',
      '/schedule',
      '/more',
      '/notifications',
      '/media-viewer',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MomCozyRouteShell(
            location: location,
            child: Text('Content: $location'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(MomCozyBottomNavigation),
        ['/notifications', '/media-viewer'].contains(location)
            ? findsNothing
            : findsOneWidget,
      );
      expect(find.text('Content: $location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
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
      final retired = Directory('lib/features/profile_overview/presentation');
      expect(retired.existsSync() ? retired.listSync() : [], isEmpty);
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
  '/privacy',
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
  'pump_notification_intents.json',
];
