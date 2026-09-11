import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
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
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
