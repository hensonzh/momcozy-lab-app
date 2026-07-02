import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Agent stream IO transports', () {
    test(
      'production SSE transport creates run and follows event stream',
      () async {
        final runConnector = _RecordingControlHttpConnector(
          const AgentStreamControlHttpResponse(
            statusCode: 201,
            body:
                '{"id":"run-production-001","thread_id":"thread-production-001","status":"running"}',
          ),
        );
        final streamConnector = _RecordingSseGetConnector([
          'data: {"event_id":"evt-1","thread_id":"thread-production-001","run_id":"run-production-001","sequence":1,"type":"message.delta","payload":{"text":"Hello"},"created_at":"2026-07-01T00:00:00Z"}\n\n',
          'data: {"event_id":"evt-2","thread_id":"thread-production-001","run_id":"run-production-001","sequence":2,"type":"run.completed","payload":{},"created_at":"2026-07-01T00:00:01Z"}\n\n',
        ]);
        final client = SseAgentStreamClient(
          ProductionAgentSseTransport(
            runsEndpoint: AgentStreamEndpoint(
              uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
              token: 'secret-token',
            ),
            payloadFactory: buildProductionAgentRunPayload,
            runConnector: runConnector,
            streamConnector: streamConnector,
          ),
        );

        final events = await client.stream(_request).toList();
        final postedBody =
            jsonDecode(runConnector.body!) as Map<String, Object?>;

        expect(events.map((event) => event.type), [
          'message.delta',
          'run.completed',
        ]);
        expect(runConnector.uri!.path, '/v1/agent/runs');
        expect(streamConnector.uri!.path, '/v1/agent/runs/run-production-001/stream');
        expect(streamConnector.uri!.queryParameters, {
          'after_sequence': '0',
          'follow': 'true',
          'limit': '200',
        });
        expect(postedBody['message'], 'Review my pumping pattern.');
        expect(postedBody['runtime_pattern'], 'langgraph_sdk');
        expect(postedBody.containsKey('user_id'), isFalse);
        expect(
          runConnector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(runConnector.headers?['Idempotency-Key'], isNotEmpty);
      },
    );

    test(
      'cancel client posts production run-scoped cancel and accepts 2xx or 404',
      () async {
        final ack = readFixtureMap('agent_events/cancel_ack.json');
        final connector = _RecordingControlHttpConnector(
          AgentStreamControlHttpResponse(
            statusCode: 200,
            body: jsonEncode(ack),
          ),
        );
        final client = AgentStreamCancelClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
            token: 'secret-token',
          ),
          connector: connector,
        );

        final result = await client.cancel(
          const AgentStreamCancelRequest(
            threadId: 'thread-fixture-001',
            runId: 'run-fixture-tool-001',
            reason: 'user_cancelled',
          ),
        );

        expect(result.acknowledged, isTrue);
        expect(result.statusCode, 200);
        expect(result.body, ack);
        expect(
          connector.uri!.queryParameters,
          isNot(containsPair('token', anything)),
        );
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(connector.headers, containsPair('Accept', 'application/json'));
        expect(
          connector.headers,
          containsPair('Content-Type', 'application/json'),
        );
        expect(connector.uri!.path, '/v1/agent/runs/run-fixture-tool-001/cancel');
        expect(jsonDecode(connector.body!) as Map<String, Object?>, {
          'reason': 'user_cancelled',
        });

        connector.nextResponse = const AgentStreamControlHttpResponse(
          statusCode: 404,
          body: '',
        );

        final alreadyClosed = await client.cancel(
          const AgentStreamCancelRequest(
            threadId: 'thread-fixture-001',
            runId: 'run-fixture-tool-001',
          ),
        );

        expect(alreadyClosed.acknowledged, isTrue);
        expect(alreadyClosed.statusCode, 404);
      },
    );

    test('cancel client reports failures without throwing', () async {
      final connector = _RecordingControlHttpConnector(
        const AgentStreamControlHttpResponse(
          statusCode: 503,
          body: '{"message":"busy"}',
        ),
      );
      final client = AgentStreamCancelClient(
        endpoint: AgentStreamEndpoint(
          uri: Uri.parse('http://127.0.0.1:8769/v1/agent/runs'),
        ),
        connector: connector,
      );

      final unavailable = await client.cancel(
        const AgentStreamCancelRequest(
          threadId: 'thread-fixture-001',
          runId: 'run-fixture-tool-001',
        ),
      );

      expect(unavailable.acknowledged, isFalse);
      expect(unavailable.statusCode, 503);
      expect(unavailable.body, {'message': 'busy'});

      connector.nextError = StateError('network down');

      final networkFailure = await client.cancel(
        const AgentStreamCancelRequest(
          threadId: 'thread-fixture-001',
          runId: 'run-fixture-tool-001',
        ),
      );

      expect(networkFailure.acknowledged, isFalse);
      expect(networkFailure.error, isA<StateError>());
    });

    test(
      'client event client posts IBCLC completion events best-effort',
      () async {
        final fixture = readFixtureMap(
          'route_intents/media_viewer_and_ibclc_return_intents.json',
        );
        final input = Map<String, Object?>.from(fixture['input']! as Map);
        final ibclc = Map<String, Object?>.from(input['ibclc']! as Map);
        final completion = Map<String, Object?>.from(
          ibclc['completionPayload']! as Map,
        );
        final connector = _RecordingControlHttpConnector(
          const AgentStreamControlHttpResponse(
            statusCode: 200,
            body: '{"status":"ok"}',
          ),
        );
        final client = AgentStreamClientEventClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/client-event'),
            token: 'secret-token',
          ),
          connector: connector,
        );

        final result = await client.post(
          AgentStreamClientEventRequest(
            threadId: completion['conversation_id']! as String,
            userId: 'demo-user-001',
            eventType: completion['event_type']! as String,
            label: '用户已完成一次 IBCLC 在线咨询',
            occurredAt: completion['completed_at']! as String,
            locale: 'zh-CN',
            timezone: 'Asia/Shanghai',
            metadata: {
              'user_id': 'demo-user-001',
              'consult_id': completion['consult_id'],
              'source': 'ibclc-chat',
            },
          ),
        );
        final body = jsonDecode(connector.body!) as Map<String, Object?>;

        expect(result.sent, isTrue);
        expect(result.body, {'status': 'ok'});
        expect(
          connector.uri!.queryParameters,
          isNot(containsPair('token', anything)),
        );
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer secret-token'),
        );
        expect(body['thread_id'], 'thread-ibclc-001');
        expect(body['user_id'], 'demo-user-001');
        expect(body['event_type'], 'ibclc_consult_completed');
        expect(body['occurred_at'], '2026-06-29T10:00:00+08:00');
        expect(body['locale'], 'zh-CN');
        expect(body['timezone'], 'Asia/Shanghai');
        expect(body['metadata'], containsPair('source', 'ibclc-chat'));
      },
    );

    test(
      'client event client reports guard, HTTP, and network failures',
      () async {
        final connector = _RecordingControlHttpConnector(
          const AgentStreamControlHttpResponse(statusCode: 500, body: ''),
        );
        final client = AgentStreamClientEventClient(
          endpoint: AgentStreamEndpoint(
            uri: Uri.parse('http://127.0.0.1:8769/api/client-event'),
          ),
          connector: connector,
        );

        final httpFailure = await client.post(
          const AgentStreamClientEventRequest(
            threadId: 'thread-fixture-001',
            userId: 'demo-user-001',
            eventType: 'milk_analysis_generated',
            occurredAt: '2026-06-29T10:00:00+08:00',
          ),
        );

        expect(httpFailure.sent, isFalse);
        expect(httpFailure.statusCode, 500);

        final guardFailure = await client.post(
          const AgentStreamClientEventRequest(
            threadId: '',
            userId: 'demo-user-001',
            eventType: 'milk_analysis_generated',
            occurredAt: '2026-06-29T10:00:00+08:00',
          ),
        );

        expect(guardFailure.sent, isFalse);
        expect(guardFailure.error, isA<AgentStreamPayloadException>());

        connector.nextError = StateError('network down');

        final networkFailure = await client.post(
          const AgentStreamClientEventRequest(
            threadId: 'thread-fixture-001',
            userId: 'demo-user-001',
            eventType: 'milk_analysis_generated',
            occurredAt: '2026-06-29T10:00:00+08:00',
          ),
        );

        expect(networkFailure.sent, isFalse);
        expect(networkFailure.error, isA<StateError>());
      },
    );
  });
}

const _request = AgentStreamRequest(
  userId: 'demo-user-fixture',
  message: 'Review my pumping pattern.',
  threadId: 'thread-fixture-001',
  metadata: {'source': 'io-transport-test'},
);

class _RecordingSseGetConnector implements AgentStreamSseGetConnector {
  _RecordingSseGetConnector(this.seedFrames);

  final Iterable<String> seedFrames;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) async* {
    this.uri = uri;
    this.headers = headers;

    for (final frame in seedFrames) {
      yield frame;
    }
  }
}

class _RecordingControlHttpConnector
    implements AgentStreamControlHttpConnector {
  _RecordingControlHttpConnector(this.nextResponse);

  AgentStreamControlHttpResponse nextResponse;
  Object? nextError;
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    this.uri = uri;
    this.headers = headers;
    this.body = body;

    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }

    return nextResponse;
  }
}
