import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/schedule/data/schedule_api_repository.dart';
import 'package:app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Schedule state goldens', () {
    for (final viewport in _goldenViewports) {
      for (final state in _scheduleStates) {
        testWidgets('${state.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);
          await _pumpScheduleStateApp(tester, response: state.response);

          expect(find.text(state.expectedText), findsAtLeastNWidgets(1));
          await expectLater(
            find.byKey(_goldenSurfaceKey),
            matchesGoldenFile(viewport.filePath(state.fileName)),
          );
        });
      }
    }
  });
}

const _goldenSurfaceKey = ValueKey('schedule-state-golden-surface');

const _scheduleStates = [
  _ScheduleGoldenState(
    label: 'populated plan',
    fileName: 'schedule_populated_plan_mobile.png',
    response: {
      'items': [
        {
          'id': 'pump-morning',
          'title': '泵奶',
          'task_date': '2026-07-03',
          'task_time': '10:30',
          'status': 'completed',
        },
        {
          'id': 'feeding-afternoon',
          'title': '喂养',
          'task_date': '2026-07-03',
          'task_time': '14:00',
          'status': 'pending',
        },
        {
          'id': 'summary-evening',
          'title': '晚间复盘',
          'task_date': '2026-07-03',
          'task_time': '20:30',
          'status': 'pending',
        },
      ],
    },
    expectedText: '待执行任务',
  ),
  _ScheduleGoldenState(
    label: 'empty day',
    fileName: 'schedule_local_task_added_mobile.png',
    response: {'items': <Object?>[]},
    expectedText: '今天还没有计划任务',
  ),
  _ScheduleGoldenState(
    label: 'sync failed',
    fileName: 'schedule_sync_failed_mobile.png',
    response: {'http_status': 503, 'status_text': 'Service Unavailable'},
    expectedText: '计划同步失败',
  ),
];

class _ScheduleGoldenState {
  const _ScheduleGoldenState({
    required this.label,
    required this.fileName,
    required this.response,
    required this.expectedText,
  });

  final String label;
  final String fileName;
  final Map<String, Object?> response;
  final String expectedText;
}

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
      return '../../goldens/schedule_states/$fileName';
    }
    return '../../goldens/schedule_states/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpScheduleStateApp(
  WidgetTester tester, {
  required Map<String, Object?> response,
}) async {
  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/schedule'),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: _scheduleRuntime(response),
      ),
    ),
  );
  await tester.pump();
  final appContext = tester.element(find.byType(MomCozyFlutterApp));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(MomCozyAssets.agentAvatar),
      appContext,
    ).timeout(const Duration(seconds: 5));
  });
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _scheduleRuntime(Map<String, Object?> response) {
  final allResourcesFailed = response['http_status'] is int;
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      scheduleDayPlanEndpoint: response,
      schedulePlansEndpoint: allResourcesFailed
          ? response
          : const {
              'items': <Object?>[
                {
                  'id': 'milk-plan-golden',
                  'plan_type': 'milk_management',
                  'title': '稳奶计划',
                  'summary': '按当前阶段稳步执行',
                  'status': 'active',
                  'version': 1,
                  'payload': <String, Object?>{
                    'postpartum_week': 29,
                    'phase': '离乳期',
                  },
                },
              ],
            },
      scheduleFeedingRecordsEndpoint: allResourcesFailed
          ? response
          : const {'items': <Object?>[]},
      schedulePumpingRecordsEndpoint: allResourcesFailed
          ? response
          : const {'items': <Object?>[]},
    }),
    agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-golden',
    babyId: 'demo-baby-golden',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7, 3),
  );
}
