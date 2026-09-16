import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoInitialization {
  const FakeVideoInitialization.success({
    this.duration = const Duration(minutes: 2),
    this.size = const Size(1920, 1080),
  }) : error = null;

  const FakeVideoInitialization.failure(this.error)
    : duration = Duration.zero,
      size = Size.zero;

  final Duration duration;
  final Size size;
  final Object? error;
}

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({
    List<FakeVideoInitialization> initializations = const [],
    this.initializationFor,
  }) : _initializations = List.of(initializations);

  final List<FakeVideoInitialization> _initializations;

  /// Select failures by source when a journey also plays avatar animations.
  final FakeVideoInitialization Function(DataSource)? initializationFor;
  final List<DataSource> createdSources = [];
  final List<int> playedIds = [];
  final List<int> pausedIds = [];
  final List<int> disposedIds = [];
  final List<(int, Duration)> seekCommands = [];
  final List<(int, double)> volumeCommands = [];
  final Map<int, Duration> _positions = {};
  final Map<int, StreamController<VideoEvent>> _eventsById = {};
  var _nextPlayerId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) => _create(dataSource);

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) {
    return _create(options.dataSource);
  }

  Future<int> _create(DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    createdSources.add(dataSource);
    _positions[playerId] = Duration.zero;
    final initialization =
        initializationFor?.call(dataSource) ??
        (_initializations.isEmpty
            ? const FakeVideoInitialization.success()
            : _initializations.removeAt(0));
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>.broadcast(
      onListen: () {
        scheduleMicrotask(() {
          if (events.isClosed) return;
          final error = initialization.error;
          if (error != null) {
            events.addError(
              error is PlatformException
                  ? error
                  : PlatformException(code: 'video_error', message: '$error'),
            );
            return;
          }
          events.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: initialization.duration,
              size: initialization.size,
            ),
          );
        });
      },
    );
    _eventsById[playerId] = events;
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventsById[playerId]?.stream ?? const Stream.empty();
  }

  @override
  Widget buildView(int playerId) {
    return SizedBox.expand(key: ValueKey('fake-video-player-view-$playerId'));
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return buildView(options.playerId);
  }

  @override
  Future<void> play(int playerId) async {
    playedIds.add(playerId);
    _eventsById[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pausedIds.add(playerId);
    _eventsById[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
    seekCommands.add((playerId, position));
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumeCommands.add((playerId, volume));
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> dispose(int playerId) async {
    disposedIds.add(playerId);
    _positions.remove(playerId);
    await _eventsById.remove(playerId)?.close();
  }

  void emitError(int playerId, Object error) {
    _eventsById[playerId]?.addError(
      error is PlatformException
          ? error
          : PlatformException(code: 'video_error', message: '$error'),
    );
  }
}
