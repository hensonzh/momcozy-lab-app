import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/services/consultations/consultation_media.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

class Media extends TestConsultationMedia {
  @override
  bool get sandbox => false;
  @override
  bool microphoneOn = true;
  @override
  bool cameraOn = true;
  @override
  bool busy = false;
  @override
  bool weakNetwork = false;
  @override
  bool audioPlaybackBlocked = false;
  @override
  String? error;
  int microphones = 0, cameras = 0, audio = 0;
  void changed() => notifyListeners();
  @override
  Future<void> toggleMicrophone() async {
    microphones++;
    microphoneOn = !microphoneOn;
    changed();
  }

  @override
  Future<void> toggleCamera() async {
    cameras++;
    cameraOn = !cameraOn;
    changed();
  }

  @override
  Future<void> enableAudio() async {
    audio++;
    audioPlaybackBlocked = false;
    changed();
  }
}

Future<void> click(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  if (name != 'media-error' &&
      name != 'leave' &&
      name != 'controls' &&
      name != 'disconnected-actions') {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
  }
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/video-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}${tester.view.physicalSize.height == 568 ? '-short' : ''}.png',
      ),
    );
  }
}

void main() {
  for (final (width, height) in [
    (320.0, 844.0),
    (390.0, 844.0),
    (430.0, 844.0),
    (320.0, 568.0),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'user waiting media controls and leave $width x $height / $scale',
        (tester) async {
          await loadMomCozyTestFonts();
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = TestRoomRepository()..ready();
          final media = Media();
          final controller = testController(repository, media);
          await controller.load();
          await controller.enter();
          var left = 0;
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: momCozyTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ConsultationRoomPage(
                createController: () => controller,
                onBack: () {
                  left++;
                },
                onIntake: () async {},
                onProgress: (_) {},
                onRebook: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Waiting for Test IBCLC to join'), findsOneWidget);
          await shot(tester, 'waiting', width, scale);
          await tester.ensureVisible(find.text('Leave room'));
          await tester.pumpAndSettle();
          await shot(tester, 'controls', width, scale);
          await click(tester, 'Microphone');
          expect(media.microphones, 1);
          expect(find.text('Muted'), findsOneWidget);
          await click(tester, 'Camera');
          expect(media.cameras, 1);
          expect(find.text('Off'), findsOneWidget);
          media.busy = true;
          media.changed();
          await tester.pumpAndSettle();
          await click(tester, 'Muted');
          await click(tester, 'Off');
          expect(media.microphones, 1);
          expect(media.cameras, 1);
          media.busy = false;
          repository.json['participants'] = [
            {
              'role': 'ibclc',
              'presence': 'joined',
              'connection_version': 1,
              'joined_at': repository.context.serverTime.toIso8601String(),
            },
          ];
          await controller.load();
          await tester.pumpAndSettle();
          expect(find.text('Test IBCLC has joined'), findsOneWidget);
          await shot(tester, 'expert-ready', width, scale);
          repository.room(status: 'in_progress', version: 2);
          await controller.load();
          await tester.pumpAndSettle();
          expect(find.text('The other camera is off'), findsOneWidget);
          await shot(tester, 'camera-off', width, scale);
          (repository.json['participants'] as List).first['presence'] =
              'reconnecting';
          await controller.load();
          await tester.pumpAndSettle();
          expect(find.text('Test IBCLC is reconnecting'), findsOneWidget);
          media.state = ConsultationMediaState.reconnecting;
          media.changed();
          await tester.pumpAndSettle();
          await shot(tester, 'reconnecting', width, scale);
          await click(tester, 'Muted');
          expect(media.microphones, 1);
          media.state = ConsultationMediaState.disconnected;
          media.changed();
          await tester.pumpAndSettle();
          expect(find.text('Video connection interrupted'), findsOneWidget);
          await shot(tester, 'disconnected', width, scale);
          await tester.ensureVisible(find.text('Back to preparation'));
          await tester.pumpAndSettle();
          await shot(tester, 'disconnected-actions', width, scale);
          await click(tester, 'Muted');
          expect(media.microphones, 1);
          await click(tester, 'Reconnect');
          expect(media.state, ConsultationMediaState.connected);
          expect(controller.inRoom, isTrue);
          expect(repository.endCalls, 0);
          media.state = ConsultationMediaState.disconnected;
          media.changed();
          await tester.pumpAndSettle();
          await click(tester, 'Back to preparation');
          expect(controller.inRoom, isFalse);
          expect(find.text('Rejoin consultation room'), findsOneWidget);
          // The normal preparation/re-entry route is covered by the App journey.
          // Restore this isolated media fixture to inspect its remaining notice.
          await controller.enter();
          await tester.pumpAndSettle();
          media.weakNetwork = true;
          media.audioPlaybackBlocked = true;
          media.error = 'Could not start the camera. Check device permissions.';
          media.changed();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Tap to enable call audio'));
          await tester.pumpAndSettle();
          await shot(tester, 'media-error', width, scale);
          await click(tester, 'Tap to enable call audio');
          expect(media.audio, 1);
          expect(find.text('Tap to enable call audio'), findsNothing);
          // One canonical viewport records the changed notice without adding
          // an extra size/text-scale matrix for this interaction.
          if (width == 390 && height == 844 && scale == 1) {
            await shot(tester, 'media-audio-enabled', width, scale);
          }
          await click(tester, 'Leave room');
          await shot(tester, 'leave', width, scale);
          await click(tester, 'Stay in room');
          expect(left, 0);
          expect(media.state, ConsultationMediaState.connected);
          await click(tester, 'Leave room');
          await click(tester, 'Leave for now');
          expect(left, 1);
          expect(repository.endCalls, 0);
          expect(media.state, ConsultationMediaState.disconnected);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
