import 'dart:async';

import 'package:flutter/material.dart';
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
    'keeps local camera and screen guidance when session creation fails',
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
      expect(controller.phase, MotionAssessmentPagePhase.calibrating);
      expect(controller.guidance, contains('屏幕提示'));
      expect(voice.connectCalls, 0);

      await controller.finish();
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

  test('keeps camera assessment running when realtime voice fails', () async {
    final repository = _FakeRepository(immediateSession: _session());
    final pose = _FakePosePlatform();
    final voice = _FakeVoice(connectError: StateError('voice unavailable'));
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: repository,
      posePlatform: pose,
      voice: voice,
    );

    await controller.start();
    await _flush();

    expect(pose.startCalls, 1);
    expect(controller.phase, MotionAssessmentPagePhase.calibrating);
    expect(controller.voiceStatusMessage, contains('屏幕提示'));

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
      await _flush();
      await _flush();

      expect(repository.createdSourceArtifactIds, ['artifact-motion-1']);
      expect(voice.latestContext?.assessmentId, 'assessment-1');
      expect(voice.latestContext?.samplingState, 'completed');

      await controller.finish(completed: true);

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
    },
  );

  testWidgets(
    'shows active local camera and realtime voice fallback on screen',
    (tester) async {
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: _FakeRepository(immediateSession: _session()),
        posePlatform: _FakePosePlatform(),
        voice: _FakeVoice(connectError: StateError('voice unavailable')),
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

      expect(find.textContaining('相机已开启'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('motion-assessment-voice-status')),
        findsOneWidget,
      );
      expect(find.textContaining('屏幕提示'), findsOneWidget);
    },
  );

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
  _FakePosePlatform({this.startCompleter});

  final Completer<void>? startCompleter;
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
    return startCompleter?.future ?? Future.value();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (!stopCalled.isCompleted) stopCalled.complete();
  }

  void emit(MotionPoseObservation observation) =>
      _observations.add(observation);
}

class _FakeVoice extends ChangeNotifier implements MotionRealtimeVoiceClient {
  _FakeVoice({this.connectError});

  final Object? connectError;
  int connectCalls = 0;
  MotionAssessmentContextSnapshot? latestContext;

  @override
  Stream<MotionVoiceCommand> get commands => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  MotionRealtimeVoicePhase get phase => MotionRealtimeVoicePhase.idle;

  @override
  Future<void> connect({required String assessmentId}) async {
    connectCalls += 1;
    final error = connectError;
    if (error != null) throw error;
  }

  @override
  Future<void> speak(String instruction, {bool interrupt = false}) async {}

  @override
  Future<void> sendClientEvent(
    String eventType,
    Map<String, Object?> payload,
  ) async {}

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
  Future<void> close() async {}
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
