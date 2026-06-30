import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';

void main() {
  testWidgets('route shell starts at Agent Hub and navigates bottom tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const MomCozyFlutterApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/')), findsOneWidget);
    expect(find.text('智能体'), findsWidgets);

    await tester.tap(find.text('设备').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/device')), findsOneWidget);
    expect(find.text('设备'), findsWidgets);
  });

  testWidgets('route shell hides bottom navigation on focused flows', (
    tester,
  ) async {
    final router = createMomCozyRouter(initialLocation: '/pump');

    await tester.pumpWidget(MomCozyFlutterApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('route shell renders recoverable not found route', (
    tester,
  ) async {
    final router = createMomCozyRouter(initialLocation: '/unknown-old-page');

    await tester.pumpWidget(MomCozyFlutterApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/404')), findsOneWidget);
    expect(find.text('页面未找到'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
