import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_login_chrome.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/widgets/confirm_discard.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduced in [false, true]) {
      testWidgets('$platform route motion reduced=$reduced', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme().copyWith(
              platform: platform,
              pageTransitionsTheme: momCozyPageTransitionsTheme,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Center(child: Text('Destination')),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        final destination = find.text('Destination');
        final initialRect = tester.getRect(destination);
        final route = ModalRoute.of(tester.element(destination))!;
        expect(route.animation!.value, inExclusiveRange(0, 1));
        if (reduced) {
          for (final fade in tester.widgetList<FadeTransition>(
            find.ancestor(
              of: destination,
              matching: find.byType(FadeTransition),
            ),
          )) {
            expect(fade.opacity.value, 1);
          }
        }
        await tester.pumpAndSettle();
        if (reduced) {
          expect(tester.getRect(destination), initialRect);
        } else if (platform == TargetPlatform.iOS) {
          expect(tester.getRect(destination), isNot(initialRect));
        }
        if (platform == TargetPlatform.iOS) {
          await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(destination, findsNothing);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('discard opens fully and preserves cancel with reduced motion', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async => result = await confirmDiscard(context),
            child: const Text('Close'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump();
    final dialog = find.byType(AlertDialog);
    expect(ModalRoute.of(tester.element(dialog))!.animation!.value, 1);
    await tester.tap(find.text('继续填写'));
    await tester.pump();
    await tester.pump();
    expect(result, false);
    expect(dialog, findsNothing);
  });
  testWidgets('language sheet opens fully without elapsed animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SingleChildScrollView(child: AuthLoginHeader())),
    );
    await tester.tap(find.byKey(const ValueKey('auth-language-button')));
    await tester.pump();
    await tester.pump();
    final sheet = find.byType(BottomSheet);
    expect(ModalRoute.of(tester.element(sheet))!.animation!.value, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    expect(sheet, findsNothing);
  });
}

Widget _host(Widget body) => MaterialApp(
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: body),
);
