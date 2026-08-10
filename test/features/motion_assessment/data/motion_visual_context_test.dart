import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_visual_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';

void main() {
  test(
    'captures only consented visual events with fresh single-person context',
    () async {
      var captureCalls = 0;
      final coordinator = MotionVisualContextCoordinator(
        captureKeyFrame: () async {
          captureCalls += 1;
          return _frame(id: 'frame-$captureCalls');
        },
      );

      expect(
        await coordinator.captureForEvent(
          eventType: 'framing_incomplete',
          eventId: 'assessment-1:1',
          context: _context(),
          contextAgeMs: 100,
        ),
        isNull,
      );

      coordinator
        ..setUserConsent(true)
        ..setServerCapability(true);
      expect(
        await coordinator.captureForEvent(
          eventType: 'assessment_plan_updated',
          eventId: 'assessment-1:2',
          context: _context(),
          contextAgeMs: 100,
        ),
        isNull,
      );
      final visual = await coordinator.captureForEvent(
        eventType: 'framing_incomplete',
        eventId: 'assessment-1:3',
        context: _context(),
        contextAgeMs: 100,
      );

      expect(captureCalls, 1);
      expect(visual, isNotNull);
      expect(visual!.trigger, 'device_event');
      expect(visual.sourceEventId, 'assessment-1:3');
      expect(visual.stateRevision, 8);
    },
  );

  test(
    'serializes concurrent captures and applies a visual cooldown',
    () async {
      var captureCalls = 0;
      final coordinator =
          MotionVisualContextCoordinator(
              captureKeyFrame: () async {
                captureCalls += 1;
                return _frame(id: 'frame-$captureCalls');
              },
              cooldown: const Duration(seconds: 2),
            )
            ..setUserConsent(true)
            ..setServerCapability(true);

      final captures = await Future.wait([
        coordinator.captureForEvent(
          eventType: 'side_view_required',
          eventId: 'assessment-1:1',
          context: _context(),
          contextAgeMs: 50,
        ),
        coordinator.captureForEvent(
          eventType: 'front_view_required',
          eventId: 'assessment-1:2',
          context: _context(),
          contextAgeMs: 50,
        ),
      ]);

      expect(captureCalls, 1);
      expect(captures.whereType<MotionVisualContext>(), hasLength(1));
    },
  );

  test(
    'runs automatic visual capture outside the voice critical path',
    () async {
      final capture = Completer<MotionPoseKeyFrame>();
      final submitted = Completer<MotionVisualContext>();
      final coordinator =
          MotionVisualContextCoordinator(
              captureKeyFrame: () => capture.future,
              cooldown: Duration.zero,
            )
            ..setUserConsent(true)
            ..setServerCapability(true);

      coordinator.scheduleEventCapture(
        eventType: 'framing_incomplete',
        eventId: 'assessment-1:latency',
        context: _context(),
        contextAgeMs: 10,
        onCaptured: (visual) async => submitted.complete(visual),
      );

      expect(submitted.isCompleted, isFalse);
      capture.complete(_frame(id: 'non-blocking-frame'));
      final visual = await submitted.future.timeout(const Duration(seconds: 1));
      expect(visual.sourceEventId, 'assessment-1:latency');
    },
  );

  test(
    'capture failures and oversized images degrade without throwing',
    () async {
      final failures = <Object>[
        StateError('camera already stopped'),
        _frame(
          id: 'too-large',
          bytes: Uint8List(
            MotionVisualContextCoordinator.maximumFrameBytes + 1,
          ),
        ),
      ];
      final coordinator =
          MotionVisualContextCoordinator(
              captureKeyFrame: () async {
                final next = failures.removeAt(0);
                if (next is MotionPoseKeyFrame) return next;
                throw next;
              },
              cooldown: Duration.zero,
            )
            ..setUserConsent(true)
            ..setServerCapability(true);

      expect(
        await coordinator.captureForEvent(
          eventType: 'capture_countdown',
          eventId: 'assessment-1:1',
          context: _context(),
          contextAgeMs: 10,
        ),
        isNull,
      );
      expect(
        await coordinator.captureOnDemand(
          reason: MotionVisualSnapshotReason.currentPose,
          userAudioItemId: 'audio-1',
          context: _context(),
          contextAgeMs: 10,
        ),
        isNull,
      );
      expect(coordinator.failureCount, 2);
    },
  );

  test('builds a bounded official Realtime input_image conversation item', () {
    final visual = MotionVisualContext(
      frame: _frame(id: 'frame-9'),
      trigger: 'model_request',
      reason: 'current_pose',
      stateRevision: 8,
      requiredView: 'side',
      userAudioItemId: 'audio-9',
    );

    final event = motionVisualConversationItemCreate(
      clientEventId: 'visual-client-9',
      assessmentId: 'assessment-1',
      visual: visual,
    );
    final item = Map<String, Object?>.from(event['item']! as Map);
    final content = item['content']! as List;
    final metadata = Map<String, Object?>.from(content.first as Map);
    final image = Map<String, Object?>.from(content.last as Map);

    expect(event['event_id'], 'visual-client-9');
    expect(event['type'], 'conversation.item.create');
    expect(metadata['type'], 'input_text');
    expect(metadata['text'], contains('motion_visual_context.v1'));
    expect(metadata['text'], contains('audio-9'));
    expect(image['type'], 'input_image');
    expect(image['image_url'], startsWith('data:image/jpeg;base64,'));
    expect(event.toString(), isNot(contains('landmarks')));
  });

  test('parses only bounded visual snapshot tool requests', () {
    final request = motionVisualSnapshotRequestsFromServerEvent({
      'type': 'response.function_call_arguments.done',
      'name': 'motion_visual_snapshot',
      'call_id': 'visual-call-1',
      'arguments': '{"reason":"current_pose"}',
    }).single;

    expect(request.callId, 'visual-call-1');
    expect(request.reason, MotionVisualSnapshotReason.currentPose);
    expect(
      motionVisualSnapshotRequestsFromServerEvent({
        'type': 'response.function_call_arguments.done',
        'name': 'motion_visual_snapshot',
        'call_id': 'visual-call-2',
        'arguments': '{"reason":"unknown"}',
      }),
      isEmpty,
    );
  });

  test('correlates image errors without swallowing unrelated voice errors', () {
    final pending = {'motion-visual-1'};

    expect(
      motionRealtimeErrorTargetsVisualContext({
        'type': 'error',
        'error': {'event_id': 'motion-visual-1', 'code': 'invalid_value'},
      }, pendingVisualEventIds: pending),
      isTrue,
    );
    expect(pending, isEmpty);
    expect(
      motionRealtimeErrorTargetsVisualContext({
        'type': 'error',
        'error': {'event_id': 'motion-semantic-1', 'code': 'server_error'},
      }, pendingVisualEventIds: pending),
      isFalse,
    );
  });
}

MotionPoseKeyFrame _frame({required String id, Uint8List? bytes}) {
  return MotionPoseKeyFrame(
    id: id,
    bytes: bytes ?? Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xd9]),
    mimeType: 'image/jpeg',
    capturedAtMs: 1234,
    width: 448,
    height: 252,
  );
}

MotionAssessmentContextSnapshot _context() {
  return const MotionAssessmentContextSnapshot(
    assessmentId: 'assessment-1',
    sequence: 8,
    observedAtMs: 1200,
    target: 'posture_screen',
    phase: 'calibrating',
    elapsedMs: 3000,
    personCount: 1,
    targetLocked: true,
    continuity: 'stable',
    assessmentRegionVisible: true,
    missingRegions: [],
    distance: 'good',
    requiredView: 'side',
    detectedView: 'side',
    detectedSide: 'right',
    alignmentQuality: 'good',
    samplingState: 'waiting',
    validSamples: 0,
    requiredSamples: 30,
    stableDurationMs: 800,
    requiredDurationMs: 5000,
    samplingProgress: 0,
    rejectionReasons: [],
    measurementStatus: 'collecting',
    metric: 'craniovertebral_angle',
    rollingMedian: null,
    dispersion: null,
    unit: 'degrees',
    multiplePeople: false,
    targetChanged: false,
    discomfortReported: false,
    recommendedAction: 'hold_still',
    guidanceReason: 'framing',
  );
}
