import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';

void main() {
  test('default Agent Hub runner uses production run stream transport', () {
    final runner = createDefaultAgentHubRunner();
    final client = runner.client as SseAgentStreamClient;
    final transport = client.transport as ProductionAgentSseTransport;
    final request = buildDefaultAgentHubRequest(' Review my pattern ');
    final payload = transport.payloadFactory(request);

    expect(
      transport.runsEndpoint.uri.toString(),
      'http://127.0.0.1:8769/v1/agent/runs',
    );
    expect(transport.runsEndpoint.token, isNull);
    expect(
      transport.runsEndpoint.headers,
      containsPair('X-Momcozy-Client', 'flutter'),
    );
    expect(request.threadId, isNull);
    expect(request.locale, 'zh-CN');
    expect(payload['message'], 'Review my pattern');
    expect(payload['runtime_pattern'], 'langgraph_sdk');
    expect(payload.containsKey('thread_id'), isFalse);
    expect(payload.containsKey('user_id'), isFalse);
  });

  test('default Agent Hub cancel client uses unified API endpoint', () {
    final cancelClient = createDefaultAgentHubCancelClient();

    expect(
      cancelClient.endpoint.uri.toString(),
      'http://127.0.0.1:8769/v1/agent/runs',
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
    final transport = client.transport as ProductionAgentSseTransport;
    final cancelClient = createSessionAgentHubCancelClient(session);
    final request = buildSessionAgentHubRequest(
      '  Help me plan today  ',
      session: session,
    );
    final payload = buildDefaultAgentHubPayload(request);

    expect(transport.runsEndpoint.token, 'secure-access');
    expect(cancelClient.endpoint.token, 'secure-access');
    expect(request.threadId, isNull);
    expect(request.locale, 'en-US');
    expect(request.message, '  Help me plan today  ');
    expect(payload['message'], 'Help me plan today');
    expect(payload.containsKey('user_id'), isFalse);
  });
}
