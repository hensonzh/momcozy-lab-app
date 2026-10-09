import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/web_demo/web_demo_app.dart';

void main() {
  final today = DateTime.utc(2026, 10, 9, 10);

  testWidgets('web demo opens fictional Me and Baby without a login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(WebDemoApp(now: () => today));
    await tester.pumpAndSettle();
    expect(find.text('Mia'), findsWidgets);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(find.text('Reset demo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'schedule edits are scoped to this run and Reset demo restores the seed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(WebDemoApp(now: () => today));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Demo walk',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-title')), findsNothing);
      expect(find.text('Demo walk'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
      await tester.pumpAndSettle();
      expect(find.text('Demo walk'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('web demo hides account and native-only surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(WebDemoApp(now: () => today));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
    await tester.pumpAndSettle();
    expect(find.textContaining('fictional', findRichText: true), findsWidgets);
    expect(find.text('Request account deletion'), findsNothing);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Reset demo'), findsOneWidget);
  });
}
