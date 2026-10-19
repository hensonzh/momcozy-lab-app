import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Backend-owned 24 kHz, mono PCM16. No vendor credential is ever on-device.
abstract interface class ChatFirstPcmPlayer {
  Future<void> start();
  Future<void> write(Uint8List bytes);
  Future<void> finish();
  Future<void> stop();
}

class NativeChatFirstPcmPlayer implements ChatFirstPcmPlayer {
  const NativeChatFirstPcmPlayer();
  static const _channel = MethodChannel('momcozy/chat_first_pcm');

  @override
  Future<void> start() => _channel.invokeMethod<void>('start');
  @override
  Future<void> write(Uint8List bytes) =>
      _channel.invokeMethod<void>('write', bytes);
  @override
  Future<void> finish() => _channel.invokeMethod<void>('finish');
  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}

class ChatFirstVoiceController extends ChangeNotifier {
  ChatFirstVoiceController({
    required this.baseUri,
    required this.tokenProvider,
    ChatFirstPcmPlayer? player,
    HttpClient Function()? httpClientFactory,
  }) : _player = player ?? const NativeChatFirstPcmPlayer(),
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Uri baseUri;
  final String? Function() tokenProvider;
  final ChatFirstPcmPlayer _player;
  final HttpClient Function() _httpClientFactory;
  HttpClient? _streamClient;
  bool _disposed = false;
  bool available = false;
  bool enabled = true;
  bool playing = false;
  int _generation = 0;
  final Set<String> _spoken = {};

  Future<void> checkAvailability() async {
    final token = tokenProvider();
    if (token == null || token.isEmpty) return;
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(
        baseUri.resolve('/v1/realtime-voice-capability'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final body = await utf8.decoder.bind(response).join();
      if (!_disposed) {
        available =
            response.statusCode == 200 &&
            (jsonDecode(body) as Map<String, dynamic>)['available'] == true;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        available = false;
        notifyListeners();
      }
    } finally {
      client.close(force: true);
    }
  }

  void toggle() {
    if (!available || _disposed) return;
    enabled = !enabled;
    if (!enabled) stop();
    notifyListeners();
  }

  void stop() {
    ++_generation;
    _streamClient?.close(force: true);
    _streamClient = null;
    unawaited(_player.stop().catchError((Object _) {}));
    if (!_disposed) {
      playing = false;
      notifyListeners();
    }
  }

  Future<void> speakCompleted(String id, String text) async {
    if (_disposed || !available || !enabled || !_spoken.add(id)) return;
    stop();
    final generation = _generation;
    final token = tokenProvider();
    if (token == null || token.isEmpty) return;
    final content = String.fromCharCodes(text.runes.take(500)).trim();
    if (content.isEmpty) return;
    final client = _streamClient = _httpClientFactory();
    var started = false;
    try {
      final request = await client.postUrl(
        baseUri.resolve('/v1/realtime-voice-stream'),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'text': content})));
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      if (generation != _generation || _disposed) return;
      if (response.statusCode != 200 ||
          response.headers.value('x-mai-audio-format') != 'pcm16' ||
          response.headers.value('x-mai-audio-sample-rate') != '24000' ||
          response.headers.value('x-mai-audio-channels') != '1') {
        if (response.statusCode == 503 && !_disposed) {
          available = false;
          notifyListeners();
        }
        return;
      }
      int? pendingByte;
      var totalBytes = 0;
      await for (final chunk in response) {
        if (generation != _generation || _disposed) return;
        if (chunk.isEmpty) continue;
        totalBytes += chunk.length;
        if (totalBytes > 8 * 1024 * 1024) {
          throw const FormatException('Audio too large');
        }
        final bytes = Uint8List(chunk.length + (pendingByte == null ? 0 : 1));
        if (pendingByte != null) bytes[0] = pendingByte;
        bytes.setRange(pendingByte == null ? 0 : 1, bytes.length, chunk);
        final even = bytes.length & ~1;
        pendingByte = even < bytes.length ? bytes.last : null;
        if (even == 0) continue;
        if (!started) {
          await _player.start();
          started = true;
          if (generation != _generation || _disposed) return;
          playing = true;
          notifyListeners();
        }
        await _player.write(Uint8List.sublistView(bytes, 0, even));
      }
      if (started &&
          pendingByte == null &&
          generation == _generation &&
          !_disposed) {
        await _player.finish();
      }
    } catch (_) {
      // No fabricated fallback or replay after partially spoken audio.
    } finally {
      client.close(force: true);
      if (identical(_streamClient, client)) _streamClient = null;
      if (generation == _generation && !_disposed) {
        playing = false;
        notifyListeners();
        if (started) await _player.stop().catchError((Object _) {});
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

class ChatFirstVoiceHost extends StatefulWidget {
  const ChatFirstVoiceHost({
    super.key,
    required this.runtimeBaseUri,
    required this.tokenProvider,
    required this.child,
  });
  final Uri runtimeBaseUri;
  final String? Function() tokenProvider;
  final Widget child;

  @override
  State<ChatFirstVoiceHost> createState() => _ChatFirstVoiceHostState();
}

class _ChatFirstVoiceHostState extends State<ChatFirstVoiceHost>
    with WidgetsBindingObserver {
  late final ChatFirstVoiceController _controller = ChatFirstVoiceController(
    baseUri: widget.runtimeBaseUri,
    tokenProvider: widget.tokenProvider,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.checkAvailability());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChatFirstVoiceScope(controller: _controller, child: widget.child);
}

class ChatFirstVoiceScope extends InheritedNotifier<ChatFirstVoiceController> {
  const ChatFirstVoiceScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);
  final ChatFirstVoiceController controller;

  static ChatFirstVoiceController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatFirstVoiceScope>()
      ?.controller;
}
