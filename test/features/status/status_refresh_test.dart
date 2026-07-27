import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:app/features/records/data/records_api_repository.dart';
import 'package:app/features/status/data/status_api_repository.dart';
import 'package:app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('status refreshes on resume and pull without dropping content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final routes = FakeRouteIntentPlatform();
    addTearDown(routes.dispose);
    final transport = FixtureApiJsonTransportByPath({
      statusProfileEndpoint: const {
        'user_id': 'refresh-user',
        'estimated_due_date': '2026-06-20',
      },
      statusInfantsEndpoint: const {'items': <Object?>[]},
      feedingRecordsEndpoint: const {'items': <Object?>[]},
      milkTrendsEndpoint: const {'items': <Object?>[]},
      growthRecordsEndpoint: const {'items': <Object?>[]},
      pregnancyDiaryEntriesEndpoint: const {'items': <Object?>[]},
      pregnancyPlansEndpoint: const {'items': <Object?>[]},
    });
    var clock = DateTime(2026, 7, 11, 10);
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'refresh-user',
      babyId: 'refresh-baby',
      now: () => clock,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/status'),
        routeIntentPlatform: routes,
        apiRuntime: runtime,
      ),
    );
    await tester.pumpAndSettle();
    expect(_requestCount(transport, statusProfileEndpoint), 1);
    expect(find.text('母乳产出'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_requestCount(transport, statusProfileEndpoint), 1);
    expect(find.text('母乳产出'), findsOneWidget);

    clock = clock.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_requestCount(transport, statusProfileEndpoint), 2);
    expect(find.text('母乳产出'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('route-page-/status')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();
    expect(_requestCount(transport, statusProfileEndpoint), 3);
    expect(find.text('母乳产出'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh tab return renders cached Status without new GETs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final routes = FakeRouteIntentPlatform();
    addTearDown(routes.dispose);
    final transport = FixtureApiJsonTransportByPath({
      statusProfileEndpoint: const {
        'user_id': 'cache-user',
        'estimated_due_date': '2026-06-20',
      },
      statusInfantsEndpoint: const {'items': <Object?>[]},
      feedingRecordsEndpoint: const {'items': <Object?>[]},
      milkTrendsEndpoint: const {'items': <Object?>[]},
      growthRecordsEndpoint: const {'items': <Object?>[]},
      pregnancyDiaryEntriesEndpoint: const {'items': <Object?>[]},
      pregnancyPlansEndpoint: const {'items': <Object?>[]},
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'cache-user',
      babyId: 'cache-baby',
      now: () => DateTime(2026, 7, 11, 10),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/status'),
        routeIntentPlatform: routes,
        apiRuntime: runtime,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
    await tester.pumpAndSettle();
    final countsBeforeReturn = Map<String, int>.fromEntries(
      [
        statusProfileEndpoint,
        statusInfantsEndpoint,
        feedingRecordsEndpoint,
        milkTrendsEndpoint,
        growthRecordsEndpoint,
        pregnancyDiaryEntriesEndpoint,
        pregnancyPlansEndpoint,
      ].map((path) => MapEntry(path, _requestCount(transport, path))),
    );
    await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
    await tester.pump();
    await tester.pump();

    expect(find.text('母乳产出'), findsOneWidget);
    expect(find.text('正在加载孕期计划'), findsNothing);
    await tester.pumpAndSettle();
    for (final entry in countsBeforeReturn.entries) {
      expect(_requestCount(transport, entry.key), entry.value);
    }
  });
}

int _requestCount(FixtureApiJsonTransportByPath transport, String path) {
  return transport.getPaths.where((value) => value == path).length;
}
