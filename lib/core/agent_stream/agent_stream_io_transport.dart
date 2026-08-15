import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/transport_security_policy.dart';
import '../privacy/log_redactor.dart';
import 'agent_run_create_context.dart';
import 'agent_stream_client.dart';
import 'agent_stream_event.dart';

const _agentStreamFollowPollIntervalSeconds = '0.01';

typedef AgentStreamPayloadFactory =
    Map<String, Object?> Function(AgentStreamRequest request);
typedef AgentStreamUnauthorizedHandler = FutureOr<bool> Function();

class AgentStreamEndpoint {
  AgentStreamEndpoint({
    required Uri uri,
    this.token,
    this.tokenProvider,
    this.headers = const <String, String>{},
  }) : uri = TransportSecurityPolicy.requireSecureHttpOrWebSocket(uri);

  final Uri uri;
  final String? token;
  final String? Function()? tokenProvider;
  final Map<String, String> headers;

  Uri get requestUri => uri;

  @Deprecated('Use requestUri. Tokens are sent in headers, never URLs.')
  Uri get uriWithToken => requestUri;

  Map<String, String> requestHeaders({
    String accept = 'application/json',
    bool includeContentType = false,
  }) {
    final authToken = (tokenProvider?.call() ?? token)?.trim();
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

class AgentStreamTransportException
    implements Exception, AgentStreamRetryableFailure {
  const AgentStreamTransportException(
    this.message, {
    this.statusCode,
    this.isRetryable = false,
    this.cause,
  });

  final String message;
  final int? statusCode;
  @override
  final bool isRetryable;
  final Object? cause;

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

    return {
      if (editedApplyPayload != null)
        'edited_apply_payload': editedApplyPayload,
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

  List<AgentStreamEvent> get events {
    final rawEvents =
        body?['events'] ?? body?['run_events'] ?? body?['stream_events'];
    return _decodeActionEvents(rawEvents);
  }
}

abstract interface class AgentStreamControlHttpConnector {
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    Duration? timeout,
  });
}

abstract interface class AgentStreamControlHttpGetConnector {
  Future<AgentStreamControlHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
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
    Duration? timeout,
  }) {
    HttpClientRequest? activeRequest;
    Future<AgentStreamControlHttpResponse> send() async {
      final request = await _httpClient.postUrl(uri);
      activeRequest = request;
      headers.forEach(request.headers.set);
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return AgentStreamControlHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    }

    final operation = send();
    if (timeout == null) return operation;
    return operation.timeout(
      timeout,
      onTimeout: () {
        final error = TimeoutException('HTTP POST timeout.', timeout);
        activeRequest?.abort(error);
        throw error;
      },
    );
  }
}

class IoAgentStreamControlHttpGetConnector
    implements AgentStreamControlHttpGetConnector {
  IoAgentStreamControlHttpGetConnector({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<AgentStreamControlHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final request = await _httpClient.getUrl(uri);
    headers.forEach(request.headers.set);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return AgentStreamControlHttpResponse(
      statusCode: response.statusCode,
      body: responseBody,
    );
  }
}

class ProductionAgentRunStatusReader implements AgentRunStatusReader {
  const ProductionAgentRunStatusReader({
    required this.runsEndpoint,
    this.onUnauthorized,
    this.connector = const _DefaultControlHttpGetConnector(),
  });

  final AgentStreamEndpoint runsEndpoint;
  final AgentStreamUnauthorizedHandler? onUnauthorized;
  final AgentStreamControlHttpGetConnector connector;

  @override
  Future<AgentRunStatusSnapshot> read(String runId) async {
    final normalizedRunId = runId.trim();
    if (normalizedRunId.isEmpty) {
      throw const AgentStreamPayloadException('Missing runId.');
    }

    final uri = _runResourceUri(runsEndpoint.requestUri, normalizedRunId);
    var response = await _get(uri);
    if (response.statusCode == HttpStatus.unauthorized &&
        await _refreshAfterUnauthorized()) {
      response = await _get(uri);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentStreamTransportException(
        'run status request failed: ${response.statusCode}',
        statusCode: response.statusCode,
        isRetryable: _isRetryableHttpStatus(response.statusCode),
      );
    }

    final body = response.jsonBody;
    final responseRunId = body == null ? null : stringField(body, 'id');
    if (body == null || responseRunId == null || responseRunId.isEmpty) {
      throw const AgentStreamTransportException(
        'run status response must include id',
      );
    }
    return AgentRunStatusSnapshot(
      runId: responseRunId,
      threadId: stringField(body, 'thread_id'),
      status: _runLifecycleStatus(stringField(body, 'status')),
      errorCode: stringField(body, 'error_code'),
    );
  }

  Future<AgentStreamControlHttpResponse> _get(Uri uri) {
    return connector.get(uri, headers: runsEndpoint.requestHeaders());
  }

  Future<bool> _refreshAfterUnauthorized() async {
    final handler = onUnauthorized;
    if (handler == null) return false;
    return await handler();
  }
}

class AgentStreamCancelClient {
  const AgentStreamCancelClient({
    required this.endpoint,
    this.onUnauthorized,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamUnauthorizedHandler? onUnauthorized;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamCancelResult> cancel(
    AgentStreamCancelRequest request,
  ) async {
    try {
      final runId = request.runId?.trim();
      if (runId == null || runId.isEmpty) {
        throw const AgentStreamPayloadException('Missing runId.');
      }
      final uri = _runScopedUri(endpoint.requestUri, runId, 'cancel');
      final body = jsonEncode(request.toMap());
      final response = await _postWithSingleUnauthorizedRetry(
        onUnauthorized: onUnauthorized,
        post: () => connector.post(
          uri,
          headers: endpoint.requestHeaders(includeContentType: true),
          body: body,
        ),
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
    this.onUnauthorized,
    this.connector = const _DefaultControlHttpConnector(),
  });

  final AgentStreamEndpoint endpoint;
  final AgentStreamUnauthorizedHandler? onUnauthorized;
  final AgentStreamControlHttpConnector connector;

  Future<AgentStreamActionResult> confirm(
    AgentStreamActionConfirmRequest request,
  ) {
    final idempotencyKey = request.idempotencyKey?.trim().isNotEmpty == true
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
      final uri = _actionScopedUri(
        endpoint.requestUri,
        normalizedActionId,
        suffix,
      );
      final encodedBody = jsonEncode(body);
      final response = await _postWithSingleUnauthorizedRetry(
        onUnauthorized: onUnauthorized,
        post: () => connector.post(
          uri,
          headers: {
            ...endpoint.requestHeaders(includeContentType: true),
            ...extraHeaders,
          },
          body: encodedBody,
        ),
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

Uri _runResourceUri(Uri runsUri, String runId) {
  final basePath = runsUri.path.endsWith('/')
      ? runsUri.path.substring(0, runsUri.path.length - 1)
      : runsUri.path;
  return runsUri.replace(path: '$basePath/$runId', queryParameters: null);
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
    this.runId,
    this.label,
    this.locale,
    this.timezone,
    this.metadata = const <String, Object?>{},
    this.clientSequence,
  });

  final String eventType;
  final String occurredAt;
  final String? runId;
  final String? label;
  final String? locale;
  final String? timezone;
  final Map<String, Object?> metadata;
  final int? clientSequence;

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

  Map<String, Object?> toAgentRunClientEventMap() {
    final localBody = toMap();
    final payload = <String, Object?>{
      if (localBody['label'] is String) 'label': localBody['label'],
      'occurred_at': localBody['occurred_at'],
      if (localBody['locale'] is String) 'locale': localBody['locale'],
      if (localBody['timezone'] is String) 'timezone': localBody['timezone'],
      if (localBody['metadata'] is Map) 'metadata': localBody['metadata'],
    };
    return {
      'type': localBody['event_type'],
      'payload': payload,
      if (clientSequence != null) 'client_sequence': clientSequence,
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
    this.endpoint,
    this.onUnauthorized,
    this.connector = const _DefaultControlHttpConnector(),
    this.recorder,
    this.sent = true,
    this.error,
  });

  final AgentStreamEndpoint? endpoint;
  final AgentStreamUnauthorizedHandler? onUnauthorized;
  final AgentStreamControlHttpConnector connector;
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

      final runId = event.runId?.trim();
      final endpoint = this.endpoint;
      if (endpoint != null && runId != null && runId.isNotEmpty) {
        final uri = _runScopedUri(endpoint.requestUri, runId, 'client-events');
        final encodedBody = jsonEncode(event.toAgentRunClientEventMap());
        final response = await _postWithSingleUnauthorizedRetry(
          onUnauthorized: onUnauthorized,
          post: () => connector.post(
            uri,
            headers: endpoint.requestHeaders(includeContentType: true),
            body: encodedBody,
          ),
        );
        final accepted =
            response.statusCode >= 200 && response.statusCode < 300;
        if (accepted) recorder?.call(body);
        return AgentStreamClientEventResult(
          sent: accepted,
          body: response.jsonBody ?? body,
          error: accepted ? null : response.body,
        );
      }

      recorder?.call(body);
      return AgentStreamClientEventResult(sent: true, body: body);
    } catch (error) {
      return AgentStreamClientEventResult(sent: false, error: error);
    }
  }
}

Future<AgentStreamControlHttpResponse> _postWithSingleUnauthorizedRetry({
  required Future<AgentStreamControlHttpResponse> Function() post,
  AgentStreamUnauthorizedHandler? onUnauthorized,
}) async {
  var response = await post();
  if (response.statusCode == HttpStatus.unauthorized &&
      onUnauthorized != null &&
      await onUnauthorized()) {
    response = await post();
  }
  return response;
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
    try {
      final request = await _httpClient.getUrl(uri);
      headers.forEach(request.headers.set);

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AgentStreamTransportException(
          'SSE request failed: ${response.statusCode}',
          statusCode: response.statusCode,
          isRetryable: _isRetryableHttpStatus(response.statusCode),
        );
      }

      yield* _decodeSseBlocks(response.transform(utf8.decoder));
    } on AgentStreamTransportException {
      rethrow;
    } catch (error) {
      throw AgentStreamTransportException(
        'SSE connection failed.',
        isRetryable: true,
        cause: error,
      );
    }
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
    this.onUnauthorized,
    this.runConnector = const _DefaultControlHttpConnector(),
    this.streamConnector = const _DefaultSseGetConnector(),
    this.runCreateContextProvider,
    this.runCreationTimeout = const Duration(seconds: 15),
    this.streamIdleTimeout = const Duration(seconds: 45),
  });

  final AgentStreamEndpoint runsEndpoint;
  final AgentStreamPayloadFactory payloadFactory;
  final AgentStreamUnauthorizedHandler? onUnauthorized;
  final AgentStreamControlHttpConnector runConnector;
  final AgentStreamSseGetConnector streamConnector;
  final AgentRunCreateContextProvider? runCreateContextProvider;
  final Duration runCreationTimeout;
  final Duration streamIdleTimeout;

  @override
  Stream<String> frames(AgentStreamRequest request) async* {
    final existingRunId = request.runId?.trim();
    final runId = existingRunId != null && existingRunId.isNotEmpty
        ? existingRunId
        : await _createRun(request);
    final afterSequence = request.afterSequence < 0 ? 0 : request.afterSequence;

    final streamUri = _runScopedUri(runsEndpoint.requestUri, runId, 'stream')
        .replace(
          queryParameters: {
            'after_sequence': afterSequence.toString(),
            'follow': 'true',
            'limit': '200',
            'poll_interval_seconds': _agentStreamFollowPollIntervalSeconds,
          },
        );

    try {
      await for (final frame in _streamOnce(streamUri)) {
        yield frame;
      }
    } on AgentStreamTransportException catch (error) {
      if (!_isUnauthorizedStreamError(error) ||
          !await _refreshAfterUnauthorized()) {
        rethrow;
      }
      await for (final frame in _streamOnce(streamUri)) {
        yield frame;
      }
    }
  }

  Stream<String> _streamOnce(Uri streamUri) async* {
    try {
      await for (final frame
          in streamConnector
              .get(
                streamUri,
                headers: runsEndpoint.requestHeaders(
                  accept: 'text/event-stream',
                ),
              )
              .timeout(streamIdleTimeout)) {
        yield frame;
      }
    } on AgentStreamTransportException {
      rethrow;
    } catch (error) {
      throw AgentStreamTransportException(
        'SSE connection failed.',
        isRetryable: true,
        cause: error,
      );
    }
  }

  Future<String> _createRun(AgentStreamRequest request) async {
    try {
      return await _createRunWithinDeadline(
        request,
      ).timeout(runCreationTimeout);
    } on TimeoutException catch (error) {
      throw AgentStreamTransportException(
        'run create timeout.',
        isRetryable: true,
        cause: error,
      );
    }
  }

  Future<String> _createRunWithinDeadline(AgentStreamRequest request) async {
    final runCreateContext =
        await (runCreateContextProvider ??
                PlatformAgentRunCreateContextProvider())
            .load();
    final payload = Map<String, Object?>.from(
      payloadFactory(request.withRunCreateContext(runCreateContext)),
    );
    final idempotencyKey =
        stringField(payload, 'idempotency_key') ?? _agentRunIdempotencyKey();
    payload['idempotency_key'] = idempotencyKey;

    var response = await _postCreateRun(
      payload: payload,
      idempotencyKey: idempotencyKey,
    );
    if (response.statusCode == HttpStatus.unauthorized &&
        await _refreshAfterUnauthorized()) {
      response = await _postCreateRun(
        payload: payload,
        idempotencyKey: idempotencyKey,
      );
    }
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

  Future<AgentStreamControlHttpResponse> _postCreateRun({
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) {
    return runConnector.post(
      runsEndpoint.requestUri,
      headers: {
        ...runsEndpoint.requestHeaders(includeContentType: true),
        'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(payload),
      timeout: runCreationTimeout,
    );
  }

  Future<bool> _refreshAfterUnauthorized() async {
    final handler = onUnauthorized;
    if (handler == null) return false;
    return await handler();
  }
}

String _agentRunIdempotencyKey() {
  return 'agent-run-${DateTime.now().microsecondsSinceEpoch}';
}

bool _isUnauthorizedStreamError(AgentStreamTransportException error) {
  return error.statusCode == HttpStatus.unauthorized ||
      error.message.contains('401');
}

bool _isRetryableHttpStatus(int statusCode) =>
    statusCode == HttpStatus.requestTimeout ||
    statusCode == HttpStatus.tooManyRequests ||
    statusCode >= HttpStatus.internalServerError;

AgentRunLifecycleStatus _runLifecycleStatus(String? status) {
  return switch (status?.trim()) {
    'queued' => AgentRunLifecycleStatus.queued,
    'running' => AgentRunLifecycleStatus.running,
    'waiting_for_confirmation' =>
      AgentRunLifecycleStatus.waitingForConfirmation,
    'completed' => AgentRunLifecycleStatus.completed,
    'failed' => AgentRunLifecycleStatus.failed,
    'cancelled' => AgentRunLifecycleStatus.cancelled,
    'expired' => AgentRunLifecycleStatus.expired,
    _ => AgentRunLifecycleStatus.unknown,
  };
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
    Duration? timeout,
  }) {
    return IoAgentStreamControlHttpConnector().post(
      uri,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }
}

class _DefaultControlHttpGetConnector
    implements AgentStreamControlHttpGetConnector {
  const _DefaultControlHttpGetConnector();

  @override
  Future<AgentStreamControlHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) {
    return IoAgentStreamControlHttpGetConnector().get(uri, headers: headers);
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

List<AgentStreamEvent> _decodeActionEvents(Object? rawEvents) {
  final values = switch (rawEvents) {
    List value => value,
    Map value => [value],
    _ => const <Object?>[],
  };
  return List<AgentStreamEvent>.unmodifiable(
    values.whereType<Map>().map(
      (event) => AgentStreamEvent(Map<String, Object?>.from(event)),
    ),
  );
}
