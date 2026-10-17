import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../domain/chat_first_cry_audio.dart';

/// Small native boundaries make cancellation and private-file cleanup testable.
abstract interface class CryAudioRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

abstract interface class CryAudioPlayer {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Future<Duration?> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> clear();
  Future<void> dispose();
}

class _NativeRecorder implements CryAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    ),
    path: path,
  );
  @override
  Future<String?> stop() => _recorder.stop();
  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Future<void> dispose() => _recorder.dispose();
}

class _NativePlayer implements CryAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<bool> get playingStream => _player.playerStateStream.map(
    (state) =>
        state.playing && state.processingState != ProcessingState.completed,
  );
  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> clear() async {
    await _player.stop();
    await _player.clearAudioSources();
  }

  @override
  Future<void> dispose() => _player.dispose();
}

/// Private temporary WAV, never an attachment, request or persisted snapshot.
/// Native capture, stop and deletion are serialized; clear invalidates a pending
/// permission prompt synchronously, before it can start a late recording.
class LocalChatFirstCryAudioSession implements ChatFirstCryAudioSession {
  LocalChatFirstCryAudioSession({
    CryAudioRecorder? recorder,
    CryAudioPlayer? player,
    Future<Directory> Function()? temporaryDirectory,
  }) : _recorder = recorder ?? _NativeRecorder(),
       _player = player ?? _NativePlayer(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final CryAudioRecorder _recorder;
  final CryAudioPlayer _player;
  final Future<Directory> Function() _temporaryDirectory;
  Future<void> _operations = Future.value();
  Directory? _captureDirectory;
  bool _recording = false;
  bool _disposed = false;
  int _captureRequest = 0;
  DateTime? _startedAt;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  bool _cancelled(int request) => _disposed || request != _captureRequest;

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> start() {
    if (_disposed) {
      return Future.error(StateError('Recording session is closed.'));
    }
    final request = ++_captureRequest;
    return _serialize(() async {
      await _clearResources();
      if (_cancelled(request)) throw StateError('Recording was cancelled.');
      if (!await _recorder.hasPermission()) {
        throw const ChatFirstCryPermissionException();
      }
      if (_cancelled(request)) throw StateError('Recording was cancelled.');
      final root = await _temporaryDirectory();
      if (_cancelled(request)) throw StateError('Recording was cancelled.');
      final directory = await Directory(
        '${root.path}/momcozy-cry-${const Uuid().v4()}',
      ).create();
      _captureDirectory = directory;
      var nativeStartAttempted = false;
      try {
        if (_cancelled(request)) throw StateError('Recording was cancelled.');
        nativeStartAttempted = true;
        await _recorder.start('${directory.path}/capture.wav');
        if (_cancelled(request)) throw StateError('Recording was cancelled.');
        _recording = true;
        _startedAt = DateTime.now();
      } catch (_) {
        // start() may have acquired the microphone before throwing or before
        // clear() invalidated this generation. Cancel even if it never returned.
        if (nativeStartAttempted) {
          try {
            await _recorder.cancel();
          } catch (_) {
            // Even an interrupted native cancel must not retain the WAV.
          } finally {
            _recording = false;
          }
        }
        await _clearResources();
        rethrow;
      }
    });
  }

  @override
  Future<Duration> stop() {
    final request = _captureRequest;
    return _serialize(() async {
      if (_cancelled(request) || !_recording || _captureDirectory == null) {
        throw StateError('No capture is in progress.');
      }
      try {
        final path = await _recorder.stop();
        _recording = false;
        if (_cancelled(request) ||
            path == null ||
            path.isEmpty ||
            !await File(path).exists()) {
          throw StateError('No recording was created.');
        }
        final duration = await _player.setFilePath(path);
        if (_cancelled(request)) throw StateError('Recording was cancelled.');
        return duration ??
            DateTime.now().difference(_startedAt ?? DateTime.now());
      } catch (_) {
        await _clearResources();
        rethrow;
      }
    });
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> clear() {
    ++_captureRequest;
    return _serialize(_clearResources);
  }

  Future<void> _clearResources() async {
    final directory = _captureDirectory;
    _captureDirectory = null;
    _startedAt = null;
    try {
      if (_recording) {
        _recording = false;
        await _recorder.cancel();
      }
    } finally {
      try {
        await _player.clear();
      } finally {
        if (directory != null && await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    }
  }

  @override
  Future<void> dispose() {
    if (_disposed) return _operations;
    _disposed = true;
    ++_captureRequest;
    return _serialize(() async {
      try {
        await _clearResources();
      } finally {
        try {
          await _recorder.dispose();
        } finally {
          await _player.dispose();
        }
      }
    });
  }
}
