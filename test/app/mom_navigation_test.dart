import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
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
            debugShowCheckedModeBanner: false,
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
        expect(
          tester.getSize(find.text('Momcozy AI')).width,
          greaterThan(100),
          reason: 'The full selected destination needs room at 2x text.',
        );
        expect(
          find.byKey(const ValueKey('bottom-nav-selected-label')),
          findsOneWidget,
        );
        for (final label in ['Me', 'Baby', 'Momcozy AI', 'Schedule', 'More']) {
          expect(
            tester
                .getSemantics(
                  find.byKey(ValueKey('bottom-nav-${label.toLowerCase()}')),
                )
                .label,
            label,
          );
        }
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('Momcozy AI'))
              .didExceedMaxLines,
          isFalse,
        );
        for (final entry in {
          'Baby': '/baby',
          'Momcozy AI': '/',
          'Schedule': '/schedule',
          'More': '/more',
          'Me': '/me',
        }.entries) {
          await tester.tap(
            find.byKey(ValueKey('bottom-nav-${entry.key.toLowerCase()}')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Page: ${entry.value}'), findsOneWidget);
          expect(find.text(entry.key), findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(entry.key))
                .didExceedMaxLines,
            isFalse,
          );
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
