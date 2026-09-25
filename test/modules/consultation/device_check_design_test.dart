import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:momcozy_flutter_app/modules/consultation/presentation/device_check_dialog.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/device_preview_dialog.dart';
import 'package:momcozy_flutter_app/services/consultations/device_check.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

class Camera extends Fake implements lk.LocalVideoTrack {
  int stops = 0, disposals = 0;
  @override
  Future<bool> stop() async {
    stops++;
    return true;
  }

  @override
  Future<bool> dispose() async {
    disposals++;
    return true;
  }
}

class Probe extends ConsultationDeviceCheck {
  int starts = 0;
  bool succeed = false;
  Completer<void>? pending;
  final tracks = <Camera>[];
  @override
  Future<void> start() async {
    starts++;
    busy = true;
    if (pending != null) await pending!.future;
    final track = Camera();
    tracks.add(track);
    video = track;
    microphoneAvailable = succeed;
    microphoneError = succeed
        ? null
        : 'Could not use the microphone. Check device permissions or hardware.';
    busy = false;
  }
}

Future<void> mount(
  WidgetTester tester,
  Probe probe,
  double width,
  double scale, {
  VoidCallback? onSuccess,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ConsultationDeviceCheckDialog(
                createCheck: () => probe,
                onSuccess: onSuccess,
              ),
            ),
            child: const Text('Check device'),
          ),
        ),
      ),
    ),
  );
  expect(probe.starts, 0);
  await tester.tap(find.text('Check device'));
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String text) async {
  final target = text == 'Close'
      ? find.byTooltip('Close device check')
      : find.text(text);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String state,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/device-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
      ),
    );
  }
}

void main() {
  testWidgets('preflight continues only after readiness and an explicit tap', (
    tester,
  ) async {
    final probe = Probe()
      ..pending = Completer<void>()
      ..succeed = true;
    var continued = 0;
    await mount(tester, probe, 390, 1, onSuccess: () => continued++);
    expect(find.text('Continue'), findsNothing);
    probe.pending!.complete();
    await tester.pumpAndSettle();
    expect(continued, 0);
    await shot(tester, 'continue', 390, 1);
    await click(tester, 'Continue');
    expect(continued, 1);
    await click(tester, 'Close');
  });
  testWidgets(
    'device completion remains reachable on a short screen with large text',
    (tester) async {
      final probe = Probe()..succeed = true;
      await mount(tester, probe, 320, 2);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await shot(tester, 'short-ready-actions', 320, 2);
      await click(tester, 'Done');
      expect(find.byType(ConsultationDeviceCheckDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'device check pending partial failure retry ready $width / $scale',
        (tester) async {
          final probe = Probe()..pending = Completer<void>();
          await mount(tester, probe, width, scale);
          expect(probe.starts, 1);
          await shot(tester, 'checking', width, scale);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Checking…'),
                )
                .onPressed,
            isNull,
          );
          probe.pending!.complete();
          await tester.pumpAndSettle();
          expect(find.text('Done'), findsNothing);
          expect(probe.tracks.single.stops, 1);
          expect(probe.tracks.single.disposals, 1);
          await shot(tester, 'error', width, scale);
          probe.pending = null;
          probe.succeed = true;
          await click(tester, 'Start check');
          expect(probe.starts, 2);
          expect(find.text('Camera and microphone are ready'), findsOneWidget);
          expect(probe.video, isNull);
          expect(probe.tracks.last.stops, 1);
          expect(probe.tracks.last.disposals, 1);
          await shot(tester, 'ready', width, scale);
          await click(tester, 'Check again');
          expect(probe.starts, 3);
          expect(probe.tracks.last.stops, 1);
          await click(tester, 'Done');
          expect(find.byType(ConsultationDeviceCheckDialog), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'closing pending permission releases late camera and never requests audio',
    (tester) async {
      final pending = Completer<lk.LocalVideoTrack>();
      var audioRequests = 0;
      final check = ConsultationDeviceCheck(
        createVideo: () => pending.future,
        createAudio: () {
          audioRequests++;
          throw StateError('must not request');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      ConsultationDeviceCheckDialog(createCheck: () => check),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close device check'));
      await tester.pumpAndSettle();
      final track = Camera();
      pending.complete(track);
      await tester.pumpAndSettle();
      expect(track.stops, 1);
      expect(track.disposals, 1);
      expect(audioRequests, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('expert device preview retains manual start', (tester) async {
    final probe = Probe();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    ConsultationDevicePreviewDialog(createCheck: () => probe),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(probe.starts, 0);
    expect(find.text('Start check'), findsOneWidget);
    await tester.tap(find.text('Close check'));
    await tester.pumpAndSettle();
  });
}
