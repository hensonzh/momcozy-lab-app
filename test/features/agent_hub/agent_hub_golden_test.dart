import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/core/agent_stream/agent_stream_client.dart';
import 'package:app/core/agent_stream/agent_stream_event.dart';
import 'package:app/core/agent_stream/agent_stream_run_state.dart';
import 'package:app/features/agent_hub/agent_hub_page.dart';

import '../../support/fixture_reader.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final viewport in _goldenViewports) {
    testWidgets('Agent Hub rich state matches ${viewport.label} baseline', (
      tester,
    ) async {
      await _setViewport(tester, viewport.size);
      final actions = <AgentArtifactActionView>[];

      await tester.pumpWidget(
        _host(
          AgentHubPage(
            state: _richAgentState(),
            historyMessages: const [
              AgentHubHistoryMessage(
                role: AgentHubHistoryRole.user,
                content: '今天左侧奶量偏低，想看一下节奏。',
              ),
              AgentHubHistoryMessage(
                role: AgentHubHistoryRole.assistant,
                content: '我会结合泵奶记录、舒适度和宝宝喂养情况一起看。',
              ),
            ],
            pickImage: (_) async => const AgentStreamImageInput(
              dataUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              mimeType: 'image/png',
              name: 'pump-display.png',
              size: 68,
              detail: 'low',
            ),
            onArtifactAction: actions.add,
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

      await tester.tap(find.byKey(const ValueKey('agent-image-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-photo-menu')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-photo-upload-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agent-history-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-work-panel')), findsNothing);
      expect(find.text('处理进度'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-artifact-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsOneWidget,
      );

      await expectLater(
        find.byKey(_goldenSurfaceKey),
        matchesGoldenFile(viewport.filePath('rich_state_mobile.png')),
      );
    });
  }
}

const _goldenSurfaceKey = ValueKey('agent-hub-rich-golden-surface');

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

Widget _host(Widget child) {
  return RepaintBoundary(
    key: _goldenSurfaceKey,
    child: MaterialApp(
      theme: momCozyTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: MomCozyColors.background,
        body: SafeArea(child: TickerMode(enabled: false, child: child)),
      ),
    ),
  );
}

AgentStreamRunState _richAgentState() {
  final toolEvents = parseAgentJsonl(
    readMigrationFixture('agent_events/tool_call_lifecycle.jsonl'),
  );
  final richArtifact = AgentStreamEvent(
    readFixtureMap('agent_events/rich_text_artifact.json'),
  );
  return AgentStreamRunState(
    phase: AgentStreamRunPhase.finished,
    events: [...toolEvents, richArtifact],
    threadId: 'thread-fixture-001',
    runId: 'run-fixture-tool-001',
    messageId: 'msg-reply-tool-001',
    textContent:
        'I found two sessions today and prepared a draft analysis. You can review the card before saving.',
  );
}
