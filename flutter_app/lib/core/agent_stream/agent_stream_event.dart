import 'dart:convert';

class AgentStreamEvent {
  AgentStreamEvent(this.raw);

  final Map<String, Object?> raw;

  String get type => _normalizedEventType(raw);
  String? get threadId =>
      stringField(raw, 'thread_id') ?? stringField(raw, 'threadId');
  String? get runId => stringField(raw, 'run_id') ?? stringField(raw, 'runId');
  String? get messageId =>
      stringField(raw, 'message_id') ??
      stringField(raw, 'messageId') ??
      stringField(payload, 'message_id') ??
      stringField(payload, 'messageId') ??
      stringField(payload, 'message_stream_id') ??
      stringField(payload, 'messageStreamId');
  String? get toolCallId =>
      stringField(raw, 'tool_call_id') ??
      stringField(raw, 'toolCallId') ??
      stringField(payload, 'tool_call_id') ??
      stringField(payload, 'toolCallId');
  String? get artifactId =>
      stringField(raw, 'artifact_id') ??
      stringField(raw, 'artifactId') ??
      stringField(payload, 'artifact_id') ??
      stringField(payload, 'artifactId');
  String? get actionId =>
      stringField(raw, 'action_id') ??
      stringField(raw, 'actionId') ??
      stringField(payload, 'action_id') ??
      stringField(payload, 'actionId');
  String? get role => stringField(raw, 'role') ?? stringField(payload, 'role');
  Map<String, Object?> get payload {
    final value = raw['payload'];
    if (value is Map) return Map<String, Object?>.from(value);
    if (type == 'run.progress') {
      final customValue = raw['value'];
      if (customValue is Map) return Map<String, Object?>.from(customValue);
    }
    return const {};
  }

  Map<String, Object?> get semantic {
    for (final value in [payload['semantic'], raw['semantic']]) {
      if (value is Map) return Map<String, Object?>.from(value);
    }
    return const {};
  }

  String? get semanticLabel =>
      stringField(semantic, 'label') ?? stringField(semantic, 'title');
  String? get semanticSurface => stringField(semantic, 'surface');
  String? get semanticVisibility => stringField(semantic, 'visibility');
  String? get semanticLifecycle => stringField(semantic, 'lifecycle');
  String? get semanticMergeKey => stringField(semantic, 'merge_key');

  String? get textDelta {
    if (type != 'message.delta') return null;
    return stringField(raw, 'delta') ??
        stringField(raw, 'text') ??
        stringField(payload, 'delta') ??
        stringField(payload, 'text');
  }

  String? get completedText {
    if (type != 'message.completed') return null;
    return cleanAgentAssistantText(_rawCompletedText);
  }

  List<String> get quickReplies {
    for (final source in [
      raw['quick_replies'],
      raw['quickReplies'],
      payload['replies'],
      payload['quick_replies'],
      payload['quickReplies'],
      _messageQuickReplies(raw['message']),
      _messageQuickReplies(payload['message']),
    ]) {
      final replies = _quickReplyTexts(source);
      if (replies.isNotEmpty) return replies;
    }
    return const <String>[];
  }

  String? get _rawCompletedText {
    if (type != 'message.completed') return null;
    return stringField(raw, 'text') ??
        stringField(payload, 'text') ??
        _messageText(raw['content']) ??
        _messageText(payload['content']) ??
        _messageText(raw['message']) ??
        _messageText(payload['message']) ??
        _messagesText(raw['messages']) ??
        _messagesText(payload['messages']);
  }

  String? get eventId =>
      stringField(raw, 'event_id') ?? stringField(raw, 'eventId');
  int? get sequence {
    final value = raw['sequence'] ?? raw['seq'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String? get cursor =>
      stringField(raw, 'cursor') ?? stringField(payload, 'cursor');

  bool get isTransient =>
      raw['transient'] == true ||
      payload['transient'] == true ||
      (eventId?.startsWith('delta:') ?? false);

  String? get replayKey {
    final id = eventId?.trim();
    if (id != null && id.isNotEmpty) return 'event:$id';

    final sequenceText = sequence?.toString() ?? '';
    if (sequenceText.isEmpty) return null;

    final scope = runId ?? threadId ?? messageId ?? 'global';
    return 'sequence:$scope:$sequenceText';
  }

  bool get isTerminal =>
      type == 'run.completed' ||
      type == 'run.waiting_for_confirmation' ||
      type == 'run.failed' ||
      type == 'run.cancelled';

  String get mergeKey {
    final toolCallId = this.toolCallId;
    if (toolCallId != null && toolCallId.isNotEmpty) {
      return 'tool:$toolCallId';
    }

    final artifactId = this.artifactId;
    if (artifactId != null && artifactId.isNotEmpty) {
      return 'artifact:$artifactId';
    }

    final actionId = this.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      return 'action:$actionId';
    }

    if (messageId != null && messageId!.isNotEmpty) {
      return 'message:${messageId!}';
    }

    if (runId != null && runId!.isNotEmpty) {
      return 'run:${runId!}:$type';
    }

    return type;
  }
}

List<AgentStreamEvent> parseAgentJsonl(String input) {
  return input
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(parseAgentJson)
      .toList(growable: false);
}

List<AgentStreamEvent> parseAgentEventStream(String input) {
  final blocks = input.split(RegExp(r'\r?\n\r?\n'));
  final events = <AgentStreamEvent>[];

  for (final block in blocks) {
    final lines = block.split(RegExp(r'\r?\n'));
    String? id;
    for (final line in lines) {
      if (!line.startsWith('id:')) continue;
      final candidate = line.substring(3).trim();
      if (candidate.isEmpty) continue;
      id = candidate;
      break;
    }
    final data = lines
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .join('\n')
        .trim();
    if (data.isEmpty) continue;
    final event = parseAgentJson(data);
    if (id == null) {
      events.add(event);
      continue;
    }
    final eventId = id;
    final raw = Map<String, Object?>.from(event.raw);
    raw.putIfAbsent('event_id', () => _sseReplayId(eventId, raw));
    final sequence = int.tryParse(eventId);
    if (sequence != null) raw.putIfAbsent('sequence', () => sequence);
    events.add(AgentStreamEvent(raw));
  }

  return events;
}

AgentStreamEvent parseAgentJson(String input) {
  final decoded = jsonDecode(input);
  if (decoded is! Map) {
    throw const FormatException('Agent stream event must be a JSON object.');
  }
  return AgentStreamEvent(Map<String, Object?>.from(decoded));
}

List<Map<String, Object?>> parseJsonlMaps(String input) {
  return input
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          throw const FormatException('JSONL line must be a JSON object.');
        }
        return Map<String, Object?>.from(decoded);
      })
      .toList(growable: false);
}

String? stringField(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}

String _normalizedEventType(Map<String, Object?> raw) {
  return stringField(raw, 'type') ?? 'unknown';
}

String _sseReplayId(String id, Map<String, Object?> raw) {
  final parts = [
    'sse',
    id,
    stringField(raw, 'type') ?? 'unknown',
    stringField(raw, 'message_id') ?? stringField(raw, 'messageId'),
    stringField(raw, 'tool_call_id') ?? stringField(raw, 'toolCallId'),
    stringField(raw, 'artifact_id') ?? stringField(raw, 'artifactId'),
    stringField(raw, 'action_id') ??
        stringField(raw, 'confirmation_id') ??
        stringField(raw, 'actionId'),
    stringField(raw, 'name'),
  ].whereType<String>().where((part) => part.trim().isNotEmpty);
  return parts.join(':');
}

String? _messagesText(Object? rawMessages) {
  if (rawMessages is! List) return null;
  final messages = rawMessages.whereType<Map>().map(
    (message) => Map<String, Object?>.from(message),
  );
  final assistantMessages = messages.where(
    (message) => stringField(message, 'role') == 'assistant',
  );
  for (final message in assistantMessages.followedBy(messages)) {
    final text = _messageText(message);
    if (text != null) return text;
  }
  return null;
}

String? _messageText(Object? rawMessage) {
  if (rawMessage is String) return _nonEmpty(rawMessage);
  if (rawMessage is List) {
    final parts = rawMessage
        .map(_messageText)
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join();
    return _nonEmpty(parts);
  }
  if (rawMessage is! Map) return null;

  final message = Map<String, Object?>.from(rawMessage);
  return _nonEmpty(
        stringField(message, 'text') ??
            stringField(message, 'value') ??
            stringField(message, 'output_text'),
      ) ??
      _messageText(message['content']) ??
      _messageText(message['parts']) ??
      _messageText(message['text']);
}

Object? _messageQuickReplies(Object? rawMessage) {
  if (rawMessage is! Map) return null;
  final message = Map<String, Object?>.from(rawMessage);
  return message['quick_replies'] ??
      message['quickReplies'] ??
      message['replies'];
}

List<String> _quickReplyTexts(Object? rawReplies) {
  if (rawReplies is! List) return const <String>[];
  final replies = <String>[];
  final seen = <String>{};
  for (final item in rawReplies) {
    final text = switch (item) {
      String value => value.trim(),
      Map value => (value['text']?.toString() ?? '').trim(),
      _ => '',
    };
    if (text.isEmpty || seen.contains(text)) continue;
    seen.add(text);
    replies.add(text);
  }
  return List<String>.unmodifiable(replies);
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}

String? cleanAgentAssistantText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final cleaned = _removeStructuredJsonChunks(text)
      .replaceAll(RegExp(r'```(?:json)?\s*```', caseSensitive: false), '')
      .replaceAll(
        RegExp(
          r'^\s*(快捷回复|推荐回复|quick replies|quick_replies|replies)\s*[:：]\s*$',
          multiLine: true,
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

String _removeStructuredJsonChunks(String text) {
  final output = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char == '{' || char == '[') {
      final end = _balancedJsonEnd(text, index);
      if (end != null) {
        final chunk = text.substring(index, end);
        final decoded = _tryDecodeJson(chunk);
        if (_looksLikeStructuredAgentJson(decoded)) {
          final replacement = _textFromStructuredJson(decoded);
          if (replacement != null && replacement.isNotEmpty) {
            output.write(replacement);
          }
          index = end;
          continue;
        }
      }
    }
    output.write(char);
    index += 1;
  }
  return output.toString();
}

int? _balancedJsonEnd(String text, int start) {
  final opening = text[start];
  final stack = <String>[opening == '{' ? '}' : ']'];
  var inString = false;
  var escaped = false;
  for (var index = start + 1; index < text.length; index += 1) {
    final char = text[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{' || char == '[') {
      stack.add(char == '{' ? '}' : ']');
    } else if (stack.isNotEmpty && char == stack.last) {
      stack.removeLast();
      if (stack.isEmpty) return index + 1;
    }
  }
  return null;
}

Object? _tryDecodeJson(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

bool _looksLikeStructuredAgentJson(Object? value) {
  if (value is List) {
    return value.isNotEmpty &&
        value.whereType<Object>().every(_looksLikeStructuredAgentJson);
  }
  if (value is! Map) return false;
  final keys = value.keys.map((key) => key.toString()).toSet();
  const structuredKeys = {
    'tool_call_id',
    'tool_name',
    'safe_args',
    'safe_output',
    'service_skill_id',
    'skill_version',
    'tool_scope',
    'business_facts',
    'display_name',
    'profile',
    'quick_replies',
    'quickReplies',
    'replies',
  };
  if (keys.intersection(structuredKeys).isNotEmpty) return true;
  final status = value['status']?.toString() ?? '';
  return status == 'service_skill_loaded' ||
      status == 'quick_replies_ready' ||
      status.startsWith('needs_');
}

String? _textFromStructuredJson(Object? value) {
  if (value is! Map) return null;
  for (final key in [
    'text',
    'message',
    'final_text',
    'finalText',
    'assistant_response',
    'assistantResponse',
    'response',
  ]) {
    final raw = value[key];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  }
  return null;
}
