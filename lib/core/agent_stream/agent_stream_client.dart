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
    this.idempotencyKey,
  });

  final String message;
  final String? threadId;
  final String? runId;
  final int afterSequence;
  final String locale;
  final List<AgentStreamImageInput> images;
  final Map<String, Object?> metadata;
  final String? idempotencyKey;

  Map<String, Object?> toMap() => {
    'message': message,
    if (threadId != null) 'threadId': threadId,
    if (locale.trim().isNotEmpty) 'locale': locale,
    if (images.isNotEmpty)
      'images': images.map((image) => image.toMap()).toList(growable: false),
    if (metadata.isNotEmpty) 'metadata': metadata,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
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
      idempotencyKey: idempotencyKey,
    );
  }
}

class AgentStreamImageInput {
  const AgentStreamImageInput({
    required this.dataUrl,
    this.fileId = '',
    this.mimeType = 'image/png',
    this.name = 'image.png',
    this.size = 0,
    this.detail = 'auto',
  });

  final String dataUrl;
  final String fileId;
  final String mimeType;
  final String name;
  final int size;
  final String detail;

  Map<String, Object?> toMap() => {
    'dataUrl': dataUrl,
    if (fileId.trim().isNotEmpty) 'fileId': fileId.trim(),
    'mimeType': mimeType,
    'name': name,
    'size': size,
    'detail': detail,
  };

  Map<String, Object?> toProductionAttachment() {
    final normalizedFileId = fileId.trim();
    return {
      'type': 'image',
      if (normalizedFileId.isNotEmpty)
        'file_id': normalizedFileId
      else
        'data_url': dataUrl,
      'mime_type': mimeType.trim().isEmpty ? 'image/png' : mimeType,
      'name': name.trim().isEmpty ? 'image.png' : name,
      'size': size,
      'detail': detail.trim().isEmpty ? 'auto' : detail,
    };
  }

  AgentStreamImageInput copyWith({
    String? dataUrl,
    String? fileId,
    String? mimeType,
    String? name,
    int? size,
    String? detail,
  }) {
    return AgentStreamImageInput(
      dataUrl: dataUrl ?? this.dataUrl,
      fileId: fileId ?? this.fileId,
      mimeType: mimeType ?? this.mimeType,
      name: name ?? this.name,
      size: size ?? this.size,
      detail: detail ?? this.detail,
    );
  }
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
      .toList(growable: true);
  final formSubmission = _productionFormSubmissionAttachment(request.metadata);
  if (formSubmission != null) attachments.add(formSubmission);
  final normalizedIdempotencyKey = (idempotencyKey ?? request.idempotencyKey)
      ?.trim();
  final normalizedLocale = request.locale.trim();
  final clientContext = <String, Object?>{
    ...request.metadata,
    if (normalizedLocale.isNotEmpty) 'locale': normalizedLocale,
  }..remove('form_submission');

  return {
    if (threadId != null && threadId.isNotEmpty && _looksLikeUuid(threadId))
      'thread_id': threadId,
    'message': text,
    if (attachments.isNotEmpty) 'attachments': attachments,
    if (clientContext.isNotEmpty) 'client_context': clientContext,
    'runtime_pattern': 'sdk_only',
    if (normalizedIdempotencyKey != null && normalizedIdempotencyKey.isNotEmpty)
      'idempotency_key': normalizedIdempotencyKey,
  };
}

Map<String, Object?>? _productionFormSubmissionAttachment(
  Map<String, Object?> metadata,
) {
  final rawSubmission = metadata['form_submission'];
  if (rawSubmission == null) return null;
  if (rawSubmission is! Map) {
    throw const AgentStreamPayloadException('Invalid form submission.');
  }
  final submission = Map<String, Object?>.from(rawSubmission);
  final artifactId = submission['artifact_id']?.toString().trim() ?? '';
  final formId = submission['form_id']?.toString().trim() ?? '';
  final values = submission['values'];
  if (artifactId.isEmpty || formId.isEmpty || values is! Map) {
    throw const AgentStreamPayloadException('Invalid form submission.');
  }
  return {
    'type': 'form_submission',
    'artifact_id': artifactId,
    'form_id': formId,
    'values': Map<String, Object?>.from(values),
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

abstract interface class AgentStreamRetryableFailure {
  bool get isRetryable;
}

enum AgentRunLifecycleStatus {
  queued,
  running,
  waitingForConfirmation,
  completed,
  failed,
  cancelled,
  unknown;

  bool get isActive => this == queued || this == running;

  bool get isTerminal => switch (this) {
    waitingForConfirmation || completed || failed || cancelled => true,
    _ => false,
  };
}

class AgentRunStatusSnapshot {
  const AgentRunStatusSnapshot({
    required this.runId,
    required this.status,
    this.threadId,
    this.errorCode,
  });

  final String runId;
  final String? threadId;
  final AgentRunLifecycleStatus status;
  final String? errorCode;

  AgentStreamEvent? terminalEvent() {
    final eventType = switch (status) {
      AgentRunLifecycleStatus.waitingForConfirmation =>
        'run.waiting_for_confirmation',
      AgentRunLifecycleStatus.completed => 'run.completed',
      AgentRunLifecycleStatus.failed => 'run.failed',
      AgentRunLifecycleStatus.cancelled => 'run.cancelled',
      _ => null,
    };
    if (eventType == null) return null;

    return AgentStreamEvent({
      'event_id': 'run-status:$runId:${status.name}',
      'type': eventType,
      'run_id': runId,
      if (threadId?.trim().isNotEmpty ?? false) 'thread_id': threadId,
      'payload': {
        'reconciled_from_run_status': true,
        if (errorCode?.trim().isNotEmpty ?? false) 'code': errorCode,
      },
    });
  }
}

abstract interface class AgentRunStatusReader {
  Future<AgentRunStatusSnapshot> read(String runId);
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
