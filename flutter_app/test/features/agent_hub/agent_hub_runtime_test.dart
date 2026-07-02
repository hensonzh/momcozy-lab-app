import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';

void main() {
  test('default Agent Hub runner uses SSE transport and AG-UI payload', () {
    final runner = createDefaultAgentHubRunner();
    final client = runner.client as SseAgentStreamClient;
    final transport = client.transport as AgentSseHttpTransport;
    final request = buildDefaultAgentHubRequest(' Review my pattern ');
    final payload = transport.payloadFactory(request);
    final messages = payload['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;

    expect(
      transport.endpoint.uri.toString(),
      'http://127.0.0.1:8768/api/ag-ui',
    );
    expect(transport.endpoint.token, isNull);
    expect(
      transport.endpoint.headers,
      containsPair('X-Momcozy-Client', 'flutter'),
    );
    expect(request.userId, 'demo-user');
    expect(request.threadId, 'thread-demo');
    expect(request.locale, 'zh-CN');
    expect(payload['threadId'], 'thread-demo');
    expect(payload['runId'], startsWith('run-flutter-'));
    expect(message['id'], startsWith('msg-flutter-'));
    expect(message['content'], 'Review my pattern');
  });

  test('default Agent Hub cancel client uses unified API endpoint', () {
    final cancelClient = createDefaultAgentHubCancelClient();

    expect(
      cancelClient.endpoint.uri.toString(),
      'http://127.0.0.1:8769/api/ag-ui-cancel',
    );
    expect(
      cancelClient.endpoint.headers,
      containsPair('X-Momcozy-Client', 'flutter'),
    );
  });

  test('session Agent Hub runtime uses secure session context', () {
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'secure-user',
      babyId: 'secure-baby',
      locale: 'en-US',
      accessToken: 'secure-access',
    );
    final runner = createSessionAgentHubRunner(session);
    final client = runner.client as SseAgentStreamClient;
    final transport = client.transport as AgentSseHttpTransport;
    final cancelClient = createSessionAgentHubCancelClient(session);
    final request = buildSessionAgentHubRequest(
      '  Help me plan today  ',
      session: session,
    );
    final payload = buildDefaultAgentHubPayload(request);
    final messages = payload['messages']! as List<Object?>;
    final message = messages.single! as Map<String, Object?>;

    expect(transport.endpoint.token, 'secure-access');
    expect(cancelClient.endpoint.token, 'secure-access');
    expect(request.userId, 'secure-user');
    expect(request.threadId, 'thread-secure-user');
    expect(request.locale, 'en-US');
    expect(request.message, '  Help me plan today  ');
    expect(message['content'], 'Help me plan today');
  });
}
