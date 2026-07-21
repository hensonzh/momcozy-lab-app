import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_conversation_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('lists flat conversation summaries in backend order', () async {
    final transport = FixtureApiJsonTransport({
      'items': [
        {
          'id': 'thread-new',
          'title': '最近的会话',
          'status': 'active',
          'metadata': <String, Object?>{},
          'created_at': '2026-07-19T08:00:00Z',
          'updated_at': '2026-07-20T08:00:00Z',
        },
        {
          'id': 'thread-old',
          'title': '较早的会话',
          'status': 'active',
          'metadata': <String, Object?>{},
          'created_at': '2026-07-18T08:00:00Z',
          'updated_at': '2026-07-19T08:00:00Z',
        },
      ],
    });
    final repository = AgentConversationApiRepository(transport: transport);

    final conversations = await repository.listConversations();

    expect(transport.lastPath, agentConversationsEndpoint);
    expect(transport.lastQuery, {'limit': 50});
    expect(conversations.map((item) => item.id), ['thread-new', 'thread-old']);
    expect(conversations.first.title, '最近的会话');
    expect(
      conversations.first.updatedAt,
      DateTime.parse('2026-07-20T08:00:00Z'),
    );
  });

  test('restores thread messages through the existing event reducer', () async {
    final transport = FixtureApiJsonTransport({
      'thread': {
        'id': 'thread-restore',
        'title': '喂养节奏',
        'status': 'active',
        'metadata': <String, Object?>{},
        'created_at': '2026-07-19T08:00:00Z',
        'updated_at': '2026-07-20T08:00:00Z',
      },
      'items': [
        {
          'id': 'message-user-1',
          'run_id': 'run-1',
          'role': 'user',
          'message_type': 'text',
          'content': {
            'text': '第一问',
            'attachments': [
              {
                'type': 'image',
                'data_url': 'data:image/png;base64,must-not-be-restored',
                'file_id': '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
                'content_type': 'image/png',
                'original_filename': '记录.png',
                'size': 1,
                'detail': 'high',
              },
              {
                'type': 'file',
                'file_id': '948ed99d-2600-45d9-886a-0068d7593529',
                'content_type': 'application/pdf',
                'original_filename': '产检报告.pdf',
                'size': 2048,
              },
            ],
          },
          'status': 'completed',
          'sequence': 1,
          'created_at': '2026-07-19T08:00:00Z',
        },
        {
          'id': 'message-assistant-1',
          'run_id': 'run-1',
          'role': 'assistant',
          'message_type': 'text',
          'content': {'text': '第一答'},
          'status': 'completed',
          'sequence': 2,
          'created_at': '2026-07-19T08:01:00Z',
        },
        {
          'id': 'message-user-2',
          'run_id': 'run-2',
          'role': 'user',
          'message_type': 'text',
          'content': {'text': '第二问', 'attachments': <Object?>[]},
          'status': 'completed',
          'sequence': 3,
          'created_at': '2026-07-20T08:00:00Z',
        },
        {
          'id': 'message-assistant-2',
          'run_id': 'run-2',
          'role': 'assistant',
          'message_type': 'text',
          'content': {'text': '第二答'},
          'status': 'completed',
          'sequence': 4,
          'created_at': '2026-07-20T08:01:00Z',
        },
      ],
      'events': [
        {
          'event_id': 'event-run-1-message',
          'thread_id': 'thread-restore',
          'run_id': 'run-1',
          'sequence': 1,
          'type': 'message.completed',
          'payload': {
            'message_id': 'message-assistant-1',
            'role': 'assistant',
            'text': '第一答',
          },
          'created_at': '2026-07-19T08:01:00Z',
        },
        {
          'event_id': 'event-run-1-completed',
          'thread_id': 'thread-restore',
          'run_id': 'run-1',
          'sequence': 2,
          'type': 'run.completed',
          'payload': <String, Object?>{},
          'created_at': '2026-07-19T08:01:01Z',
        },
        {
          'event_id': 'event-run-2-message',
          'thread_id': 'thread-restore',
          'run_id': 'run-2',
          'sequence': 1,
          'type': 'message.completed',
          'payload': {
            'message_id': 'message-assistant-2',
            'role': 'assistant',
            'text': '第二答',
          },
          'created_at': '2026-07-20T08:01:00Z',
        },
        {
          'event_id': 'event-run-2-completed',
          'thread_id': 'thread-restore',
          'run_id': 'run-2',
          'sequence': 2,
          'type': 'run.completed',
          'payload': <String, Object?>{},
          'created_at': '2026-07-20T08:01:01Z',
        },
      ],
      'next_before_sequence': null,
    });
    final repository = AgentConversationApiRepository(transport: transport);

    final history = await repository.loadConversation('thread-restore');

    expect(
      transport.lastPath,
      '$agentConversationsEndpoint/thread-restore/history',
    );
    expect(transport.lastQuery, {'limit': 20});
    expect(history.thread.id, 'thread-restore');
    expect(history.messages.map((message) => message.content), [
      '第一问',
      '第一答',
      '第二问',
    ]);
    expect(history.messages.first.images.single.name, '记录.png');
    expect(
      history.messages.first.images.single.fileId,
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    );
    expect(history.messages.first.images.single.dataUrl, isEmpty);
    expect(history.messages.first.files.single.name, '产检报告.pdf');
    expect(
      history.messages.first.files.single.fileId,
      '948ed99d-2600-45d9-886a-0068d7593529',
    );
    expect(history.messages[1].runState?.textContent, '第一答');
    expect(history.currentState.threadId, 'thread-restore');
    expect(history.currentState.runId, 'run-2');
    expect(history.currentState.textContent, '第二答');
    expect(history.currentState.hasCompletedAssistantMessage, isTrue);
  });

  test('loads only the requested history page', () async {
    final thread = {
      'id': 'thread-paged',
      'title': '分页会话',
      'status': 'active',
      'metadata': <String, Object?>{},
      'created_at': '2026-07-18T08:00:00Z',
      'updated_at': '2026-07-20T08:00:00Z',
    };
    final transport = _PagedHistoryTransport([
      {
        'thread': thread,
        'items': [
          _message(
            id: 'message-new',
            runId: 'run-new',
            text: '新消息',
            sequence: 3,
          ),
        ],
        'events': <Object?>[],
        'next_before_sequence': 3,
      },
      {
        'thread': thread,
        'items': [
          _message(
            id: 'message-old',
            runId: 'run-old',
            text: '旧消息',
            sequence: 1,
          ),
        ],
        'events': <Object?>[],
        'next_before_sequence': null,
      },
    ]);
    final repository = AgentConversationApiRepository(transport: transport);

    final latest = await repository.loadConversation('thread-paged');

    expect(latest.messages.map((message) => message.content), ['新消息']);
    expect(latest.nextBeforeSequence, 3);
    expect(transport.queries, [
      {'limit': 20},
    ]);

    final older = await repository.loadConversation(
      'thread-paged',
      beforeSequence: latest.nextBeforeSequence,
    );

    expect(older.messages.map((message) => message.content), ['旧消息']);
    expect(older.nextBeforeSequence, isNull);
    expect(transport.queries, [
      {'limit': 20},
      {'limit': 20, 'before_sequence': 3},
    ]);
  });

  test('keeps artifact-only assistant turns in restored history', () async {
    final transport = FixtureApiJsonTransport({
      'thread': {
        'id': 'thread-artifact',
        'title': '产物会话',
        'status': 'active',
        'metadata': <String, Object?>{},
        'created_at': '2026-07-18T08:00:00Z',
        'updated_at': '2026-07-20T08:00:00Z',
      },
      'items': [
        _message(
          id: 'message-artifact-user',
          runId: 'run-artifact',
          text: '生成清单',
          sequence: 1,
        ),
        _message(
          id: 'message-latest-user',
          runId: 'run-latest',
          text: '继续',
          sequence: 2,
        ),
      ],
      'events': [
        {
          'event_id': 'event-artifact',
          'thread_id': 'thread-artifact',
          'run_id': 'run-artifact',
          'sequence': 1,
          'type': 'artifact.created',
          'payload': {
            'artifact_id': 'artifact-1',
            'artifact_type': 'checklist',
            'status': 'created',
          },
          'created_at': '2026-07-18T08:00:01Z',
        },
        {
          'event_id': 'event-artifact-completed',
          'thread_id': 'thread-artifact',
          'run_id': 'run-artifact',
          'sequence': 2,
          'type': 'run.completed',
          'payload': <String, Object?>{},
          'created_at': '2026-07-18T08:00:02Z',
        },
      ],
      'next_before_sequence': null,
    });
    final repository = AgentConversationApiRepository(transport: transport);

    final history = await repository.loadConversation('thread-artifact');

    expect(history.messages.length, 3);
    expect(history.messages[1].role, AgentConversationMessageRole.assistant);
    expect(history.messages[1].runState?.artifactEvents, isNotEmpty);
  });
}

Map<String, Object?> _message({
  required String id,
  required String runId,
  required String text,
  required int sequence,
}) {
  return {
    'id': id,
    'run_id': runId,
    'role': 'user',
    'message_type': 'text',
    'content': {'text': text, 'attachments': <Object?>[]},
    'status': 'completed',
    'sequence': sequence,
    'created_at': '2026-07-20T08:00:00Z',
  };
}

class _PagedHistoryTransport implements ApiJsonTransport {
  _PagedHistoryTransport(this.responses);

  final List<Map<String, Object?>> responses;
  final List<Map<String, Object?>> queries = <Map<String, Object?>>[];
  int _index = 0;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    queries.add(Map<String, Object?>.from(query));
    return responses[_index++];
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }
}
