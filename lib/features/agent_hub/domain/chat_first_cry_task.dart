/// A local-only conversation card marker. Recording bytes and playback state
/// never become a message, Agent request, or persisted interaction snapshot.
enum ChatFirstCryTaskStatus { pending, cancelled }

class ChatFirstCryTask {
  const ChatFirstCryTask({
    required this.id,
    required this.createdAt,
    this.threadId,
    this.precedingAssistantMessageId,
    this.status = ChatFirstCryTaskStatus.pending,
  });

  final String id;
  final DateTime createdAt;
  final String? threadId;
  final String? precedingAssistantMessageId;
  final ChatFirstCryTaskStatus status;

  ChatFirstCryTask withThread(String? nextThreadId) => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: nextThreadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: status,
  );

  ChatFirstCryTask cancelled() => ChatFirstCryTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    precedingAssistantMessageId: precedingAssistantMessageId,
    status: ChatFirstCryTaskStatus.cancelled,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    if (threadId != null) 'threadId': threadId,
    if (precedingAssistantMessageId != null)
      'precedingAssistantMessageId': precedingAssistantMessageId,
    'status': status.name,
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
      status: value['status'] == ChatFirstCryTaskStatus.cancelled.name
          ? ChatFirstCryTaskStatus.cancelled
          : ChatFirstCryTaskStatus.pending,
    );
  }
}
