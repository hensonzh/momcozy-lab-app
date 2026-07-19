import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_store.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

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
    expect(payload['runtime_pattern'], 'sdk_only');
    expect(payload.containsKey('thread_id'), isFalse);
    expect(payload.containsKey('user_id'), isFalse);
    expect(runner.reconnectPolicy.enabled, isTrue);
    expect(runner.runStatusReader, isA<ProductionAgentRunStatusReader>());
  });

  test('default Agent Hub cancel client uses unified API endpoint', () {
    final cancelClient = createDefaultAgentHubCancelClient();
    final actionClient = createDefaultAgentHubActionClient();

    expect(
      cancelClient.endpoint.uri.toString(),
      'http://127.0.0.1:8769/v1/agent/runs',
    );
    expect(
      cancelClient.endpoint.headers,
      containsPair('X-Momcozy-Client', 'flutter'),
    );
    expect(
      actionClient.endpoint.uri.toString(),
      'http://127.0.0.1:8769/v1/agent/actions',
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
    final runner = createSessionAgentHubRunner(session);
    final client = runner.client as SseAgentStreamClient;
    final transport = client.transport as ProductionAgentSseTransport;
    final cancelClient = createSessionAgentHubCancelClient(session);
    final actionClient = createSessionAgentHubActionClient(session);
    final request = buildSessionAgentHubRequest(
      '  Help me plan today  ',
      session: session,
    );
    final payload = buildDefaultAgentHubPayload(request);

    expect(transport.runsEndpoint.token, 'secure-access');
    expect(cancelClient.endpoint.token, 'secure-access');
    expect(actionClient.endpoint.token, 'secure-access');
    expect(
      actionClient.endpoint.uri.toString(),
      'http://127.0.0.1:8769/v1/agent/actions',
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

  test(
    'session request includes the active runtime cart only after activation',
    () {
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'secure-user',
        babyId: 'secure-baby',
        locale: 'zh-CN',
        accessToken: 'secure-access',
      );
      final store = HospitalBagCartStore();
      final withoutCart = buildSessionAgentHubRequest(
        '先聊聊',
        session: session,
        clientContext: store.agentClientContext,
      );

      expect(withoutCart.metadata.containsKey('hospital_bag_cart'), isFalse);

      store.ingestArtifact(
        HospitalBagCartArtifactSeed.tryFromCartUpdate(
          artifactId: 'cart-context',
          cartUpdate: {
            'groups': [
              {
                'title': '我的清单',
                'tone': 'rose',
                'items': [
                  {'id': 'custom', 'name': '个性化用品', 'qty': 1, 'price': 10},
                ],
              },
            ],
          },
        )!,
      );
      final withCart = buildSessionAgentHubRequest(
        '删掉个性化用品',
        session: session,
        clientContext: store.agentClientContext,
      );
      final cart = withCart.metadata['hospital_bag_cart']! as Map;
      final groups = cart['groups']! as List;

      expect((groups.single as Map)['title'], '我的清单');
    },
  );
}
