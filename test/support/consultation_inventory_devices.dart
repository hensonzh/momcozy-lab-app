import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Platform method boundary only: production LiveKit tracks, device controller
/// and user route remain intact. This does not render native OS permission UI.
class ConsultationInventoryDevices {
  bool denied = false;
  Completer<void>? gate;
  final calls = <String>[];
  int streams = 0;
  final _visualizerChannels = <MethodChannel>[];

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('livekit_client'), (
      call,
    ) async {
      calls.add('livekit:${call.method}');
      if (call.method == 'startVisualizer') {
        final args = call.arguments as Map;
        final channel = MethodChannel(
          'io.livekit.audio.visualizer/eventChannel-${args['trackId']}-${args['visualizerId']}',
        );
        _visualizerChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (event) async {
          calls.add('visualizer:${event.method}');
          return null;
        });
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Event'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'getUserMedia') {
          await gate?.future;
          if (denied) {
            throw PlatformException(
              code: 'NotAllowedError',
              message: 'Isolated device permission denied',
            );
          }
          final constraints = (call.arguments as Map)['constraints'] as Map;
          final video = constraints['video'] != false;
          final kind = video ? 'video' : 'audio';
          return {
            'streamId': 'inventory-stream-${++streams}',
            'audioTracks': video ? [] : [_track(kind)],
            'videoTracks': video ? [_track(kind)] : [],
          };
        }
        if (call.method == 'getSources') return {'sources': []};
        return null;
      },
    );
    addTearDown(() {
      if (gate case final pending? when !pending.isCompleted) {
        pending.complete();
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('FlutterWebRTC.Method'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('FlutterWebRTC.Event'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('livekit_client'),
        null,
      );
      for (final channel in _visualizerChannels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }

  Map<String, Object?> _track(String kind) => {
    'id': 'inventory-$kind-$streams',
    'label': 'Isolated $kind',
    'kind': kind,
    'enabled': true,
    'settings': <String, Object?>{},
  };
}
