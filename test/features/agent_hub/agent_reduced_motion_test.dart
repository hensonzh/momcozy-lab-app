import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('large status text is complete and announced once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      const label = '正在整理今天的记录，稍后会显示完整回复';
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: SizedBox(
                width: 288,
                child: AgentRunStatusLine(title: label),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines,
        isFalse,
      );
      expect(tester.getSemantics(find.byType(AgentRunStatusLine)).label, label);
    } finally {
      semantics.dispose();
    }
  });
  for (final status in [false, true]) {
    testWidgets(
      'reduced motion stops and resumes ${status ? 'status sweeps' : 'reply rail'}',
      (tester) async {
        final reduced = ValueNotifier(false);
        final active = ValueNotifier(true);
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(),
            builder: (context, child) => ValueListenableBuilder<bool>(
              valueListenable: reduced,
              builder: (context, value, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: value),
                child: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (_, enabled, _) =>
                      TickerMode(enabled: enabled, child: child!),
                ),
              ),
            ),
            home: Scaffold(
              body: status
                  ? const Column(
                      children: [
                        AgentRunStatusLine(title: '正在查看记录'),
                        AgentThinkingNote(title: 'Let me think…'),
                      ],
                    )
                  : AgentHubPage(state: _thinking()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        reduced.value = true;
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(
          status
              ? find.text('正在查看记录')
              : find.byKey(const ValueKey('agent-hub-page')),
          findsOneWidget,
        );
        reduced.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        active.value = false;
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        active.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await tester.pumpWidget(const SizedBox());
        reduced.dispose();
        active.dispose();
      },
    );
  }

  testWidgets('reduced motion keeps reply and status changes readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = ValueNotifier(const AgentStreamRunState());
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: ValueListenableBuilder<AgentStreamRunState>(
            valueListenable: state,
            builder: (_, value, _) => AgentHubPage(state: value),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    state.value = AgentStreamRunState(
      phase: AgentStreamRunPhase.streaming,
      events: [
        AgentStreamEvent({
          'type': 'run.progress',
          'payload': {'label': 'Let me think…'},
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-response-light-rail-loop')),
      findsOneWidget,
    );
    expect(tester.binding.transientCallbackCount, 0);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/agent-reduced-motion-thinking-390.png',
      ),
    );
    state.value = const AgentStreamRunState();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}

AgentStreamRunState _thinking() => AgentStreamRunState(
  phase: AgentStreamRunPhase.streaming,
  events: [
    AgentStreamEvent({
      'type': 'run.progress',
      'payload': {'label': 'Let me think…'},
    }),
  ],
);
