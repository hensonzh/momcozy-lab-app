import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/features/schedule/domain/milk_plan_change_store.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('Schedule nav badge transfers one notice to the page route', (
    tester,
  ) async {
    final store = MilkPlanChangeStore();
    store.record(
      const MilkPlanChange(
        eventId: 'evt-nav-milk',
        operation: MilkPlanChangeOperation.updated,
        affectedDateKeys: ['2026-07-13'],
      ),
    );
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport(const {}),
      milkPlanChangeStore: store,
      userId: 'milk-nav-user',
      babyId: 'milk-nav-baby',
      now: () => DateTime.utc(2026, 7, 12),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        for (final path in ['/', '/schedule'])
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(
              body: Text(path),
              bottomNavigationBar: MomCozyBottomNavigation(location: path),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('bottom-nav-schedule-plan-badge')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/schedule');
    expect(store.hasUnread, isFalse);
    expect(store.hasPageNotice, isTrue);
    expect(
      find.byKey(const ValueKey('bottom-nav-schedule-plan-badge')),
      findsNothing,
    );
  });
}
