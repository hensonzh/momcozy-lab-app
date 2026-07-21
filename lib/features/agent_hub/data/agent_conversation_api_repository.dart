import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';

const agentConversationsEndpoint = '/v1/agent/threads';

class AgentConversationApiRepository implements AgentConversationRepository {
  const AgentConversationApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<AgentConversationSummary>> listConversations({
    int limit = 50,
  }) async {
    final response = await transport.getJson(
      agentConversationsEndpoint,
      query: {'limit': limit.clamp(1, 100)},
    );
    final items = response['items'];
    if (items is! List) return const <AgentConversationSummary>[];
    return List<AgentConversationSummary>.unmodifiable(
      items.map(_conversationFromValue).whereType<AgentConversationSummary>(),
    );
  }

  @override
  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  }) async {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw const FormatException('Conversation thread id is required.');
    }

    final response = await transport.getJson(
      '$agentConversationsEndpoint/${Uri.encodeComponent(normalizedThreadId)}/history',
      query: {'limit': limit.clamp(1, 50), 'before_sequence': ?beforeSequence},
    );
    final thread = _conversationFromValue(response['thread']);
    if (thread == null || thread.id != normalizedThreadId) {
      throw const FormatException('Conversation history thread mismatch.');
    }

    final messages = <_ConversationWireMessage>[];
    final eventsByKey = <String, AgentStreamEvent>{};
    final pageMessages = response['items'];
    if (pageMessages is List) {
      messages.addAll(
        pageMessages
            .map(_wireMessageFromValue)
            .whereType<_ConversationWireMessage>(),
      );
    }
    final pageEvents = response['events'];
    if (pageEvents is List) {
      for (final rawEvent in pageEvents) {
        if (rawEvent is! Map) continue;
        final event = AgentStreamEvent(Map<String, Object?>.from(rawEvent));
        eventsByKey[_eventKey(event)] = event;
      }
    }
    final nextCursor = _int(response['next_before_sequence']);
    if (nextCursor != null && nextCursor == beforeSequence) {
      throw const FormatException('Conversation history cursor repeated.');
    }

    return _buildConversationHistory(
      thread: thread,
      messages: messages,
      events: eventsByKey.values,
      nextBeforeSequence: nextCursor,
    );
  }
}

AgentConversationHistory _buildConversationHistory({
  required AgentConversationSummary thread,
  required List<_ConversationWireMessage> messages,
  required Iterable<AgentStreamEvent> events,
  int? nextBeforeSequence,
}) {
  final eventsByRun = <String, List<AgentStreamEvent>>{};
  for (final event in events) {
    final runId = event.runId?.trim();
    if (runId == null || runId.isEmpty) continue;
    eventsByRun.putIfAbsent(runId, () => <AgentStreamEvent>[]).add(event);
  }
  for (final runEvents in eventsByRun.values) {
    runEvents.sort(
      (left, right) => (left.sequence ?? 0).compareTo(right.sequence ?? 0),
    );
  }

  final latestRunId = messages.reversed
      .map((message) => message.runId?.trim())
      .whereType<String>()
      .firstWhere((runId) => runId.isNotEmpty, orElse: () => '');
  final assistantByRun = <String, _ConversationWireMessage>{};
  for (final message in messages) {
    final runId = message.runId?.trim();
    if (message.role == AgentConversationMessageRole.assistant &&
        runId != null &&
        runId.isNotEmpty) {
      assistantByRun[runId] = message;
    }
  }

  final statesByRun = <String, AgentStreamRunState>{};
  for (final runId in {
    ...eventsByRun.keys,
    ...messages.map((message) => message.runId).whereType<String>(),
  }) {
    var state = const AgentStreamRunState().start();
    for (final event in eventsByRun[runId] ?? const <AgentStreamEvent>[]) {
      state = state.applyEvent(event);
    }
    final assistant = assistantByRun[runId];
    final hasAssistant = assistant != null;
    final phase = hasAssistant && state.isActive
        ? AgentStreamRunPhase.finished
        : state.phase;
    statesByRun[runId] = state.copyWith(
      phase: phase,
      threadId: thread.id,
      runId: runId,
      messageId: assistant?.id,
      textContent: hasAssistant ? assistant.content : state.textContent,
      completedAssistantMessageReceived:
          hasAssistant || state.completedAssistantMessageReceived,
    );
  }

  final latestAssistant = assistantByRun[latestRunId];
  final historyMessages = <AgentConversationMessage>[];
  for (final message in messages) {
    if (identical(message, latestAssistant)) continue;
    final messageRunId = message.runId;
    historyMessages.add(
      AgentConversationMessage(
        role: message.role,
        content: message.content,
        images: message.images,
        files: message.files,
        runState:
            message.role == AgentConversationMessageRole.assistant &&
                message.runId != null
            ? statesByRun[message.runId]
            : null,
      ),
    );
    if (message.role == AgentConversationMessageRole.user &&
        messageRunId != null &&
        messageRunId != latestRunId &&
        !assistantByRun.containsKey(messageRunId)) {
      final projectedState = statesByRun[messageRunId];
      if (projectedState != null &&
          hasAgentConversationAssistantProjection(projectedState)) {
        historyMessages.add(
          AgentConversationMessage(
            role: AgentConversationMessageRole.assistant,
            content: projectedState.textContent,
            runState: projectedState,
          ),
        );
      }
    }
  }

  final currentState = latestRunId.isEmpty
      ? AgentStreamRunState(threadId: thread.id)
      : statesByRun[latestRunId] ??
            AgentStreamRunState(
              phase: latestAssistant == null
                  ? AgentStreamRunPhase.streaming
                  : AgentStreamRunPhase.finished,
              threadId: thread.id,
              runId: latestRunId,
              messageId: latestAssistant?.id,
              textContent: latestAssistant?.content ?? '',
              completedAssistantMessageReceived: latestAssistant != null,
            );

  return AgentConversationHistory(
    thread: thread,
    messages: List<AgentConversationMessage>.unmodifiable(historyMessages),
    currentState: currentState,
    nextBeforeSequence: nextBeforeSequence,
  );
}

AgentConversationSummary? _conversationFromValue(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final id = _string(map['id']).trim();
  final createdAt = DateTime.tryParse(_string(map['created_at']));
  final updatedAt = DateTime.tryParse(_string(map['updated_at']));
  if (id.isEmpty || createdAt == null || updatedAt == null) return null;
  final title = _string(map['title']).trim();
  return AgentConversationSummary(
    id: id,
    title: title.isEmpty ? '未命名会话' : title,
    status: _string(map['status']).trim(),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

_ConversationWireMessage? _wireMessageFromValue(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final id = _string(map['id']).trim();
  final role = _string(map['role']) == 'user'
      ? AgentConversationMessageRole.user
      : AgentConversationMessageRole.assistant;
  final content = map['content'];
  final contentMap = content is Map
      ? Map<String, Object?>.from(content)
      : const <String, Object?>{};
  final images = _imagesFromAttachments(contentMap['attachments']);
  final files = _filesFromAttachments(contentMap['attachments']);
  final text = _string(contentMap['text']).trim();
  if (id.isEmpty || (text.isEmpty && images.isEmpty && files.isEmpty)) {
    return null;
  }
  final runId = _string(map['run_id']).trim();
  return _ConversationWireMessage(
    id: id,
    runId: runId.isEmpty ? null : runId,
    role: role,
    content: text,
    images: images,
    files: files,
  );
}

List<AgentStreamImageInput> _imagesFromAttachments(Object? value) {
  if (value is! List) return const <AgentStreamImageInput>[];
  final images = <AgentStreamImageInput>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, Object?>.from(item);
    if (_string(map['type']).trim() != 'image') continue;
    final fileId = _string(map['file_id'] ?? map['fileId']).trim();
    if (fileId.isEmpty) continue;
    final mimeType = _string(
      map['content_type'] ?? map['mime_type'] ?? map['mimeType'],
    ).trim();
    final name = _string(map['name'] ?? map['original_filename']).trim();
    final detail = _string(map['detail']).trim();
    images.add(
      AgentStreamImageInput(
        dataUrl: '',
        fileId: fileId,
        mimeType: mimeType.isEmpty ? 'image/png' : mimeType,
        name: name.isEmpty ? 'image.png' : name,
        size: _int(map['size']) ?? 0,
        detail: detail.isEmpty ? 'auto' : detail,
      ),
    );
  }
  return List<AgentStreamImageInput>.unmodifiable(images);
}

List<AgentStreamFileInput> _filesFromAttachments(Object? value) {
  if (value is! List) return const <AgentStreamFileInput>[];
  final files = <AgentStreamFileInput>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, Object?>.from(item);
    if (_string(map['type']).trim() != 'file') continue;
    final fileId = _string(map['file_id'] ?? map['fileId']).trim();
    if (fileId.isEmpty) continue;
    final mimeType = _string(
      map['content_type'] ?? map['mime_type'] ?? map['mimeType'],
    ).trim();
    final name = _string(map['name'] ?? map['original_filename']).trim();
    files.add(
      AgentStreamFileInput(
        fileId: fileId,
        mimeType: mimeType.isEmpty ? 'application/pdf' : mimeType,
        name: name.isEmpty ? 'document.pdf' : name,
        size: _int(map['size']) ?? 0,
      ),
    );
  }
  return List<AgentStreamFileInput>.unmodifiable(files);
}

String _eventKey(AgentStreamEvent event) {
  final eventId = event.eventId?.trim();
  if (eventId != null && eventId.isNotEmpty) return 'event:$eventId';
  return 'run:${event.runId}:${event.sequence}:${event.type}';
}

String _string(Object? value) => value is String ? value : '';

int? _int(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

class _ConversationWireMessage {
  const _ConversationWireMessage({
    required this.id,
    required this.runId,
    required this.role,
    required this.content,
    required this.images,
    required this.files,
  });

  final String id;
  final String? runId;
  final AgentConversationMessageRole role;
  final String content;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
}
