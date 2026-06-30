import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/api_envelope.dart';
import '../privacy/log_redactor.dart';
import 'agent_stream_client.dart';
import 'agent_stream_event.dart';

typedef AgentStreamPayloadFactory =
    Map<String, Object?> Function(AgentStreamRequest request);

const agentStreamPrewarmMessage =
    '这是一次隐藏的新会话预热。请只回复“我在。”，不要调用工具，不要生成建议、表单、卡片或面向用户的内容。下一条用户消息才是真实对话。';

class AgentStreamEndpoint {
  const AgentStreamEndpoint({
    required this.uri,
    this.token,
    this.headers = const <String, String>{},
  });

  final Uri uri;
  final String? token;
  final Map<String, String> headers;

  Uri get uriWithToken {
    final authToken = token?.trim();
    if (authToken == null || authToken.isEmpty) return uri;
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'token': authToken,
      },
    );
  }

  Map<String, String> requestHeaders({
    String accept = 'application/json',
    bool includeContentType = false,
  }) {
    final authToken = token?.trim();
    return <String, String>{
      ...headers,
      'Accept': accept,
      if (includeContentType) 'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Map<String, Object?> redactedLogContext() => redactLogMap({
    'url': uriWithToken.toString(),
    'headers': requestHeaders(includeContentType: true),
  });
}

class AgentStreamTransportException implements Exception {
  const AgentStreamTransportException(this.message);

  final String message;

  @override
  String toString() => 'AgentStreamTransportException($message)';
}

class AgentStreamCancelRequest {
  const AgentStreamCancelRequest({
    required this.threadId,
    this.runId,
    this.userId,
  });

  final String threadId;
  final String? runId;
  final String? userId;

  Map<String, Object?> toMap() {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw const AgentStreamPayloadException('Missing threadId.');
    }

    final normalizedRunId = runId?.trim();
    final normalizedUserId = userId?.trim();
    return {
      'threadId': normalizedThreadId,
      if (normalizedRunId != null && normalizedRunId.isNotEmpty)
        'runId': normalizedRunId,
      if (normalizedUserId != null && normalizedUserId.isNotEmpty)
        'user_id': normalizedUserId,
    };
  }
}

class AgentStreamControlHttpResponse {
  const AgentStreamControlHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  Map<String, Object?>? get jsonBody => _decodeJsonObject(body);
}

class AgentStreamCancelResult {
  const AgentStreamCancelResult({
    required this.acknowledged,
    this.statusCode,
    this.body,
    this.error,
  });

  final bool acknowledged;
  final int? statusCode;
  final Map<String, Object?>? body;
  final Object? error;
}

abstract interface class AgentStreamControlHttpConnector {
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
}

class IoAgentStreamControlHttpConnector
    implements AgentStreamControlHttpConnector {
  IoAgentStreamControlHttpConnector({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final request = await _httpClient.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return AgentStreamControlHttpResponse(
      statusCode: response.statusCode,
      body: responseBody,
    );
  }
}

class AgentStreamCancelClient {
  const AgentStreamCancelClient({
    required this.endpoint,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamCancelResult> cancel(
    AgentStreamCancelRequest request,
  ) async {
    try {
      final response = await connector.post(
        endpoint.uriWithToken,
        headers: endpoint.requestHeaders(includeContentType: true),
        body: jsonEncode(request.toMap()),
      );
      final acknowledged =
          (response.statusCode >= 200 && response.statusCode < 300) ||
          response.statusCode == 404;
      return AgentStreamCancelResult(
        acknowledged: acknowledged,
        statusCode: response.statusCode,
        body: response.jsonBody,
      );
    } catch (error) {
      return AgentStreamCancelResult(acknowledged: false, error: error);
    }
  }
}

class AgentStreamPrewarmResult {
  const AgentStreamPrewarmResult({
    required this.status,
    required this.raw,
    this.threadId,
    this.runId,
    this.responseId,
    this.sessionState,
  });

  final String status;
  final Map<String, Object?> raw;
  final String? threadId;
  final String? runId;
  final String? responseId;
  final Object? sessionState;

  factory AgentStreamPrewarmResult.fromMap(Map<String, Object?> map) {
    return AgentStreamPrewarmResult(
      status: stringField(map, 'status') ?? '',
      raw: map,
      threadId: aliasString(map, 'thread_id', 'threadId'),
      runId: aliasString(map, 'run_id', 'runId'),
      responseId: aliasString(map, 'response_id', 'responseId'),
      sessionState: map['session_state'] ?? map['sessionState'],
    );
  }
}

class AgentStreamPrewarmClient {
  const AgentStreamPrewarmClient({
    required this.endpoint,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamPrewarmResult> prewarm({
    required String userId,
    required String threadId,
    required String runId,
    required String messageId,
    String locale = 'en-US',
    Map<String, Object?> forwardedProps = const <String, Object?>{},
  }) async {
    final payload = buildAgentRunPayload(
      AgentStreamRequest(
        userId: userId,
        message: agentStreamPrewarmMessage,
        threadId: threadId,
        locale: locale,
        metadata: {...forwardedProps, 'prewarm': true},
      ),
      runId: runId,
      messageId: messageId,
    );
    final response = await connector.post(
      endpoint.uriWithToken,
      headers: endpoint.requestHeaders(includeContentType: true),
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentStreamTransportException(
        'prewarm failed: ${response.statusCode}',
      );
    }

    final body = response.jsonBody;
    if (body == null) {
      throw const AgentStreamTransportException(
        'prewarm response must be a JSON object',
      );
    }

    final Object? data = isApiEnvelope(body) ? unwrapApiEnvelope(body) : body;
    if (data is! Map) {
      throw const AgentStreamTransportException(
        'prewarm response data must be a JSON object',
      );
    }

    return AgentStreamPrewarmResult.fromMap(Map<String, Object?>.from(data));
  }
}

class AgentStreamTimingLogEntry {
  const AgentStreamTimingLogEntry({
    required this.stage,
    this.source,
    this.runId,
    this.threadId,
    this.clientTimingId,
    this.userId,
    this.elapsedMs,
    this.clientTsMs,
    this.metadata = const <String, Object?>{},
  });

  final String stage;
  final String? source;
  final String? runId;
  final String? threadId;
  final String? clientTimingId;
  final String? userId;
  final int? elapsedMs;
  final int? clientTsMs;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    final normalizedStage = stage.trim();
    if (normalizedStage.isEmpty) {
      throw const AgentStreamPayloadException('Missing timing stage.');
    }

    return {
      if (source?.trim().isNotEmpty ?? false) 'source': source!.trim(),
      'stage': normalizedStage,
      if (runId?.trim().isNotEmpty ?? false) 'run_id': runId!.trim(),
      if (threadId?.trim().isNotEmpty ?? false) 'thread_id': threadId!.trim(),
      if (clientTimingId?.trim().isNotEmpty ?? false)
        'client_timing_id': clientTimingId!.trim(),
      if (userId?.trim().isNotEmpty ?? false) 'user_id': userId!.trim(),
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (clientTsMs != null) 'client_ts_ms': clientTsMs,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class AgentStreamTimingLogResult {
  const AgentStreamTimingLogResult({
    required this.sent,
    this.statusCode,
    this.error,
  });

  final bool sent;
  final int? statusCode;
  final Object? error;
}

class AgentStreamTimingLogClient {
  const AgentStreamTimingLogClient({
    required this.endpoint,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamTimingLogResult> post(
    AgentStreamTimingLogEntry entry,
  ) async {
    try {
      final response = await connector.post(
        endpoint.uriWithToken,
        headers: endpoint.requestHeaders(includeContentType: true),
        body: jsonEncode(entry.toMap()),
      );
      return AgentStreamTimingLogResult(
        sent: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
      );
    } catch (error) {
      return AgentStreamTimingLogResult(sent: false, error: error);
    }
  }
}

class AgentStreamClientEventRequest {
  const AgentStreamClientEventRequest({
    required this.threadId,
    required this.userId,
    required this.eventType,
    required this.occurredAt,
    this.label,
    this.locale,
    this.timezone,
    this.metadata = const <String, Object?>{},
  });

  final String threadId;
  final String userId;
  final String eventType;
  final String occurredAt;
  final String? label;
  final String? locale;
  final String? timezone;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    final normalizedThreadId = threadId.trim();
    final normalizedUserId = userId.trim();
    final normalizedEventType = eventType.trim();
    final normalizedOccurredAt = occurredAt.trim();
    if (normalizedThreadId.isEmpty) {
      throw const AgentStreamPayloadException('Missing threadId.');
    }
    if (normalizedUserId.isEmpty) {
      throw const AgentStreamPayloadException('Missing userId.');
    }
    if (normalizedEventType.isEmpty) {
      throw const AgentStreamPayloadException('Missing eventType.');
    }
    if (normalizedOccurredAt.isEmpty) {
      throw const AgentStreamPayloadException('Missing occurredAt.');
    }

    return {
      'thread_id': normalizedThreadId,
      'user_id': normalizedUserId,
      'event_type': normalizedEventType,
      if (label?.trim().isNotEmpty ?? false) 'label': label!.trim(),
      'occurred_at': normalizedOccurredAt,
      if (locale?.trim().isNotEmpty ?? false) 'locale': locale!.trim(),
      if (timezone?.trim().isNotEmpty ?? false) 'timezone': timezone!.trim(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class AgentStreamClientEventResult {
  const AgentStreamClientEventResult({
    required this.sent,
    this.statusCode,
    this.body,
    this.error,
  });

  final bool sent;
  final int? statusCode;
  final Map<String, Object?>? body;
  final Object? error;
}

class AgentStreamClientEventClient {
  const AgentStreamClientEventClient({
    required this.endpoint,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamClientEventResult> post(
    AgentStreamClientEventRequest event,
  ) async {
    try {
      final response = await connector.post(
        endpoint.uriWithToken,
        headers: endpoint.requestHeaders(includeContentType: true),
        body: jsonEncode(event.toMap()),
      );
      return AgentStreamClientEventResult(
        sent: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.jsonBody,
      );
    } catch (error) {
      return AgentStreamClientEventResult(sent: false, error: error);
    }
  }
}

abstract interface class AgentStreamSseConnector {
  Stream<String> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
}

class IoAgentStreamSseConnector implements AgentStreamSseConnector {
  IoAgentStreamSseConnector({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Stream<String> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async* {
    final request = await _httpClient.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentStreamTransportException(
        'SSE request failed: ${response.statusCode}',
      );
    }

    var buffer = '';
    await for (final chunk in response.transform(utf8.decoder)) {
      buffer += chunk;
      final blocks = buffer.split(RegExp(r'\r?\n\r?\n'));
      buffer = blocks.removeLast();
      for (final block in blocks) {
        final trimmed = block.trim();
        if (trimmed.isNotEmpty) yield '$trimmed\n\n';
      }
    }

    if (buffer.trim().isNotEmpty) yield buffer;
  }
}

class AgentSseHttpTransport implements AgentStreamTransport {
  const AgentSseHttpTransport({
    required this.endpoint,
    required this.payloadFactory,
    this.connector = const _DefaultSseConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamPayloadFactory payloadFactory;
  final AgentStreamSseConnector connector;

  @override
  Stream<String> frames(AgentStreamRequest request) {
    return connector.post(
      endpoint.uriWithToken,
      headers: endpoint.requestHeaders(
        accept: 'text/event-stream',
        includeContentType: true,
      ),
      body: jsonEncode(payloadFactory(request)),
    );
  }
}

abstract interface class AgentStreamWebSocketConnection {
  Stream<String> get frames;

  void send(String text);

  Future<void> close();
}

abstract interface class AgentStreamWebSocketConnector {
  Future<AgentStreamWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  });
}

class IoAgentStreamWebSocketConnector implements AgentStreamWebSocketConnector {
  const IoAgentStreamWebSocketConnector();

  @override
  Future<AgentStreamWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final socket = await WebSocket.connect(uri.toString(), headers: headers);
    return _IoAgentStreamWebSocketConnection(socket);
  }
}

class AgentWebSocketTransport implements AgentStreamTransport {
  const AgentWebSocketTransport({
    required this.endpoint,
    required this.payloadFactory,
    this.connector = const IoAgentStreamWebSocketConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamPayloadFactory payloadFactory;
  final AgentStreamWebSocketConnector connector;

  @override
  Stream<String> frames(AgentStreamRequest request) async* {
    final socket = await connector.connect(
      endpoint.uriWithToken,
      headers: endpoint.requestHeaders(),
    );

    try {
      socket.send(jsonEncode(payloadFactory(request)));
      await for (final frame in socket.frames) {
        yield frame;
      }
    } finally {
      await socket.close();
    }
  }
}

class _IoAgentStreamWebSocketConnection
    implements AgentStreamWebSocketConnection {
  const _IoAgentStreamWebSocketConnection(this.socket);

  final WebSocket socket;

  @override
  Stream<String> get frames =>
      socket.where((event) => event is String).cast<String>();

  @override
  void send(String text) => socket.add(text);

  @override
  Future<void> close() => socket.close();
}

class _DefaultSseConnector implements AgentStreamSseConnector {
  const _DefaultSseConnector();

  @override
  Stream<String> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return IoAgentStreamSseConnector().post(uri, headers: headers, body: body);
  }
}

class _DefaultControlHttpConnector implements AgentStreamControlHttpConnector {
  const _DefaultControlHttpConnector();

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return IoAgentStreamControlHttpConnector().post(
      uri,
      headers: headers,
      body: body,
    );
  }
}

Map<String, Object?>? _decodeJsonObject(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
  } catch (_) {
    return null;
  }

  return null;
}
