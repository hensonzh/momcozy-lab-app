import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:app/features/records/data/records_api_repository.dart';
import 'package:app/features/schedule/data/schedule_api_repository.dart';
import 'package:app/features/status/data/status_api_repository.dart';
import 'package:app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          return switch (call.method) {
            'read' => null,
            'readAll' => <String, String>{},
            'containsKey' => false,
            'write' || 'delete' || 'deleteAll' => null,
            _ => null,
          };
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('MomCozy feature page goldens', () {
    for (final viewport in _goldenViewports) {
      for (final route in _routeGoldens) {
        testWidgets('${route.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);
          await _pumpGoldenApp(tester, initialLocation: route.path);

          expect(find.byKey(route.pageKey), findsOneWidget);
          await expectLater(
            find.byKey(_goldenSurfaceKey),
            matchesGoldenFile(viewport.filePath(route.fileName)),
          );
        });
      }
    }
  });
}

const _goldenSurfaceKey = ValueKey('momcozy-feature-golden-surface');
const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

const _goldenViewports = [
  _GoldenViewport(
    label: 'narrow mobile 360x800',
    size: Size(360, 800),
    directory: 'narrow_360x800',
  ),
  _GoldenViewport(label: 'compact mobile', size: Size(390, 844)),
  _GoldenViewport(
    label: 'large mobile 430x932',
    size: Size(430, 932),
    directory: 'large_430x932',
  ),
];

final _routeGoldens = [
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

class _GoldenViewport {
  const _GoldenViewport({
    required this.label,
    required this.size,
    this.directory,
  });

  final String label;
  final Size size;
  final String? directory;

  String filePath(String fileName) {
    final viewportDirectory = directory;
    if (viewportDirectory == null) {
      return '../../goldens/feature_pages/$fileName';
    }
    return '../../goldens/feature_pages/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpGoldenApp(
  WidgetTester tester, {
  required String initialLocation,
  MomCozyApiRuntime? apiRuntime,
}) async {
  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: initialLocation),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: apiRuntime ?? _goldenRuntime(),
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
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

const _goldenImageAssets = [
  MomCozyAssets.agentAvatar,
  MomCozyAssets.momcozyLogo,
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

MomCozyApiRuntime _goldenRuntime({DateTime Function()? now}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      statusProfileEndpoint: const <String, Object?>{
        'user_id': 'demo-user-fixture',
        'estimated_due_date': '2026-06-11',
      },
      statusLactationProfileEndpoint: const <String, Object?>{
        'actual_delivery_date': '2026-04-05',
      },
      statusInfantsEndpoint: const <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'demo-baby-fixture',
            'owner_user_id': 'demo-user-fixture',
            'name': 'Mia',
            'birth_date': '2026-04-05',
            'sex': 'female',
            'status': 'active',
          },
        ],
      },
      milkTrendsEndpoint: const <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'date': '2026-06-27',
            'pumped_milk_volume_ml': 120,
            'pumping_count': 2,
            'measured_only': true,
          },
          <String, Object?>{
            'date': '2026-06-28',
            'pumped_milk_volume_ml': 160,
            'pumping_count': 2,
            'measured_only': true,
          },
          <String, Object?>{
            'date': '2026-06-29',
            'pumped_milk_volume_ml': 190,
            'pumping_count': 3,
            'measured_only': true,
          },
          <String, Object?>{
            'date': '2026-06-30',
            'pumped_milk_volume_ml': 170,
            'pumping_count': 2,
            'measured_only': true,
          },
          <String, Object?>{
            'date': '2026-07-01',
            'pumped_milk_volume_ml': 220,
            'pumping_count': 3,
            'measured_only': true,
          },
          <String, Object?>{
            'date': '2026-07-02',
            'pumped_milk_volume_ml': 240,
            'pumping_count': 3,
            'measured_only': true,
          },
          <String, Object?>{
            'date': '2026-07-03',
            'pumped_milk_volume_ml': 90,
            'pumping_count': 1,
            'measured_only': true,
          },
        ],
        'days': 31,
        'include_today': true,
      },
      pumpWorkstateEndpoint: const <String, Object?>{
        'id': 'telemetry-001',
        'owner_user_id': 'demo-user-fixture',
        'device_id': 'app-pump-session',
        'event_type': 'workstate',
        'occurred_at': '2026-07-01T10:00:00Z',
        'payload': <String, Object?>{},
      },
      scheduleDayPlanEndpoint: const <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'schedule-golden-task',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '喂养',
            'description': '记录本次奶量',
            'status': 'pending',
            'payload': <String, Object?>{'task_type': 'feeding'},
          },
        ],
      },
      scheduleFeedingRecordsEndpoint: const <String, Object?>{
        'items': <Object?>[],
      },
      schedulePumpingRecordsEndpoint: const <String, Object?>{
        'items': <Object?>[],
      },
    }),
    agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
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
    clientEventClient: const AgentStreamClientEventClient(sent: false),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-golden',
    babyId: 'demo-baby-golden',
    locale: 'zh-CN',
    now: now ?? () => DateTime.utc(2026, 7, 3),
  );
}
