import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/birth_journey_plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

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
        'delivery_date': '2026-06-20',
      },
      statusInfantsEndpoint: const {'items': <Object?>[]},
      feedingRecordsEndpoint: const {'items': <Object?>[]},
      milkTrendsEndpoint: const {'items': <Object?>[]},
      growthRecordsEndpoint: const {'items': <Object?>[]},
      pregnancyDiaryEntriesEndpoint: const {'items': <Object?>[]},
      statusPlansEndpoint: const {'items': <Object?>[]},
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'refresh-user',
      babyId: 'refresh-baby',
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
    expect(_requestCount(transport, statusProfileEndpoint), 1);
    expect(find.text('母乳产出'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
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
}

int _requestCount(FixtureApiJsonTransportByPath transport, String path) {
  return transport.getPaths.where((value) => value == path).length;
}
