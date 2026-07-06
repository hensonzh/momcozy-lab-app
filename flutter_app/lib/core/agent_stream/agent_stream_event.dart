import 'dart:convert';

class AgentStreamEvent {
  AgentStreamEvent(this.raw);

  final Map<String, Object?> raw;

  String get type => stringField(raw, 'type') ?? 'CUSTOM';
  String? get threadId =>
      stringField(raw, 'thread_id') ?? stringField(raw, 'threadId');
  String? get runId => stringField(raw, 'run_id') ?? stringField(raw, 'runId');
  String? get messageId =>
      stringField(raw, 'message_id') ?? stringField(raw, 'messageId');
  Map<String, Object?> get payload {
    final value = raw['payload'];
    return value is Map ? Map<String, Object?>.from(value) : const {};
  }

  String? get textDelta =>
      stringField(raw, 'delta') ??
      stringField(raw, 'text') ??
      stringField(payload, 'delta') ??
      stringField(payload, 'text');
  String? get completedText =>
      textDelta ??
      _messageText(raw['content']) ??
      _messageText(payload['content']) ??
      _messageText(raw['message']) ??
      _messageText(payload['message']) ??
      _messagesText(raw['messages']) ??
      _messagesText(payload['messages']);
  String? get eventId =>
      stringField(raw, 'event_id') ?? stringField(raw, 'eventId');

  String? get replayKey {
    final id = eventId?.trim();
    if (id != null && id.isNotEmpty) return 'event:$id';

    final sequence = raw['sequence'] ?? raw['seq'];
    final sequenceText = switch (sequence) {
      int value => value.toString(),
      String value => value.trim(),
      _ => '',
    };
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
    final toolCallId =
        stringField(raw, 'tool_call_id') ??
        stringField(raw, 'toolCallId') ??
        stringField(payload, 'tool_call_id') ??
        stringField(payload, 'toolCallId');
    if (toolCallId != null && toolCallId.isNotEmpty) {
      return 'tool:$toolCallId';
    }

    final artifactId =
        stringField(raw, 'artifact_id') ?? stringField(raw, 'artifactId');
    if (artifactId != null && artifactId.isNotEmpty) {
      return 'artifact:$artifactId';
    }

    final actionId =
        stringField(raw, 'action_id') ??
        stringField(raw, 'actionId') ??
        stringField(payload, 'action_id') ??
        stringField(payload, 'actionId');
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
    final data = block
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .join('\n')
        .trim();
    if (data.isNotEmpty) events.add(parseAgentJson(data));
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

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}
