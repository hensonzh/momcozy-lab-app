import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

const defaultAgentVoicePcmPlayerChannelName =
    'com.momcozymai.flutter/voice_pcm_player';
const agentVoicePlaybackMaxChunkChars = 900;
const agentVoiceRealtimeMaxSegmentChars = 64;
const agentVoiceRealtimeMinSegmentChars = 12;

final _voiceBareUrlPattern = RegExp(
  r'''\b(?:(?:https?|ftp):\/\/|www\.)[^\s<>"'，。！？；、]+''',
  caseSensitive: false,
);
final _voiceAppRoutePattern = RegExp(
  r'''(^|[\s(（\[])\/[A-Za-z][^\s<>"'，。！？；、)]*''',
  multiLine: true,
);
final _voiceHashOrQueryUrlPattern = RegExp(
  r'''(^|[\s(（\[])[?#][A-Za-z0-9_=&%./:%+-][^\s<>"'，。！？；、)]*''',
  multiLine: true,
);
final _voiceBareDomainPattern = RegExp(
  r'''\b(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、]*)?''',
  caseSensitive: false,
);
final _voiceMediaPathPattern = RegExp(
  r'''(^|[\s(（\[])(?:\.{0,2}\/|\/)?[^\s<>"'，。！？；、)]*\.(?:png|jpe?g|webp|gif|svg|mp4|mov|m4v|webm|mp3|wav|m4a|aac|pdf)(?:[?#][^\s<>"'，。！？；、)]*)?''',
  caseSensitive: false,
  multiLine: true,
);
final _voiceBareDomainLikePattern = RegExp(
  r'^(?:(?:https?|ftp):\/\/|www\.|(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/|$))',
  caseSensitive: false,
);
final _voiceStreamTrailingUrlLikePattern = RegExp(
  r'''(^|[\s(（\[])((?:(?:https?|ftp):\/\/|www\.)[^\s<>"'，。！？；、)]*|\/[A-Za-z][^\s<>"'，。！？；、)]*|(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|co|app|dev|me|us|uk|jp|edu|gov)(?:\/[^\s<>"'，。！？；、)]*)?)$''',
  caseSensitive: false,
);
const _hospitalBagCartVoicePath = '/hospital-bag-cart';

abstract interface class AgentVoicePcmPlayer {
  Future<void> start({int sampleRate, int channels});

  Future<void> write(List<int> bytes);

  Future<void> finish();

  Future<void> stop();
}

class MethodChannelAgentVoicePcmPlayer implements AgentVoicePcmPlayer {
  MethodChannelAgentVoicePcmPlayer({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(defaultAgentVoicePcmPlayerChannelName);

  final MethodChannel _channel;

  @override
  Future<void> start({int sampleRate = 24000, int channels = 1}) async {
    await _channel.invokeMethod<void>('start', {
      'sampleRate': sampleRate,
      'channels': channels,
    });
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (bytes.isEmpty) return;
    await _channel.invokeMethod<void>('write', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<void> finish() async {
    await _channel.invokeMethod<void>('finish');
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}

class AgentVoiceApiPlaybackPlayer implements AgentVoicePlaybackPlayer {
  AgentVoiceApiPlaybackPlayer({
    required this.repository,
    AgentVoicePcmPlayer? pcmPlayer,
    this.sampleRate = 24000,
    this.channels = 1,
  }) : pcmPlayer = pcmPlayer ?? MethodChannelAgentVoicePcmPlayer();

  final AgentVoiceRepository repository;
  final AgentVoicePcmPlayer pcmPlayer;
  final int sampleRate;
  final int channels;
  int _playToken = 0;

  @override
  Future<void> playText(String text) async {
    final chunks = buildAgentVoicePlaybackTextChunks(text);
    if (chunks.isEmpty) return;
    final token = ++_playToken;
    await pcmPlayer.start(sampleRate: sampleRate, channels: channels);
    try {
      for (final textChunk in chunks) {
        if (token != _playToken) break;
        await for (final pcmChunk in repository.realtimeVoicePcmStream(
          text: textChunk,
        )) {
          if (token != _playToken) break;
          await pcmPlayer.write(pcmChunk);
        }
      }
    } finally {
      if (token == _playToken) {
        await pcmPlayer.finish();
      }
    }
  }

  @override
  AgentVoiceRealtimePlaybackSession startRealtimeSession({
    AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
  }) {
    final token = ++_playToken;
    return AgentVoiceApiRealtimePlaybackSession(
      repository: repository,
      pcmPlayer: pcmPlayer,
      sampleRate: sampleRate,
      channels: channels,
      isCurrent: () => token == _playToken,
      mediaNarrationResolver: mediaNarrationResolver,
    );
  }

  @override
  Future<void> stop() async {
    _playToken += 1;
    await pcmPlayer.stop();
  }
}

class AgentVoiceApiRealtimePlaybackSession
    implements AgentVoiceRealtimePlaybackSession {
  AgentVoiceApiRealtimePlaybackSession({
    required this.repository,
    required this.pcmPlayer,
    required this.sampleRate,
    required this.channels,
    required this.isCurrent,
    this.mediaNarrationResolver,
    this.maxSegmentChars = agentVoiceRealtimeMaxSegmentChars,
    this.minSegmentChars = agentVoiceRealtimeMinSegmentChars,
    this.eagerSegmenting = true,
  }) : _textFilter = AgentVoiceTextStreamFilter(
         mediaNarrationResolver: mediaNarrationResolver,
       ) {
    unawaited(_run());
  }

  final AgentVoiceRepository repository;
  final AgentVoicePcmPlayer pcmPlayer;
  final int sampleRate;
  final int channels;
  final bool Function() isCurrent;
  final AgentVoiceMediaNarrationResolver? mediaNarrationResolver;
  final int maxSegmentChars;
  final int minSegmentChars;
  final bool eagerSegmenting;
  final AgentVoiceTextStreamFilter _textFilter;

  final Completer<void> _done = Completer<void>();
  final List<String> _pendingSegments = <String>[];
  AgentVoiceRealtimeSessionConnection? _connection;
  Future<void> _sendQueue = Future<void>.value();
  String _buffer = '';
  bool _cancelled = false;
  bool _finished = false;
  bool _finishSent = false;
  bool _pcmStarted = false;
  bool _pcmStopped = false;

  @override
  Future<void> get done => _done.future;

  @override
  void append(String delta) {
    if (_cancelled || _finished || delta.isEmpty || !isCurrent()) return;
    _buffer += _textFilter.push(delta);
    _drainBuffer(force: false);
    _flushPendingSegments();
  }

  @override
  void flush() {
    if (_cancelled || !isCurrent()) return;
    _buffer += _textFilter.flush();
    _drainBuffer(force: true);
    _flushPendingSegments();
  }

  @override
  void finish() {
    if (_cancelled || _finished || !isCurrent()) return;
    _buffer += _textFilter.flush();
    _drainBuffer(force: true);
    _finished = true;
    _flushPendingSegments();
  }

  @override
  Future<void> cancel() async {
    if (_cancelled) return _done.future;
    _cancelled = true;
    _buffer = '';
    _textFilter.clear();
    _pendingSegments.clear();
    final connection = _connection;
    if (connection != null) {
      try {
        await connection.cancel();
      } catch (_) {
        // Best-effort cancellation; close/stop below still releases resources.
      }
      await _closeConnection();
    }
    await _stopPcm(immediate: true);
    if (!_done.isCompleted) _done.complete();
    return _done.future;
  }

  Future<void> _run() async {
    Object? failure;
    try {
      final connection = await repository.openRealtimeVoiceSession();
      if (_cancelled || !isCurrent()) {
        await connection.close();
        return;
      }
      _connection = connection;
      await pcmPlayer.start(sampleRate: sampleRate, channels: channels);
      _pcmStarted = true;
      _flushPendingSegments();

      await for (final event in connection.events) {
        if (_cancelled || !isCurrent()) break;
        switch (event.type) {
          case AgentVoiceSessionEventType.opened:
            _flushPendingSegments();
            break;
          case AgentVoiceSessionEventType.audioChunk:
            if (event.audioBytes.isNotEmpty) {
              await pcmPlayer.write(event.audioBytes);
            }
            break;
          case AgentVoiceSessionEventType.completed:
            return;
          case AgentVoiceSessionEventType.failed:
            throw StateError(event.message ?? '实时语音播报失败');
        }
      }
    } catch (error) {
      failure = error;
    } finally {
      await _sendQueue.catchError((Object error) {
        failure ??= error;
      });
      await _closeConnection();
      await _stopPcm(immediate: _cancelled || failure != null || !isCurrent());
      if (!_done.isCompleted) {
        if (_cancelled || failure == null) {
          _done.complete();
        } else {
          _done.completeError(failure!);
        }
      }
    }
  }

  void _drainBuffer({required bool force}) {
    while (_buffer.trim().isNotEmpty) {
      _buffer = _buffer.trimLeft();
      final splitAt = _voiceRealtimeSegmentBoundary(
        _buffer,
        maxSegmentChars: maxSegmentChars,
        minSegmentChars: minSegmentChars,
        force: force,
        eager: eagerSegmenting,
      );
      if (splitAt <= 0) return;
      final segment = sanitizeAgentVoicePlaybackText(
        _buffer.substring(0, splitAt),
      );
      _buffer = _buffer.substring(splitAt).trimLeft();
      if (_hasVoiceSpeakableText(segment)) {
        _pendingSegments.add(segment);
      }
    }
  }

  void _flushPendingSegments() {
    final connection = _connection;
    if (connection == null || _cancelled || !isCurrent()) return;
    while (_pendingSegments.isNotEmpty) {
      final segment = _pendingSegments.removeAt(0);
      _enqueueSend(() => connection.append(segment));
    }
    if (_finished && !_finishSent && _pendingSegments.isEmpty) {
      _finishSent = true;
      _enqueueSend(connection.finish);
    }
  }

  void _enqueueSend(Future<void> Function() send) {
    _sendQueue = _sendQueue.then((_) async {
      if (_cancelled || !isCurrent()) return;
      await send();
    });
  }

  Future<void> _closeConnection() async {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    await connection.close();
  }

  Future<void> _stopPcm({required bool immediate}) async {
    if (!_pcmStarted || _pcmStopped) return;
    _pcmStopped = true;
    if (immediate) {
      await pcmPlayer.stop();
    } else {
      await pcmPlayer.finish();
    }
  }
}

@visibleForTesting
class AgentVoiceTextStreamFilter {
  AgentVoiceTextStreamFilter({this.mediaNarrationResolver});

  final AgentVoiceMediaNarrationResolver? mediaNarrationResolver;
  final Set<String> _spokenMediaNarrations = {};
  String _pending = '';

  String push(String delta) {
    if (delta.isEmpty) return '';
    _pending += delta;
    return _drain(force: false);
  }

  String flush() => _drain(force: true);

  void clear() {
    _pending = '';
    _spokenMediaNarrations.clear();
  }

  String _drain({required bool force}) {
    if (_pending.isEmpty) return '';
    if (force) {
      final ready = _pending;
      _pending = '';
      return _stripVoiceLinks(
        ready,
        mediaNarrationResolver: mediaNarrationResolver,
        spokenMediaNarrations: _spokenMediaNarrations,
      );
    }

    final holdStart = _voiceStreamHoldStart(_pending);
    if (holdStart < 0) {
      final ready = _pending;
      _pending = '';
      return _stripVoiceLinks(
        ready,
        mediaNarrationResolver: mediaNarrationResolver,
        spokenMediaNarrations: _spokenMediaNarrations,
      );
    }
    if (holdStart == 0) return '';

    final ready = _pending.substring(0, holdStart);
    _pending = _pending.substring(holdStart);
    return _stripVoiceLinks(
      ready,
      mediaNarrationResolver: mediaNarrationResolver,
      spokenMediaNarrations: _spokenMediaNarrations,
    );
  }
}

@visibleForTesting
String sanitizeAgentVoicePlaybackText(
  String text, {
  AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
}) {
  if (text.isEmpty) return '';
  var normalized = text;
  normalized = normalized.replaceAll(
    RegExp(r'&nbsp;|&#160;', caseSensitive: false),
    ' ',
  );
  normalized = normalized.replaceAll(
    RegExp(r'&amp;', caseSensitive: false),
    '和',
  );
  normalized = normalized.replaceAll(
    RegExp(r'&(lt|gt|quot|apos);', caseSensitive: false),
    ' ',
  );
  normalized = normalized.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
  normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), ' ');
  normalized = normalized.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  normalized = normalized.replaceAll(RegExp(r'`{1,3}[^`]*`{1,3}'), ' ');
  normalized = _stripVoiceLinks(
    normalized,
    mediaNarrationResolver: mediaNarrationResolver,
  );
  normalized = _normalizeVoiceSlashes(normalized);
  normalized = normalized.replaceAll(
    RegExp(r'^#{1,6}\s+', multiLine: true),
    '',
  );
  normalized = normalized.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
  normalized = normalized.replaceAll(
    RegExp(r'^\s*[-*+]\s+', multiLine: true),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'^\s*[•·]\s+', multiLine: true),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'^\s*\d+[.)、]\s+', multiLine: true),
    '',
  );
  normalized = _stripVoiceMarkupAndSymbols(normalized);
  normalized = normalized.replaceAll(RegExp(r'\r?\n+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

@visibleForTesting
List<String> buildAgentVoicePlaybackTextChunks(
  String text, {
  int maxChars = agentVoicePlaybackMaxChunkChars,
  AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
}) {
  final sanitized = sanitizeAgentVoicePlaybackText(
    text,
    mediaNarrationResolver: mediaNarrationResolver,
  );
  if (sanitized.isEmpty) return const <String>[];
  final chunkLimit = _voiceChunkLimit(maxChars, sanitized.length);
  if (sanitized.length <= chunkLimit) {
    return <String>[sanitized];
  }

  final chunks = <String>[];
  var remaining = sanitized;
  while (remaining.length > chunkLimit) {
    var splitAt = _voiceChunkBoundary(remaining, chunkLimit);
    if (splitAt <= 0) splitAt = chunkLimit;
    final chunk = remaining.substring(0, splitAt).trim();
    if (chunk.isNotEmpty) chunks.add(chunk);
    remaining = remaining.substring(splitAt).trimLeft();
  }
  if (remaining.trim().isNotEmpty) chunks.add(remaining.trim());
  return chunks;
}

String _stripVoiceLinks(
  String text, {
  AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
  Set<String>? spokenMediaNarrations,
}) {
  final spoken = spokenMediaNarrations ?? <String>{};
  var normalized = text;
  normalized = normalized.replaceAllMapped(RegExp(r'!\[([^\]]*)]\(([^)]*)\)'), (
    match,
  ) {
    final alt = (match.group(1) ?? '').trim();
    final destination = _voiceLinkDestination(match.group(2));
    final narration = _resolveMediaVoiceNarration(
      destination,
      alt: alt,
      resolver: mediaNarrationResolver,
      spoken: spoken,
    );
    return narration.text == null ? ' ' : ' ${narration.text} ';
  });
  normalized = normalized.replaceAll(RegExp(r'!\[[^\]]*]\s*\[[^\]]*]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'!\[[^\]]*]\([^)]*$'), ' ');
  normalized = normalized.replaceAll(RegExp(r'!\[[^\]]*]?\s*$'), ' ');
  normalized = normalized.replaceAllMapped(RegExp(r'\[([^\]]*)]\(([^)]*)\)'), (
    match,
  ) {
    final label = (match.group(1) ?? '').trim();
    final destination = _voiceLinkDestination(match.group(2));
    final narration = _resolveMediaVoiceNarration(
      destination,
      alt: label,
      resolver: mediaNarrationResolver,
      spoken: spoken,
    );
    if (narration.matched) {
      return narration.text == null ? ' ' : ' ${narration.text} ';
    }
    if (label.isEmpty || _isVoiceUrlLike(label)) return ' ';
    if (_isHospitalBagCartVoiceUrl(destination)) return ' ';
    return ' $label ';
  });
  normalized = normalized.replaceAllMapped(RegExp(r'\[([^\]]+)]\(\s*$'), (
    match,
  ) {
    final label = (match.group(1) ?? '').trim();
    if (label.isEmpty || _isVoiceUrlLike(label)) return ' ';
    return ' $label ';
  });
  normalized = normalized.replaceAllMapped(_voiceMediaPathPattern, (match) {
    final prefix = match.group(1) ?? '';
    final mediaId = (match.group(0) ?? '').substring(prefix.length).trim();
    final narration = _resolveMediaVoiceNarration(
      mediaId,
      resolver: mediaNarrationResolver,
      spoken: spoken,
    );
    return narration.text == null ? '$prefix ' : '$prefix${narration.text} ';
  });
  normalized = normalized.replaceAll(
    RegExp(r'<(?:https?|ftp):\/\/[^>\s]+>', caseSensitive: false),
    ' ',
  );
  normalized = normalized.replaceAllMapped(_voiceBareUrlPattern, (match) {
    final mediaId = match.group(0) ?? '';
    final narration = _resolveMediaVoiceNarration(
      mediaId,
      resolver: mediaNarrationResolver,
      spoken: spoken,
    );
    return narration.text == null ? ' ' : ' ${narration.text} ';
  });
  normalized = normalized.replaceAllMapped(_voiceAppRoutePattern, (match) {
    final prefix = match.group(1) ?? '';
    final mediaId = (match.group(0) ?? '').substring(prefix.length).trim();
    final narration = _resolveMediaVoiceNarration(
      mediaId,
      resolver: mediaNarrationResolver,
      spoken: spoken,
    );
    return narration.text == null ? '$prefix ' : '$prefix${narration.text} ';
  });
  normalized = normalized.replaceAllMapped(
    _voiceHashOrQueryUrlPattern,
    (match) => '${match.group(1) ?? ''} ',
  );
  normalized = normalized.replaceAllMapped(_voiceBareDomainPattern, (match) {
    final mediaId = match.group(0) ?? '';
    final narration = _resolveMediaVoiceNarration(
      mediaId,
      resolver: mediaNarrationResolver,
      spoken: spoken,
    );
    return narration.text == null ? ' ' : ' ${narration.text} ';
  });
  normalized = normalized.replaceAllMapped(
    RegExp(r'(^|[\s(（\[])[)\]](?=($|[\s，。！？；、,.!?;:]))', multiLine: true),
    (match) => '${match.group(1) ?? ''} ',
  );
  return normalized;
}

String _voiceLinkDestination(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '';
  return text.split(RegExp(r'\s+')).first;
}

({bool matched, String? text}) _resolveMediaVoiceNarration(
  String mediaId, {
  String alt = '',
  required AgentVoiceMediaNarrationResolver? resolver,
  required Set<String> spoken,
}) {
  if (mediaId.trim().isEmpty || resolver == null) {
    return (matched: false, text: null);
  }
  final narration = resolver(url: mediaId.trim(), alt: alt.trim())?.trim();
  if (narration == null || narration.isEmpty) {
    return (matched: false, text: null);
  }
  if (!spoken.add(narration)) return (matched: true, text: null);
  return (matched: true, text: narration);
}

int _voiceStreamHoldStart(String text) {
  final starts = <int>[
    _incompleteMarkdownVoiceImageStart(text),
    _incompleteMarkdownVoiceLinkStart(text),
    _trailingVoiceUrlLikeStart(text),
  ].where((start) => start >= 0).toList(growable: false);
  if (starts.isEmpty) return -1;
  return starts.reduce((left, right) => left < right ? left : right);
}

int _incompleteMarkdownVoiceLinkStart(String text) {
  final openLabel = text.lastIndexOf('[');
  if (openLabel < 0) return -1;
  final closeLabel = text.indexOf(']', openLabel + 1);
  if (closeLabel < 0) return openLabel;
  if (closeLabel == text.length - 1) return openLabel;
  if (text[closeLabel + 1] != '(') return -1;
  return text.indexOf(')', closeLabel + 2) >= 0 ? -1 : openLabel;
}

int _incompleteMarkdownVoiceImageStart(String text) {
  final openImage = text.lastIndexOf('![');
  if (openImage < 0) return text.endsWith('!') ? text.length - 1 : -1;
  final closeLabel = text.indexOf(']', openImage + 2);
  if (closeLabel < 0) return openImage;
  if (closeLabel == text.length - 1) return openImage;
  if (text[closeLabel + 1] != '(') return -1;
  return text.indexOf(')', closeLabel + 2) >= 0 ? -1 : openImage;
}

int _trailingVoiceUrlLikeStart(String text) {
  final match = _voiceStreamTrailingUrlLikePattern.firstMatch(text);
  if (match == null || match.end != text.length) return -1;
  return match.start + (match.group(1)?.length ?? 0);
}

String _normalizeVoiceSlashes(String text) {
  var normalized = text;
  normalized = normalized.replaceAllMapped(
    RegExp(r'(^|[^\d])(\d{1,2})\s*/\s*(\d{1,2})(?=$|[^\d])'),
    (match) => '${match.group(1) ?? ''}${match.group(2)}月${match.group(3)}日',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'((?:\d+(?:\.\d+)?\s*)?(?:ml|mL|ML|g|kg|oz|cm|mm|分钟|小时|天|周|月|次|侧|边|度|℃))\s*/\s*(次|天|日|周|月|侧|边|小时|分钟|min|h)',
    ),
    (match) => '${match.group(1)} 每${match.group(2)}',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'(次|顿|餐|片|粒|袋|瓶)\s*/\s*(天|日|周|月|次)'),
    (match) => '${match.group(1)} 每${match.group(2)}',
  );
  normalized = normalized.replaceAll(RegExp(r'\s*/\s*'), ' ');
  return normalized;
}

String _stripVoiceMarkupAndSymbols(String text) {
  var normalized = text;
  normalized = normalized.replaceAllMapped(
    RegExp(r'~~([^~]+)~~'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\*{1,2}([^*\n]+)\*{1,2}'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'_{1,2}([^_\n]+)_{1,2}'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'(\d)\s*[-~～]\s*(\d)'),
    (match) => '${match.group(1)}到${match.group(2)}',
  );
  normalized = normalized.replaceAll(RegExp(r'[*_~`]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[\\|#>{}\[\]<>]'), ' ');
  normalized = normalized.replaceAll(
    RegExp(
      r'[()（）【】「」『』“”"'
      '‘’]',
    ),
    ' ',
  );
  normalized = normalized.replaceAll(RegExp(r'={2,}|-{2,}|—{2,}|_{2,}'), ' ');
  return normalized;
}

bool _isVoiceUrlLike(String value) {
  return _voiceBareDomainLikePattern.hasMatch(value.trim());
}

bool _isHospitalBagCartVoiceUrl(String value) {
  final raw = value.trim().split(RegExp(r'\s+')).first;
  if (raw.isEmpty) return false;
  final path = Uri.tryParse(raw)?.path;
  if (path != null && path.isNotEmpty) return path == _hospitalBagCartVoicePath;
  return raw.split(RegExp(r'[?#]')).first == _hospitalBagCartVoicePath;
}

int _voiceChunkLimit(int maxChars, int textLength) {
  if (textLength <= 0) return 0;
  if (maxChars <= 0) return textLength;
  if (maxChars > textLength) return textLength;
  return maxChars;
}

int _voiceChunkBoundary(String text, int maxChars) {
  final limit = _voiceChunkLimit(maxChars, text.length);
  if (limit <= 0) return 0;
  final window = text.substring(0, limit);
  final sentenceBoundary = window.lastIndexOf(RegExp(r'[。！？.!?；;]\s*'));
  if (sentenceBoundary > limit * 0.45) {
    return sentenceBoundary + 1;
  }
  final commaBoundary = window.lastIndexOf(RegExp(r'[，、,]\s*'));
  if (commaBoundary > limit * 0.65) {
    return commaBoundary + 1;
  }
  final spaceBoundary = window.lastIndexOf(' ');
  if (spaceBoundary > limit * 0.5) return spaceBoundary;
  return limit;
}

int _voiceRealtimeSegmentBoundary(
  String text, {
  required int maxSegmentChars,
  required int minSegmentChars,
  required bool force,
  required bool eager,
}) {
  if (text.isEmpty) return 0;
  final requestedMax = maxSegmentChars <= 0 ? text.length : maxSegmentChars;
  final maxChars = text.length < 24
      ? text.length
      : requestedMax.clamp(24, text.length).toInt();
  final requestedMin = minSegmentChars <= 0 ? 6 : minSegmentChars;
  final minChars = maxChars < 6
      ? maxChars
      : requestedMin.clamp(6, maxChars).toInt();
  final scanLimit = text.length < maxChars ? text.length : maxChars;

  for (var index = 0; index < scanLimit; index += 1) {
    final char = text[index];
    final cut = index + 1;
    if (_voiceRealtimeStrongBreakPattern.hasMatch(char) ||
        char == '…' ||
        char == '.') {
      if (cut >= minChars || force) return cut;
    }
    if (cut >= minChars && _voiceRealtimeSoftBreakPattern.hasMatch(char)) {
      return cut;
    }
  }

  if (text.length >= maxChars) {
    for (var index = minChars; index <= maxChars; index += 1) {
      if (_voiceRealtimeSoftBreakPattern.hasMatch(text[index - 1])) {
        return index;
      }
    }
    return maxChars;
  }

  if (eager && text.length >= minChars) return minChars;
  return force ? text.length : 0;
}

final _voiceRealtimeStrongBreakPattern = RegExp(r'[。！？；!?]');
final _voiceRealtimeSoftBreakPattern = RegExp(r'[，,、：:\s]');

bool _hasVoiceSpeakableText(String text) {
  return RegExp(r'[0-9A-Za-z\u3400-\u9fff]').hasMatch(text);
}
