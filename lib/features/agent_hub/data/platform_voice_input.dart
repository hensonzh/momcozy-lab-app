import 'dart:io';

import 'package:app/features/agent_hub/domain/agent_voice.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AgentHubPlatformVoiceRecorder implements AgentVoiceRecorder {
  AgentHubPlatformVoiceRecorder([this._recorder]);

  AudioRecorder? _recorder;
  final Stopwatch _duration = Stopwatch();
  String? _activePath;

  @override
  Future<AgentVoiceInputPermissionState> permissionState() async {
    return _permissionState(await Permission.microphone.status);
  }

  @override
  Future<AgentVoiceInputPermissionState> requestPermission() async {
    return _permissionState(await Permission.microphone.request());
  }

  @override
  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/momcozy-agent-${DateTime.now().microsecondsSinceEpoch}.wav';
    _activePath = path;
    _duration
      ..reset()
      ..start();
    try {
      await _activeRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
    } catch (_) {
      _duration.stop();
      _activePath = null;
      rethrow;
    }
  }

  @override
  Future<AgentVoiceRecording?> stop() async {
    _duration.stop();
    final recordedPath = await _activeRecorder.stop() ?? _activePath;
    _activePath = null;
    if (recordedPath == null || recordedPath.trim().isEmpty) return null;

    final file = File(recordedPath);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return AgentVoiceRecording(
        name: 'speech.wav',
        mimeType: 'audio/wav',
        bytes: bytes,
        durationMs: _duration.elapsedMilliseconds,
      );
    } finally {
      await _deleteQuietly(file);
    }
  }

  @override
  Future<void> cancel() async {
    _duration.stop();
    final path = _activePath;
    _activePath = null;
    final recorder = _recorder;
    if (recorder != null) await recorder.cancel();
    if (path != null) await _deleteQuietly(File(path));
  }

  AudioRecorder get _activeRecorder => _recorder ??= AudioRecorder();
}

AgentVoiceInputPermissionState _permissionState(PermissionStatus status) {
  if (status.isGranted) return AgentVoiceInputPermissionState.granted;
  if (status.isPermanentlyDenied || status.isRestricted) {
    return AgentVoiceInputPermissionState.permanentlyDenied;
  }
  return AgentVoiceInputPermissionState.denied;
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Temporary recording cleanup is best effort.
  }
}
