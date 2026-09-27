import 'dart:async';
import 'dart:convert';

import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';

enum MotionVisualSnapshotReason {
  currentPose('current_pose'),
  framing('framing'),
  orientation('orientation');

  const MotionVisualSnapshotReason(this.wireName);

  final String wireName;
}

class MotionVisualContext {
  const MotionVisualContext({
    required this.frame,
    required this.trigger,
    required this.reason,
    required this.stateRevision,
    required this.requiredView,
    this.sourceEventId,
    this.userAudioItemId,
  });

  final MotionPoseKeyFrame frame;
  final String trigger;
  final String reason;
  final int stateRevision;
  final String requiredView;
  final String? sourceEventId;
  final String? userAudioItemId;
}

typedef MotionKeyFrameCapture = Future<MotionPoseKeyFrame> Function();

/// Selects sparse visual context without making camera images part of the
/// assessment's correctness or availability path.
class MotionVisualContextCoordinator {
  MotionVisualContextCoordinator({
    required this.captureKeyFrame,
    this.cooldown = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const int maximumFrameBytes = 120 * 1024;
  static const int maximumFrameWidth = 448;
  static const int maximumFrameHeight = 896;
  static const int maximumFramesPerSession = 12;
  static const Set<String> automaticEventTypes = {
    'framing_incomplete',
    'side_view_required',
    'front_view_required',
    'target_changed',
    'capture_countdown',
  };

  final MotionKeyFrameCapture captureKeyFrame;
  final Duration cooldown;
  final DateTime Function() _now;

  Future<void> _operationTail = Future<void>.value();
  DateTime? _lastSuccessfulCaptureAt;
  bool _userConsent = false;
  bool _serverCapability = false;
  bool _disabledForSession = false;
  bool _closed = false;
  int _sentCount = 0;
  int _failureCount = 0;

  bool get isEnabled =>
      !_closed &&
      !_disabledForSession &&
      _userConsent &&
      _serverCapability &&
      _sentCount < maximumFramesPerSession;
  int get sentCount => _sentCount;
  int get failureCount => _failureCount;

  void setUserConsent(bool value) => _userConsent = value;

  void setServerCapability(bool value) => _serverCapability = value;

  /// Stops further image attempts for this session while leaving pose and
  /// voice processing untouched.
  void disableForSession() => _disabledForSession = true;

  void markSent() {
    if (_sentCount < maximumFramesPerSession) _sentCount += 1;
  }

  void recordTransportFailure({bool disableForSession = false}) {
    _failureCount += 1;
    if (disableForSession) _disabledForSession = true;
  }

  Future<MotionVisualContext?> captureForEvent({
    required String eventType,
    required String eventId,
    required MotionAssessmentContextSnapshot? context,
    required int contextAgeMs,
  }) {
    if (!automaticEventTypes.contains(eventType)) {
      return Future<MotionVisualContext?>.value();
    }
    return _capture(
      trigger: 'device_event',
      reason: eventType,
      sourceEventId: eventId,
      context: context,
      contextAgeMs: contextAgeMs,
    );
  }

  /// Starts best-effort event capture without putting camera work on the
  /// semantic event or voice-response critical path.
  void scheduleEventCapture({
    required String eventType,
    required String eventId,
    required MotionAssessmentContextSnapshot? context,
    required int contextAgeMs,
    required Future<void> Function(MotionVisualContext visual) onCaptured,
  }) {
    final operation =
        captureForEvent(
          eventType: eventType,
          eventId: eventId,
          context: context,
          contextAgeMs: contextAgeMs,
        ).then<void>((visual) async {
          if (visual != null) await onCaptured(visual);
        });
    unawaited(operation.catchError((Object _, StackTrace _) {}));
  }

  Future<MotionVisualContext?> captureOnDemand({
    required MotionVisualSnapshotReason reason,
    required String? userAudioItemId,
    required MotionAssessmentContextSnapshot? context,
    required int contextAgeMs,
  }) {
    return _capture(
      trigger: 'model_request',
      reason: reason.wireName,
      userAudioItemId: userAudioItemId,
      context: context,
      contextAgeMs: contextAgeMs,
    );
  }

  Future<MotionVisualContext?> _capture({
    required String trigger,
    required String reason,
    required MotionAssessmentContextSnapshot? context,
    required int contextAgeMs,
    String? sourceEventId,
    String? userAudioItemId,
  }) {
    final result = Completer<MotionVisualContext?>();
    _operationTail = _operationTail
        .then((_) async {
          if (!isEnabled || !_contextIsEligible(context, contextAgeMs)) {
            result.complete();
            return;
          }
          final now = _now();
          final previous = _lastSuccessfulCaptureAt;
          if (previous != null && now.difference(previous) < cooldown) {
            result.complete();
            return;
          }
          try {
            final frame = await captureKeyFrame().timeout(
              const Duration(milliseconds: 1800),
            );
            if (!isEnabled) {
              result.complete();
              return;
            }
            if (!_isValidFrame(frame)) {
              _failureCount += 1;
              result.complete();
              return;
            }
            _lastSuccessfulCaptureAt = _now();
            result.complete(
              MotionVisualContext(
                frame: frame,
                trigger: trigger,
                reason: reason,
                stateRevision: context!.sequence,
                requiredView: context.requiredView,
                sourceEventId: sourceEventId,
                userAudioItemId: userAudioItemId,
              ),
            );
          } catch (_) {
            _failureCount += 1;
            result.complete();
          }
        })
        .catchError((Object _, StackTrace _) {
          if (!result.isCompleted) {
            _failureCount += 1;
            result.complete();
          }
        });
    return result.future;
  }

  bool _contextIsEligible(
    MotionAssessmentContextSnapshot? context,
    int contextAgeMs,
  ) {
    return context != null &&
        contextAgeMs >= 0 &&
        contextAgeMs <= context.freshForMs &&
        context.personCount == 1 &&
        !context.multiplePeople;
  }

  bool _isValidFrame(MotionPoseKeyFrame frame) {
    final bytes = frame.bytes;
    return frame.id.trim().isNotEmpty &&
        frame.mimeType.toLowerCase() == 'image/jpeg' &&
        frame.width > 0 &&
        frame.width <= maximumFrameWidth &&
        frame.height > 0 &&
        frame.height <= maximumFrameHeight &&
        frame.capturedAtMs > 0 &&
        bytes.lengthInBytes <= maximumFrameBytes &&
        bytes.lengthInBytes >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[bytes.length - 2] == 0xff &&
        bytes.last == 0xd9;
  }

  void close() {
    _closed = true;
    _userConsent = false;
    _serverCapability = false;
  }
}

class MotionVisualSnapshotRequest {
  const MotionVisualSnapshotRequest({
    required this.callId,
    required this.reason,
  });

  final String callId;
  final MotionVisualSnapshotReason reason;
}

List<MotionVisualSnapshotRequest> motionVisualSnapshotRequestsFromServerEvent(
  Map<Object?, Object?> event,
) {
  final type = event['type']?.toString();
  if (type == 'response.function_call_arguments.done') {
    final request = _visualRequestFromFunctionCall(event);
    return request == null ? const [] : [request];
  }
  if (type != 'response.done') return const [];
  final response = event['response'];
  if (response is! Map || response['output'] is! List) return const [];
  return [
    for (final item in response['output']! as List)
      if (item is Map) ?_visualRequestFromFunctionCall(item),
  ];
}

bool motionRealtimeErrorTargetsVisualContext(
  Map<Object?, Object?> event, {
  required Set<String> pendingVisualEventIds,
}) {
  if (event['type']?.toString() != 'error') return false;
  final rawError = event['error'];
  final error = rawError is Map
      ? Map<Object?, Object?>.from(rawError)
      : const <Object?, Object?>{};
  final correlatedEventId =
      error['event_id']?.toString() ?? event['event_id']?.toString();
  final explicitlyCorrelated =
      correlatedEventId != null &&
      pendingVisualEventIds.remove(correlatedEventId);
  final diagnostic = [
    error['param'],
    error['message'],
    error['code'],
  ].whereType<Object>().join(' ').toLowerCase();
  return explicitlyCorrelated ||
      diagnostic.contains('input_image') ||
      diagnostic.contains('image_url') ||
      diagnostic.contains('motion_visual_context');
}

MotionVisualSnapshotRequest? _visualRequestFromFunctionCall(
  Map<Object?, Object?> item,
) {
  final itemType = item['type']?.toString();
  if (itemType != null &&
      itemType != 'function_call' &&
      itemType != 'response.function_call_arguments.done') {
    return null;
  }
  if (item['name']?.toString() != 'motion_visual_snapshot') return null;
  final callId = item['call_id']?.toString().trim() ?? '';
  final arguments = item['arguments']?.toString() ?? '';
  if (callId.isEmpty || arguments.isEmpty || arguments.length > 1024) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(arguments);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final reason = switch (decoded['reason']?.toString()) {
    'current_pose' => MotionVisualSnapshotReason.currentPose,
    'framing' => MotionVisualSnapshotReason.framing,
    'orientation' => MotionVisualSnapshotReason.orientation,
    _ => null,
  };
  return reason == null
      ? null
      : MotionVisualSnapshotRequest(callId: callId, reason: reason);
}

Map<String, Object?> motionVisualConversationItemCreate({
  required String clientEventId,
  required String assessmentId,
  required MotionVisualContext visual,
}) {
  final metadata = <String, Object?>{
    'schema_version': 'motion_visual_context.v1',
    'assessment_id': assessmentId,
    'frame_id': visual.frame.id,
    'captured_at_ms': visual.frame.capturedAtMs,
    'trigger': visual.trigger,
    'reason': visual.reason,
    'state_revision': visual.stateRevision,
    'required_view': visual.requiredView,
    if (visual.sourceEventId != null) 'source_event_id': visual.sourceEventId,
    if (visual.userAudioItemId != null)
      'user_audio_item_id': visual.userAudioItemId,
    'retention': 'session_only',
    'authority': 'advisory',
  };
  return {
    'event_id': clientEventId,
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': 'user',
      'content': [
        {
          'type': 'input_text',
          'text': '[Sparse visual context]${jsonEncode(metadata)}',
        },
        {
          'type': 'input_image',
          'image_url':
              'data:${visual.frame.mimeType};base64,${base64Encode(visual.frame.bytes)}',
        },
      ],
    },
  };
}
