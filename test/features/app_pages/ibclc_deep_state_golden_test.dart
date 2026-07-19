import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('IBCLC deep-state goldens', () {
    for (final viewport in _goldenViewports) {
      for (final state in _ibclcStates) {
        testWidgets('${state.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);
          await _pumpIbclc(tester, eventSent: state.eventSent);
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

const _goldenSurfaceKey = ValueKey('ibclc-deep-state-golden-surface');

const _ibclcStates = [
  _IbclcGoldenState(
    label: 'queue state',
    fileName: 'queue_state_mobile.png',
    eventSent: true,
  ),
  _IbclcGoldenState(
    label: 'chat ready synced state',
    fileName: 'chat_ready_synced_state_mobile.png',
    eventSent: true,
    drive: _advanceToReadyChat,
  ),
  _IbclcGoldenState(
    label: 'local queue failed sync state',
    fileName: 'local_queue_failed_sync_state_mobile.png',
    eventSent: false,
    drive: _advanceToReadyChat,
  ),
];

class _IbclcGoldenState {
  const _IbclcGoldenState({
    required this.label,
    required this.fileName,
    required this.eventSent,
    this.drive = _noOpDrive,
  });

  final String label;
  final String fileName;
  final bool eventSent;
  final Future<void> Function(WidgetTester tester) drive;
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
      return '../../goldens/ibclc_states/$fileName';
    }
    return '../../goldens/ibclc_states/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpIbclc(WidgetTester tester, {required bool eventSent}) async {
  final route = momCozyRoutes.singleWhere(
    (route) => route.path == '/ibclc-chat.html',
  );
  final client = AgentStreamClientEventClient(sent: eventSent);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyRuntimeScope(
        apiRuntime: MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransportByPath(const {}),
          clientEventClient: client,
          agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
          userId: 'demo-user-fixture',
          babyId: 'demo-baby-fixture',
          locale: 'zh-CN',
          now: () => DateTime.utc(2026, 7),
        ),
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

Future<void> _noOpDrive(WidgetTester tester) async {}

Future<void> _advanceToReadyChat(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
  await tester.pumpAndSettle();
  expect(find.textContaining('你好，我是 Emily Chen'), findsOneWidget);
}
