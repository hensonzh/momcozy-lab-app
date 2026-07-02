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
      expect(payload.containsKey('user_id'), isFalse);
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
  });
}
