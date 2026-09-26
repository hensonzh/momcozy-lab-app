import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';

void main() {
  testWidgets(
    'without a tool status, the app supplies only one thinking line',
    (tester) async {
      await tester.pumpWidget(
        _host(const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)),
      );
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-thinking-note')), findsNothing);
    },
  );

  testWidgets(
    'tool outcome stays visible through a model progress event, then hides on first text',
    (tester) async {
      final started = AgentStreamEvent(_status('running'));
      final completed = AgentStreamEvent(_status('success'));
      final state = AgentStreamRunState(
        phase: AgentStreamRunPhase.streaming,
        events: [
          started,
          completed,
          AgentStreamEvent(const {
            'type': 'run.progress',
            'payload': {'phase': 'model_followup', 'label': 'Generic progress'},
          }),
        ],
      );
      await tester.pumpWidget(_host(state));
      expect(find.text('已核对相关记录。'), findsOneWidget);
      expect(find.text('Thinking…'), findsNothing);
      expect(find.text('Generic progress'), findsNothing);

      await tester.pumpWidget(_host(state.copyWith(textContent: '建议先观察。')));
      expect(find.byKey(const ValueKey('agent-run-status-line')), findsNothing);
      expect(find.textContaining('建议先观察'), findsOneWidget);
    },
  );

  testWidgets('an actual failed tool outcome selects failure, not success', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          events: [
            AgentStreamEvent(_status('running')),
            AgentStreamEvent(_status('failure')),
          ],
        ),
      ),
    );
    expect(find.text('这次没能读取记录。'), findsOneWidget);
    expect(find.text('已核对相关记录。'), findsNothing);
  });
}

Widget _host(AgentStreamRunState state) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: AgentRunTranscript(state: state)),
  ),
);
Map<String, Object?> _status(String outcome) => {
  'type': 'run.progress',
  'payload': {
    'phase': 'tool_status',
    'call_id': 'call-1',
    'outcome': outcome,
    'user_facing_status': {
      'running': '正在核对相关记录。',
      'success': '已核对相关记录。',
      'failure': '这次没能读取记录。',
    },
  },
};
