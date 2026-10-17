import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_cry_audio.dart';

void main() {
  late Directory root;
  late _Recorder recorder;
  late _Player player;
  late LocalChatFirstCryAudioSession session;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cry-audio-test-');
    recorder = _Recorder();
    player = _Player();
    session = LocalChatFirstCryAudioSession(
      recorder: recorder,
      player: player,
      temporaryDirectory: () async => root,
    );
  });
  tearDown(() async {
    await session.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'late permission after leave never starts recorder or creates file',
    () async {
      recorder.permission = Completer<bool>();
      final starting = session.start();
      await recorder.permissionEntered.future;
      final clearing = session.clear();
      recorder.permission!.complete(true);
      await expectLater(starting, throwsStateError);
      await clearing;
      expect(recorder.starts, 0);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test(
    'clear during native start cancels it and removes private directory',
    () async {
      recorder.starting = Completer<void>();
      final starting = session.start();
      await recorder.startEntered.future;
      final clearing = session.clear();
      recorder.starting!.complete();
      await expectLater(starting, throwsStateError);
      await clearing;
      expect(recorder.cancels, 1);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test(
    'native start failure still deletes private WAV if cancel also fails',
    () async {
      recorder.startError = StateError('native start interrupted');
      recorder.cancelError = StateError('native cancel interrupted');
      await expectLater(session.start(), throwsStateError);
      expect(recorder.cancels, 1);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test('clear while recording cancels and deletes temporary capture', () async {
    await session.start();
    final path = recorder.path!;
    await File(path).writeAsBytes([1, 2, 3]);
    await session.clear();
    expect(recorder.cancels, 1);
    expect(await File(path).exists(), isFalse);
    expect(await root.list().toList(), isEmpty);
  });

  test('clear while stop is resolving never leaves playable bytes', () async {
    await session.start();
    final path = recorder.path!;
    await File(path).writeAsBytes([1, 2, 3]);
    recorder.stopping = Completer<String?>();
    final stopping = session.stop();
    await recorder.stopEntered.future;
    final clearing = session.clear();
    recorder.stopping!.complete(path);
    await expectLater(stopping, throwsStateError);
    await clearing;
    expect(player.loads, 0);
    expect(await File(path).exists(), isFalse);
  });

  test(
    'preview then leave clears source, capture, and native objects',
    () async {
      await session.start();
      final path = recorder.path!;
      await File(path).writeAsBytes([1, 2, 3]);
      expect(await session.stop(), const Duration(seconds: 3));
      expect(player.loads, 1);
      await session.dispose();
      expect(player.clears, greaterThan(0));
      expect(player.disposed, isTrue);
      expect(recorder.disposed, isTrue);
      expect(await File(path).exists(), isFalse);
    },
  );

  test(
    'dispose during permission prompt invalidates before native disposal',
    () async {
      recorder.permission = Completer<bool>();
      final starting = session.start();
      await recorder.permissionEntered.future;
      final disposing = session.dispose();
      recorder.permission!.complete(true);
      await expectLater(starting, throwsStateError);
      await disposing;
      expect(recorder.starts, 0);
      expect(recorder.disposed, isTrue);
      expect(await root.list().toList(), isEmpty);
    },
  );
}

class _Recorder implements CryAudioRecorder {
  Completer<bool>? permission;
  Completer<void>? starting;
  Completer<String?>? stopping;
  final permissionEntered = Completer<void>();
  final startEntered = Completer<void>();
  final stopEntered = Completer<void>();
  String? path;
  Object? startError;
  Object? cancelError;
  int starts = 0;
  int cancels = 0;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async {
    if (!permissionEntered.isCompleted) permissionEntered.complete();
    return await permission?.future ?? true;
  }

  @override
  Future<void> start(String nextPath) async {
    starts++;
    path = nextPath;
    if (!startEntered.isCompleted) startEntered.complete();
    await starting?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<String?> stop() async {
    if (!stopEntered.isCompleted) stopEntered.complete();
    return stopping == null ? path : await stopping!.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class _Player implements CryAudioPlayer {
  int loads = 0;
  int clears = 0;
  bool disposed = false;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Future<Duration?> setFilePath(String path) async {
    loads++;
    return const Duration(seconds: 3);
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> clear() async => clears++;
  @override
  Future<void> dispose() async => disposed = true;
}
