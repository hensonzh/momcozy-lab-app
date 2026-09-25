import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:momcozy_flutter_app/services/consultations/device_check.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/device_check_dialog.dart';

class _Video extends Fake implements lk.LocalVideoTrack {
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

class _Probe extends ConsultationDeviceCheck {
  int starts = 0, closes = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  test(
    'closing while camera permission is pending stops the late track without opening the microphone',
    () async {
      final pending = Completer<lk.LocalVideoTrack>();
      var microphoneRequests = 0;
      final probe = ConsultationDeviceCheck(
        createVideo: () => pending.future,
        createAudio: () {
          microphoneRequests++;
          throw StateError('unexpected microphone');
        },
      );
      final started = probe.start();
      await Future<void>.delayed(Duration.zero);
      probe.dispose();
      final track = _Video();
      pending.complete(track);
      await started;
      expect(track.stops, 1);
      expect(track.disposals, 1);
      expect(microphoneRequests, 0);
    },
  );
  testWidgets(
    'opening the device dialog requests once and releases tracks after the check',
    (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      ConsultationDeviceCheckDialog(createCheck: () => probe),
                ),
                child: const Text('检查'),
              ),
            ),
          ),
        ),
      );
      expect(probe.starts, 0);
      await tester.tap(find.text('检查'));
      await tester.pumpAndSettle();
      expect(probe.starts, 1);
      expect(probe.closes, 1);
      await tester.tap(find.byTooltip('Close device check'));
      await tester.pumpAndSettle();
      expect(probe.closes, 2);
    },
  );
}
