import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

void main() {
  group('AgentVoiceInputController', () {
    test(
      'requests unknown microphone permission and transcribes recording',
      () async {
        final recorder = _FakeVoiceRecorder(
          initialPermission: AgentVoiceInputPermissionState.unknown,
          requestResult: AgentVoiceInputPermissionState.granted,
          recording: const AgentVoiceRecording(
            name: 'speech.wav',
            mimeType: 'audio/wav',
            bytes: [1, 2, 3],
          ),
        );
        final transcriber = _FakeVoiceTranscriber(' 今天左侧奶量偏低 ');
        final controller = AgentVoiceInputController(
          recorder: recorder,
          transcriber: transcriber,
        );

        final result = await controller.captureAndTranscribe();

        expect(result.status, AgentVoiceInputResultStatus.transcribed);
        expect(result.text, '今天左侧奶量偏低');
        expect(recorder.calls, [
          'permissionState',
          'requestPermission',
          'start',
          'stop',
        ]);
        expect(transcriber.recordings.single.name, 'speech.wav');
      },
    );

    test(
      'does not start recording when microphone permission is denied',
      () async {
        final recorder = _FakeVoiceRecorder(
          initialPermission: AgentVoiceInputPermissionState.unknown,
          requestResult: AgentVoiceInputPermissionState.denied,
        );
        final controller = AgentVoiceInputController(
          recorder: recorder,
          transcriber: _FakeVoiceTranscriber('ignored'),
        );

        final result = await controller.captureAndTranscribe();

        expect(result.status, AgentVoiceInputResultStatus.permissionDenied);
        expect(result.permissionState, AgentVoiceInputPermissionState.denied);
        expect(recorder.calls, ['permissionState', 'requestPermission']);
      },
    );

    test('cancels active recording if stop fails', () async {
      final recorder = _FakeVoiceRecorder(
        initialPermission: AgentVoiceInputPermissionState.granted,
        stopFailure: StateError('recorder stopped unexpectedly'),
      );
      final controller = AgentVoiceInputController(
        recorder: recorder,
        transcriber: _FakeVoiceTranscriber('ignored'),
      );

      await expectLater(controller.captureAndTranscribe(), throwsStateError);

      expect(recorder.calls, ['permissionState', 'start', 'stop', 'cancel']);
    });
  });
}

class _FakeVoiceRecorder implements AgentVoiceRecorder {
  _FakeVoiceRecorder({
    this.initialPermission = AgentVoiceInputPermissionState.granted,
    this.requestResult = AgentVoiceInputPermissionState.granted,
    this.recording = const AgentVoiceRecording(
      name: 'speech.webm',
      mimeType: 'audio/webm',
      bytes: [1],
    ),
    this.stopFailure,
  });

  final AgentVoiceInputPermissionState initialPermission;
  final AgentVoiceInputPermissionState requestResult;
  final AgentVoiceRecording? recording;
  final Object? stopFailure;
  final List<String> calls = [];

  @override
  Future<AgentVoiceInputPermissionState> permissionState() async {
    calls.add('permissionState');
    return initialPermission;
  }

  @override
  Future<AgentVoiceInputPermissionState> requestPermission() async {
    calls.add('requestPermission');
    return requestResult;
  }

  @override
  Future<void> start() async {
    calls.add('start');
  }

  @override
  Future<AgentVoiceRecording?> stop() async {
    calls.add('stop');
    final failure = stopFailure;
    if (failure != null) throw failure;
    return recording;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }
}

class _FakeVoiceTranscriber implements AgentVoiceTranscriber {
  _FakeVoiceTranscriber(this.text);

  final String? text;
  final List<AgentVoiceRecording> recordings = [];

  @override
  Future<String?> transcribe(AgentVoiceRecording recording) async {
    recordings.add(recording);
    return text;
  }
}
