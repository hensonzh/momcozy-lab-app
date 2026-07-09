import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Agent Hub deep-state goldens', () {
    for (final viewport in _goldenViewports) {
      for (final state in _agentStates) {
        testWidgets('${state.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);
          await _pumpAgentHub(tester, state.build());
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

const _goldenSurfaceKey = ValueKey('agent-hub-deep-state-golden-surface');

final _agentStates = [
  _AgentGoldenState(
    label: 'streaming state',
    fileName: 'streaming_state_mobile.png',
    build: () => AgentHubPage(
      state: AgentStreamRunState(
        phase: AgentStreamRunPhase.streaming,
        threadId: 'thread-streaming-001',
        runId: 'run-streaming-001',
        messageId: 'msg-streaming-001',
        textContent: '我正在读取今天的泵奶记录，并同步检查左右侧节奏。',
        events: [
          AgentStreamEvent(const {
            'type': 'tool.started',
            'thread_id': 'thread-streaming-001',
            'run_id': 'run-streaming-001',
            'tool_call_id': 'call-pump-summary',
            'payload': {'tool_name': 'pump_session_summary_query'},
          }),
        ],
      ),
    ),
  ),
  _AgentGoldenState(
    label: 'cancelled state',
    fileName: 'cancelled_state_mobile.png',
    build: () => const AgentHubPage(
      state: AgentStreamRunState(
        phase: AgentStreamRunPhase.cancelled,
        threadId: 'thread-cancelled-001',
        runId: 'run-cancelled-001',
        messageId: 'msg-cancelled-001',
        textContent: '我已经停下这次回复，保留目前整理出的片段。',
      ),
    ),
  ),
  _AgentGoldenState(
    label: 'disconnected state',
    fileName: 'disconnected_state_mobile.png',
    build: () => const AgentHubPage(
      state: AgentStreamRunState(
        phase: AgentStreamRunPhase.disconnected,
        threadId: 'thread-disconnected-001',
        runId: 'run-disconnected-001',
        messageId: 'msg-disconnected-001',
        textContent: '已经收到部分分析内容，但连接在继续生成前中断。',
        errorMessage: 'SocketException: Failed host lookup: api.momcozy.test',
      ),
    ),
  ),
  _AgentGoldenState(
    label: 'voice error state',
    fileName: 'voice_error_state_mobile.png',
    build: () => AgentHubPage(voiceInput: _failingVoiceInput),
    drive: (tester) async {
      await tester.tap(find.byKey(const ValueKey('agent-voice-button')));
      await tester.pump();
      final holdGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('agent-voice-hold-button'))),
      );
      await tester.pump();
      await holdGesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-voice-status')), findsOneWidget);
    },
  ),
];

class _AgentGoldenState {
  const _AgentGoldenState({
    required this.label,
    required this.fileName,
    required this.build,
    this.drive = _noOpDrive,
  });

  final String label;
  final String fileName;
  final Widget Function() build;
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
      return '../../goldens/agent_hub/$fileName';
    }
    return '../../goldens/agent_hub/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpAgentHub(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MaterialApp(
        theme: momCozyTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: MomCozyColors.background,
          body: SafeArea(child: TickerMode(enabled: false, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
  final appContext = tester.element(find.byType(AgentHubPage));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(MomCozyAssets.agentAvatar),
      appContext,
    ).timeout(const Duration(seconds: 5));
  });
  await tester.pumpAndSettle();
}

Future<void> _noOpDrive(WidgetTester tester) async {}

Future<String?> _failingVoiceInput() async {
  await Future<void>.delayed(Duration.zero);
  throw StateError('microphone unavailable');
}
