/// A local-only conversation card marker. Recording bytes and playback state
/// never become a message, Agent request, or persisted interaction snapshot.
enum ChatFirstCryTaskStatus {
  pending,
  verifying,
  unavailable,
  failed,
  completed,
  incomplete,
  cancelled,
}

class ChatFirstCryTask {
  const ChatFirstCryTask({
    required this.id,
    required this.createdAt,
    this.threadId,
    this.precedingAssistantMessageId,
    this.status = ChatFirstCryTaskStatus.pending,
    this.analysisId,
    this.requestKey,
    this.answer,
    this.analyzedAt,
    this.adviceAccepted = false,
    this.autoAdvicePending = false,
    this.adviceAttempt = 0,
  });

  final String id;
  final DateTime createdAt;
  final String? threadId;
  final String? precedingAssistantMessageId;
  final ChatFirstCryTaskStatus status;
  final String? analysisId;
  final String? requestKey;
  final String? answer;
  final DateTime? analyzedAt;
  final bool adviceAccepted;
  final bool autoAdvicePending;
  final int adviceAttempt;

  ChatFirstCryTask withThread(String? nextThreadId) => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: nextThreadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: status,
    analysisId: analysisId,
    requestKey: requestKey,
    answer: answer,
    analyzedAt: analyzedAt,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: autoAdvicePending,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask withSubmissionKey(String? key) => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: ChatFirstCryTaskStatus.pending,
    analysisId: analysisId,
    requestKey: key,
    answer: answer,
    analyzedAt: analyzedAt,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: key != null,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask awaitingResult() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: ChatFirstCryTaskStatus.verifying,
    analysisId: analysisId,
    requestKey: requestKey,
    answer: null,
    analyzedAt: null,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: autoAdvicePending,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask cancelled() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: ChatFirstCryTaskStatus.cancelled,
    analysisId: analysisId,
    requestKey: requestKey,
    answer: answer,
    analyzedAt: analyzedAt,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: autoAdvicePending,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask withResult({
    required String id,
    required String resultStatus,
    String? resultAnswer,
    required DateTime resultAt,
  }) => ChatFirstCryTask(
    id: this.id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: resultStatus == 'done'
        ? ChatFirstCryTaskStatus.completed
        : resultStatus == 'incomplete'
        ? ChatFirstCryTaskStatus.incomplete
        : resultStatus == 'pending'
        ? ChatFirstCryTaskStatus.verifying
        : ChatFirstCryTaskStatus.failed,
    analysisId: id,
    requestKey: requestKey,
    answer: resultAnswer,
    analyzedAt: resultAt,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: autoAdvicePending,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask resultUnavailable() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: ChatFirstCryTaskStatus.unavailable,
    analysisId: analysisId,
    requestKey: requestKey,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: autoAdvicePending,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask acceptedAdvice() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: status,
    analysisId: analysisId,
    requestKey: requestKey,
    answer: answer,
    analyzedAt: analyzedAt,
    adviceAccepted: true,
    autoAdvicePending: false,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask adviceRequested() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: status,
    analysisId: analysisId,
    requestKey: requestKey,
    answer: answer,
    analyzedAt: analyzedAt,
    adviceAccepted: adviceAccepted,
    autoAdvicePending: false,
    adviceAttempt: adviceAttempt,
  );

  ChatFirstCryTask failedAdvice() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: status,
    analysisId: analysisId,
    requestKey: requestKey,
    answer: answer,
    analyzedAt: analyzedAt,
    adviceAccepted: false,
    autoAdvicePending: false,
    adviceAttempt: adviceAttempt + 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    if (threadId != null) 'threadId': threadId,
    if (precedingAssistantMessageId != null)
      'precedingAssistantMessageId': precedingAssistantMessageId,
    'status': status.name,
    if (analysisId != null) 'analysisId': analysisId,
    if (requestKey != null) 'requestKey': requestKey,
    if (answer != null) 'answer': answer,
    if (analyzedAt != null) 'analyzedAt': analyzedAt!.toIso8601String(),
    if (adviceAccepted) 'adviceAccepted': true,
    if (autoAdvicePending) 'autoAdvicePending': true,
    if (adviceAttempt > 0) 'adviceAttempt': adviceAttempt,
  };

  static ChatFirstCryTask? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final createdAt = value['createdAt'];
    if (id is! String || !id.startsWith('local:cry:') || createdAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return null;
    return ChatFirstCryTask(
      id: id,
      createdAt: parsed,
      threadId: value['threadId'] is String
          ? value['threadId'] as String
          : null,
      precedingAssistantMessageId:
          value['precedingAssistantMessageId'] is String
          ? value['precedingAssistantMessageId'] as String
          : null,
      status: value['status'] == 'cancelled'
          ? ChatFirstCryTaskStatus.cancelled
          : value['analysisId'] is String || value['requestKey'] is String
          ? ChatFirstCryTaskStatus.verifying
          : ChatFirstCryTaskStatus.pending,
      analysisId: value['analysisId'] is String
          ? value['analysisId'] as String
          : null,
      requestKey: value['requestKey'] is String
          ? value['requestKey'] as String
          : null,
      answer: null,
      analyzedAt: null,
      adviceAccepted: value['adviceAccepted'] == true,
      autoAdvicePending: value['autoAdvicePending'] == true,
      adviceAttempt:
          value['adviceAttempt'] is int && (value['adviceAttempt'] as int) >= 0
          ? value['adviceAttempt'] as int
          : 0,
    );
  }
}
