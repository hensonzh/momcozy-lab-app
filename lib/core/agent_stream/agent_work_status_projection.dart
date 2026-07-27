import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

const agentCompletedStatusHold = Duration(milliseconds: 600);

class AgentWorkStatusProjection {
  const AgentWorkStatusProjection({required this.isTerminal, this.statusEvent});

  final bool isTerminal;
  final AgentStreamEvent? statusEvent;
}

AgentWorkStatusProjection projectAgentWorkStatus(
  Iterable<AgentStreamEvent> events, {
  DateTime? now,
  Duration completedHold = agentCompletedStatusHold,
}) {
  final currentTime = (now ?? DateTime.now()).toUtc();
  final latestByMergeKey = <String, _IndexedSemanticEvent>{};
  var index = 0;

  for (final event in events) {
    if (_isTerminalEvent(event)) {
      return const AgentWorkStatusProjection(isTerminal: true);
    }
    final semantic = event.semantic;
    if (semantic.isEmpty) {
      index += 1;
      continue;
    }
    final mergeKey = event.semanticMergeKey?.trim().isNotEmpty == true
        ? event.semanticMergeKey!.trim()
        : event.mergeKey;
    final lifecycle = event.semanticLifecycle?.trim() ?? '';
    if (lifecycle == 'failed') {
      latestByMergeKey.remove(mergeKey);
      index += 1;
      continue;
    }
    final surface = event.semanticSurface?.trim() ?? '';
    if (!_visibleSurfaces.contains(surface)) {
      if (lifecycle == 'completed') {
        latestByMergeKey.remove(mergeKey);
      }
      index += 1;
      continue;
    }
    final label = event.semanticLabel?.trim() ?? '';
    if (label.isEmpty) {
      index += 1;
      continue;
    }
    latestByMergeKey[mergeKey] = _IndexedSemanticEvent(
      event: event,
      index: index,
      surface: surface,
      lifecycle: lifecycle.isEmpty ? 'running' : lifecycle,
      priority: event.semanticPriority ?? 0,
    );
    index += 1;
  }

  final candidates = latestByMergeKey.values.toList(growable: false);
  final runningUserWork = candidates.where(
    (candidate) =>
        candidate.surface != 'status_bar' && candidate.lifecycle != 'completed',
  );
  final recentCompletedWork = candidates.where(
    (candidate) =>
        candidate.surface != 'status_bar' &&
        candidate.lifecycle == 'completed' &&
        _isRecentCompletion(
          candidate.event,
          now: currentTime,
          completedHold: completedHold,
        ),
  );
  final statusBarProgress = candidates.where(
    (candidate) => candidate.surface == 'status_bar',
  );
  final selected =
      _highestPriority(runningUserWork) ??
      _highestPriority(recentCompletedWork) ??
      _highestPriority(statusBarProgress);

  return AgentWorkStatusProjection(
    isTerminal: false,
    statusEvent: selected?.event,
  );
}

const _visibleSurfaces = {'status_bar', 'work_item', 'artifact', 'action'};

bool _isTerminalEvent(AgentStreamEvent event) {
  return (event.type == 'message.completed' && event.role != 'user') ||
      event.type == 'run.completed' ||
      event.type == 'run.failed' ||
      event.type == 'run.cancelled';
}

bool _isRecentCompletion(
  AgentStreamEvent event, {
  required DateTime now,
  required Duration completedHold,
}) {
  final createdAt = event.createdAt?.toUtc();
  if (createdAt == null) return true;
  final age = now.difference(createdAt);
  return age.isNegative || age <= completedHold;
}

_IndexedSemanticEvent? _highestPriority(
  Iterable<_IndexedSemanticEvent> candidates,
) {
  _IndexedSemanticEvent? selected;
  for (final candidate in candidates) {
    if (selected == null ||
        candidate.priority > selected.priority ||
        (candidate.priority == selected.priority &&
            candidate.index > selected.index)) {
      selected = candidate;
    }
  }
  return selected;
}

class _IndexedSemanticEvent {
  const _IndexedSemanticEvent({
    required this.event,
    required this.index,
    required this.surface,
    required this.lifecycle,
    required this.priority,
  });

  final AgentStreamEvent event;
  final int index;
  final String surface;
  final String lifecycle;
  final int priority;
}
