import 'package:momcozy_flutter_app/modules/consultation/presentation/consultation_start_dialog.dart';
import 'dart:async';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/device_check_dialog.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/services/consultations/device_check.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('device check states $width / $scale', (tester) async {
        _size(tester, width);
        var requests = 0;
        final pending = Completer<lk.LocalVideoTrack>();
        final check = ConsultationDeviceCheck(
          createVideo: () async {
            requests++;
            return pending.future;
          },
          createAudio: () async {
            requests++;
            throw StateError('microphone unavailable');
          },
        );
        await tester.pumpWidget(
          _app(
            scale,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ConsultationDeviceCheckDialog(createCheck: () => check),
                  ),
                  child: const Text('设备检查'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('设备检查'));
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(tester.takeException(), isNull);
        await _golden(tester, 'room-device', width, scale);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Checking…'))
              .onPressed,
          isNull,
        );
        pending.completeError(StateError('camera unavailable'));
        await tester.pumpAndSettle();
        expect(requests, 2);
        await tester.ensureVisible(find.textContaining('Could not use the microphone. Check device permissions or hardware.'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _golden(tester, 'room-device-error', width, scale);
        await tester.tap(find.byTooltip('Close device check'));
        await tester.pumpAndSettle();
        expect(find.byType(ConsultationDeviceCheckDialog), findsNothing);
      });
      testWidgets('room location and consent $width / $scale', (tester) async {
        _size(tester, width);
        final repository = TestRoomRepository()..ready();
        final controller = testController(repository, TestConsultationMedia());
        await tester.pumpWidget(
          _app(
            scale,
            ConsultationRoomPage(
              createController: () => controller,
              createDeviceCheck: TestReadyDeviceCheck.new,
              onBack: () {},
              onIntake: () async {},
              onProgress: (_) {},
              onRebook: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Start consultation'), 180);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start consultation'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('consult-location')),
        );
        await tester.tap(find.byKey(const ValueKey('consult-location')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New York (NY)').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _golden(tester, 'room-location', width, scale);
        await tester.tap(
          find.descendant(
            of: find.byType(ConsultationStartDialog),
            matching: find.byTooltip('Close consultation confirmation'),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.data!.location, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('expert end reason sheet and cancel $width / $scale', (
        tester,
      ) async {
        _size(tester, width);
        final repository = TestRoomRepository()..ready();
        repository.json['viewer_role'] = 'ibclc';
        final controller = testController(repository, TestConsultationMedia());
        await controller.load();
        await controller.enter();
        await tester.pumpWidget(
          _app(
            scale,
            ConsultationRoomPage(
              createController: () => controller,
              onBack: () {},
              onIntake: () async {},
              onProgress: (_) {},
              onRebook: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Cannot continue consultation'), 180);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cannot continue consultation'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _golden(tester, 'room-end-reason', width, scale);
        await tester.ensureVisible(find.text('Technical or network issue'));
        await tester.tap(find.text('Technical or network issue'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _golden(tester, 'room-end-confirm', width, scale);
        await tester.tap(find.text('Continue consultation'));
        await tester.pumpAndSettle();
        expect(repository.endCalls, 0);
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('ended room destinations $width / $scale', (tester) async {
        _size(tester, width);
        final repository = TestRoomRepository()
          ..ready()
          ..room(status: 'note_pending', roomStatus: 'closed');
        var progress = 0, rebook = 0;
        await tester.pumpWidget(
          _app(
            scale,
            ConsultationRoomPage(
              createController: () =>
                  testController(repository, TestConsultationMedia()),
              onBack: () {},
              onIntake: () async {},
              onProgress: (_) => progress++,
              onRebook: (_) => rebook++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _golden(tester, 'room-outcome', width, scale);
        await tester.ensureVisible(find.text('View consultation summary'));
        await tester.tap(find.text('View consultation summary'));
        await tester.ensureVisible(find.text('Book another appointment'));
        await tester.tap(find.text('Book another appointment'));
        expect(progress, 1);
        expect(rebook, 1);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

void _size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(double scale, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);
Future<void> _golden(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  if (scale == 1) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/$name-${width.toInt()}.png',
      ),
    );
  }
}
