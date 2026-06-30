import 'agent_stream_event.dart';

class AgentStreamRequest {
  const AgentStreamRequest({
    required this.userId,
    required this.message,
    this.threadId,
    this.locale = 'en-US',
    this.images = const <AgentStreamImageInput>[],
    this.metadata = const <String, Object?>{},
  });

  final String userId;
  final String message;
  final String? threadId;
  final String locale;
  final List<AgentStreamImageInput> images;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() => {
    'userId': userId,
    'message': message,
    if (threadId != null) 'threadId': threadId,
    if (locale.trim().isNotEmpty) 'locale': locale,
    if (images.isNotEmpty)
      'images': images.map((image) => image.toMap()).toList(growable: false),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

class AgentStreamImageInput {
  const AgentStreamImageInput({
    required this.dataUrl,
    this.mimeType = 'image/png',
    this.name = 'image.png',
    this.size = 0,
    this.detail = 'auto',
  });

  final String dataUrl;
  final String mimeType;
  final String name;
  final int size;
  final String detail;

  Map<String, Object?> toMap() => {
    'dataUrl': dataUrl,
    'mimeType': mimeType,
    'name': name,
    'size': size,
    'detail': detail,
  };

  Map<String, Object?> toAgUiContentPart() => {
    'type': 'image',
    'image_url': dataUrl,
    'mime_type': mimeType.trim().isEmpty ? 'image/png' : mimeType,
    'name': name.trim().isEmpty ? 'image.png' : name,
    'size': size,
    'detail': detail.trim().isEmpty ? 'auto' : detail,
  };
}

class AgentStreamPayloadException implements Exception {
  const AgentStreamPayloadException(this.message);

  final String message;

  @override
  String toString() => 'AgentStreamPayloadException($message)';
}

Map<String, Object?> buildAgentRunPayload(
  AgentStreamRequest request, {
  required String runId,
  required String messageId,
}) {
  final threadId = request.threadId?.trim() ?? '';
  if (threadId.isEmpty) {
    throw const AgentStreamPayloadException('Missing threadId.');
  }

  final normalizedRunId = runId.trim();
  if (normalizedRunId.isEmpty) {
    throw const AgentStreamPayloadException('Missing runId.');
  }

  final normalizedMessageId = messageId.trim();
  if (normalizedMessageId.isEmpty) {
    throw const AgentStreamPayloadException('Missing messageId.');
  }

  final userId = request.userId.trim();
  if (userId.isEmpty) {
    throw const AgentStreamPayloadException('Missing userId.');
  }

  final text = request.message.trim();
  final locale = request.locale.trim().isEmpty
      ? 'en-US'
      : request.locale.trim();
  final Object content = request.images.isEmpty
      ? text
      : <Map<String, Object?>>[
          {'type': 'text', 'text': text},
          ...request.images.map((image) => image.toAgUiContentPart()),
        ];

  return {
    'threadId': threadId,
    'runId': normalizedRunId,
    'state': {'locale': locale, 'user_id': userId},
    'messages': [
      {'id': normalizedMessageId, 'role': 'user', 'content': content},
    ],
    'tools': <Object?>[],
    'context': <Object?>[],
    'forwardedProps': request.metadata,
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
