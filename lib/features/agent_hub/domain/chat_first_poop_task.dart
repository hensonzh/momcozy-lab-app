const chatFirstPoopRequestPrompt =
    '[momcozy_internal_poop_v1] 请结合这些宝宝便便照片，描述可见的颜色和形态，说明可能需要关注的线索与日常观察建议。多张照片请综合观察，信息不足时请明确说明并询问必要情况，不要仅凭照片诊断。';

bool isChatFirstPoopPrompt(String value) =>
    value.trimLeft().startsWith('[momcozy_internal_poop_v1]');

/// Local presentation marker. Photo bytes live only in the active page and
/// must not be serialized into interaction state or ordinary composer drafts.
enum ChatFirstPoopTaskStatus { pending, completed, cancelled }

class ChatFirstPoopTask {
  const ChatFirstPoopTask({
    required this.id,
    required this.createdAt,
    this.threadId,
    this.runId,
    this.status = ChatFirstPoopTaskStatus.pending,
  });

  final String id;
  final DateTime createdAt;
  final String? threadId;
  final String? runId;
  final ChatFirstPoopTaskStatus status;

  ChatFirstPoopTask withThread(String? threadId) => ChatFirstPoopTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    runId: runId,
    status: status,
  );

  ChatFirstPoopTask withStatus(ChatFirstPoopTaskStatus status) =>
      ChatFirstPoopTask(
        id: id,
        createdAt: createdAt,
        threadId: threadId,
        runId: runId,
        status: status,
      );

  ChatFirstPoopTask completed(String? runId) => ChatFirstPoopTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    runId: runId,
    status: ChatFirstPoopTaskStatus.completed,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    if (threadId != null) 'threadId': threadId,
    if (runId != null) 'runId': runId,
    'status': status.name,
  };

  static ChatFirstPoopTask? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final createdAt = value['createdAt'];
    if (id is! String ||
        !id.startsWith('local:poop:') ||
        createdAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return null;
    return ChatFirstPoopTask(
      id: id,
      createdAt: parsed,
      threadId: value['threadId'] is String
          ? value['threadId'] as String
          : null,
      runId: value['runId'] is String ? value['runId'] as String : null,
      status: ChatFirstPoopTaskStatus.values.firstWhere(
        (status) => status.name == value['status'],
        orElse: () => ChatFirstPoopTaskStatus.pending,
      ),
    );
  }
}
