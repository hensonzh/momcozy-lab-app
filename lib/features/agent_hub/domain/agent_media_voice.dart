import 'dart:convert';

import 'package:app/core/agent_stream/agent_stream_event.dart';

const _deviceGuidanceImageSpokenLabel = '我放了一张当前步骤的对照图，你可以边看图边完成这一步。';
final _deviceGuidanceImagePathPattern = RegExp(
  r'^/skill-assets/device-guidance/[^/]+/images/[^?#]+\.(?:png|jpe?g|webp|gif|svg)(?:[?#].*)?$',
  caseSensitive: false,
);

enum AgentMediaVoicePolicy { silent, announce, describeOnRequest, readText }

class AgentMediaVoiceNarration {
  const AgentMediaVoiceNarration({
    required this.voicePolicy,
    this.mediaId,
    this.kind,
    this.visualLabel,
    this.accessibilityLabel,
    this.spokenLabel,
    this.spokenDetail,
    this.priority,
  });

  factory AgentMediaVoiceNarration.fromMap(Map<String, Object?> map) {
    return AgentMediaVoiceNarration(
      mediaId: _firstText(map, const ['mediaId', 'media_id', 'id', 'url']),
      kind: _firstText(map, const ['kind', 'type']),
      visualLabel: _firstText(map, const [
        'visualLabel',
        'visual_label',
        'title',
        'alt',
      ]),
      accessibilityLabel: _firstText(map, const [
        'accessibilityLabel',
        'accessibility_label',
      ]),
      spokenLabel: _firstText(map, const ['spokenLabel', 'spoken_label']),
      spokenDetail: _firstText(map, const ['spokenDetail', 'spoken_detail']),
      voicePolicy: _voicePolicy(map['voicePolicy'] ?? map['voice_policy']),
      priority: _firstText(map, const ['priority']),
    );
  }

  final String? mediaId;
  final String? kind;
  final String? visualLabel;
  final String? accessibilityLabel;
  final String? spokenLabel;
  final String? spokenDetail;
  final AgentMediaVoicePolicy voicePolicy;
  final String? priority;

  bool get isAutoSpeakable =>
      voicePolicy == AgentMediaVoicePolicy.announce ||
      voicePolicy == AgentMediaVoicePolicy.readText;

  String? get spokenText {
    final label = spokenLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final detail = spokenDetail?.trim();
    return detail != null && detail.isNotEmpty ? detail : null;
  }

  String get dedupeKey => [
    voicePolicy.name,
    mediaId ?? '',
    spokenLabel ?? '',
    spokenDetail ?? '',
  ].join(':');
}

class AgentMediaVoiceNarrationIndex {
  AgentMediaVoiceNarrationIndex._(this.items) {
    for (final item in items) {
      final mediaId = item.mediaId;
      if (mediaId == null || mediaId.isEmpty) continue;
      final keys = agentMediaVoiceLookupKeys(mediaId);
      _knownMediaKeys.addAll(keys);
      final spoken = item.isAutoSpeakable ? item.spokenText : null;
      if (spoken == null) continue;
      for (final key in keys) {
        _spokenByMediaKey[key] = spoken;
      }
    }
  }

  factory AgentMediaVoiceNarrationIndex.fromEvents(
    Iterable<AgentStreamEvent> events,
  ) {
    final items = <AgentMediaVoiceNarration>[];
    final seen = <String>{};
    for (final event in events) {
      for (final rawItem in _mediaVoiceItemsFromEvent(event)) {
        final item = AgentMediaVoiceNarration.fromMap(rawItem);
        if (!seen.add(item.dedupeKey)) continue;
        items.add(item);
      }
    }
    return AgentMediaVoiceNarrationIndex._(
      List<AgentMediaVoiceNarration>.unmodifiable(items),
    );
  }

  final List<AgentMediaVoiceNarration> items;
  final Map<String, String> _spokenByMediaKey = {};
  final Set<String> _knownMediaKeys = {};

  List<String> get autoSpeakableTexts {
    final texts = <String>[];
    final seen = <String>{};
    for (final item in items) {
      if (!item.isAutoSpeakable) continue;
      final text = item.spokenText?.trim();
      if (text == null || text.isEmpty || !seen.add(text)) continue;
      texts.add(text);
    }
    return List<String>.unmodifiable(texts);
  }

  String? resolve(String mediaId) {
    final keys = agentMediaVoiceLookupKeys(mediaId);
    for (final key in keys) {
      final spoken = _spokenByMediaKey[key];
      if (spoken != null && spoken.isNotEmpty) return spoken;
    }
    if (keys.any(_knownMediaKeys.contains)) return null;
    return fallbackAgentMediaVoiceNarration(mediaId);
  }
}

List<String> agentMediaVoiceLookupKeys(String? mediaId) {
  final raw = mediaId?.trim();
  if (raw == null || raw.isEmpty) return const [];
  final keys = <String>[];

  void add(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || keys.contains(text)) return;
    keys.add(text);
  }

  add(raw);
  final uri = Uri.tryParse(raw);
  if (uri != null) {
    final path = uri.path;
    final pathWithQuery = uri.hasQuery ? '$path?${uri.query}' : path;
    add(pathWithQuery);
    add(path);
    if (uri.hasFragment) add('$pathWithQuery#${uri.fragment}');
    try {
      add(Uri.decodeFull(pathWithQuery));
      add(Uri.decodeFull(path));
    } on FormatException {
      // Encoded lookup keys remain available.
    }
  } else {
    add(raw.split('#').first);
    add(raw.split('#').first.split('?').first);
  }
  return List<String>.unmodifiable(keys);
}

String? fallbackAgentMediaVoiceNarration(String? mediaId) {
  for (final key in agentMediaVoiceLookupKeys(mediaId)) {
    if (_deviceGuidanceImagePathPattern.hasMatch(key)) {
      return _deviceGuidanceImageSpokenLabel;
    }
  }
  return null;
}

Iterable<Map<String, Object?>> _mediaVoiceItemsFromEvent(
  AgentStreamEvent event,
) sync* {
  final queue = <Map<String, Object?>>[
    event.raw,
    event.payload,
    ?_decodedMap(event.raw['content']),
  ];
  const nestedKeys = [
    'safe_output',
    'safeOutput',
    'tool_result',
    'toolResult',
    'result',
    'output',
    'rich_text',
    'richText',
    'artifact',
    'payload',
  ];
  for (var index = 0; index < queue.length && index < 24; index += 1) {
    final source = queue[index];
    for (final key in const ['media_voice', 'mediaVoice', 'voice']) {
      final value = source[key];
      if (value is! List) continue;
      for (final item in value) {
        if (item is Map) yield Map<String, Object?>.from(item);
      }
    }
    for (final key in nestedKeys) {
      final nested = source[key];
      if (nested is Map) queue.add(Map<String, Object?>.from(nested));
      if (nested is String) {
        final decoded = _decodedMap(nested);
        if (decoded != null) queue.add(decoded);
      }
    }
  }
}

Map<String, Object?>? _decodedMap(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

AgentMediaVoicePolicy _voicePolicy(Object? value) {
  return switch (value?.toString().trim()) {
    'announce' => AgentMediaVoicePolicy.announce,
    'describe_on_request' => AgentMediaVoicePolicy.describeOnRequest,
    'read_text' => AgentMediaVoicePolicy.readText,
    _ => AgentMediaVoicePolicy.silent,
  };
}

String? _firstText(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
