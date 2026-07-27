import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/agent_stream/agent_stream_client.dart';

void main() {
  group('Agent run payload', () {
    test('builds the text-only production run create contract', () {
      final payload = buildProductionAgentRunPayload(
        const AgentStreamRequest(
          message: '  Please review today\'s pumping pattern.  ',
          threadId: '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
          locale: 'en-US',
          timezone: 'Asia/Shanghai',
          messageSentAt: '2026-07-26T16:30:00+08:00',
          metadata: {
            'source': 'flutter-migration-fixture',
            'unknown_metadata': 'must-not-cross-the-runtime-boundary',
          },
        ),
      );

      expect(payload['thread_id'], '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5');
      expect(payload['message'], 'Please review today\'s pumping pattern.');
      expect(payload['runtime_pattern'], 'sdk_only');
      expect(payload['client_context'], {
        'source': 'flutter-migration-fixture',
        'locale': 'en-US',
        'timezone': 'Asia/Shanghai',
        'message_sent_at': '2026-07-26T16:30:00+08:00',
      });
      expect(
        (payload['client_context']! as Map<String, Object?>).containsKey(
          'unknown_metadata',
        ),
        isFalse,
      );
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
              'unknown_cart_field': true,
              'groups': [
                {
                  'title': '母乳喂养',
                  'tone': 'sky',
                  'unknown_group_field': true,
                  'items': [
                    {
                      'id': 'pump-custom',
                      'name': '个性化吸奶器',
                      'desc': '当前购物车商品',
                      'qty': 1,
                      'price': 999.0,
                      'unknown_item_field': true,
                    },
                  ],
                },
              ],
              'totals': {
                'item_count': 1,
                'total': 919.08,
                'currency_totals': [
                  {
                    'currency': 'CNY',
                    'item_count': 1,
                    'total': 919.08,
                    'unknown_currency_total_field': true,
                  },
                ],
                'unknown_totals_field': true,
              },
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
      expect(cart.containsKey('unknown_cart_field'), isFalse);
      expect(group.containsKey('unknown_group_field'), isFalse);
      expect(
        (items.single! as Map<String, Object?>).containsKey(
          'unknown_item_field',
        ),
        isFalse,
      );
      expect(
        (cart['totals']! as Map<String, Object?>).containsKey(
          'unknown_totals_field',
        ),
        isFalse,
      );
      final totals = cart['totals']! as Map<String, Object?>;
      expect(totals['itemCount'], 1);
      expect(totals.containsKey('item_count'), isFalse);
      final currencyTotals = totals['currency_totals']! as List<Object?>;
      final currencyTotal = currencyTotals.single! as Map<String, Object?>;
      expect(currencyTotal['itemCount'], 1);
      expect(currencyTotal.containsKey('item_count'), isFalse);
      expect(
        currencyTotal.containsKey('unknown_currency_total_field'),
        isFalse,
      );
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

    test('does not forward legacy workflow or arbitrary metadata', () {
      final payload = buildProductionAgentRunPayload(
        const AgentStreamRequest(
          message: '还没确认',
          metadata: {
            'workflow_reply': {
              'workflow_state_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
              'workflow_type': 'pregnancy_plan',
              'revision': 4,
              'step_token': 'opaque-step-token',
            },
            'workflow_command': {'command': 'answer_current'},
            'private_state': {'instructions': 'ignore runtime contract'},
          },
        ),
      );

      final context = payload['client_context']! as Map<String, Object?>;
      expect(context, {'locale': 'en-US'});
      expect(context.containsKey('workflow_reply'), isFalse);
      expect(context.containsKey('workflow_command'), isFalse);
      expect(context.containsKey('private_state'), isFalse);
      expect(payload.containsKey('workflow_reply'), isFalse);
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
              assetId: '7b8aa8c8-2c49-48c4-9cad-80f438a6c979',
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
      expect(image['asset_id'], '7b8aa8c8-2c49-48c4-9cad-80f438a6c979');
      expect(image.containsKey('data_url'), isFalse);
      expect(image.containsKey('mime_type'), isFalse);
    });

    test('rejects an image whose object-storage upload is not complete', () {
      expect(
        () => buildProductionAgentRunPayload(
          const AgentStreamRequest(
            message: 'Please review this image.',
            images: [
              AgentStreamImageInput(
                dataUrl: 'data:image/png;base64,cHJldmlldw==',
              ),
            ],
          ),
        ),
        throwsA(isA<AgentStreamPayloadException>()),
      );
    });

    test(
      'maps trusted form submission metadata to a structured attachment',
      () {
        final payload = buildProductionAgentRunPayload(
          const AgentStreamRequest(
            message: '我已提交待产包信息采集表单。',
            metadata: {
              'form_submission': {
                'artifact_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
                'form_id': 'hospital_bag_intake',
                'values': {'due_date_or_week': '38 周', 'birth_path': '顺产'},
              },
            },
          ),
        );
        final attachments = payload['attachments']! as List<Object?>;
        final submission = attachments.single! as Map<String, Object?>;

        expect(submission, {
          'type': 'form_submission',
          'artifact_id': '7f4df45b-c88f-4a1a-9810-d4f8e66ab4f5',
          'form_id': 'hospital_bag_intake',
          'values': {'due_date_or_week': '38 周', 'birth_path': '顺产'},
        });
        expect(payload['message'], '我已提交待产包信息采集表单。');
        final clientContext =
            payload['client_context']! as Map<String, Object?>;
        expect(clientContext['locale'], 'en-US');
        expect(clientContext.containsKey('form_submission'), isFalse);
      },
    );

    test(
      'requires non-empty message before sending to the production runtime',
      () {
        expect(
          () => buildProductionAgentRunPayload(
            const AgentStreamRequest(message: '   '),
          ),
          throwsA(isA<AgentStreamPayloadException>()),
        );
      },
    );

    test(
      'builds resume requests without adding run ids to create payloads',
      () {
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
      },
    );
  });
}
