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

const _agentSystemFlowTriggerPrefix = '[系统流程触发]';
const _motionAssessmentCompletionPrompts = {'用户刚完成体态动态评估', '用户刚完成头颈姿态动态评估'};

bool isMotionAssessmentCompletionPrompt(String value) {
  final normalized = value.trimLeft();
  if (!normalized.startsWith(_agentSystemFlowTriggerPrefix)) return false;
  final body = normalized
      .substring(_agentSystemFlowTriggerPrefix.length)
      .trimLeft();
  return _motionAssessmentCompletionPrompts.any(body.startsWith);
}

class AgentConversationMessage {
  const AgentConversationMessage({
    required this.role,
    required this.content,
    this.runState,
    this.images = const <AgentStreamImageInput>[],
    this.files = const <AgentStreamFileInput>[],
  });

  final AgentConversationMessageRole role;
  final String content;
  final AgentStreamRunState? runState;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
}

class AgentConversationHistory {
  const AgentConversationHistory({
    required this.thread,
    required this.messages,
    required this.currentState,
    this.nextBeforeSequence,
  });

  final AgentConversationSummary thread;
  final List<AgentConversationMessage> messages;
  final AgentStreamRunState currentState;
  final int? nextBeforeSequence;
}

abstract interface class AgentConversationRepository {
  Future<List<AgentConversationSummary>> listConversations({int limit = 50});

  Future<AgentConversationHistory> loadConversation(
    String threadId, {
    int? beforeSequence,
    int limit = 20,
  });
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
