import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/transport_security_policy.dart';
import '../privacy/log_redactor.dart';
import 'agent_stream_client.dart';
import 'agent_stream_event.dart';

typedef AgentStreamPayloadFactory =
    Map<String, Object?> Function(AgentStreamRequest request);

class AgentStreamEndpoint {
  AgentStreamEndpoint({
    required Uri uri,
    this.token,
    this.headers = const <String, String>{},
  }) : uri = TransportSecurityPolicy.requireSecureHttpOrWebSocket(uri);

  final Uri uri;
  final String? token;
  final Map<String, String> headers;

  Uri get requestUri => uri;

  @Deprecated('Use requestUri. Tokens are sent in headers, never URLs.')
  Uri get uriWithToken => requestUri;

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
    'url': requestUri.toString(),
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
    this.reason,
  });

  final String threadId;
  final String? runId;
  final String? reason;

  Map<String, Object?> toMap() {
    final normalizedRunId = runId?.trim();
    if (normalizedRunId == null || normalizedRunId.isEmpty) {
      throw const AgentStreamPayloadException('Missing runId.');
    }

    final normalizedReason = reason?.trim();
    return {
      if (normalizedReason != null && normalizedReason.isNotEmpty)
        'reason': normalizedReason,
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

class AgentStreamActionConfirmRequest {
  const AgentStreamActionConfirmRequest({
    required this.actionId,
    this.editedApplyPayload,
    this.idempotencyKey,
  });

  final String actionId;
  final Map<String, Object?>? editedApplyPayload;
  final String? idempotencyKey;

  Map<String, Object?> toMap() {
    final normalizedActionId = actionId.trim();
    if (normalizedActionId.isEmpty) {
      throw const AgentStreamPayloadException('Missing actionId.');
    }

    final normalizedIdempotencyKey = idempotencyKey?.trim();
    return {
      if (editedApplyPayload != null)
        'edited_apply_payload': editedApplyPayload,
      if (normalizedIdempotencyKey != null &&
          normalizedIdempotencyKey.isNotEmpty)
        'idempotency_key': normalizedIdempotencyKey,
    };
  }
}

class AgentStreamActionRejectRequest {
  const AgentStreamActionRejectRequest({required this.actionId, this.reason});

  final String actionId;
  final String? reason;

  Map<String, Object?> toMap() {
    final normalizedActionId = actionId.trim();
    if (normalizedActionId.isEmpty) {
      throw const AgentStreamPayloadException('Missing actionId.');
    }

    final normalizedReason = reason?.trim();
    return {
      if (normalizedReason != null && normalizedReason.isNotEmpty)
        'reason': normalizedReason,
    };
  }
}

class AgentStreamActionResult {
  const AgentStreamActionResult({
    required this.accepted,
    this.statusCode,
    this.body,
    this.error,
  });

  final bool accepted;
  final int? statusCode;
  final Map<String, Object?>? body;
  final Object? error;

  String? get actionStatus {
    final rawStatus = body?['status'];
    return rawStatus is String ? rawStatus : null;
  }
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
      final runId = request.runId?.trim();
      if (runId == null || runId.isEmpty) {
        throw const AgentStreamPayloadException('Missing runId.');
      }
      final response = await connector.post(
        _runScopedUri(endpoint.requestUri, runId, 'cancel'),
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

class AgentStreamActionClient {
  const AgentStreamActionClient({
    required this.endpoint,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamActionResult> confirm(
    AgentStreamActionConfirmRequest request,
  ) {
    final idempotencyKey =
        request.idempotencyKey?.trim().isNotEmpty == true
        ? request.idempotencyKey!.trim()
        : 'agent-action-${request.actionId.trim()}';
    return _postAction(
      actionId: request.actionId,
      suffix: 'confirm',
      body: request.toMap(),
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
  }

  Future<AgentStreamActionResult> reject(
    AgentStreamActionRejectRequest request,
  ) {
    return _postAction(
      actionId: request.actionId,
      suffix: 'reject',
      body: request.toMap(),
    );
  }

  Future<AgentStreamActionResult> _postAction({
    required String actionId,
    required String suffix,
    required Map<String, Object?> body,
    Map<String, String> extraHeaders = const {},
  }) async {
    try {
      final normalizedActionId = actionId.trim();
      if (normalizedActionId.isEmpty) {
        throw const AgentStreamPayloadException('Missing actionId.');
      }
      final response = await connector.post(
        _actionScopedUri(endpoint.requestUri, normalizedActionId, suffix),
        headers: {
          ...endpoint.requestHeaders(includeContentType: true),
          ...extraHeaders,
        },
        body: jsonEncode(body),
      );
      final accepted = response.statusCode >= 200 && response.statusCode < 300;
      return AgentStreamActionResult(
        accepted: accepted,
        statusCode: response.statusCode,
        body: response.jsonBody,
      );
    } catch (error) {
      return AgentStreamActionResult(accepted: false, error: error);
    }
  }
}

Uri _runScopedUri(Uri runsUri, String runId, String suffix) {
  final basePath = runsUri.path.endsWith('/')
      ? runsUri.path.substring(0, runsUri.path.length - 1)
      : runsUri.path;
  return runsUri.replace(
    path: '$basePath/$runId/$suffix',
    queryParameters: null,
  );
}

Uri _actionScopedUri(Uri actionsUri, String actionId, String suffix) {
  final basePath = actionsUri.path.endsWith('/')
      ? actionsUri.path.substring(0, actionsUri.path.length - 1)
      : actionsUri.path;
  return actionsUri.replace(
    path: '$basePath/$actionId/$suffix',
    queryParameters: null,
  );
}

class AgentStreamClientEventRequest {
  const AgentStreamClientEventRequest({
    required this.eventType,
    required this.occurredAt,
    this.label,
    this.locale,
    this.timezone,
    this.metadata = const <String, Object?>{},
  });

  final String eventType;
  final String occurredAt;
  final String? label;
  final String? locale;
  final String? timezone;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    final normalizedEventType = eventType.trim();
    final normalizedOccurredAt = occurredAt.trim();
    if (normalizedEventType.isEmpty) {
      throw const AgentStreamPayloadException('Missing eventType.');
    }
    if (normalizedOccurredAt.isEmpty) {
      throw const AgentStreamPayloadException('Missing occurredAt.');
    }

    return {
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
    this.body,
    this.error,
  });

  final bool sent;
  final Map<String, Object?>? body;
  final Object? error;
}

typedef AgentStreamClientEventRecorder =
    void Function(Map<String, Object?> event);

class AgentStreamClientEventClient {
  const AgentStreamClientEventClient({
    this.recorder,
    this.sent = true,
    this.error,
  });

  final AgentStreamClientEventRecorder? recorder;
  final bool sent;
  final Object? error;

  Future<AgentStreamClientEventResult> post(
    AgentStreamClientEventRequest event,
  ) async {
    try {
      final body = event.toMap();
      if (!sent) {
        return AgentStreamClientEventResult(
          sent: false,
          body: body,
          error: error,
        );
      }
      recorder?.call(body);
      return AgentStreamClientEventResult(
        sent: true,
        body: body,
      );
    } catch (error) {
      return AgentStreamClientEventResult(sent: false, error: error);
    }
  }
}

abstract interface class AgentStreamSseGetConnector {
  Stream<String> get(Uri uri, {required Map<String, String> headers});
}

class IoAgentStreamSseGetConnector implements AgentStreamSseGetConnector {
  IoAgentStreamSseGetConnector({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) async* {
    final request = await _httpClient.getUrl(uri);
    headers.forEach(request.headers.set);

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentStreamTransportException(
        'SSE request failed: ${response.statusCode}',
      );
    }

    yield* _decodeSseBlocks(response.transform(utf8.decoder));
  }
}

Stream<String> _decodeSseBlocks(Stream<String> chunks) async* {
  var buffer = '';
  await for (final chunk in chunks) {
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

class ProductionAgentSseTransport implements AgentStreamTransport {
  const ProductionAgentSseTransport({
    required this.runsEndpoint,
    required this.payloadFactory,
    this.runConnector = const _DefaultControlHttpConnector(),
    this.streamConnector = const _DefaultSseGetConnector(),
  });

  final AgentStreamEndpoint runsEndpoint;
  final AgentStreamPayloadFactory payloadFactory;
  final AgentStreamControlHttpConnector runConnector;
  final AgentStreamSseGetConnector streamConnector;

  @override
  Stream<String> frames(AgentStreamRequest request) async* {
    final existingRunId = request.runId?.trim();
    final runId = existingRunId != null && existingRunId.isNotEmpty
        ? existingRunId
        : await _createRun(request);
    final afterSequence = request.afterSequence < 0 ? 0 : request.afterSequence;

    final streamUri = _runScopedUri(
      runsEndpoint.requestUri,
      runId,
      'stream',
    ).replace(
      queryParameters: {
        'after_sequence': afterSequence.toString(),
        'follow': 'true',
        'limit': '200',
      },
    );

    yield* streamConnector.get(
      streamUri,
      headers: runsEndpoint.requestHeaders(accept: 'text/event-stream'),
    );
  }

  Future<String> _createRun(AgentStreamRequest request) async {
    final payload = Map<String, Object?>.from(payloadFactory(request));
    final idempotencyKey =
        stringField(payload, 'idempotency_key') ?? _agentRunIdempotencyKey();
    payload['idempotency_key'] = idempotencyKey;

    final response = await runConnector.post(
      runsEndpoint.requestUri,
      headers: {
        ...runsEndpoint.requestHeaders(includeContentType: true),
        'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentStreamTransportException(
        'run create failed: ${response.statusCode}',
      );
    }

    final body = response.jsonBody;
    final runId = body == null ? null : stringField(body, 'id');
    if (runId == null || runId.isEmpty) {
      throw const AgentStreamTransportException(
        'run create response must include id',
      );
    }
    return runId;
  }
}

String _agentRunIdempotencyKey() {
  return 'agent-run-${DateTime.now().microsecondsSinceEpoch}';
}

class _DefaultSseGetConnector implements AgentStreamSseGetConnector {
  const _DefaultSseGetConnector();

  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) {
    return IoAgentStreamSseGetConnector().get(uri, headers: headers);
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
