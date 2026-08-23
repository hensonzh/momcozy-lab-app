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
      'http://127.0.0.1:8010/v1/agent/runs',
    );
    expect(transport.runsEndpoint.token, isNull);
    expect(
      transport.runsEndpoint.headers,
      containsPair('X-Momcozy-Client', 'flutter'),
    );
    expect(request.threadId, isNull);
    expect(request.locale, 'zh-CN');
    expect(payload['message'], 'Review my pattern');
    expect(payload['runtime_pattern'], 'proprietary_runtime');
    expect(payload.containsKey('thread_id'), isFalse);
    expect(payload.containsKey('user_id'), isFalse);
    expect(runner.reconnectPolicy.enabled, isTrue);
    expect(runner.runStatusReader, isA<ProductionAgentRunStatusReader>());
  });

  test('default Agent Hub controls use the dedicated Agent Runtime', () {
    final cancelClient = createDefaultAgentHubCancelClient();
    final actionClient = createDefaultAgentHubActionClient();

    expect(
      cancelClient.endpoint.uri.toString(),
      'http://127.0.0.1:8010/v1/agent/runs',
    );
    expect(
      cancelClient.endpoint.headers,
      containsPair('X-Momcozy-Client', 'flutter'),
    );
    expect(
      actionClient.endpoint.uri.toString(),
      'http://127.0.0.1:8010/v1/agent/actions',
    );
    expect(
      actionClient.endpoint.headers,
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
    Future<bool> onUnauthorized() async => true;
    final runner = createSessionAgentHubRunner(
      session,
      onUnauthorized: onUnauthorized,
    );
    final client = runner.client as SseAgentStreamClient;
    final transport = client.transport as ProductionAgentSseTransport;
    final cancelClient = createSessionAgentHubCancelClient(
      session,
      onUnauthorized: onUnauthorized,
    );
    final actionClient = createSessionAgentHubActionClient(
      session,
      onUnauthorized: onUnauthorized,
    );
    final clientEventClient = createSessionAgentHubClientEventClient(
      session,
      onUnauthorized: onUnauthorized,
    );
    final request = buildSessionAgentHubRequest(
      '  Help me plan today  ',
      session: session,
    );
    final payload = buildDefaultAgentHubPayload(request);

    expect(transport.runsEndpoint.token, 'secure-access');
    expect(cancelClient.endpoint.token, 'secure-access');
    expect(actionClient.endpoint.token, 'secure-access');
    expect(clientEventClient.endpoint?.token, 'secure-access');
    expect(cancelClient.onUnauthorized, same(onUnauthorized));
    expect(actionClient.onUnauthorized, same(onUnauthorized));
    expect(clientEventClient.onUnauthorized, same(onUnauthorized));
    expect(
      actionClient.endpoint.uri.toString(),
      'http://127.0.0.1:8010/v1/agent/actions',
    );
    expect(request.threadId, isNull);
    expect(request.locale, 'en-US');
    expect(request.message, '  Help me plan today  ');
    expect(payload['message'], 'Help me plan today');
    expect(payload.containsKey('user_id'), isFalse);
    expect(runner.reconnectPolicy.enabled, isTrue);
    expect(runner.runStatusReader, isA<ProductionAgentRunStatusReader>());
  });

  test('production payload preserves a valid backend thread id', () {
    final payload = buildDefaultAgentHubPayload(
      const AgentStreamRequest(
        message: 'Follow up',
        threadId: '123e4567-e89b-12d3-a456-426614174000',
      ),
    );

    expect(payload['thread_id'], '123e4567-e89b-12d3-a456-426614174000');
    expect(payload['message'], 'Follow up');
  });
}
