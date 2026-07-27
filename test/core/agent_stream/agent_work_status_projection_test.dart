import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_work_status_projection.dart';

void main() {
  group('projectAgentWorkStatus', () {
    final now = DateTime.utc(2026, 7, 27, 10);

    test('keeps active user work ahead of generic progress', () {
      final projection = projectAgentWorkStatus([
        _semanticEvent(
          type: 'tool.started',
          label: '我在查专业资料～',
          surface: 'work_item',
          lifecycle: 'running',
          mergeKey: 'tool:web-search-1',
          priority: 55,
          createdAt: now.subtract(const Duration(seconds: 1)),
        ),
        _semanticEvent(
          type: 'run.progress',
          label: '我在组织回复～',
          surface: 'status_bar',
          lifecycle: 'running',
          mergeKey: 'progress:response_finalizing',
          priority: 80,
          createdAt: now,
        ),
      ], now: now);

      expect(projection.isTerminal, isFalse);
      expect(projection.statusEvent?.semanticLabel, '我在查专业资料～');
    });

    test('holds a fast completion before falling back to generic progress', () {
      final events = [
        _semanticEvent(
          type: 'tool.completed',
          label: '我看好今天的奶量状态啦',
          surface: 'work_item',
          lifecycle: 'completed',
          mergeKey: 'tool:milk-status-1',
          priority: 70,
          createdAt: now.subtract(const Duration(milliseconds: 100)),
        ),
        _semanticEvent(
          type: 'run.progress',
          label: '我接着处理下一步',
          surface: 'status_bar',
          lifecycle: 'running',
          mergeKey: 'progress:model_followup',
          priority: 55,
          createdAt: now.subtract(const Duration(milliseconds: 50)),
        ),
      ];

      expect(
        projectAgentWorkStatus(events, now: now).statusEvent?.semanticLabel,
        '我看好今天的奶量状态啦',
      );
      expect(
        projectAgentWorkStatus(
          events,
          now: now.add(const Duration(milliseconds: 700)),
        ).statusEvent?.semanticLabel,
        '我接着处理下一步',
      );
    });

    test('failed lifecycle closes prior work without becoming visible', () {
      final projection = projectAgentWorkStatus([
        _semanticEvent(
          type: 'run.progress',
          label: '我先理解一下你的需求～',
          surface: 'status_bar',
          lifecycle: 'running',
          mergeKey: 'progress:context_ready',
          priority: 20,
          createdAt: now.subtract(const Duration(seconds: 2)),
        ),
        _semanticEvent(
          type: 'tool.started',
          label: '我先读取记录～',
          surface: 'work_item',
          lifecycle: 'running',
          mergeKey: 'tool:record-1',
          priority: 45,
          createdAt: now.subtract(const Duration(seconds: 1)),
        ),
        _semanticEvent(
          type: 'tool.failed',
          label: '记录暂时没读取好',
          surface: 'hidden',
          lifecycle: 'failed',
          mergeKey: 'tool:record-1',
          priority: 90,
          createdAt: now,
        ),
      ], now: now);

      expect(projection.isTerminal, isFalse);
      expect(projection.statusEvent?.semanticLabel, '我先理解一下你的需求～');
    });

    test('terminal response clears all work status', () {
      final projection = projectAgentWorkStatus([
        _semanticEvent(
          type: 'tool.started',
          label: '我在查专业资料～',
          surface: 'work_item',
          lifecycle: 'running',
          mergeKey: 'tool:web-search-1',
          priority: 55,
          createdAt: now,
        ),
        AgentStreamEvent(const {
          'type': 'message.completed',
          'payload': {'role': 'assistant', 'text': '最终回复'},
        }),
      ], now: now);

      expect(projection.isTerminal, isTrue);
      expect(projection.statusEvent, isNull);
    });
  });
}

AgentStreamEvent _semanticEvent({
  required String type,
  required String label,
  required String surface,
  required String lifecycle,
  required String mergeKey,
  required int priority,
  required DateTime createdAt,
}) {
  return AgentStreamEvent({
    'type': type,
    'created_at': createdAt.toIso8601String(),
    'payload': {
      'semantic': {
        'label': label,
        'surface': surface,
        'lifecycle': lifecycle,
        'merge_key': mergeKey,
        'priority': priority,
      },
    },
  });
}
