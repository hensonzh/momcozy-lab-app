import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/web_demo/demo_agent_client.dart';

void main() {
  test(
    'demo replies are scripted and never trigger actions or tools',
    () async {
      final runner = AgentStreamRunner(DemoAgentClient());
      final states = await runner
          .run(const AgentStreamRequest(message: 'How is Luna feeding?'))
          .toList();
      final reply = states.last;
      expect(reply.textContent, contains('demo'));
      expect(reply.hasCompletedAssistantMessage, isTrue);
      expect(reply.artifactEvents, isEmpty);
      expect(reply.actionEvents, isEmpty);
      expect(reply.toolEvents, isEmpty);
    },
  );
}
