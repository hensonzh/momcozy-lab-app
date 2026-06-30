import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../privacy/log_redactor.dart';
import 'agent_stream_client.dart';

typedef AgentStreamPayloadFactory =
    Map<String, Object?> Function(AgentStreamRequest request);

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

  Map<String, String> jsonHeaders({required bool includeContentType}) {
    final authToken = token?.trim();
    return <String, String>{
      ...headers,
      'Accept': includeContentType ? 'text/event-stream' : 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Map<String, Object?> redactedLogContext() => redactLogMap({
    'url': uriWithToken.toString(),
    'headers': jsonHeaders(includeContentType: true),
  });
}

class AgentStreamTransportException implements Exception {
  const AgentStreamTransportException(this.message);

  final String message;

  @override
  String toString() => 'AgentStreamTransportException($message)';
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
      headers: endpoint.jsonHeaders(includeContentType: true),
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
      headers: endpoint.jsonHeaders(includeContentType: false),
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
