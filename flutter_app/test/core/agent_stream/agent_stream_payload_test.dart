import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Agent run payload', () {
    test('builds the text-only AG-UI first frame contract', () {
      final payload = buildAgentRunPayload(
        const AgentStreamRequest(
          userId: 'demo-user-fixture',
          message: '  Please review today\'s pumping pattern.  ',
          threadId: 'thread-fixture-001',
          locale: 'en-US',
          metadata: {'source': 'flutter-migration-fixture'},
        ),
        runId: 'run-fixture-text-001',
        messageId: 'msg-user-text-001',
      );

      expect(payload['threadId'], 'thread-fixture-001');
      expect(payload['runId'], 'run-fixture-text-001');
      expect(payload['state'], {
        'locale': 'en-US',
        'user_id': 'demo-user-fixture',
      });
      expect(payload['messages'], [
        {
          'id': 'msg-user-text-001',
          'role': 'user',
          'content': 'Please review today\'s pumping pattern.',
        },
      ]);
      expect(payload['tools'], isEmpty);
      expect(payload['context'], isEmpty);
      expect(payload['forwardedProps'], {
        'source': 'flutter-migration-fixture',
      });
    });

    test('matches the frozen image upload AG-UI fixture', () {
      final expected = readFixtureMap('ag_ui/image_upload_message.json');
      final payload = buildAgentRunPayload(
        const AgentStreamRequest(
          userId: 'demo-user-fixture',
          message: 'Please review this pump display photo.',
          threadId: 'thread-fixture-001',
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
        runId: 'run-fixture-image-001',
        messageId: 'msg-user-image-001',
      );

      expect(payload, expected);
    });

    test('requires a thread id before sending to the AG-UI transport', () {
      expect(
        () => buildAgentRunPayload(
          const AgentStreamRequest(
            userId: 'demo-user-fixture',
            message: 'Hello',
          ),
          runId: 'run-fixture-001',
          messageId: 'msg-user-001',
        ),
        throwsA(isA<AgentStreamPayloadException>()),
      );
    });
  });
}
