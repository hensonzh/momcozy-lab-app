import 'stool_analysis.dart';

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
    this.placedAfterMessageId,
    this.runId,
    this.analysisState,
    this.status = ChatFirstPoopTaskStatus.pending,
  });

  final String id;
  final DateTime createdAt;
  final String? threadId;
  final String? placedAfterMessageId;
  final String? runId;
  final StoolCardState? analysisState;
  final ChatFirstPoopTaskStatus status;

  ChatFirstPoopTask withThread(String? threadId) {
    if (analysisState != null && threadId != this.threadId) {
      throw StateError('A submitted analysis cannot change conversations.');
    }
    return ChatFirstPoopTask(
      id: id,
      createdAt: createdAt,
      threadId: threadId,
      placedAfterMessageId: placedAfterMessageId,
      runId: runId,
      analysisState: analysisState,
      status: status,
    );
  }

  ChatFirstPoopTask placedAfter(String? messageId) => ChatFirstPoopTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    placedAfterMessageId: messageId,
    runId: runId,
    analysisState: analysisState,
    status: status,
  );

  ChatFirstPoopTask withStatus(ChatFirstPoopTaskStatus status) =>
      ChatFirstPoopTask(
        id: id,
        createdAt: createdAt,
        threadId: threadId,
        placedAfterMessageId: placedAfterMessageId,
        runId: runId,
        analysisState: analysisState,
        status: status,
      );

  ChatFirstPoopTask completed(String? runId) => ChatFirstPoopTask(
    id: id,
    createdAt: createdAt,
    threadId: threadId,
    placedAfterMessageId: placedAfterMessageId,
    runId: runId,
    analysisState: analysisState,
    status: ChatFirstPoopTaskStatus.completed,
  );

  ChatFirstPoopTask submitted(StoolCardState state) {
    if (threadId == null ||
        threadId!.isEmpty ||
        (analysisState != null &&
            analysisState!.analysisId != state.analysisId)) {
      throw const FormatException(
        'Submitted analysis requires its original thread.',
      );
    }
    return ChatFirstPoopTask(
      id: id,
      createdAt: createdAt,
      threadId: threadId,
      placedAfterMessageId: placedAfterMessageId,
      runId: runId,
      analysisState: state,
      status: ChatFirstPoopTaskStatus.completed,
    );
  }

  ChatFirstPoopTask withAnalysisState(StoolCardState state) {
    if (analysisState == null ||
        analysisState!.analysisId != state.analysisId ||
        status != ChatFirstPoopTaskStatus.completed) {
      throw const FormatException('Analysis card does not belong to task.');
    }
    return submitted(state);
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    if (threadId != null) 'threadId': threadId,
    if (placedAfterMessageId != null)
      'placedAfterMessageId': placedAfterMessageId,
    if (runId != null) 'runId': runId,
    if (analysisState != null) 'analysis': analysisState!.toMap(),
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
    final status = ChatFirstPoopTaskStatus.values.firstWhere(
      (candidate) => candidate.name == value['status'],
      orElse: () => ChatFirstPoopTaskStatus.pending,
    );
    final rawAnalysis = value['analysis'];
    final analysis = rawAnalysis == null
        ? null
        : StoolCardState.fromMap(rawAnalysis);
    if (rawAnalysis != null &&
        (analysis == null ||
            status != ChatFirstPoopTaskStatus.completed ||
            value['threadId'] is! String ||
            (value['threadId'] as String).isEmpty)) {
      return null;
    }
    return ChatFirstPoopTask(
      id: id,
      createdAt: parsed,
      threadId: value['threadId'] is String
          ? value['threadId'] as String
          : null,
      placedAfterMessageId: value['placedAfterMessageId'] is String
          ? value['placedAfterMessageId'] as String
          : null,
      runId: value['runId'] is String ? value['runId'] as String : null,
      status: status,
      analysisState: analysis,
    );
  }
}
