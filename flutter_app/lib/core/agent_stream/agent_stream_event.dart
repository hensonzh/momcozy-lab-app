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
      type == 'RUN_FINISHED' ||
      type == 'RUN_ERROR' ||
      type == 'RUN_FAILED' ||
      type == 'ERROR' ||
      type == 'run.completed' ||
      type == 'run.failed' ||
      type == 'run.cancelled';

  String get mergeKey {
    final toolCallId = stringField(raw, 'tool_call_id');
    if (toolCallId != null && toolCallId.isNotEmpty) {
      return 'tool:$toolCallId';
    }

    final artifactId =
        stringField(raw, 'artifact_id') ?? stringField(raw, 'artifactId');
    if (artifactId != null && artifactId.isNotEmpty) {
      return 'artifact:$artifactId';
    }

    final actionId =
        stringField(raw, 'action_id') ?? stringField(raw, 'actionId');
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

List<AgentStreamEvent> parseAgentWebSocketFixtureJsonl(String input) {
  return parseJsonlMaps(input)
      .expand(
        (entry) => parseAgentWebSocketFrame(stringField(entry, 'frame') ?? ''),
      )
      .toList(growable: false);
}

List<AgentStreamEvent> parseAgentWebSocketFrame(String frame) {
  final trimmed = frame.trim();
  if (trimmed.isEmpty) return const [];
  if (trimmed.contains('data:')) return parseAgentEventStream(trimmed);
  return [parseAgentJson(trimmed)];
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
