import 'dart:typed_data';

import 'agent_stream_event.dart';

class AgentStreamRequest {
  const AgentStreamRequest({
    required this.message,
    this.threadId,
    this.runId,
    this.afterSequence = 0,
    this.afterTransientCursor,
    this.locale = 'en-US',
    this.timezone,
    this.messageSentAt,
    this.images = const <AgentStreamImageInput>[],
    this.files = const <AgentStreamFileInput>[],
    this.metadata = const <String, Object?>{},
    this.idempotencyKey,
  });

  final String message;
  final String? threadId;
  final String? runId;
  final int afterSequence;
  final String? afterTransientCursor;
  final String locale;
  final String? timezone;
  final String? messageSentAt;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
  final Map<String, Object?> metadata;
  final String? idempotencyKey;

  Map<String, Object?> toMap() => {
    'message': message,
    if (threadId != null) 'threadId': threadId,
    if (locale.trim().isNotEmpty) 'locale': locale,
    if (timezone?.trim().isNotEmpty ?? false) 'timezone': timezone,
    if (messageSentAt?.trim().isNotEmpty ?? false)
      'messageSentAt': messageSentAt,
    if (images.isNotEmpty)
      'images': images.map((image) => image.toMap()).toList(growable: false),
    if (files.isNotEmpty)
      'files': files.map((file) => file.toMap()).toList(growable: false),
    if (metadata.isNotEmpty) 'metadata': metadata,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
  };

  AgentStreamRequest resume({
    required String runId,
    required int afterSequence,
    String? afterTransientCursor,
    String? threadId,
  }) {
    return AgentStreamRequest(
      message: message,
      threadId: threadId ?? this.threadId,
      runId: runId,
      afterSequence: afterSequence < 0 ? 0 : afterSequence,
      afterTransientCursor: afterTransientCursor ?? this.afterTransientCursor,
      locale: locale,
      timezone: timezone,
      messageSentAt: messageSentAt,
      images: images,
      files: files,
      metadata: metadata,
      idempotencyKey: idempotencyKey,
    );
  }

  AgentStreamRequest withRunCreateContext(AgentRunCreateContext context) {
    return AgentStreamRequest(
      message: message,
      threadId: threadId,
      runId: runId,
      afterSequence: afterSequence,
      afterTransientCursor: afterTransientCursor,
      locale: locale,
      timezone: context.timezone,
      messageSentAt: context.messageSentAt,
      images: images,
      files: files,
      metadata: metadata,
      idempotencyKey: idempotencyKey,
    );
  }
}

class AgentRunCreateContext {
  const AgentRunCreateContext({
    required this.timezone,
    required this.messageSentAt,
  });

  final String timezone;
  final String messageSentAt;
}

class AgentStreamFileInput {
  const AgentStreamFileInput({
    required this.fileId,
    this.mimeType = 'application/pdf',
    this.name = 'document.pdf',
    this.size = 0,
  });

  final String fileId;
  final String mimeType;
  final String name;
  final int size;

  Map<String, Object?> toMap() => {
    'fileId': fileId,
    'mimeType': mimeType,
    'name': name,
    'size': size,
  };

  Map<String, Object?> toProductionAttachment() {
    final normalizedFileId = fileId.trim();
    if (normalizedFileId.isEmpty) {
      throw const AgentStreamPayloadException(
        'File upload must complete before sending.',
      );
    }
    return {'type': 'file', 'file_id': normalizedFileId};
  }

  @override
  bool operator ==(Object other) {
    return other is AgentStreamFileInput &&
        other.fileId == fileId &&
        other.mimeType == mimeType &&
        other.name == name &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(fileId, mimeType, name, size);
}

class AgentStreamImageInput {
  const AgentStreamImageInput({
    required this.dataUrl,
    this.assetId = '',
    this.fileId = '',
    this.mimeType = 'image/png',
    this.name = 'image.png',
    this.size = 0,
    this.detail = 'auto',
    this.localBytes,
    this.openRead,
  });

  final String dataUrl;
  final String assetId;
  final String fileId;
  final String mimeType;
  final String name;
  final int size;
  final String detail;
  final Uint8List? localBytes;
  final Stream<List<int>> Function()? openRead;

  Map<String, Object?> toMap() => {
    'dataUrl': dataUrl,
    if (assetId.trim().isNotEmpty) 'assetId': assetId.trim(),
    if (fileId.trim().isNotEmpty) 'fileId': fileId.trim(),
    'mimeType': mimeType,
    'name': name,
    'size': size,
    'detail': detail,
  };

  Map<String, Object?> toProductionAttachment() {
    final normalizedAssetId = assetId.trim().isNotEmpty
        ? assetId.trim()
        : fileId.trim();
    if (normalizedAssetId.isEmpty) {
      throw const AgentStreamPayloadException(
        'Image upload must complete before sending.',
      );
    }
    return {
      'type': 'image',
      'asset_id': normalizedAssetId,
      'detail': detail.trim().isEmpty ? 'auto' : detail,
    };
  }

  AgentStreamImageInput copyWith({
    String? dataUrl,
    String? assetId,
    String? fileId,
    String? mimeType,
    String? name,
    int? size,
    String? detail,
    Uint8List? localBytes,
    Stream<List<int>> Function()? openRead,
  }) {
    return AgentStreamImageInput(
      dataUrl: dataUrl ?? this.dataUrl,
      assetId: assetId ?? this.assetId,
      fileId: fileId ?? this.fileId,
      mimeType: mimeType ?? this.mimeType,
      name: name ?? this.name,
      size: size ?? this.size,
      detail: detail ?? this.detail,
      localBytes: localBytes ?? this.localBytes,
      openRead: openRead ?? this.openRead,
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
  attachments.addAll(
    request.files.map((file) => file.toProductionAttachment()),
  );
  final formSubmission = _productionFormSubmissionAttachment(request.metadata);
  if (formSubmission != null) attachments.add(formSubmission);
  final normalizedIdempotencyKey = (idempotencyKey ?? request.idempotencyKey)
      ?.trim();
  final normalizedLocale = request.locale.trim();
  final normalizedSource = _productionClientContextString(
    request.metadata['source'],
  );
  final normalizedTimezone = request.timezone?.trim();
  final normalizedMessageSentAt = request.messageSentAt?.trim();
  final clientContext = <String, Object?>{
    if (normalizedLocale.isNotEmpty) 'locale': normalizedLocale,
    if (normalizedTimezone != null && normalizedTimezone.isNotEmpty)
      'timezone': normalizedTimezone,
    if (normalizedMessageSentAt != null && normalizedMessageSentAt.isNotEmpty)
      'message_sent_at': normalizedMessageSentAt,
  };
  if (normalizedSource != null) clientContext['source'] = normalizedSource;

  return {
    if (threadId != null && threadId.isNotEmpty && _looksLikeUuid(threadId))
      'thread_id': threadId,
    'message': text,
    if (attachments.isNotEmpty) 'attachments': attachments,
    if (clientContext.isNotEmpty) 'client_context': clientContext,
    'runtime_pattern': 'proprietary_runtime',
    if (normalizedIdempotencyKey != null && normalizedIdempotencyKey.isNotEmpty)
      'idempotency_key': normalizedIdempotencyKey,
  };
}

String? _productionClientContextString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
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
  expired,
  unknown;

  bool get isActive => this == queued || this == running;

  bool get isTerminal => switch (this) {
    waitingForConfirmation ||
    completed ||
    failed ||
    cancelled ||
    expired => true,
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
      AgentRunLifecycleStatus.expired => 'run.expired',
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
