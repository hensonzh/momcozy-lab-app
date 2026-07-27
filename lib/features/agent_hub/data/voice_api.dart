import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/core/network/api_json_transport.dart';
import 'package:app/core/network/transport_security_policy.dart';
import 'package:app/core/privacy/log_redactor.dart';
import 'package:app/features/agent_hub/domain/agent_voice.dart';

const speechTranscribeChunkEndpoint = '/v1/speech/transcribe-chunk';
const realtimeVoiceStreamEndpoint = '/v1/realtime-voice-stream';
const realtimeVoiceSessionEndpoint = '/v1/realtime-voice-session';
const agentVoiceWebSocketPingInterval = Duration(seconds: 15);

typedef AgentVoiceUnauthorizedHandler = FutureOr<bool> Function();

abstract interface class AgentVoiceRepository {
  Future<String?> transcribeSpeechChunk({
    required ApiUploadFile file,
    String? language,
  });

  Stream<List<int>> realtimeVoicePcmStream({required String text});

  Future<AgentVoiceRealtimeSessionConnection> openRealtimeVoiceSession();

  Stream<AgentVoiceSessionEvent> realtimeVoiceSession();
}

abstract interface class AgentVoiceRealtimeSessionConnection {
  Stream<AgentVoiceSessionEvent> get events;

  Future<void> append(String text);

  Future<void> finish();

  Future<void> cancel();

  Future<void> close();
}

class AgentVoiceApiRepository implements AgentVoiceRepository {
  AgentVoiceApiRepository({
    required this.multipartTransport,
    required Uri baseUri,
    this.token,
    this.tokenProvider,
    this.onUnauthorized,
    this.headers = const <String, String>{},
    this.binaryConnector = const _DefaultAgentVoiceBinaryStreamConnector(),
    this.websocketConnector = const _DefaultAgentVoiceWebSocketConnector(),
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri);

  final ApiMultipartTransport multipartTransport;
  final Uri baseUri;
  final String? token;
  final String? Function()? tokenProvider;
  final AgentVoiceUnauthorizedHandler? onUnauthorized;
  final Map<String, String> headers;
  final AgentVoiceBinaryStreamConnector binaryConnector;
  final AgentVoiceWebSocketConnector websocketConnector;

  @override
  Future<String?> transcribeSpeechChunk({
    required ApiUploadFile file,
    String? language,
  }) async {
    try {
      final response = await multipartTransport.uploadMultipart(
        speechTranscribeChunkEndpoint,
        fields: {
          if (language != null && language.trim().isNotEmpty)
            'language': language.trim(),
        },
        headers: _requestHeaders(accept: 'application/json'),
        file: file,
      );
      final text = _string(response['text'] ?? response['transcript'])?.trim();
      return text == null || text.isEmpty ? null : text;
    } on ApiRequestCancelledException {
      rethrow;
    } on Object {
      return null;
    }
  }

  @override
  Stream<List<int>> realtimeVoicePcmStream({required String text}) async* {
    final uri = _resolveHttp(
      realtimeVoiceStreamEndpoint,
      query: {'text': text},
    );
    try {
      await for (final chunk in _openRealtimeVoicePcmStream(uri)) {
        yield chunk;
      }
    } on ApiHttpException catch (error) {
      if (error.statusCode != HttpStatus.unauthorized ||
          !await _refreshAfterUnauthorized()) {
        rethrow;
      }
      await for (final chunk in _openRealtimeVoicePcmStream(uri)) {
        yield chunk;
      }
    }
  }

  Map<String, Object?> redactedRealtimeVoiceStreamLogContext({
    required String text,
  }) {
    return _redactedRequestContext(
      _resolveHttp(realtimeVoiceStreamEndpoint, query: {'text': text}),
      accept: 'audio/pcm',
    );
  }

  @override
  Stream<AgentVoiceSessionEvent> realtimeVoiceSession() async* {
    final connection = await openRealtimeVoiceSession();
    try {
      yield* connection.events;
    } finally {
      await connection.close();
    }
  }

  @override
  Future<AgentVoiceRealtimeSessionConnection> openRealtimeVoiceSession() async {
    final connection = await websocketConnector.connect(
      _resolveWebSocket(realtimeVoiceSessionEndpoint),
      headers: _requestHeaders(accept: 'application/json'),
    );
    return _AgentVoiceApiRealtimeSessionConnection(connection);
  }

  Map<String, Object?> redactedRealtimeVoiceSessionLogContext() {
    return _redactedRequestContext(
      _resolveWebSocket(realtimeVoiceSessionEndpoint),
      accept: 'application/json',
    );
  }

  Uri _resolveHttp(String path, {Map<String, Object?> query = const {}}) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final nextPath = path.startsWith('/') ? path.substring(1) : path;
    final nextQuery = <String, String>{
      ...baseUri.queryParameters,
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return baseUri.replace(
      path: '$basePath$nextPath',
      queryParameters: nextQuery.isEmpty ? null : nextQuery,
    );
  }

  Uri _resolveWebSocket(String path, {Map<String, Object?> query = const {}}) {
    final httpUri = _resolveHttp(path, query: query);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme);
  }

  Map<String, String> _requestHeaders({required String accept}) {
    final authToken = (tokenProvider?.call() ?? token)?.trim();
    return {
      ...headers,
      'Accept': accept,
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Future<bool> _refreshAfterUnauthorized() async {
    final handler = onUnauthorized;
    if (handler == null) return false;
    return await handler();
  }

  Stream<List<int>> _openRealtimeVoicePcmStream(Uri uri) {
    return binaryConnector.get(
      uri,
      headers: _requestHeaders(accept: 'audio/pcm'),
    );
  }

  Map<String, Object?> _redactedRequestContext(
    Uri uri, {
    required String accept,
  }) {
    return redactLogMap({
      'url': uri,
      'headers': _requestHeaders(accept: accept),
    });
  }
}

class AgentVoiceApiInputTranscriber implements AgentVoiceTranscriber {
  const AgentVoiceApiInputTranscriber({
    required this.repository,
    this.language,
  });

  final AgentVoiceRepository repository;
  final String? language;

  @override
  Future<String?> transcribe(AgentVoiceRecording recording) {
    if (recording.bytes.isEmpty) return Future<String?>.value();
    return repository.transcribeSpeechChunk(
      language: language,
      file: ApiUploadFile(
        name: recording.name,
        mimeType: recording.mimeType,
        sizeBytes: recording.sizeBytes,
        bytes: recording.bytes,
      ),
    );
  }
}

abstract interface class AgentVoiceBinaryStreamConnector {
  Stream<List<int>> get(Uri uri, {required Map<String, String> headers});
}

class IoAgentVoiceBinaryStreamConnector
    implements AgentVoiceBinaryStreamConnector {
  IoAgentVoiceBinaryStreamConnector({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Stream<List<int>> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async* {
    final request = await _httpClient.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.transform(utf8.decoder).join();
      throw ApiHttpException(
        statusCode: response.statusCode,
        statusText: response.reasonPhrase,
        body: body.trim().isEmpty ? null : {'body': body},
      );
    }
    yield* response;
  }
}

abstract interface class AgentVoiceWebSocketConnection {
  Stream<Object?> get frames;

  Future<void> send(String text);

  Future<void> close();
}

abstract interface class AgentVoiceWebSocketConnector {
  Future<AgentVoiceWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  });
}

class IoAgentVoiceWebSocketConnector implements AgentVoiceWebSocketConnector {
  const IoAgentVoiceWebSocketConnector();

  @override
  Future<AgentVoiceWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final socket = await WebSocket.connect(uri.toString(), headers: headers);
    socket.pingInterval = agentVoiceWebSocketPingInterval;
    return _IoAgentVoiceWebSocketConnection(socket);
  }
}

class _IoAgentVoiceWebSocketConnection
    implements AgentVoiceWebSocketConnection {
  const _IoAgentVoiceWebSocketConnection(this.socket);

  final WebSocket socket;

  @override
  Stream<Object?> get frames => socket.cast<Object?>();

  @override
  Future<void> send(String text) async {
    socket.add(text);
  }

  @override
  Future<void> close() => socket.close();
}

class _AgentVoiceApiRealtimeSessionConnection
    implements AgentVoiceRealtimeSessionConnection {
  const _AgentVoiceApiRealtimeSessionConnection(this.connection);

  final AgentVoiceWebSocketConnection connection;

  @override
  Stream<AgentVoiceSessionEvent> get events {
    return connection.frames.map(_voiceSessionEventFromTransportFrame);
  }

  @override
  Future<void> append(String text) {
    return _sendJson({'type': 'append', 'text': text});
  }

  @override
  Future<void> finish() {
    return _sendJson({'type': 'finish'});
  }

  @override
  Future<void> cancel() {
    return _sendJson({'type': 'cancel'});
  }

  @override
  Future<void> close() {
    return connection.close();
  }

  Future<void> _sendJson(Map<String, Object?> payload) {
    return connection.send(jsonEncode(payload));
  }
}

AgentVoiceSessionEvent _voiceSessionEventFromTransportFrame(Object? frame) {
  if (frame is String) return parseAgentVoiceSessionFrame(frame);
  if (frame is List<int>) {
    return AgentVoiceSessionEvent(
      type: AgentVoiceSessionEventType.audioChunk,
      audioBytes: frame,
    );
  }
  throw AgentVoiceSessionFrameFormatException(
    'Unsupported voice session transport frame: ${frame.runtimeType}',
  );
}

class _DefaultAgentVoiceBinaryStreamConnector
    implements AgentVoiceBinaryStreamConnector {
  const _DefaultAgentVoiceBinaryStreamConnector();

  @override
  Stream<List<int>> get(Uri uri, {required Map<String, String> headers}) {
    return IoAgentVoiceBinaryStreamConnector().get(uri, headers: headers);
  }
}

class _DefaultAgentVoiceWebSocketConnector
    implements AgentVoiceWebSocketConnector {
  const _DefaultAgentVoiceWebSocketConnector();

  @override
  Future<AgentVoiceWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) {
    return const IoAgentVoiceWebSocketConnector().connect(
      uri,
      headers: headers,
    );
  }
}

String? _string(Object? value) => value is String ? value : null;
