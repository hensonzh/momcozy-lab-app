import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_work_status_projection.dart';

void main() {
  test(
    'running status is replaced by runtime-confirmed success and held while waiting',
    () {
      final events = [
        _status('call-1', 'running', 1),
        _status('call-1', 'success', 2),
        AgentStreamEvent(const {
          'type': 'run.progress',
          'sequence': 3,
          'payload': {
            'phase': 'model_followup',
            'label': 'Working on the next step…',
          },
        }),
      ];
      final projection = projectAgentWorkStatus(
        events,
        now: DateTime.utc(2026, 9, 25, 8),
      );
      expect(projection.statusEvent?.userFacingStatus, '已核对相关记录。');
      expect(projection.statusEvent?.toolStatusOutcome, 'success');
      expect(
        projectAgentWorkStatus(
          events,
          now: DateTime.utc(2026, 9, 25, 9),
        ).statusEvent?.userFacingStatus,
        '已核对相关记录。',
      );
    },
  );

  test('failure is selected by actual outcome, then next tool replaces it', () {
    final events = [
      _status('call-1', 'running', 1),
      _status('call-1', 'failure', 2),
    ];
    expect(
      projectAgentWorkStatus(events).statusEvent?.userFacingStatus,
      '这次没能读取记录。',
    );
    events.add(_status('call-2', 'running', 3));
    expect(
      projectAgentWorkStatus(events).statusEvent?.userFacingStatus,
      '正在核对相关记录。',
    );
    events.add(
      AgentStreamEvent(const {'type': 'run.completed', 'sequence': 4}),
    );
    expect(projectAgentWorkStatus(events).statusEvent, isNull);
  });

  test(
    'malformed completion does not leave an earlier running status on screen',
    () {
      final events = [
        _status('call-1', 'running', 1),
        AgentStreamEvent(const {
          'type': 'run.progress',
          'sequence': 2,
          'payload': {
            'phase': 'tool_status',
            'call_id': 'call-1',
            'outcome': 'failure',
            'user_facing_status': {
              'running': '正在核对相关记录。',
              'success': '已核对相关记录。',
              'failure': 'API error_code=123',
            },
          },
        }),
      ];
      final projection = projectAgentWorkStatus(events);
      expect(projection.statusEvent?.toolStatusOutcome, 'failure');
      expect(projection.statusEvent?.userFacingStatus, isNull);
    },
  );

  test(
    'tool completion awaits the runtime result rather than guessing success',
    () {
      final events = [
        _status('call-1', 'running', 1),
        AgentStreamEvent(const {
          'type': 'tool.completed',
          'sequence': 2,
          'payload': {'call_id': 'call-1', 'tool_name': 'read_topical_records'},
        }),
      ];
      expect(
        projectAgentWorkStatus(events).statusEvent?.userFacingStatus,
        '正在核对相关记录。',
      );
      events.add(_status('call-1', 'success', 3));
      expect(
        projectAgentWorkStatus(events).statusEvent?.userFacingStatus,
        '已核对相关记录。',
      );
    },
  );

  test('durable failed or blocked tools correct running status on replay', () {
    for (final type in ['tool.failed', 'tool.blocked']) {
      final events = [
        _status('call-1', 'running', 1),
        AgentStreamEvent({
          'type': type,
          'payload': {'call_id': 'call-1'},
        }),
      ];
      expect(
        projectAgentWorkStatus(events).statusEvent?.userFacingStatus,
        '这次没能读取记录。',
      );
    }
  });

  test(
    'restores latest status through state persistence and replay deduplication',
    () {
      final running = _status('call-1', 'running', 1);
      final completed = _status('call-1', 'success', 2);
      final beforeRestore = const AgentStreamRunState(
        phase: AgentStreamRunPhase.streaming,
      ).applyEvent(running).applyEvent(completed);
      final restored = AgentStreamRunState.fromMap(beforeRestore.toMap());
      expect(restored.events.length, 2);
      expect(
        projectAgentWorkStatus(restored.events).statusEvent?.userFacingStatus,
        '已核对相关记录。',
      );
      final replayed = restored.applyEvent(completed);
      expect(
        projectAgentWorkStatus(replayed.events).statusEvent?.userFacingStatus,
        '已核对相关记录。',
      );
    },
  );

  test('terminal cancel and failure clear the last tool status', () {
    for (final type in ['run.cancelled', 'run.failed']) {
      final events = [
        _status('call-1', 'running', 1),
        AgentStreamEvent({'type': type, 'sequence': 2}),
      ];
      expect(projectAgentWorkStatus(events).isTerminal, isTrue);
      expect(projectAgentWorkStatus(events).statusEvent, isNull);
    }
  });

  test('rejects model-provided status outcome or malformed copy', () {
    final event = AgentStreamEvent(const {
      'type': 'run.progress',
      'payload': {
        'phase': 'tool_status',
        'call_id': 'call-1',
        'outcome': 'success',
        'user_facing_status': {
          'running': '正在查阅。',
          'success': 'API error_code=123',
          'failure': '未查阅。',
        },
      },
    });
    expect(event.userFacingStatus, isNull);
  });
}

AgentStreamEvent _status(String callId, String outcome, int sequence) =>
    AgentStreamEvent({
      'type': 'run.progress',
      'sequence': sequence,
      'payload': {
        'phase': 'tool_status',
        'call_id': callId,
        'outcome': outcome,
        'user_facing_status': {
          'running': '正在核对相关记录。',
          'success': '已核对相关记录。',
          'failure': '这次没能读取记录。',
        },
      },
    });
