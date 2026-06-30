import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

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

  testWidgets('route shell consumes pending native route on startup', (
    tester,
  ) async {
    final routes = FakeRouteIntentPlatform();
    await routes.enqueuePendingRoute(const PendingNativeRoute(path: '/pump'));

    await tester.pumpWidget(MomCozyFlutterApp(routeIntentPlatform: routes));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await routes.dispose();
  });

  testWidgets('route shell follows active native route events', (tester) async {
    final routes = FakeRouteIntentPlatform();
    final router = createMomCozyRouter(initialLocation: '/status');

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, routeIntentPlatform: routes),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);

    routes.dispatchActiveRoute(const PendingNativeRoute(path: '/pump'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);

    await routes.dispose();
  });
}
