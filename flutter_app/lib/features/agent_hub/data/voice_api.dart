import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

const speechTranscribeChunkEndpoint = '/v1/speech/transcribe-chunk';
const realtimeVoiceStreamEndpoint = '/v1/realtime-voice-stream';
const realtimeVoiceSessionEndpoint = '/v1/realtime-voice-session';

abstract interface class AgentVoiceRepository {
  Future<String?> transcribeSpeechChunk({
    required String userId,
    required ApiUploadFile file,
    String? language,
  });

  Stream<List<int>> realtimeVoicePcmStream({
    required String userId,
    required String text,
  });

  Stream<AgentVoiceSessionEvent> realtimeVoiceSession({required String userId});
}

class AgentVoiceApiRepository implements AgentVoiceRepository {
  const AgentVoiceApiRepository({
    required this.multipartTransport,
    required this.baseUri,
    this.token,
    this.headers = const <String, String>{},
    this.binaryConnector = const _DefaultAgentVoiceBinaryStreamConnector(),
    this.websocketConnector = const _DefaultAgentVoiceWebSocketConnector(),
  });

  final ApiMultipartTransport multipartTransport;
  final Uri baseUri;
  final String? token;
  final Map<String, String> headers;
  final AgentVoiceBinaryStreamConnector binaryConnector;
  final AgentVoiceWebSocketConnector websocketConnector;

  @override
  Future<String?> transcribeSpeechChunk({
    required String userId,
    required ApiUploadFile file,
    String? language,
  }) async {
    try {
      final response = await multipartTransport.uploadMultipart(
        speechTranscribeChunkEndpoint,
        fields: {
          'user_id': userId,
          if (language != null && language.trim().isNotEmpty)
            'language': language.trim(),
        },
        file: file,
      );
      final data = _mapOrEmpty(unwrapApiEnvelope(response));
      final text = _string(data['text'] ?? data['transcript'])?.trim();
      return text == null || text.isEmpty ? null : text;
    } on ApiRequestCancelledException {
      rethrow;
    } on Object {
      return null;
    }
  }

  @override
  Stream<List<int>> realtimeVoicePcmStream({
    required String userId,
    required String text,
  }) {
    return binaryConnector.get(
      _resolveHttp(
        realtimeVoiceStreamEndpoint,
        query: {'user_id': userId, 'text': text},
      ),
      headers: _requestHeaders(accept: 'audio/pcm'),
    );
  }

  @override
  Stream<AgentVoiceSessionEvent> realtimeVoiceSession({
    required String userId,
  }) async* {
    final connection = await websocketConnector.connect(
      _resolveWebSocket(
        realtimeVoiceSessionEndpoint,
        query: {
          'user_id': userId,
          if (token != null && token!.trim().isNotEmpty) 'token': token!.trim(),
        },
      ),
      headers: _requestHeaders(accept: 'application/json'),
    );

    try {
      await for (final frame in connection.frames) {
        yield parseAgentVoiceSessionFrame(frame);
      }
    } finally {
      await connection.close();
    }
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
    final authToken = token?.trim();
    return {
      ...headers,
      'Accept': accept,
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
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
  Stream<String> get frames;

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
    return _IoAgentVoiceWebSocketConnection(socket);
  }
}

class _IoAgentVoiceWebSocketConnection
    implements AgentVoiceWebSocketConnection {
  const _IoAgentVoiceWebSocketConnection(this.socket);

  final WebSocket socket;

  @override
  Stream<String> get frames => socket.map((frame) => frame.toString());

  @override
  Future<void> close() => socket.close();
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

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String? _string(Object? value) => value is String ? value : null;
