import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_voice.dart';

class _Player implements ChatFirstPcmPlayer {
  final writes = <int>[];
  int starts = 0, finishes = 0, stops = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> write(Uint8List bytes) async {
    writes.addAll(bytes);
  }

  @override
  Future<void> finish() async {
    finishes++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class _Headers extends Fake implements HttpHeaders {
  final values = <String, String>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name] = '$value';
  @override
  String? value(String name) => values[name];
  @override
  set contentType(ContentType? value) =>
      values[HttpHeaders.contentTypeHeader] = '$value';
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  final sent = <int>[];
  final _Headers _headers = _Headers();
  @override
  HttpHeaders get headers => _headers;
  @override
  void add(List<int> data) => sent.addAll(data);
  @override
  Future<HttpClientResponse> close() async => response;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.chunks, this.headers);
  @override
  final int statusCode;
  final List<List<int>> chunks;
  @override
  final HttpHeaders headers;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable(chunks).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client extends Fake implements HttpClient {
  _Client(this.request, this.urls);
  final _Request request;
  final List<Uri> urls;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    return request;
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    urls.add(url);
    return request;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('authenticated PCM chunks are streamed and not replayed', () async {
    final urls = <Uri>[];
    final capability = _Request(
      _Response(200, [utf8.encode('{"available":true}')], _Headers()),
    );
    final headers = _Headers()
      ..set('x-mai-audio-format', 'pcm16')
      ..set('x-mai-audio-sample-rate', '24000')
      ..set('x-mai-audio-channels', '1');
    final speech = _Request(
      _Response(200, [
        [1],
        [2, 3, 4],
      ], headers),
    );
    final clients = [_Client(capability, urls), _Client(speech, urls)];
    final player = _Player();
    final voice = ChatFirstVoiceController(
      baseUri: Uri.parse('https://example.org'),
      tokenProvider: () => 'private-token',
      player: player,
      httpClientFactory: () => clients.removeAt(0),
    );
    expect(
      voice.enabled,
      isTrue,
      reason: 'Voice playback starts enabled by default',
    );
    await voice.checkAvailability();
    expect(voice.available, isTrue);
    await voice.speakCompleted('reply-1', '你好');
    await voice.speakCompleted('reply-1', '你好');
    expect(player.writes, [1, 2, 3, 4]);
    expect(player.starts, 1);
    expect(player.finishes, 1);
    expect(urls.map((uri) => uri.path), [
      '/v1/realtime-voice-capability',
      '/v1/realtime-voice-stream',
    ]);
    expect(urls.every((uri) => uri.query.isEmpty), isTrue);
    expect(capability.headers.value('authorization'), 'Bearer private-token');
    expect(speech.headers.value('authorization'), 'Bearer private-token');
    expect(utf8.decode(speech.sent), '{"text":"你好"}');
    voice.dispose();
  });

  test(
    'speaks the first complete phrase before the reply finishes, then queues the rest',
    () async {
      final urls = <Uri>[];
      final headers = _Headers()
        ..set('x-mai-audio-format', 'pcm16')
        ..set('x-mai-audio-sample-rate', '24000')
        ..set('x-mai-audio-channels', '1');
      final first = _Request(
        _Response(200, [
          [1, 2],
        ], headers),
      );
      final second = _Request(
        _Response(200, [
          [3, 4],
        ], headers),
      );
      final clients = <_Client>[
        _Client(
          _Request(
            _Response(200, [utf8.encode('{"available":true}')], _Headers()),
          ),
          urls,
        ),
        _Client(first, urls),
        _Client(second, urls),
      ];
      final player = _Player();
      final voice = ChatFirstVoiceController(
        baseUri: Uri.parse('https://example.org'),
        tokenProvider: () => 'private-token',
        player: player,
        httpClientFactory: () => clients.removeAt(0),
      );
      await voice.checkAvailability();
      await voice.speakProgress('run-1', '先照顾宝宝。后面还在生成');
      expect(utf8.decode(first.sent), '{"text":"先照顾宝宝。"}');
      expect(player.writes, [1, 2]);
      expect(player.finishes, 0);
      await voice.speakProgress('run-1', '先照顾宝宝。后面还在生成。', complete: true);
      expect(utf8.decode(second.sent), '{"text":"后面还在生成。"}');
      expect(player.writes, [1, 2, 3, 4]);
      expect(player.starts, 1);
      expect(player.finishes, 1);
      voice.dispose();
    },
  );

  test('503 stops requesting the remaining queued phrases', () async {
    final urls = <Uri>[];
    final clients = <_Client>[
      _Client(
        _Request(
          _Response(200, [utf8.encode('{"available":true}')], _Headers()),
        ),
        urls,
      ),
      _Client(_Request(_Response(503, const [], _Headers())), urls),
    ];
    final player = _Player();
    final voice = ChatFirstVoiceController(
      baseUri: Uri.parse('https://example.org'),
      tokenProvider: () => 'private-token',
      player: player,
      httpClientFactory: () => clients.removeAt(0),
    );
    await voice.checkAvailability();
    await voice.speakCompleted('run-1', '先照顾宝宝。然后休息。');
    expect(voice.available, isFalse);
    expect(urls.map((uri) => uri.path), [
      '/v1/realtime-voice-capability',
      '/v1/realtime-voice-stream',
    ]);
    expect(player.starts, 0);
    voice.dispose();
  });

  test('disabled provider never starts playback', () async {
    final urls = <Uri>[];
    final request = _Request(
      _Response(200, [utf8.encode('{"available":false}')], _Headers()),
    );
    final player = _Player();
    final voice = ChatFirstVoiceController(
      baseUri: Uri.parse('https://example.org'),
      tokenProvider: () => 'token',
      player: player,
      httpClientFactory: () => _Client(request, urls),
    );
    await voice.checkAvailability();
    await voice.speakCompleted('reply-1', '不会出声');
    expect(voice.available, isFalse);
    expect(player.starts, 0);
    expect(urls, hasLength(1));
    voice.dispose();
  });
}
