import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

void main() {
  group('Agent run payload', () {
    test('builds the text-only production run create contract', () {
      final payload = buildProductionAgentRunPayload(
        const AgentStreamRequest(
          message: '  Please review today\'s pumping pattern.  ',
          threadId: '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
          locale: 'en-US',
          metadata: {'source': 'flutter-migration-fixture'},
        ),
      );

      expect(payload['thread_id'], '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5');
      expect(payload['message'], 'Please review today\'s pumping pattern.');
      expect(payload['runtime_pattern'], 'langgraph_sdk');
      expect(payload['client_context'], {
        'source': 'flutter-migration-fixture',
        'locale': 'en-US',
      });
      expect(payload.containsKey('user_id'), isFalse);
    });

    test('forwards the active hospital bag cart as client context', () {
      final payload = buildProductionAgentRunPayload(
        const AgentStreamRequest(
          message: '把吸奶器删掉',
          locale: 'zh-CN',
          metadata: {
            'source': 'flutter-agent-hub',
            'hospital_bag_cart': {
              'groups': [
                {
                  'title': '母乳喂养',
                  'tone': 'sky',
                  'items': [
                    {
                      'id': 'pump-custom',
                      'name': '个性化吸奶器',
                      'desc': '当前购物车商品',
                      'qty': 1,
                      'price': 999.0,
                    },
                  ],
                },
              ],
              'totals': {'itemCount': 1, 'total': 919.08},
            },
          },
        ),
      );

      final context = payload['client_context']! as Map<String, Object?>;
      final cart = context['hospital_bag_cart']! as Map<String, Object?>;
      final groups = cart['groups']! as List<Object?>;
      final group = groups.single! as Map<String, Object?>;
      final items = group['items']! as List<Object?>;

      expect(context['locale'], 'zh-CN');
      expect((items.single! as Map<String, Object?>)['id'], 'pump-custom');
    });

    test('forwards a stable caller-provided run idempotency key', () {
      final payload = buildProductionAgentRunPayload(
        const AgentStreamRequest(
          message: '提交表单',
          idempotencyKey: 'agent-form-submit-fixture',
        ),
      );

      expect(payload['idempotency_key'], 'agent-form-submit-fixture');
    });

    test('adds image attachments to the production run create contract', () {
      final payload = buildProductionAgentRunPayload(
        const AgentStreamRequest(
          message: 'Please review this pump display photo.',
          threadId: 'not-a-production-uuid',
          locale: 'en-US',
          metadata: {'source': 'flutter-migration-fixture'},
          images: [
            AgentStreamImageInput(
              dataUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              mimeType: 'image/png',
              name: 'pump-display-fixture.png',
              size: 68,
              detail: 'low',
            ),
          ],
        ),
      );
      final attachments = payload['attachments']! as List<Object?>;
      final image = attachments.single! as Map<String, Object?>;

      expect(payload.containsKey('thread_id'), isFalse);
      expect(image['type'], 'image');
      expect(image['data_url'], startsWith('data:image/png;base64,'));
      expect(image['mime_type'], 'image/png');
      expect(image['name'], 'pump-display-fixture.png');
    });

    test('requires non-empty message before sending to the production runtime', () {
      expect(
        () => buildProductionAgentRunPayload(
          const AgentStreamRequest(
            message: '   ',
          ),
        ),
        throwsA(isA<AgentStreamPayloadException>()),
      );
    });

    test('builds resume requests without adding run ids to create payloads', () {
      const request = AgentStreamRequest(
        message: 'Retry the interrupted answer.',
        threadId: '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
        locale: 'zh-CN',
        metadata: {'source': 'resume-test'},
      );

      final resume = request.resume(
        runId: '0d39da8a-6f31-4e23-b5ac-b81d9808fb8c',
        afterSequence: 12,
      );
      final payload = buildProductionAgentRunPayload(resume);

      expect(resume.runId, '0d39da8a-6f31-4e23-b5ac-b81d9808fb8c');
      expect(resume.afterSequence, 12);
      expect(payload.containsKey('run_id'), isFalse);
      expect(payload.containsKey('after_sequence'), isFalse);
      expect(payload['thread_id'], '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5');
    });
  });
}
