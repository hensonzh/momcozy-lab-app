import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_conversation_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'restores normalized transcript without assistant completion events',
    () async {
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
                  'asset_id': '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
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
            'event_id': 'event-run-1-completed',
            'thread_id': 'thread-restore',
            'run_id': 'run-1',
            'sequence': 1,
            'type': 'run.completed',
            'payload': <String, Object?>{},
            'created_at': '2026-07-19T08:01:01Z',
          },
          {
            'event_id': 'event-run-2-completed',
            'thread_id': 'thread-restore',
            'run_id': 'run-2',
            'sequence': 1,
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
      expect(history.messages.first.id, 'message-user-1');
      expect(history.messages.first.sequence, 1);
      expect(history.messages.first.createdAt, DateTime.utc(2026, 7, 19, 8));
      expect(history.currentState.messageId, 'message-assistant-2');
      expect(history.latestMessageCreatedAt, DateTime.utc(2026, 7, 20, 8, 1));
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
      expect(
        history.messages.first.images.single.assetId,
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
    },
  );

  test(
    'latest discovery skips empty threads and restores the latest real conversation',
    () async {
      Map<String, Object?> thread(String id) => {
        'id': id,
        'status': 'active',
        'created_at': '2026-07-20T08:00:00Z',
        'updated_at': '2026-07-20T08:00:00Z',
      };
      final transport = _PagedHistoryTransport([
        {
          'items': [thread('empty'), thread('real')],
        },
        {'thread': thread('empty'), 'items': [], 'events': []},
        {
          'thread': thread('real'),
          'items': [
            _message(
              id: 'first',
              runId: 'run-first',
              text: '第一条消息',
              sequence: 1,
            ),
          ],
          'events': [],
        },
      ]);
      final history = await AgentConversationApiRepository(
        transport: transport,
      ).loadLatestConversation();
      expect(history?.thread.id, 'real');
      expect(history?.messages.single.id, 'first');
      expect(transport.paths, [
        '/v1/agent/threads',
        '/v1/agent/threads/empty/history',
        '/v1/agent/threads/real/history',
      ]);
      expect(transport.queries.every((query) => query['limit'] == 20), isTrue);
    },
  );

  test('empty account discovery does not create a conversation', () async {
    final transport = _PagedHistoryTransport([
      {'items': []},
    ]);
    expect(
      await AgentConversationApiRepository(
        transport: transport,
      ).loadLatestConversation(),
      isNull,
    );
    expect(transport.paths, ['/v1/agent/threads']);
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
          text: 'Continue',
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

  test(
    'hides motion assessment automation prompts when restoring history',
    () async {
      final transport = FixtureApiJsonTransport({
        'thread': {
          'id': 'thread-motion-feedback',
          'title': '体态评估反馈',
          'status': 'active',
          'metadata': <String, Object?>{},
          'created_at': '2026-08-10T08:00:00Z',
          'updated_at': '2026-08-10T08:01:00Z',
        },
        'items': [
          {
            'id': 'message-motion-automation',
            'run_id': 'run-motion-feedback',
            'role': 'user',
            'message_type': 'text',
            'content': {
              'text':
                  '[系统流程触发] 用户刚完成体态动态评估。请调用 '
                  'motion_assessment_result.read 读取权威聚合结果。',
              'attachments': <Object?>[],
            },
            'status': 'completed',
            'sequence': 1,
            'created_at': '2026-08-10T08:00:00Z',
          },
          {
            'id': 'message-motion-feedback',
            'run_id': 'run-motion-feedback',
            'role': 'assistant',
            'message_type': 'text',
            'content': {'text': '你的头前伸角度处于轻度范围。'},
            'status': 'completed',
            'sequence': 2,
            'created_at': '2026-08-10T08:01:00Z',
          },
        ],
        'events': <Object?>[],
        'next_before_sequence': null,
      });
      final repository = AgentConversationApiRepository(transport: transport);

      final history = await repository.loadConversation(
        'thread-motion-feedback',
      );

      expect(history.messages, isEmpty);
      expect(history.currentState.textContent, '你的头前伸角度处于轻度范围。');
      expect(history.currentState.hasCompletedAssistantMessage, isTrue);
    },
  );

  test(
    'hides chat-first welcome trigger while retaining the streamed reply',
    () async {
      final transport = FixtureApiJsonTransport({
        'thread': {
          'id': 'welcome-thread',
          'title': 'Momcozy AI',
          'status': 'active',
          'metadata': <String, Object?>{},
          'created_at': '2026-10-15T08:00:00Z',
          'updated_at': '2026-10-15T08:01:00Z',
        },
        'items': [
          {
            'id': 'welcome-user',
            'run_id': 'welcome-run',
            'role': 'user',
            'message_type': 'text',
            'status': 'completed',
            'sequence': 1,
            'created_at': '2026-10-15T08:00:00Z',
            'content': {
              'text':
                  '[Momcozy Chat 欢迎引导][cccccccccccccccccccccccc] 请根据当前账号资料介绍自己。',
              'client_context': {'source': 'chat_first_welcome'},
              'attachments': <Object?>[],
            },
          },
          {
            'id': 'welcome-answer',
            'run_id': 'welcome-run',
            'role': 'assistant',
            'message_type': 'text',
            'status': 'completed',
            'sequence': 2,
            'created_at': '2026-10-15T08:01:00Z',
            'content': {'text': '你好，我是 Momcozy AI。'},
          },
        ],
        'events': <Object?>[],
        'next_before_sequence': null,
      });
      final history = await AgentConversationApiRepository(
        transport: transport,
      ).loadConversation('welcome-thread');
      expect(history.messages, isEmpty);
      expect(history.currentState.textContent, '你好，我是 Momcozy AI。');
      expect(history.currentRunIsChatFirstWelcome, isTrue);
    },
  );

  test(
    'classifies both welcome replies without hiding ordinary turns',
    () async {
      const thread = {
        'id': 'welcome-thread',
        'title': 'Momcozy AI',
        'status': 'active',
        'created_at': '2026-10-15T08:00:00Z',
        'updated_at': '2026-10-16T08:01:00Z',
      };
      Map<String, Object?> message(
        int sequence,
        String runId,
        String role,
        String text,
      ) => {
        'id': 'message-$sequence',
        'sequence': sequence,
        'run_id': runId,
        'role': role,
        'created_at': '2026-10-16T08:00:00Z',
        'content': {'text': text},
      };
      final response = {
        'thread': thread,
        'items': [
          message(
            1,
            'welcome-old',
            'user',
            '[Momcozy Chat 欢迎引导][aaaaaaaaaaaaaaaaaaaaaaaa] 初次引导',
          ),
          message(2, 'welcome-old', 'assistant', '旧资料的欢迎回复'),
          message(3, 'ordinary-1', 'user', '宝宝今天睡得好吗？'),
          message(4, 'ordinary-1', 'assistant', '请结合实际情况观察。'),
          message(
            5,
            'welcome-new',
            'user',
            '[Momcozy Chat 欢迎引导][bbbbbbbbbbbbbbbbbbbbbbbb] 更新引导',
          ),
          message(6, 'welcome-new', 'assistant', '新资料的欢迎回复'),
          message(7, 'ordinary-2', 'user', '怎么记录喂养？'),
          message(8, 'ordinary-2', 'assistant', '在记录入口填写。'),
        ],
        'events': <Object>[],
        'next_before_sequence': null,
      };
      final history = await AgentConversationApiRepository(
        transport: FixtureApiJsonTransport(response),
      ).loadConversation('welcome-thread');
      expect(history.currentRunIsChatFirstWelcome, isFalse);
      expect(history.messages.map((item) => item.content), [
        '旧资料的欢迎回复',
        '宝宝今天睡得好吗？',
        '请结合实际情况观察。',
        '新资料的欢迎回复',
        '怎么记录喂养？',
      ]);
      expect(
        history.messages
            .where((item) => item.isChatFirstWelcome)
            .map((item) => item.content),
        ['旧资料的欢迎回复', '新资料的欢迎回复'],
      );
    },
  );

  test(
    'classifies a welcome reply split from its trigger by pagination',
    () async {
      final thread = {
        'id': 'welcome-thread',
        'title': 'Momcozy AI',
        'status': 'active',
        'created_at': '2026-10-15T08:00:00Z',
        'updated_at': '2026-10-16T08:01:00Z',
      };
      final transport = _PagedHistoryTransport([
        {
          'thread': thread,
          'items': [
            {
              'id': 'welcome-answer',
              'run_id': 'welcome-run',
              'role': 'assistant',
              'sequence': 2,
              'created_at': '2026-10-15T08:01:00Z',
              'content': {'text': '旧资料的欢迎回复'},
            },
            _message(
              id: 'next-user',
              runId: 'next-run',
              text: '普通问题',
              sequence: 3,
            ),
          ],
          'events': <Object>[],
          'next_before_sequence': 2,
        },
        {
          'thread': thread,
          'items': [
            {
              ..._message(
                id: 'welcome-user',
                runId: 'welcome-run',
                text: '[Momcozy Chat 欢迎引导][aaaaaaaaaaaaaaaaaaaaaaaa] 初次引导',
                sequence: 1,
              ),
              'client_context': {'source': 'chat_first_welcome'},
            },
          ],
          'events': <Object>[],
          'next_before_sequence': null,
        },
      ]);
      final history = await AgentConversationApiRepository(
        transport: transport,
        identifyWelcomeBoundary: true,
      ).loadConversation('welcome-thread');
      expect(history.messages.first.content, '旧资料的欢迎回复');
      expect(history.messages.first.isChatFirstWelcome, isTrue);
      expect(history.messages.last.content, '普通问题');
      expect(history.messages.last.isChatFirstWelcome, isFalse);
      expect(transport.queries, [
        {'limit': 20},
        {'limit': 1, 'before_sequence': 2},
      ]);
    },
  );

  test(
    'poop history classifies internal photo trigger without exposing prompt',
    () async {
      final history = await AgentConversationApiRepository(
        transport: FixtureApiJsonTransport({
          'thread': {
            'id': 'thread-poop',
            'title': 'Momcozy AI',
            'status': 'active',
            'created_at': '2026-10-17T08:00:00Z',
            'updated_at': '2026-10-17T08:10:00Z',
          },
          'items': [
            {
              'id': 'poop-user',
              'run_id': 'run-poop',
              'role': 'user',
              'sequence': 1,
              'created_at': '2026-10-17T08:00:00Z',
              'content': {
                'text': '[momcozy_internal_poop_v1] 请结合这张宝宝便便照片观察。',
                'attachments': [
                  {
                    'type': 'image',
                    'asset_id': 'owned-photo',
                    'content_type': 'image/png',
                  },
                ],
              },
            },
            {
              'id': 'poop-answer',
              'run_id': 'run-poop',
              'role': 'assistant',
              'sequence': 2,
              'created_at': '2026-10-17T08:01:00Z',
              'content': {'text': '只能整理可见的观察线索。'},
            },
            {
              'id': 'ordinary-user',
              'run_id': 'run-ordinary',
              'role': 'user',
              'sequence': 3,
              'created_at': '2026-10-17T08:02:00Z',
              'content': {'text': '普通问题'},
            },
            {
              'id': 'ordinary-answer',
              'run_id': 'run-ordinary',
              'role': 'assistant',
              'sequence': 4,
              'created_at': '2026-10-17T08:03:00Z',
              'content': {'text': '普通回答'},
            },
          ],
          'events': <Object>[],
        }),
      ).loadConversation('thread-poop');
      expect(history.messages.first.isChatFirstPoopTrigger, isTrue);
      expect(history.messages.first.runId, 'run-poop');
      expect(history.messages.first.content, isEmpty);
      expect(history.messages.first.images, isEmpty);
      expect(history.messages[1].content, '只能整理可见的观察线索。');
      expect(history.messages[2].content, '普通问题');
      expect(history.currentState.textContent, '普通回答');
    },
  );

  test('ordinary history does not require a boundary lookup', () async {
    const thread = {
      'id': 'ordinary-thread',
      'title': 'Momcozy AI',
      'status': 'active',
      'created_at': '2026-10-15T08:00:00Z',
      'updated_at': '2026-10-16T08:01:00Z',
    };
    final transport = _PagedHistoryTransport([
      {
        'thread': thread,
        'items': [
          {
            'id': 'ordinary-answer',
            'run_id': 'ordinary-run',
            'role': 'assistant',
            'sequence': 12,
            'created_at': '2026-10-16T08:01:00Z',
            'content': {'text': '普通回答'},
          },
        ],
        'events': <Object>[],
        'next_before_sequence': 12,
      },
    ]);
    final history = await AgentConversationApiRepository(
      transport: transport,
    ).loadConversation('ordinary-thread');
    expect(history.currentState.textContent, '普通回答');
    expect(history.currentRunIsChatFirstWelcome, isFalse);
    expect(transport.queries, [
      {'limit': 20},
    ]);
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
  final List<String> paths = [];
  int _index = 0;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    queries.add(Map<String, Object?>.from(query));
    paths.add(path);
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
