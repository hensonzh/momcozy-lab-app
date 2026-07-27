import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:app/features/status/data/status_api_repository.dart';
import 'package:app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Status offline fallback goldens', () {
    for (final viewport in _goldenViewports) {
      for (final state in _statusStates) {
        testWidgets('${state.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);
          await _pumpStatusStateApp(tester);

          await state.interact(tester);
          await tester.pumpAndSettle();

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

const _goldenSurfaceKey = ValueKey('status-state-golden-surface');

const _statusStates = [
  _StatusGoldenState(
    label: 'postpartum mom offline fallback',
    fileName: 'status_postpartum_mom_offline_mobile.png',
    expectedText: '母乳产出',
  ),
  _StatusGoldenState(
    label: 'postpartum baby offline fallback',
    fileName: 'status_postpartum_baby_offline_mobile.png',
    expectedText: '成长发育',
    interact: _selectBaby,
  ),
  _StatusGoldenState(
    label: 'pregnancy mom offline fallback',
    fileName: 'status_pregnancy_mom_offline_mobile.png',
    expectedText: '孕期日记',
    interact: _selectPregnancy,
  ),
];

class _StatusGoldenState {
  const _StatusGoldenState({
    required this.label,
    required this.fileName,
    required this.expectedText,
    this.interact = _noInteraction,
  });

  final String label;
  final String fileName;
  final String expectedText;
  final Future<void> Function(WidgetTester tester) interact;
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
      return '../../goldens/status_states/$fileName';
    }
    return '../../goldens/status_states/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpStatusStateApp(WidgetTester tester) async {
  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/status'),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransportByPath({
            statusOverviewEndpoint: const {
              'http_status': 503,
              'status_text': 'Service Unavailable',
            },
            pregnancyDiaryEntriesEndpoint: const {'items': <Object?>[]},
            pregnancyPlansEndpoint: const {'items': <Object?>[]},
          }),
          agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
          blePlatform: FakeBlePlatform(
            initialPermission: BlePermissionState.granted,
          ),
          userId: 'demo-user-status-golden',
          babyId: 'demo-baby-status-golden',
          locale: 'zh-CN',
          now: () => DateTime.utc(2026, 7, 3),
        ),
      ),
    ),
  );
  await tester.pump();
  final appContext = tester.element(find.byType(MomCozyFlutterApp));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(const AssetImage(MomCozyAssets.agentAvatar), appContext),
      precacheImage(const AssetImage(MomCozyAssets.momAvatar), appContext),
      precacheImage(const AssetImage(MomCozyAssets.babyAvatar), appContext),
    ]).timeout(const Duration(seconds: 5));
  });
  await tester.pumpAndSettle();
  await _settleVisibleStatusResources(tester);
}

Future<void> _settleVisibleStatusResources(WidgetTester tester) async {
  const loadingCopy = '正在加载最近一个月泌乳数据…';
  for (var frame = 0; frame < 30; frame += 1) {
    if (find.text(loadingCopy).evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.text(loadingCopy), findsNothing);
}

Future<void> _noInteraction(WidgetTester tester) async {}

Future<void> _selectBaby(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('status-identity-tab-baby')));
}

Future<void> _selectPregnancy(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('status-care-stage-pregnancy')));
}
