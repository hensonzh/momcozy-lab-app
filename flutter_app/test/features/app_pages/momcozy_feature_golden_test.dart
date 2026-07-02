import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('MomCozy feature page goldens', () {
    for (final route in _routeGoldens) {
      testWidgets('${route.label} matches compact mobile baseline', (
        tester,
      ) async {
        await _setCompactMobileViewport(tester);
        await _pumpGoldenApp(tester, initialLocation: route.path);

        expect(find.byKey(route.pageKey), findsOneWidget);
        await expectLater(
          find.byKey(_goldenSurfaceKey),
          matchesGoldenFile('../../goldens/feature_pages/${route.fileName}'),
        );
      });
    }
  });
}

const _goldenSurfaceKey = ValueKey('momcozy-feature-golden-surface');

const _routeGoldens = [
  _RouteGolden(
    label: 'agent hub',
    path: '/',
    fileName: 'agent_hub_mobile.png',
    pageKey: ValueKey('agent-hub-page'),
  ),
  _RouteGolden(
    label: 'status page',
    path: '/status',
    fileName: 'status_page_mobile.png',
    pageKey: ValueKey('route-page-/status'),
  ),
  _RouteGolden(
    label: 'schedule page',
    path: '/schedule',
    fileName: 'schedule_page_mobile.png',
    pageKey: ValueKey('route-page-/schedule'),
  ),
  _RouteGolden(
    label: 'records page',
    path: '/records',
    fileName: 'records_page_mobile.png',
    pageKey: ValueKey('route-page-/records'),
  ),
  _RouteGolden(
    label: 'pump page',
    path: '/pump',
    fileName: 'pump_page_mobile.png',
    pageKey: ValueKey('route-page-/pump'),
  ),
  _RouteGolden(
    label: 'device page',
    path: '/device',
    fileName: 'device_page_mobile.png',
    pageKey: ValueKey('route-page-/device'),
  ),
  _RouteGolden(
    label: 'device manage page',
    path: '/device/manage',
    fileName: 'device_manage_page_mobile.png',
    pageKey: ValueKey('route-page-/device/manage'),
  ),
  _RouteGolden(
    label: 'device user page',
    path: '/device/user',
    fileName: 'device_user_page_mobile.png',
    pageKey: ValueKey('route-page-/device/user'),
  ),
  _RouteGolden(
    label: 'calibration page',
    path: '/calibration',
    fileName: 'calibration_page_mobile.png',
    pageKey: ValueKey('route-page-/calibration'),
  ),
  _RouteGolden(
    label: 'community page',
    path: '/community',
    fileName: 'community_page_mobile.png',
    pageKey: ValueKey('route-page-/community'),
  ),
  _RouteGolden(
    label: 'w1 page',
    path: '/w1',
    fileName: 'w1_page_mobile.png',
    pageKey: ValueKey('route-page-/w1'),
  ),
  _RouteGolden(
    label: 'hospital bag page',
    path: '/hospital-bag-cart',
    fileName: 'hospital_bag_page_mobile.png',
    pageKey: ValueKey('route-page-/hospital-bag-cart'),
  ),
  _RouteGolden(
    label: 'ibclc page',
    path: '/ibclc-chat.html',
    fileName: 'ibclc_page_mobile.png',
    pageKey: ValueKey('route-page-/ibclc-chat.html'),
  ),
  _RouteGolden(
    label: 'media viewer page',
    path: '/media-viewer',
    fileName: 'media_viewer_page_mobile.png',
    pageKey: ValueKey('route-page-/media-viewer'),
  ),
  _RouteGolden(
    label: 'not found page',
    path: '/404',
    fileName: 'not_found_page_mobile.png',
    pageKey: ValueKey('route-page-/404'),
  ),
];

class _RouteGolden {
  const _RouteGolden({
    required this.label,
    required this.path,
    required this.fileName,
    required this.pageKey,
  });

  final String label;
  final String path;
  final String fileName;
  final ValueKey<String> pageKey;
}

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
  await tester.pump();
  final appContext = tester.element(find.byType(MomCozyFlutterApp));
  await tester.runAsync(() async {
    for (final asset in _goldenImageAssets) {
      await precacheImage(
        AssetImage(asset),
        appContext,
      ).timeout(const Duration(seconds: 5));
    }
  });
  await tester.pumpAndSettle();
}

const _goldenImageAssets = [
  MomCozyAssets.agentAvatar,
  MomCozyAssets.momAvatar,
  MomCozyAssets.babyAvatar,
  MomCozyAssets.pumpM9,
  MomCozyAssets.ibclcConsultantAvatar,
  MomCozyAssets.postpartumRecoveryIcon,
  'assets/images/hospital_bag_mom_pad.jpg',
  'assets/images/hospital_bag_mom_sanitary.jpg',
  'assets/images/hospital_bag_mom_underwear.png',
  'assets/images/hospital_bag_mom_wipes.jpg',
  'assets/images/hospital_bag_mom_bottle.jpg',
  'assets/images/hospital_bag_mom_briefs.png',
  'assets/images/hospital_bag_baby_diaper.jpg',
  'assets/images/hospital_bag_baby_wipes.jpg',
  'assets/images/hospital_bag_baby_towel.jpg',
  'assets/images/hospital_bag_baby_blanket.jpg',
  'assets/images/hospital_bag_baby_clothes.jpg',
  'assets/images/hospital_bag_baby_bath_towel.jpg',
  'assets/images/hospital_bag_milk_pad.jpg',
  'assets/images/hospital_bag_milk_cream.jpg',
  'assets/images/hospital_bag_milk_storage.jpg',
  'assets/images/hospital_bag_pump_m9.jpg',
  'assets/images/hospital_bag_milk_bra.jpg',
  'assets/images/hospital_bag_milk_bottle.jpg',
];

MomCozyApiRuntime _goldenRuntime() {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      statusOverviewEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'mom': <String, Object?>{'stage': '哺乳期', 'postpartum_day': 21},
          'baby': <String, Object?>{'nickname': 'Mia', 'age_days': 88},
        },
      },
      pumpWorkstateEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'need_reply': true,
          'output': 'Workstate accepted',
          'reply_code': 'pump_state_changed',
          'reply_side': 'left',
        },
      },
      scheduleDayPlanEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{'tasks': <Object?>[]},
      },
      pumpMilkRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': [
            {
              'id': 'pump-1',
              'title': '20分钟',
              'amountMl': 175,
              'pumpSource': 1,
              'occurredAt': '2026-07-02T08:20:00Z',
            },
            {
              'id': 'pump-2',
              'title': '15分钟',
              'amountMl': 135,
              'pumpSource': 1,
              'occurredAt': '2026-07-02T13:20:00Z',
            },
            {
              'id': 'pump-3',
              'title': '一分钟',
              'amountMl': 155,
              'pumpSource': 9,
              'occurredAt': '2026-07-02T18:10:00Z',
            },
          ],
        },
      },
      feedingRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': [
            {
              'id': 'feed-1',
              'type': 'bottle',
              'amountMl': 70,
              'occurredAt': '2026-07-02T10:10:00Z',
            },
          ],
        },
      },
      growthRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': [
            {
              'id': 'growth-1',
              'weightGram': 5600,
              'heightCm': 58.2,
              'measuredAt': '2026-07-01T08:00:00Z',
            },
          ],
        },
      },
    }),
    multipartTransport: FixtureApiMultipartTransport(const <String, Object?>{
      'status': 200,
      'data': <String, Object?>{
        'id': 'file-golden',
        'name': 'pump-display-fixture.png',
        'size': 68,
        'extension': 'png',
        'mime_type': 'image/png',
      },
    }),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-golden',
    babyId: 'demo-baby-golden',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7, 3),
  );
}
