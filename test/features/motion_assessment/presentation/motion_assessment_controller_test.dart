import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_quality_gate.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_controller.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_page.dart';

void main() {
  test(
    'starts local camera before session creation completes and never starts voice after close',
    () async {
      final createCompleter = Completer<MotionAssessmentSession>();
      final repository = _FakeRepository(createCompleter: createCompleter);
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
      );

      final start = controller.start();
      while (repository.createCalls == 0) {
        await _flush();
      }
      expect(repository.createCalls, 1);
      expect(pose.startCalls, 1);

      await controller.finish();
      createCompleter.complete(_session());
      await start;

      expect(pose.startCalls, 1);
      expect(voice.connectCalls, 0);
      expect(repository.updatedStatuses, ['cancelled']);
    },
  );

  test(
    'closes the camera when cloud session creation fails because voice is required',
    () async {
      final repository = _FakeRepository(
        createError: StateError('backend unavailable'),
      );
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
      );

      await controller.start();

      expect(pose.startCalls, 1);
      expect(controller.exitRequested, isTrue);
      expect(controller.phase, MotionAssessmentPagePhase.completed);
      expect(voice.connectCalls, 0);
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'stops a native camera start that completes after the page was closed',
    () async {
      final startCompleter = Completer<void>();
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform(startCompleter: startCompleter);
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
      );

      final start = controller.start();
      while (pose.startCalls == 0) {
        await _flush();
      }
      final finish = controller.finish();
      await _flush();
      startCompleter.complete();
      await Future.wait([start, finish]);

      expect(pose.stopCalls, greaterThanOrEqualTo(2));
      expect(voice.connectCalls, 0);
    },
  );

  test(
    'retries then closes the camera when required realtime voice fails',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice(connectError: StateError('voice unavailable'));
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        voiceRetryDelay: Duration.zero,
      );

      await controller.start();
      await _flush();

      expect(voice.connectCalls, 2);
      expect(controller.exitRequested, isTrue);
      expect(controller.phase, MotionAssessmentPagePhase.completed);
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  test('drains normal agent audio before opening realtime voice', () async {
    final repository = _FakeRepository(immediateSession: _session());
    final pose = _FakePosePlatform();
    final voice = _FakeVoice();
    var agentAudioDrained = false;
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: repository,
      posePlatform: pose,
      voice: voice,
      prepareRealtimeAudio: () async {
        agentAudioDrained = true;
      },
    );
    voice.beforeConnect = () {
      expect(agentAudioDrained, isTrue);
    };

    await controller.start();

    expect(voice.connectCalls, 1);
    expect(voice.guidanceRequests.first.type, 'assessment_started');
    expect(voice.guidanceRequests.first.awaitPlaybackStart, isTrue);
    await controller.finish();
  });

  test(
    'does not sample pose frames until first Realtime audio starts',
    () async {
      final firstAudio = Completer<void>();
      final pose = _FakePosePlatform();
      final voice = _FakeVoice()..firstGuidanceCompleter = firstAudio;
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: _FakeRepository(immediateSession: _session()),
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
      );

      final start = controller.start();
      while (voice.guidanceRequests.isEmpty) {
        await _flush();
      }
      pose.emit(_acceptedSideObservation());
      await _flush();
      expect(controller.voiceReady, isFalse);
      expect(voice.latestContext, isNull);

      firstAudio.complete();
      await start;
      pose.emit(_acceptedSideObservation());
      await _flush();
      expect(controller.voiceReady, isTrue);
      expect(voice.latestContext, isNotNull);

      await controller.finish();
    },
  );

  test(
    'converts live pose changes into Realtime-owned guidance turns',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(
          singlePersonStableFor: Duration.zero,
          multiplePeopleStableFor: Duration.zero,
        ),
      );

      await controller.start();
      await _flush();

      pose.emit(_poseObservation(Duration.zero, const []));
      await _flush();
      pose.emit(_acceptedSideObservation());
      await _flush();
      final tracked = _acceptedSideObservation().poses.single;
      pose.emit(
        _poseObservation(const Duration(seconds: 2), [
          tracked,
          MotionPose(
            centerX: 0.82,
            centerY: tracked.centerY,
            bodyScale: tracked.bodyScale,
            landmarks: tracked.landmarks,
          ),
        ]),
      );
      await _flush();
      await _flush();

      expect(voice.spokenInstructions, isEmpty);
      expect(
        voice.guidanceRequests.map((event) => event.type),
        containsAll([
          'assessment_started',
          'person_not_detected',
          'single_person_stable',
          'multiple_people',
        ]),
      );
      expect(voice.latestContext?.personCount, 2);
      expect(voice.latestContext?.recommendedAction, 'ask_others_to_leave');

      await controller.finish();
    },
  );

  test(
    'surfaces a native pose model startup failure with a useful cause',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform(
        startError: PlatformException(
          code: 'pose_model_initialization_failed',
          message: 'Unable to open pose model asset',
          details: const {
            'exception': 'java.lang.RuntimeException',
            'build': 42,
            'abis': ['arm64-v8a'],
          },
        ),
      );
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: _FakeVoice(),
      );

      await controller.start();

      expect(controller.phase, MotionAssessmentPagePhase.failed);
      expect(controller.errorMessage, contains('姿态模型加载失败'));
      expect(controller.errorMessage, isNot(contains('网络')));
      expect(controller.poseDiagnosticMessage, contains('Unable to open'));
      expect(controller.poseDiagnosticMessage, contains('RuntimeException'));
      expect(controller.poseDiagnosticMessage, contains('build 42'));
      expect(repository.createCalls, 0);
      expect(pose.stopCalls, 1);

      await controller.finish();
    },
  );

  test('stops the local camera when native pose inference fails', () async {
    final repository = _FakeRepository(immediateSession: _session());
    final pose = _FakePosePlatform();
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: repository,
      posePlatform: pose,
      voice: _FakeVoice(),
    );

    await controller.start();
    pose.emitError(
      PlatformException(
        code: 'pose_inference_failed',
        message: 'MediaPipe execution failed',
      ),
    );
    await _flush();

    expect(controller.phase, MotionAssessmentPagePhase.failed);
    expect(controller.errorMessage, contains('姿态识别运行异常'));
    expect(pose.stopCalls, 1);

    await controller.finish();
  });

  test(
    'links the source artifact and preserves rich completion evidence',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        sourceArtifactId: 'artifact-motion-1',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
        forwardHeadAnalyzer: ForwardHeadAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
      );

      await controller.start();
      pose.emit(_acceptedSideObservation());
      while (!controller.exitRequested) {
        await _flush();
      }

      expect(repository.createdSourceArtifactIds, ['artifact-motion-1']);
      expect(voice.latestContext?.assessmentId, 'assessment-1');
      expect(voice.latestContext?.samplingState, 'completed');

      final completed = repository.updates.lastWhere(
        (update) => update.status == 'completed',
      );
      expect(completed.resultSummary?['sample_count'], 1);
      expect(completed.resultSummary?['sample_duration_ms'], 0);
      expect(completed.resultSummary?['angle_dispersion_degrees'], 0.0);
      expect(completed.resultSummary?['accepted_frame_ratio'], 1.0);
      expect(
        completed.resultSummary?['measurement_quality_score'],
        isA<double>(),
      );
      expect(completed.resultSummary?['analyzer_version'], isNotEmpty);
      expect(completed.resultSummary?['threshold_version'], isNotEmpty);
      expect(controller.completedSuccessfully, isTrue);
      expect(controller.completedAssessmentId, 'assessment-1');
      expect(
        voice.guidanceRequests.map((request) => request.type),
        contains('assessment_completed'),
      );
    },
  );

  testWidgets(
    'keeps the assessment hands-free without fallback text or controls',
    (tester) async {
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: _FakeRepository(immediateSession: _session()),
        posePlatform: _FakePosePlatform(),
        voice: _FakeVoice(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MotionAssessmentPage(
            controllerIdentity: 'voice-fallback',
            controllerFactory: () => controller,
            previewBuilder: (_) => const ColoredBox(color: Colors.black),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(
        find.byKey(const ValueKey('motion-assessment-guidance')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('motion-assessment-voice-status')),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps live guidance focused without technical keypoint labels', (
    tester,
  ) async {
    final pose = _FakePosePlatform();
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: _FakeRepository(immediateSession: _session()),
      posePlatform: pose,
      voice: _FakeVoice(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MotionAssessmentPage(
          controllerIdentity: 'pose-overlay',
          controllerFactory: () => controller,
          previewBuilder: (_) => const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('motion-pose-tracking-status')),
      findsNothing,
    );
    expect(pose.startCalls, 1);

    pose.emit(_acceptedSideObservation());
    await tester.pump();
    await tester.pump();
    expect(controller.observation, isNotNull);

    expect(find.byKey(const ValueKey('motion-pose-overlay')), findsOneWidget);
    expect(find.textContaining('个关键点'), findsNothing);
    expect(
      find.byKey(const ValueKey('motion-assessment-guidance')),
      findsNothing,
    );
  });

  testWidgets(
    'replaces and disposes the controller when runtime identity changes',
    (tester) async {
      final firstPose = _FakePosePlatform();
      final secondPose = _FakePosePlatform();

      MotionAssessmentController controllerFor(_FakePosePlatform pose) {
        return MotionAssessmentController(
          target: 'forward_head',
          locale: 'zh-CN',
          repository: _FakeRepository(immediateSession: _session()),
          posePlatform: pose,
          voice: _FakeVoice(),
        );
      }

      var runtimeIdentity = 'runtime-a';
      late StateSetter updateHost;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return MotionAssessmentPage(
                key: const ValueKey('motion-page'),
                controllerIdentity: runtimeIdentity,
                controllerFactory: () => controllerFor(
                  runtimeIdentity == 'runtime-a' ? firstPose : secondPose,
                ),
                previewBuilder: (_) => const ColoredBox(color: Colors.black),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(firstPose.startCalls, 1);

      updateHost(() => runtimeIdentity = 'runtime-b');
      await tester.pump();
      expect(secondPose.startCalls, 1);
      await tester.runAsync(
        () => firstPose.stopCalled.future.timeout(const Duration(seconds: 1)),
      );
      await tester.pump();

      expect(firstPose.stopCalls, greaterThanOrEqualTo(1));
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

MotionAssessmentSession _session() {
  return const MotionAssessmentSession(
    id: 'assessment-1',
    target: 'forward_head',
    status: 'ready',
    poseEngine: 'mediapipe_pose_landmarker',
    videoUploadEnabled: false,
    landmarkUploadEnabled: false,
    pauseReason: '',
    resultSummary: {},
  );
}

class _FakeRepository implements MotionAssessmentRepository {
  _FakeRepository({
    this.createCompleter,
    this.immediateSession,
    this.createError,
  });

  final Completer<MotionAssessmentSession>? createCompleter;
  final MotionAssessmentSession? immediateSession;
  final Object? createError;
  int createCalls = 0;
  final List<String> createdSourceArtifactIds = [];
  final List<String> updatedStatuses = [];
  final List<({String status, Map<String, Object?>? resultSummary})> updates =
      [];

  @override
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
  }) {
    createCalls += 1;
    createdSourceArtifactIds.add(sourceArtifactId);
    final error = createError;
    if (error != null) return Future<MotionAssessmentSession>.error(error);
    return createCompleter?.future ?? Future.value(immediateSession!);
  }

  @override
  Future<MotionAssessmentSession> update({
    required String assessmentId,
    required String status,
    String pauseReason = '',
    Map<String, Object?>? resultSummary,
  }) async {
    updatedStatuses.add(status);
    updates.add((status: status, resultSummary: resultSummary));
    return _session();
  }
}

class _FakePosePlatform implements MotionPosePlatform {
  _FakePosePlatform({this.startCompleter, this.startError});

  final Completer<void>? startCompleter;
  final Object? startError;
  final _observations = StreamController<MotionPoseObservation>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  final Completer<void> stopCalled = Completer<void>();

  @override
  String get engineName => 'mediapipe_pose_landmarker';

  @override
  Stream<MotionPoseObservation> get observations => _observations.stream;

  @override
  Future<bool> requestCameraPermission() async => true;

  @override
  Future<void> start() {
    startCalls += 1;
    final error = startError;
    if (error != null) return Future.error(error);
    return startCompleter?.future ?? Future.value();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (!stopCalled.isCompleted) stopCalled.complete();
  }

  void emit(MotionPoseObservation observation) =>
      _observations.add(observation);

  void emitError(Object error) => _observations.addError(error);
}

class _FakeVoice extends ChangeNotifier implements MotionRealtimeVoiceClient {
  _FakeVoice({this.connectError});

  final Object? connectError;
  Completer<void>? firstGuidanceCompleter;
  VoidCallback? beforeConnect;
  int connectCalls = 0;
  MotionAssessmentContextSnapshot? latestContext;
  final List<String> spokenInstructions = [];
  final List<({String type, Map<String, Object?> payload})> sentEvents = [];
  final List<
    ({
      String type,
      Map<String, Object?> payload,
      bool interrupt,
      bool awaitPlaybackStart,
      bool awaitPlaybackCompletion,
    })
  >
  guidanceRequests = [];
  MotionRealtimeVoicePhase _phase = MotionRealtimeVoicePhase.idle;

  @override
  Stream<MotionVoiceCommand> get commands => const Stream.empty();

  @override
  bool get isConnected =>
      _phase == MotionRealtimeVoicePhase.listening ||
      _phase == MotionRealtimeVoicePhase.speaking;

  @override
  bool get hasRemoteAudioTrack => true;

  @override
  String get providerName => 'openai_realtime';

  @override
  String? get failureCode => connectError == null ? null : 'signaling';

  @override
  MotionRealtimeVoicePhase get phase => _phase;

  @override
  Future<void> connect({required String assessmentId}) async {
    connectCalls += 1;
    beforeConnect?.call();
    final error = connectError;
    if (error != null) {
      _phase = MotionRealtimeVoicePhase.failed;
      notifyListeners();
      throw error;
    }
    _phase = MotionRealtimeVoicePhase.listening;
    notifyListeners();
  }

  @override
  Future<void> requestGuidance(
    String eventType,
    Map<String, Object?> payload, {
    bool interrupt = false,
    bool awaitPlaybackStart = false,
    bool awaitPlaybackCompletion = false,
  }) async {
    guidanceRequests.add((
      type: eventType,
      payload: payload,
      interrupt: interrupt,
      awaitPlaybackStart: awaitPlaybackStart,
      awaitPlaybackCompletion: awaitPlaybackCompletion,
    ));
    if (awaitPlaybackStart) {
      await firstGuidanceCompleter?.future;
      firstGuidanceCompleter = null;
    }
  }

  @override
  Future<void> speak(
    String instruction, {
    bool interrupt = false,
    bool exact = false,
  }) async {
    spokenInstructions.add(instruction);
  }

  @override
  Future<void> sendClientEvent(
    String eventType,
    Map<String, Object?> payload,
  ) async {
    sentEvents.add((type: eventType, payload: payload));
  }

  @override
  void updateAssessmentContext(MotionAssessmentContextSnapshot snapshot) {
    latestContext = snapshot;
  }

  @override
  Future<void> completeCommand(
    MotionVoiceCommand command, {
    required bool accepted,
    required String message,
    bool speakResult = true,
  }) async {}

  @override
  Future<void> close() async {
    _phase = MotionRealtimeVoicePhase.closed;
  }
}

MotionPoseObservation _acceptedSideObservation() {
  const reliable = MotionPoseLandmark(
    x: 0.5,
    y: 0.5,
    z: 0,
    visibility: 0.95,
    presence: 0.95,
  );
  return MotionPoseObservation(
    timestamp: const Duration(seconds: 1),
    inputWidth: 1000,
    inputHeight: 1000,
    inferenceTime: const Duration(milliseconds: 20),
    poses: [
      MotionPose(
        centerX: 0.5,
        centerY: 0.5,
        bodyScale: 0.8,
        landmarks: {
          MotionPoseLandmarkType.nose: const MotionPoseLandmark(
            x: 0.5,
            y: 0.08,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
          MotionPoseLandmarkType.leftEar: const MotionPoseLandmark(
            x: 0.7,
            y: 0.35,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
          MotionPoseLandmarkType.rightEar: const MotionPoseLandmark(
            x: 0.7,
            y: 0.35,
            z: 0,
            visibility: 0.9,
            presence: 0.9,
          ),
          MotionPoseLandmarkType.leftShoulder: const MotionPoseLandmark(
            x: 0.5,
            y: 0.55,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
          MotionPoseLandmarkType.rightShoulder: const MotionPoseLandmark(
            x: 0.51,
            y: 0.55,
            z: 0,
            visibility: 0.9,
            presence: 0.9,
          ),
          MotionPoseLandmarkType.leftHip: const MotionPoseLandmark(
            x: 0.5,
            y: 0.7,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
          MotionPoseLandmarkType.rightHip: const MotionPoseLandmark(
            x: 0.51,
            y: 0.7,
            z: 0,
            visibility: 0.9,
            presence: 0.9,
          ),
          MotionPoseLandmarkType.leftKnee: reliable,
          MotionPoseLandmarkType.leftAnkle: const MotionPoseLandmark(
            x: 0.5,
            y: 0.92,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
        },
      ),
    ],
  );
}

MotionPoseObservation _poseObservation(
  Duration timestamp,
  List<MotionPose> poses,
) {
  return MotionPoseObservation(
    timestamp: timestamp,
    inputWidth: 1000,
    inputHeight: 1000,
    inferenceTime: const Duration(milliseconds: 20),
    poses: poses,
  );
}
