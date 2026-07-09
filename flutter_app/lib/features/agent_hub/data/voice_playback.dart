import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

const defaultAgentVoicePcmPlayerChannelName =
    'com.momcozymai.flutter/voice_pcm_player';
const agentVoicePlaybackMaxChunkChars = 900;

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
const _hospitalBagCartVoicePath = '/hospital-bag-cart';

abstract interface class AgentVoicePcmPlayer {
  Future<void> start({int sampleRate, int channels});

  Future<void> write(List<int> bytes);

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
        await pcmPlayer.stop();
      }
    }
  }

  @override
  Future<void> stop() async {
    _playToken += 1;
    await pcmPlayer.stop();
  }
}

@visibleForTesting
String sanitizeAgentVoicePlaybackText(String text) {
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
  normalized = _stripVoiceLinks(normalized);
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
}) {
  final sanitized = sanitizeAgentVoicePlaybackText(text);
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

String _stripVoiceLinks(String text) {
  var normalized = text;
  normalized = normalized.replaceAllMapped(
    RegExp(r'!\[([^\]]*)]\(([^)]*)\)'),
    (_) => ' ',
  );
  normalized = normalized.replaceAll(RegExp(r'!\[[^\]]*]\s*\[[^\]]*]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'!\[[^\]]*]\([^)]*$'), ' ');
  normalized = normalized.replaceAll(RegExp(r'!\[[^\]]*]?\s*$'), ' ');
  normalized = normalized.replaceAllMapped(RegExp(r'\[([^\]]*)]\(([^)]*)\)'), (
    match,
  ) {
    final label = (match.group(1) ?? '').trim();
    final destination = (match.group(2) ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
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
  normalized = normalized.replaceAllMapped(
    _voiceMediaPathPattern,
    (match) => '${match.group(1) ?? ''} ',
  );
  normalized = normalized.replaceAll(
    RegExp(r'<(?:https?|ftp):\/\/[^>\s]+>', caseSensitive: false),
    ' ',
  );
  normalized = normalized.replaceAll(_voiceBareUrlPattern, ' ');
  normalized = normalized.replaceAllMapped(
    _voiceAppRoutePattern,
    (match) => '${match.group(1) ?? ''} ',
  );
  normalized = normalized.replaceAllMapped(
    _voiceHashOrQueryUrlPattern,
    (match) => '${match.group(1) ?? ''} ',
  );
  normalized = normalized.replaceAll(_voiceBareDomainPattern, ' ');
  normalized = normalized.replaceAllMapped(
    RegExp(r'(^|[\s(（\[])[)\]](?=($|[\s，。！？；、,.!?;:]))', multiLine: true),
    (match) => '${match.group(1) ?? ''} ',
  );
  return normalized;
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
