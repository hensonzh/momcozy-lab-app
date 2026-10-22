import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

class AgentConversationSummary {
  const AgentConversationSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum AgentConversationMessageRole { user, assistant }

const _agentSystemFlowTriggerPrefixes = {'[系统流程触发]', '[System flow trigger]'};
const _motionAssessmentCompletionPrompts = {
  '用户刚完成体态动态评估',
  '用户刚完成头颈姿态动态评估',
  'The user just completed a posture assessment',
  'The user just completed a head and neck assessment',
};

bool isMotionAssessmentCompletionPrompt(String value) {
  final normalized = value.trimLeft();
  final prefix = _agentSystemFlowTriggerPrefixes
      .where(normalized.startsWith)
      .firstOrNull;
  if (prefix == null) return false;
  final body = normalized.substring(prefix.length).trimLeft();
  return _motionAssessmentCompletionPrompts.any(body.startsWith);
}

class AgentConversationMessage {
  const AgentConversationMessage({
    required this.role,
    required this.content,
    this.id,
    this.runId,
    this.sequence,
    this.createdAt,
    this.runState,
    this.images = const <AgentStreamImageInput>[],
    this.files = const <AgentStreamFileInput>[],
    this.isChatFirstWelcome = false,
    this.isChatFirstPoopTrigger = false,
    this.chatFirstWelcomeKey,
  });

  final String? id;
  final String? runId;
  final int? sequence;
  final DateTime? createdAt;
  final AgentConversationMessageRole role;
  final String content;
  final AgentStreamRunState? runState;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
  final bool isChatFirstWelcome;
  final bool isChatFirstPoopTrigger;
  final String? chatFirstWelcomeKey;
}

class AgentConversationHistory {
  const AgentConversationHistory({
    required this.thread,
    required this.messages,
    required this.currentState,
    this.nextBeforeSequence,
    this.latestMessageCreatedAt,
    this.currentRunIsChatFirstWelcome = false,
    this.currentWelcomeKey,
  });

  final AgentConversationSummary thread;
  final List<AgentConversationMessage> messages;
  final AgentStreamRunState currentState;
  final int? nextBeforeSequence;
  final DateTime? latestMessageCreatedAt;
  final bool currentRunIsChatFirstWelcome;
  final String? currentWelcomeKey;
}

abstract interface class AgentConversationRepository {
  Future<AgentConversationHistory?> loadLatestConversation();

  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  });
}

/// A committed thread is required before a cry result can be claimed by a Run.
abstract interface class AgentConversationThreadCreator {
  Future<String> createConversation();
}

bool hasAgentConversationAssistantProjection(AgentStreamRunState state) {
  return state.textContent.trim().isNotEmpty ||
      state.artifactEvents.isNotEmpty ||
      state.actionEvents.isNotEmpty ||
      state.phase == AgentStreamRunPhase.finished ||
      state.phase == AgentStreamRunPhase.error ||
      state.phase == AgentStreamRunPhase.cancelled ||
      state.phase == AgentStreamRunPhase.waitingForConfirmation;
}
