import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/media/data/product_asset_repository.dart';
import 'package:app/features/media/domain/product_asset.dart';
import 'package:video_player/video_player.dart';

class ProductAssetVideoPlayer extends StatefulWidget {
  const ProductAssetVideoPlayer({
    super.key,
    required this.reference,
    required this.repository,
  });

  final ProductAssetReference reference;
  final ProductAssetRepository repository;

  @override
  State<ProductAssetVideoPlayer> createState() =>
      _ProductAssetVideoPlayerState();
}

class _ProductAssetVideoPlayerState extends State<ProductAssetVideoPlayer> {
  static const _initializationTimeout = Duration(seconds: 20);
  static const _refreshTimeout = Duration(seconds: 10);

  VideoPlayerController? _controller;
  Object? _error;
  var _loading = true;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo(notify: false));
  }

  @override
  void didUpdateWidget(covariant ProductAssetVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.assetId != widget.reference.assetId ||
        oldWidget.reference.kind != widget.reference.kind ||
        !identical(oldWidget.repository, widget.repository)) {
      unawaited(_loadVideo());
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(_disposeController(controller));
    super.dispose();
  }

  Future<void> _loadVideo({bool notify = true}) async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final reference = widget.reference;
    final previous = _controller;
    _controller = null;
    _error = null;
    _loading = true;
    if (notify && mounted) setState(() {});
    if (previous != null) await _disposeController(previous);
    if (!_isCurrent(generation)) return;

    final request = repository.networkRequest(reference);
    await _initializeRequest(
      generation: generation,
      repository: repository,
      reference: reference,
      request: request,
      allowAuthorizationRefresh: true,
    );
  }

  Future<void> _initializeRequest({
    required int generation,
    required ProductAssetRepository repository,
    required ProductAssetReference reference,
    required ProductAssetNetworkRequest request,
    required bool allowAuthorizationRefresh,
  }) async {
    final controller = VideoPlayerController.networkUrl(
      request.uri,
      httpHeaders: request.headers,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
    );
    try {
      await controller.initialize().timeout(_initializationTimeout);
      await controller.setLooping(false);
      if (!_isCurrent(generation)) {
        await _disposeController(controller);
        return;
      }
      controller.addListener(_onControllerValueChanged);
      setState(() {
        _controller = controller;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      await _disposeController(controller);
      if (!_isCurrent(generation)) return;
      if (allowAuthorizationRefresh) {
        final refreshed = await _refreshRequest(
          repository: repository,
          reference: reference,
        );
        if (!_isCurrent(generation)) return;
        if (refreshed != null) {
          await _initializeRequest(
            generation: generation,
            repository: repository,
            reference: reference,
            request: refreshed,
            allowAuthorizationRefresh: false,
          );
          return;
        }
      }
      if (!_isCurrent(generation)) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<ProductAssetNetworkRequest?> _refreshRequest({
    required ProductAssetRepository repository,
    required ProductAssetReference reference,
  }) async {
    try {
      return await repository
          .refreshNetworkRequest(reference)
          .timeout(_refreshTimeout);
    } catch (_) {
      return null;
    }
  }

  bool _isCurrent(int generation) {
    return mounted && generation == _loadGeneration;
  }

  Future<void> _disposeController(VideoPlayerController controller) async {
    controller.removeListener(_onControllerValueChanged);
    try {
      await controller.dispose();
    } catch (_) {
      // The next controller or the static error state remains usable.
    }
  }

  void _onControllerValueChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.hasError) return;
    controller.removeListener(_onControllerValueChanged);
    _loadGeneration += 1;
    _controller = null;
    _loading = false;
    _error = StateError(
      controller.value.errorDescription ?? 'Video playback failed.',
    );
    if (mounted) setState(() {});
    unawaited(_disposeController(controller));
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'product-asset-video-fullscreen'),
        opaque: true,
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ProductAssetVideoFullscreenPage(controller: controller);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _VideoLoadingState();
    final controller = _controller;
    if (_error != null || controller == null) {
      return _VideoErrorState(onRetry: _loadVideo);
    }
    return ColoredBox(
      color: MomCozyColors.background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('product-asset-video-fullscreen'),
              onPressed: _openFullscreen,
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
              label: const Text('全屏播放'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MomCozyColors.foreground,
                backgroundColor: MomCozyColors.secondary,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _ProductAssetVideoViewport(
                  controller: controller,
                  onFullscreen: _openFullscreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLoadingState extends StatelessWidget {
  const _VideoLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        key: ValueKey('product-asset-video-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xb3ffffff),
              ),
            ),
            SizedBox(height: 10),
            Text(
              '加载视频…',
              style: TextStyle(
                color: Color(0xb3ffffff),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        key: const ValueKey('product-asset-video-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Color(0xb3ffffff),
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              '视频加载失败',
              style: TextStyle(
                color: Color(0xb3ffffff),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              key: const ValueKey('product-asset-video-retry'),
              tooltip: '重新加载',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              color: const Color(0xb3ffffff),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductAssetVideoFullscreenPage extends StatelessWidget {
  const _ProductAssetVideoFullscreenPage({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('product-asset-video-immersive'),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _ProductAssetVideoViewport(
              controller: controller,
              immersive: true,
              onFullscreen: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: MediaQuery.paddingOf(context).right + 8,
            child: IconButton.filledTonal(
              key: const ValueKey('product-asset-video-exit-fullscreen'),
              tooltip: '退出全屏',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0x99000000),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductAssetVideoViewport extends StatelessWidget {
  const _ProductAssetVideoViewport({
    required this.controller,
    required this.onFullscreen,
    this.immersive = false,
  });

  final VideoPlayerController controller;
  final VoidCallback onFullscreen;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey(
        immersive
            ? 'product-asset-video-immersive-player'
            : 'product-asset-video-player',
      ),
      color: Colors.black,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: _ProductAssetVideoCanvas(
                  controller: controller,
                  value: value,
                  rotateLandscape: immersive,
                ),
              ),
              if (value.isBuffering)
                const Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _ProductAssetVideoControls(
                  controller: controller,
                  value: value,
                  immersive: immersive,
                  onFullscreen: onFullscreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductAssetVideoCanvas extends StatelessWidget {
  const _ProductAssetVideoCanvas({
    required this.controller,
    required this.value,
    required this.rotateLandscape,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool rotateLandscape;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = value.aspectRatio.isFinite && value.aspectRatio > 0
        ? value.aspectRatio
        : 16 / 9;
    final player = Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
    if (!rotateLandscape || aspectRatio <= 1) return player;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight <= constraints.maxWidth) return player;
        return Center(
          child: Transform.rotate(
            key: const ValueKey('product-asset-video-rotated-canvas'),
            angle: math.pi / 2,
            child: SizedBox(
              width: constraints.maxHeight,
              height: constraints.maxWidth,
              child: player,
            ),
          ),
        );
      },
    );
  }
}

class _ProductAssetVideoControls extends StatelessWidget {
  const _ProductAssetVideoControls({
    required this.controller,
    required this.value,
    required this.immersive,
    required this.onFullscreen,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool immersive;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final durationMilliseconds = math.max(0, value.duration.inMilliseconds);
    final positionMilliseconds = value.position.inMilliseconds.clamp(
      0,
      durationMilliseconds,
    );
    return ColoredBox(
      color: const Color(0xa6000000),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: immersive,
        minimum: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: MomCozyColors.primary,
                  inactiveTrackColor: const Color(0x66ffffff),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0x33ffffff),
                ),
                child: Slider(
                  key: const ValueKey('product-asset-video-progress'),
                  min: 0,
                  max: math.max(1, durationMilliseconds).toDouble(),
                  value: positionMilliseconds.toDouble(),
                  onChanged: durationMilliseconds > 0
                      ? (milliseconds) {
                          unawaited(
                            _runVideoCommand(
                              () => controller.seekTo(
                                Duration(milliseconds: milliseconds.round()),
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('product-asset-video-play-pause'),
                    tooltip: value.isPlaying ? '暂停' : '播放',
                    onPressed: () => unawaited(_togglePlayback()),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    color: Colors.white,
                  ),
                  Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('product-asset-video-volume'),
                    tooltip: value.volume == 0 ? '打开声音' : '静音',
                    onPressed: () {
                      final volume = value.volume == 0 ? 1.0 : 0.0;
                      unawaited(
                        _runVideoCommand(() => controller.setVolume(volume)),
                      );
                    },
                    icon: Icon(
                      value.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                    color: Colors.white,
                  ),
                  IconButton(
                    key: ValueKey(
                      immersive
                          ? 'product-asset-video-exit-fullscreen-control'
                          : 'product-asset-video-fullscreen-control',
                    ),
                    tooltip: immersive ? '退出全屏' : '全屏播放',
                    onPressed: onFullscreen,
                    icon: Icon(
                      immersive
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                    ),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (value.isPlaying) {
      await _runVideoCommand(controller.pause);
      return;
    }
    if (value.duration > Duration.zero && value.position >= value.duration) {
      await _runVideoCommand(() => controller.seekTo(Duration.zero));
    }
    await _runVideoCommand(controller.play);
  }
}

Future<void> _runVideoCommand(Future<void> Function() command) async {
  try {
    await command();
  } catch (_) {
    // The current controls remain available for another attempt.
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = math.max(0, duration.inSeconds);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = hours > 0
      ? minutes.toString().padLeft(2, '0')
      : minutes.toString();
  final body = '$minuteText:${seconds.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$body' : body;
}
