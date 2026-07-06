import 'agent_stream_event.dart';

class AgentStreamRequest {
  const AgentStreamRequest({
    required this.message,
    this.threadId,
    this.runId,
    this.afterSequence = 0,
    this.locale = 'en-US',
    this.images = const <AgentStreamImageInput>[],
    this.metadata = const <String, Object?>{},
  });

  final String message;
  final String? threadId;
  final String? runId;
  final int afterSequence;
  final String locale;
  final List<AgentStreamImageInput> images;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() => {
    'message': message,
    if (threadId != null) 'threadId': threadId,
    if (locale.trim().isNotEmpty) 'locale': locale,
    if (images.isNotEmpty)
      'images': images.map((image) => image.toMap()).toList(growable: false),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  AgentStreamRequest resume({
    required String runId,
    required int afterSequence,
    String? threadId,
  }) {
    return AgentStreamRequest(
      message: message,
      threadId: threadId ?? this.threadId,
      runId: runId,
      afterSequence: afterSequence < 0 ? 0 : afterSequence,
      locale: locale,
      images: images,
      metadata: metadata,
    );
  }
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

  Map<String, Object?> toProductionAttachment() => {
    'type': 'image',
    'data_url': dataUrl,
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

Map<String, Object?> buildProductionAgentRunPayload(
  AgentStreamRequest request, {
  String? idempotencyKey,
}) {
  final text = request.message.trim();
  if (text.isEmpty) {
    throw const AgentStreamPayloadException('Missing message.');
  }

  final threadId = request.threadId?.trim();
  final attachments = request.images
      .map((image) => image.toProductionAttachment())
      .toList(growable: false);
  final normalizedIdempotencyKey = idempotencyKey?.trim();

  return {
    if (threadId != null && threadId.isNotEmpty && _looksLikeUuid(threadId))
      'thread_id': threadId,
    'message': text,
    if (attachments.isNotEmpty) 'attachments': attachments,
    'runtime_pattern': 'langgraph_sdk',
    if (normalizedIdempotencyKey != null && normalizedIdempotencyKey.isNotEmpty)
      'idempotency_key': normalizedIdempotencyKey,
  };
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
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
        if (event.isTerminal) return;
      }
    }
  }
}

class SseAgentStreamClient extends TransportAgnosticAgentStreamClient {
  const SseAgentStreamClient(AgentStreamTransport transport)
    : super(transport: transport, decodeFrame: parseAgentEventStream);
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
