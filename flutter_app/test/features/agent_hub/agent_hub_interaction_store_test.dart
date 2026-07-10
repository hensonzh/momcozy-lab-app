import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';

void main() {
  test('history snapshot round-trips structured artifact state', () {
    final artifactEvent = AgentStreamEvent({
      'event_id': 'history-artifact-event',
      'type': 'artifact.created',
      'artifact_id': 'history-artifact',
      'payload': {
        'artifact_type': 'milk_plan_preview',
        'schema_version': 'v1',
        'artifact': {
          'id': 'history-artifact',
          'artifact_type': 'milk_plan_preview',
          'schema_version': 'v1',
          'payload': {
            'title': '历史奶量计划',
            'tasks': [
              {'title': '20:00 泵奶'},
            ],
          },
        },
      },
    });
    final runState =
        const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)
            .applyEvent(artifactEvent)
            .copyWith(phase: AgentStreamRunPhase.finished, textContent: '历史回复');
    final snapshot = AgentHubHistorySnapshot(
      role: 'assistant',
      content: '历史回复',
      runState: runState,
    );

    final restored = AgentHubHistorySnapshot.fromMap(snapshot.toMap());

    expect(restored, isNotNull);
    expect(restored!.runState, isNotNull);
    expect(restored.runState!.phase, AgentStreamRunPhase.finished);
    expect(restored.runState!.artifactEvents, hasLength(1));
    expect(
      restored.runState!.artifactEvents.values.single.artifactId,
      'history-artifact',
    );
  });

  test('legacy text-only history snapshots remain readable', () {
    final restored = AgentHubHistorySnapshot.fromMap({
      'role': 'assistant',
      'content': '旧历史消息',
    });

    expect(restored, isNotNull);
    expect(restored!.content, '旧历史消息');
    expect(restored.runState, isNull);
  });
}
