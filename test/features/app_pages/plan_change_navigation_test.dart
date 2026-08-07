import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_change_store.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('Plan tab opens Plan and marks its pending update viewed', (
    tester,
  ) async {
    final store = PlanChangeStore();
    store.record(const PlanChange(eventId: 'evt-nav-plan'));
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransportByPath({
        planListEndpoint: const {'items': <Object?>[]},
      }),
      planChangeStore: store,
      userId: 'plan-nav-user',
      babyId: 'plan-nav-baby',
      now: () => DateTime.utc(2026, 7, 12),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        for (final path in ['/', '/plan'])
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

    expect(find.byKey(const ValueKey('bottom-nav-plan')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-plan')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/plan');
    expect(store.hasUnread, isFalse);
  });
}
