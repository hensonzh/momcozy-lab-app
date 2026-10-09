import '../core/agent_stream/agent_stream_client.dart';
import '../core/agent_stream/agent_stream_event.dart';

/// A scripted conversation: no model, HTTP, SSE, action or tool execution.
class DemoAgentClient implements AgentStreamClient {
  int _nextRun = 0;

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    if (request.images.isNotEmpty || request.files.isNotEmpty) {
      throw UnsupportedError('Attachments are not available in the demo.');
    }
    final id = ++_nextRun;
    const threadId = 'demo-thread';
    final runId = 'demo-run-$id';
    final messageId = 'demo-message-$id';
    yield AgentStreamEvent({
      'type': 'run.queued',
      'thread_id': threadId,
      'run_id': runId,
      'sequence': id * 10 + 1,
    });
    yield AgentStreamEvent({
      'type': 'message.completed',
      'thread_id': threadId,
      'run_id': runId,
      'message_id': messageId,
      'sequence': id * 10 + 2,
      'payload': {'role': 'assistant', 'text': _scriptedReply(request.message)},
    });
    yield AgentStreamEvent({
      'type': 'run.completed',
      'thread_id': threadId,
      'run_id': runId,
      'sequence': id * 10 + 3,
    });
  }

  String _scriptedReply(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('feed') || lower.contains('milk')) {
      return 'In this demo, Luna has a sample feeding entry. You can explore it in the Baby tab. This is fictional data, not medical advice.';
    }
    if (lower.contains('sleep') || lower.contains('rest')) {
      return 'In this demo, try adding a rest reminder to the Schedule tab. The data is fictional and resets when you refresh.';
    }
    return 'This is a scripted demo reply, not a live AI or medical consultation. Explore the Me, Baby and Schedule tabs to see how the app works.';
  }
}
