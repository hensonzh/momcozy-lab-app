import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('navigation reference at $width with all selected states', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: const Scaffold(
            body: RepaintBoundary(
              key: ValueKey('navigation-reference'),
              child: Column(
                children: [
                  MomCozyBottomNavigation(location: '/me'),
                  MomCozyBottomNavigation(location: '/baby'),
                  MomCozyBottomNavigation(location: '/'),
                  MomCozyBottomNavigation(location: '/schedule'),
                  MomCozyBottomNavigation(location: '/more'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bars = find.byKey(const ValueKey('bottom-nav-chrome'));
      for (var index = 0; index < 5; index++) {
        expect(tester.getSize(bars.at(index)), Size(width, 82));
        final navigation = find.byType(MomCozyBottomNavigation).at(index);
        final origin = tester.getTopLeft(navigation);
        for (final label in ['me', 'baby', 'cozymate', 'schedule', 'more']) {
          final destination = find.descendant(
            of: navigation,
            matching: find.byKey(ValueKey('bottom-nav-$label')),
          );
          final first = find.descendant(
            of: find.byType(MomCozyBottomNavigation).first,
            matching: find.byKey(ValueKey('bottom-nav-$label')),
          );
          expect(
            tester.getRect(destination).shift(-origin),
            tester
                .getRect(first)
                .shift(
                  -tester.getTopLeft(
                    find.byType(MomCozyBottomNavigation).first,
                  ),
                ),
          );
        }
      }
      await expectLater(
        find.byKey(const ValueKey('navigation-reference')),
        matchesGoldenFile(
          '../goldens/design_system/navigation-${width.toInt()}.png',
        ),
      );
    });
    testWidgets(
      'five navigation destinations remain readable and tappable at 2x text on $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/me',
          routes: [
            for (final path in ['/me', '/baby', '/', '/schedule', '/more'])
              GoRoute(
                path: path,
                builder: (context, state) => Scaffold(
                  body: Text('Page: ${state.uri.path}'),
                  bottomNavigationBar: MomCozyBottomNavigation(
                    location: state.uri.path,
                  ),
                ),
              ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: momCozyTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final initialBar = tester.getRect(
          find.byKey(const ValueKey('bottom-nav-chrome')),
        );
        final avatar = tester.getRect(
          find.byKey(const ValueKey('bottom-nav-center-avatar')),
        );
        await tester.tapAt(Offset(avatar.center.dx, avatar.top + 3));
        await tester.pumpAndSettle();
        expect(find.text('Page: /'), findsOneWidget);
        for (final entry in {
          'Baby': '/baby',
          'Cozymate': '/',
          'Schedule': '/schedule',
          'More': '/more',
          'Me': '/me',
        }.entries) {
          await tester.tap(find.text(entry.key));
          await tester.pumpAndSettle();
          expect(find.text('Page: ${entry.value}'), findsOneWidget);
          expect(
            tester.getRect(find.byKey(const ValueKey('bottom-nav-chrome'))),
            initialBar,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
