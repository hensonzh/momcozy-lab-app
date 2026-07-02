import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('MomCozy feature page goldens', () {
    testWidgets('status page matches compact mobile baseline', (tester) async {
      await _setCompactMobileViewport(tester);
      await _pumpGoldenApp(tester, initialLocation: '/status');

      expect(find.byKey(const ValueKey('route-page-/status')), findsOneWidget);
      await expectLater(
        find.byKey(_goldenSurfaceKey),
        matchesGoldenFile('../../goldens/feature_pages/status_page_mobile.png'),
      );
    });

    testWidgets('pump page matches compact mobile baseline', (tester) async {
      await _setCompactMobileViewport(tester);
      await _pumpGoldenApp(tester, initialLocation: '/pump');

      expect(find.byKey(const ValueKey('route-page-/pump')), findsOneWidget);
      await expectLater(
        find.byKey(_goldenSurfaceKey),
        matchesGoldenFile('../../goldens/feature_pages/pump_page_mobile.png'),
      );
    });
  });
}

const _goldenSurfaceKey = ValueKey('momcozy-feature-golden-surface');

Future<void> _setCompactMobileViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpGoldenApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: initialLocation),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: _goldenRuntime(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _goldenRuntime() {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      statusProfileEndpoint: const <String, Object?>{
        'user_id': 'demo-user-fixture',
        'daily_summary': '哺乳期',
        'delivery_date': '2026-06-11',
      },
      statusInfantsEndpoint: const <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'demo-baby-fixture',
            'owner_user_id': 'demo-user-fixture',
            'infant_name': 'Mia',
            'birth_date': '2026-04-05',
            'sex': 'female',
            'status': 'active',
          },
        ],
      },
      pumpWorkstateEndpoint: const <String, Object?>{
        'id': 'telemetry-001',
        'owner_user_id': 'demo-user-fixture',
        'device_id': 'app-pump-session',
        'event_type': 'workstate',
        'occurred_at': '2026-07-01T10:00:00Z',
        'payload': <String, Object?>{},
      },
    }),
    blePlatform: FakeBlePlatform(
      initialPermission: BlePermissionState.granted,
      seedDevices: const [
        BleDeviceSnapshot(
          side: 'L',
          deviceId: 'ble-left-golden',
          deviceName: 'S12 Pro L',
          connected: true,
          battery: 87,
        ),
      ],
    ),
    userId: 'demo-user-golden',
    babyId: 'demo-baby-golden',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7),
  );
}
