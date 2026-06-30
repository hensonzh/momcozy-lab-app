import 'agent_stream_event.dart';

class AgentStreamRequest {
  const AgentStreamRequest({
    required this.userId,
    required this.message,
    this.threadId,
    this.metadata = const <String, Object?>{},
  });

  final String userId;
  final String message;
  final String? threadId;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() => {
    'userId': userId,
    'message': message,
    if (threadId != null) 'threadId': threadId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

abstract interface class AgentStreamClient {
  Stream<AgentStreamEvent> stream(AgentStreamRequest request);
}

abstract interface class AgentStreamTransport {
  Stream<String> frames(AgentStreamRequest request);
}

typedef AgentStreamFrameDecoder = List<AgentStreamEvent> Function(String frame);

class TransportAgnosticAgentStreamClient implements AgentStreamClient {
  const TransportAgnosticAgentStreamClient({
    required this.transport,
    required this.decodeFrame,
  });

  final AgentStreamTransport transport;
  final AgentStreamFrameDecoder decodeFrame;

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    await for (final frame in transport.frames(request)) {
      for (final event in decodeFrame(frame)) {
        yield event;
      }
    }
  }
}

class SseAgentStreamClient extends TransportAgnosticAgentStreamClient {
  const SseAgentStreamClient(AgentStreamTransport transport)
    : super(transport: transport, decodeFrame: parseAgentEventStream);
}

class WebSocketAgentStreamClient extends TransportAgnosticAgentStreamClient {
  const WebSocketAgentStreamClient(AgentStreamTransport transport)
    : super(transport: transport, decodeFrame: parseAgentWebSocketFrame);
}

class JsonlAgentStreamClient extends TransportAgnosticAgentStreamClient {
  const JsonlAgentStreamClient(AgentStreamTransport transport)
    : super(transport: transport, decodeFrame: parseAgentJsonl);
}

class FixtureAgentStreamTransport implements AgentStreamTransport {
  const FixtureAgentStreamTransport(this.seedFrames);

  final Iterable<String> seedFrames;

  @override
  Stream<String> frames(AgentStreamRequest request) async* {
    for (final frame in seedFrames) {
      yield frame;
    }
  }
}
