import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_controller.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

// Real Android Flutter rendering and controller lifecycle; camera/voice/API are
// isolated. No camera permission, frames, microphone or provider calls are used.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android motion denial, camera failure, retry and end',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        final repository = _PendingRepository();
        final poses = <_Pose>[];
        var attempts = 0;
        final router = GoRouter(
          initialLocation: '/motion',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('评估返回页'))),
            ),
            GoRoute(
              path: '/motion',
              builder: (_, _) => MotionAssessmentPage(
                controllerIdentity: scale,
                controllerFactory: () {
                  final attempt = attempts++;
                  final pose = _Pose(
                    granted: attempt > 0,
                    startError: attempt == 1
                        ? PlatformException(code: 'camera_start_failed')
                        : null,
                  );
                  poses.add(pose);
                  return MotionAssessmentController(
                    target: 'forward_head',
                    locale: 'zh-CN',
                    repository: repository,
                    posePlatform: pose,
                    voice: _Voice(),
                  );
                },
                previewBuilder: (_) =>
                    const ColoredBox(color: Color(0xff283538)),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: momCozyTheme(),
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('请允许摄像头权限后重试。'), findsOneWidget);
        expect(repository.createCalls, 0);
        expect(poses.first.starts, 0);
        if (scale == 1) await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await _capture(binding, 'native-motion-permission-${scale.toInt()}x');
        await tester.tap(find.byKey(const ValueKey('motion-assessment-retry')));
        await tester.pumpAndSettle();
        expect(find.textContaining('前置摄像头启动失败'), findsOneWidget);
        await _capture(binding, 'native-motion-camera-error-${scale.toInt()}x');
        await tester.tap(find.byKey(const ValueKey('motion-assessment-retry')));
        await tester.pumpAndSettle();
        expect(repository.createCalls, 1);
        expect(poses.last.starts, 1);
        expect(
          find.byKey(const ValueKey('motion-assessment-error')),
          findsNothing,
        );
        final header = tester.getRect(
          find.byKey(const ValueKey('motion-assessment-end')),
        );
        final guide = tester.getRect(
          find.byKey(const ValueKey('motion-assessment-body-guide')),
        );
        expect(header.bottom, lessThan(guide.top));
        expect(header.height, greaterThanOrEqualTo(44));
        await _capture(binding, 'native-motion-guide-${scale.toInt()}x');
        await tester.tap(find.byKey(const ValueKey('motion-assessment-end')));
        await tester.pumpAndSettle();
        expect(find.text('评估返回页'), findsOneWidget);
        expect(poses.last.stops, greaterThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final directory = await getApplicationDocumentsDirectory();
  await File('${directory.path}/$name.png').writeAsBytes(bytes);
}

class _PendingRepository extends Fake implements MotionAssessmentRepository {
  int createCalls = 0;
  final pending = Completer<MotionAssessmentSession>();
  @override
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
    bool keyFrameUploadEnabled = false,
  }) {
    createCalls++;
    return pending.future;
  }
}

class _Pose implements MotionPosePlatform {
  _Pose({required this.granted, this.startError});
  final bool granted;
  final Object? startError;
  int starts = 0, stops = 0;
  @override
  String get engineName => 'isolated-ui-fixture';
  @override
  Stream<MotionPoseObservation> get observations => const Stream.empty();
  @override
  Future<bool> requestCameraPermission() async => granted;
  @override
  Future<void> start() async {
    starts++;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class _Voice extends ChangeNotifier implements MotionRealtimeVoiceClient {
  @override
  Stream<MotionVoiceCommand> get commands => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
