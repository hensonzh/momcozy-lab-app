import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';

import '../../support/fixture_reader.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('Agent Hub rich state matches compact mobile baseline', (
    tester,
  ) async {
    await _setCompactMobileViewport(tester);
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
          pickImage: () async => const AgentStreamImageInput(
            dataUrl: 'data:image/png;base64,fixture',
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

    expect(find.byKey(const ValueKey('agent-history-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-work-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-artifact-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-image-attachment-chip')),
      findsOneWidget,
    );

    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('../../goldens/agent_hub/rich_state_mobile.png'),
    );
  });
}

const _goldenSurfaceKey = ValueKey('agent-hub-rich-golden-surface');

Future<void> _setCompactMobileViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
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
        body: SafeArea(child: child),
      ),
    ),
  );
}

AgentStreamRunState _richAgentState() {
  final toolEvents = parseAgentJsonl(
    readMigrationFixture('ag_ui/tool_call_lifecycle.jsonl'),
  );
  final richArtifact = AgentStreamEvent(
    readFixtureMap('ag_ui/rich_text_artifact.json'),
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
