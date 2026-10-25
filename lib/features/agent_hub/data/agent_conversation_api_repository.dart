import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_welcome.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_poop_task.dart';

const agentConversationsEndpoint = '/v1/agent/threads';

class AgentConversationApiRepository
    implements AgentConversationRepository, AgentConversationThreadCreator {
  const AgentConversationApiRepository({
    required this.transport,
    this.identifyWelcomeBoundary = false,
  });

  final ApiJsonTransport transport;
  final bool identifyWelcomeBoundary;

  @override
  Future<String> createConversation() async {
    final response = await transport.postJson(
      agentConversationsEndpoint,
      body: {'title': '宝宝哭声'},
    );
    final id = response['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Invalid conversation thread.');
    }
    return id;
  }

  @override
  Future<AgentConversationHistory?> loadLatestConversation() async {
    final response = await transport.getJson(
      agentConversationsEndpoint,
      query: {'limit': 20},
    );
    final items = response['items'];
    if (items is! List) return null;
    for (final item in items) {
      final thread = _conversationFromValue(item);
      if (thread == null) continue;
      final history = await loadConversation(thread.id);
      if (history.messages.isNotEmpty || history.currentState.runId != null) {
        return history;
      }
    }
    return null;
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
    // A page can start with an assistant reply while its user trigger sits
    // just before the cursor. The adjacent completed user message identifies
    // the run without guessing from the model's reply text.
    final first = messages.firstOrNull;
    String? boundaryWelcomeRunId;
    String? boundaryWelcomeKey;
    if (identifyWelcomeBoundary &&
        first?.role == AgentConversationMessageRole.assistant &&
        first?.runId != null &&
        (first?.sequence ?? 0) > 1) {
      final preceding = await transport.getJson(
        '$agentConversationsEndpoint/${Uri.encodeComponent(normalizedThreadId)}/history',
        query: {'limit': 1, 'before_sequence': first!.sequence},
      );
      final precedingThread = _conversationFromValue(preceding['thread']);
      if (precedingThread?.id != normalizedThreadId ||
          preceding['items'] is! List) {
        throw const FormatException(
          'Conversation history boundary is invalid.',
        );
      }
      final previousItems = preceding['items'] as List;
      if (previousItems.length == 1) {
        final previous = _wireMessageFromValue(previousItems.single);
        if (previous?.runId == first.runId &&
            previous?.isChatFirstWelcomeTrigger == true) {
          boundaryWelcomeRunId = first.runId;
          boundaryWelcomeKey = previous?.chatFirstWelcomeKey;
        }
      }
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
      boundaryWelcomeRunId: boundaryWelcomeRunId,
      boundaryWelcomeKey: boundaryWelcomeKey,
    );
  }
}

AgentConversationHistory _buildConversationHistory({
  required AgentConversationSummary thread,
  required List<_ConversationWireMessage> messages,
  required Iterable<AgentStreamEvent> events,
  int? nextBeforeSequence,
  String? boundaryWelcomeRunId,
  String? boundaryWelcomeKey,
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
  final welcomeRunIds =
      messages
          .where((message) => message.isChatFirstWelcomeTrigger)
          .map((message) => message.runId)
          .whereType<String>()
          .toSet()
        ..addAll([?boundaryWelcomeRunId]);
  final welcomeKeysByRun = <String, String>{
    for (final message in messages)
      if (message.isChatFirstWelcomeTrigger &&
          message.runId != null &&
          message.chatFirstWelcomeKey != null)
        message.runId!: message.chatFirstWelcomeKey!,
    if (boundaryWelcomeRunId != null && boundaryWelcomeKey != null)
      boundaryWelcomeRunId: boundaryWelcomeKey,
  };
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
    final runEvents = eventsByRun[runId] ?? const <AgentStreamEvent>[];
    var state = runEvents.isEmpty
        ? const AgentStreamRunState()
        : const AgentStreamRunState().start();
    for (final event in runEvents) {
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
    if (!message.hiddenAutomation) {
      historyMessages.add(
        AgentConversationMessage(
          id: message.id,
          runId: message.runId,
          sequence: message.sequence,
          createdAt: message.createdAt,
          role: message.role,
          content: message.isChatFirstPoopTrigger ? '' : message.content,
          images: message.isChatFirstPoopTrigger ? const [] : message.images,
          files: message.files,
          isChatFirstPoopTrigger: message.isChatFirstPoopTrigger,
          runState:
              message.role == AgentConversationMessageRole.assistant &&
                  message.runId != null
              ? statesByRun[message.runId]
              : null,
          isChatFirstWelcome:
              message.role == AgentConversationMessageRole.assistant &&
              welcomeRunIds.contains(message.runId),
          chatFirstWelcomeKey: welcomeKeysByRun[message.runId],
        ),
      );
    }
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
            id: projectedState.messageId ?? 'run:$messageRunId:assistant',
            runId: messageRunId,
            sequence: message.sequence,
            createdAt: message.createdAt,
            content: projectedState.textContent,
            runState: projectedState,
            isChatFirstWelcome: welcomeRunIds.contains(messageRunId),
            chatFirstWelcomeKey: welcomeKeysByRun[messageRunId],
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
    latestMessageCreatedAt: messages.isEmpty ? null : messages.last.createdAt,
    currentRunIsChatFirstWelcome: welcomeRunIds.contains(latestRunId),
    currentWelcomeKey: welcomeKeysByRun[latestRunId],
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
    title: title.isEmpty ? 'Untitled conversation' : title,
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
  final clientContext = contentMap['client_context'];
  final source = clientContext is Map
      ? _string(clientContext['source']).trim()
      : '';
  return _ConversationWireMessage(
    id: id,
    sequence: _int(map['sequence']),
    createdAt: DateTime.tryParse(_string(map['created_at'])),
    runId: runId.isEmpty ? null : runId,
    role: role,
    content: text,
    images: images,
    files: files,
    hiddenAutomation:
        role == AgentConversationMessageRole.user &&
        (source == 'motion_assessment_completion' ||
            source == 'chat_first_welcome' ||
            isMotionAssessmentCompletionPrompt(text) ||
            isChatFirstWelcomePrompt(text)),
    isChatFirstPoopTrigger:
        role == AgentConversationMessageRole.user &&
        isChatFirstPoopPrompt(text),
    isChatFirstWelcomeTrigger:
        role == AgentConversationMessageRole.user &&
        (source == 'chat_first_welcome' || isChatFirstWelcomePrompt(text)),
    chatFirstWelcomeKey: role == AgentConversationMessageRole.user
        ? chatFirstWelcomeKeyForPrompt(text)
        : null,
  );
}

List<AgentStreamImageInput> _imagesFromAttachments(Object? value) {
  if (value is! List) return const <AgentStreamImageInput>[];
  final images = <AgentStreamImageInput>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, Object?>.from(item);
    if (_string(map['type']).trim() != 'image') continue;
    final assetId = _string(map['asset_id'] ?? map['assetId']).trim();
    final fileId = _string(map['file_id'] ?? map['fileId']).trim();
    final contentId = assetId.isNotEmpty ? assetId : fileId;
    if (contentId.isEmpty) continue;
    final mimeType = _string(
      map['content_type'] ?? map['mime_type'] ?? map['mimeType'],
    ).trim();
    final name = _string(map['name'] ?? map['original_filename']).trim();
    final detail = _string(map['detail']).trim();
    images.add(
      AgentStreamImageInput(
        dataUrl: '',
        assetId: assetId,
        fileId: contentId,
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
    this.hiddenAutomation = false,
    this.isChatFirstWelcomeTrigger = false,
    this.isChatFirstPoopTrigger = false,
    this.chatFirstWelcomeKey,
    this.sequence,
    this.createdAt,
  });

  final int? sequence;
  final DateTime? createdAt;
  final String id;
  final String? runId;
  final AgentConversationMessageRole role;
  final String content;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
  final bool hiddenAutomation;
  final bool isChatFirstWelcomeTrigger;
  final bool isChatFirstPoopTrigger;
  final String? chatFirstWelcomeKey;
}
