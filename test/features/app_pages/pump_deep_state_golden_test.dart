@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Pump deep-state goldens', () {
    for (final viewport in _goldenViewports) {
      for (final state in _pumpStates) {
        testWidgets('${state.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);
          await _pumpPumpApp(tester, transport: state.transport());
          await _dismissCalibrationPrompt(tester);

          await state.drive(tester);

          await expectLater(
            find.byKey(_goldenSurfaceKey),
            matchesGoldenFile(viewport.filePath(state.fileName)),
          );
        });
      }
    }
  });
}

const _goldenSurfaceKey = ValueKey('pump-deep-state-golden-surface');

final _pumpStates = [
  _PumpGoldenState(
    label: 'running state',
    fileName: 'running_state_mobile.png',
    drive: (tester) async {
      await _tapScrollableWidgetWithText(tester, OutlinedButton, '开始');
      await _scrollToText(tester, 'Session 用户已绑定');
      await tester.pumpAndSettle();
    },
  ),
  _PumpGoldenState(
    label: 'paused state',
    fileName: 'paused_state_mobile.png',
    drive: (tester) async {
      await _tapScrollableWidgetWithText(tester, OutlinedButton, '开始');
      await _tapScrollableWidgetWithText(tester, OutlinedButton, '暂停');
      await _scrollToFinder(tester, find.widgetWithText(OutlinedButton, '恢复'));
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, '恢复'));
      await tester.pumpAndSettle();
    },
  ),
  _PumpGoldenState(
    label: 'finished locked state',
    fileName: 'finished_locked_state_mobile.png',
    drive: (tester) async {
      await _tapScrollableWidgetWithText(tester, OutlinedButton, '开始');
      await _tapScrollableWidgetWithText(tester, FilledButton, '结束');
      await tester.ensureVisible(find.text('结束同步已锁定'));
      await tester.pumpAndSettle();
    },
  ),
  _PumpGoldenState(
    label: 'upload failed state',
    fileName: 'upload_failed_state_mobile.png',
    transport: _failingPumpTransport,
    drive: (tester) async {
      await _tapScrollableWidgetWithText(tester, OutlinedButton, '开始');
      await tester.ensureVisible(find.text('Workstate 同步失败'));
      await tester.pumpAndSettle();
    },
  ),
];

class _PumpGoldenState {
  const _PumpGoldenState({
    required this.label,
    required this.fileName,
    required this.drive,
    this.transport = _successfulPumpTransport,
  });

  final String label;
  final String fileName;
  final Future<void> Function(WidgetTester tester) drive;
  final FixtureApiJsonTransportByPath Function() transport;
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
      return '../../goldens/pump_states/$fileName';
    }
    return '../../goldens/pump_states/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPumpApp(
  WidgetTester tester, {
  required FixtureApiJsonTransportByPath transport,
}) async {
  final route = momCozyRoutes.singleWhere((route) => route.path == '/pump');

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyRuntimeScope(
        apiRuntime: _runtime(transport),
        child: MaterialApp(
          theme: momCozyTheme(),
          home: Scaffold(
            body: MomCozyFeaturePage(
              path: route.path,
              title: route.title,
              summary: route.summary,
              icon: route.icon,
              accent: route.accent,
              priority: route.priority,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _runtime(FixtureApiJsonTransportByPath transport) {
  return MomCozyApiRuntime(
    jsonTransport: transport,
    agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
    blePlatform: FakeBlePlatform(
      initialPermission: BlePermissionState.granted,
      seedDevices: const [
        BleDeviceSnapshot(
          side: 'L',
          deviceId: 'ble-left-fixture',
          deviceName: 'S12 Pro L',
          connected: true,
        ),
      ],
    ),
    userId: 'demo-user-fixture',
    babyId: 'demo-baby-fixture',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7),
  );
}

FixtureApiJsonTransportByPath _successfulPumpTransport() {
  return FixtureApiJsonTransportByPath(
    {
      pumpWorkstateEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'need_reply': true,
          'output': 'Workstate accepted',
          'reply_code': 'pump_state_changed',
          'reply_side': 'left',
        },
      },
    },
    writeResponsesByPath: {
      pumpMilkRecordsEndpoint: const <String, Object?>{
        'id': 'a68b32a6-34cb-514e-a8ec-55984ae634b5',
        'owner_user_id': 'c1715770-8a29-5584-9fe5-6d6e758299b5',
        'pump_start_time': '2026-07-01T00:00:00Z',
        'pump_end_time': '2026-07-01T00:02:00Z',
        'pump_type': 'electric',
        'source': 'manual',
        'title': 'Pumping record',
        'status': 'completed',
        'milk_volume_ml': 27,
        'duration_seconds': 120,
      },
    },
  );
}

FixtureApiJsonTransportByPath _failingPumpTransport() {
  return FixtureApiJsonTransportByPath({
    pumpWorkstateEndpoint: const <String, Object?>{
      'http_status': 500,
      'status_text': 'Server Error',
    },
  });
}

Future<void> _dismissCalibrationPrompt(WidgetTester tester) async {
  final skipButton = find.widgetWithText(OutlinedButton, '先跳过');
  expect(skipButton, findsOneWidget);
  await tester.tap(skipButton);
  await tester.pumpAndSettle();
}

Future<void> _tapScrollableWidgetWithText(
  WidgetTester tester,
  Type widgetType,
  String text,
) async {
  final finder = find.widgetWithText(widgetType, text);
  await _scrollToFinder(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await _scrollToFinder(tester, finder);
  await tester.ensureVisible(finder);
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  for (final offset in const [Offset(0, -240), Offset(0, 240)]) {
    for (var attempt = 0; attempt < 12; attempt += 1) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(find.byType(Scrollable).first, offset);
      await tester.pump();
    }
  }
  expect(finder, findsWidgets);
}
