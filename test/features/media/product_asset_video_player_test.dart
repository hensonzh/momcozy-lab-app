@Tags(['golden'])
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';
import '../../support/momcozy_test_fonts.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  late VideoPlayerPlatform previousPlatform;
  late FakeVideoPlayerPlatform videoPlatform;

  setUp(() {
    previousPlatform = VideoPlayerPlatform.instance;
    videoPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = previousPlatform;
  });

  testWidgets(
    'reduced motion opens fullscreen fully without elapsed animation',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(_repository()));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('product-asset-video-player')),
      );
      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-fullscreen')),
      );
      await tester.pump();
      await tester.pump();
      final fullscreen = find.byKey(
        const ValueKey('product-asset-video-immersive'),
      );
      expect(fullscreen, findsOneWidget);
      expect(ModalRoute.of(tester.element(fullscreen))!.animation!.value, 1);
      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-exit-fullscreen')).first,
      );
      await tester.pump();
      await tester.pump();
      expect(fullscreen, findsNothing);
      expect(videoPlatform.createdSources, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('video long duration, controls and fullscreen $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final deferredPlatform = _DeferredVideoPlatform();
        videoPlatform = deferredPlatform;
        VideoPlayerPlatform.instance = videoPlatform;
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
            home: Scaffold(
              body: ProductAssetVideoPlayer(
                reference: ProductAssetReference.tryParse(
                  '/v1/assets/asset-video?kind=video',
                )!,
                repository: _repository(),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('product-asset-video-loading')),
          findsOneWidget,
        );
        await _captureVideo(tester, 'loading', width, scale);
        deferredPlatform.ready.complete();
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('product-asset-video-player')),
        );
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Play full screen'), findsOneWidget);
        expect(find.text('Play full screen'), findsNothing);
        for (final key in ['play-pause', 'volume', 'fullscreen']) {
          final size = tester.getSize(
            find.byKey(ValueKey('product-asset-video-$key')),
          );
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }
        final canvas = tester.getRect(find.byType(VideoPlayer));
        final progress = tester.getRect(
          find.byKey(const ValueKey('product-asset-video-progress')),
        );
        expect(canvas.bottom, lessThanOrEqualTo(progress.top));
        {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/media-video-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
            ),
          );
        }
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-play-pause')),
        );
        await tester.pump();
        expect(videoPlatform.playedIds, [1]);
        await _captureVideo(tester, 'playing', width, scale);
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-play-pause')),
        );
        await tester.pump();
        expect(videoPlatform.pausedIds, contains(1));
        await _captureVideo(tester, 'paused', width, scale);
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-progress')),
        );
        await tester.pump();
        expect(videoPlatform.seekCommands, isNotEmpty);
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-volume')),
        );
        await tester.pump();
        expect(videoPlatform.volumeCommands, contains((1, 0.0)));
        await _captureVideo(tester, 'seek-mute', width, scale);
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-fullscreen')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/media-fullscreen-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
            ),
          );
        }
        if (width == 390 && scale == 1) {
          await tester.tap(
            find.byKey(const ValueKey('product-asset-video-play-pause')).last,
          );
          await tester.pump();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/ui_inventory/media-fullscreen-playing-390.png',
            ),
          );
          await tester.tap(
            find.byKey(const ValueKey('product-asset-video-play-pause')).last,
          );
          await tester.pump();
          expect(videoPlatform.pausedIds, contains(1));
        }
        await tester.tap(
          find
              .byKey(const ValueKey('product-asset-video-exit-fullscreen'))
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('product-asset-video-immersive')),
          findsNothing,
        );
        await _captureVideo(tester, 'returned', width, scale);
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-fullscreen')),
        );
        await tester.pumpAndSettle();
        videoPlatform.emitError(1, StateError('stream interrupted'));
        await tester.pumpAndSettle();
        expect(find.text('Video playback interrupted'), findsOneWidget);
        await _captureVideo(tester, 'interrupted', width, scale);
        await tester.tap(find.text('Back to video'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('product-asset-video-immersive')),
          findsNothing,
        );
        await _captureVideo(tester, 'error', width, scale);
        await tester.tap(
          find.byKey(const ValueKey('product-asset-video-retry')),
        );
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('product-asset-video-player')),
        );
        expect(videoPlatform.createdSources, hasLength(2));
        await _captureVideo(tester, 'recovered', width, scale);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _pumpUntil(tester, () => videoPlatform.disposedIds.contains(2));
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('video short and landscape accessible controls $size', (
      tester,
    ) async {
      await loadMomCozyTestFonts();
      tester.view.physicalSize = size;
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
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ProductAssetVideoPlayer(
              reference: ProductAssetReference.tryParse(
                '/v1/assets/asset-video?kind=video',
              )!,
              repository: _repository(),
            ),
          ),
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('product-asset-video-player')),
      );
      final suffix = size.width > size.height ? 'landscape' : 'short';
      await _captureVideo(tester, suffix, size.width, 2);
      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-fullscreen')),
      );
      await tester.pumpAndSettle();
      await _captureVideo(tester, '$suffix-fullscreen', size.width, 2);
      videoPlatform.emitError(1, StateError('short screen failure'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Back to video'));
      await tester.tap(find.text('Back to video'));
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('product-asset-video-retry'));
      await tester.ensureVisible(retry);
      await _captureVideo(tester, '$suffix-error', size.width, 2);
      await tester.tap(retry);
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('product-asset-video-player')),
      );
      expect(videoPlatform.createdSources, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _pumpUntil(tester, () => videoPlatform.disposedIds.contains(2));
    });
  }

  test('fake platform supports a successful controller lifecycle', () async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://api.example.test/video.mp4'),
    );

    await controller.initialize();
    await controller.dispose();

    expect(videoPlatform.disposedIds, [1]);
  });

  test('fake platform supports a failed controller lifecycle', () async {
    videoPlatform = FakeVideoPlayerPlatform(
      initializations: [
        FakeVideoInitialization.failure(StateError('network failed')),
      ],
    );
    VideoPlayerPlatform.instance = videoPlatform;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://api.example.test/video.mp4'),
    );

    await expectLater(controller.initialize(), throwsA(isA<Exception>()));
    await controller.dispose();

    expect(videoPlatform.disposedIds, [1]);
  });

  testWidgets('streams authenticated video and exposes playback controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository(tokenProvider: () => 'video-token');

    await tester.pumpWidget(_host(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-player')),
    );

    expect(videoPlatform.createdSources, hasLength(1));
    final source = videoPlatform.createdSources.single;
    expect(source.uri, 'https://api.example.test/v1/assets/asset-video');
    expect(source.httpHeaders['Authorization'], 'Bearer video-token');
    expect(source.httpHeaders['Accept'], 'video/*');
    expect(videoPlatform.playedIds, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('product-asset-video-play-pause')),
    );
    await tester.pump();
    expect(videoPlatform.playedIds, [1]);

    await tester.tap(find.byKey(const ValueKey('product-asset-video-volume')));
    await tester.pump();
    expect(videoPlatform.volumeCommands, contains((1, 0.0)));

    await tester.tap(
      find.byKey(const ValueKey('product-asset-video-fullscreen')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('product-asset-video-immersive')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-asset-video-rotated-canvas')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('product-asset-video-exit-fullscreen')).first,
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(
      tester,
      () => videoPlatform.disposedIds.contains(1),
      diagnostics: () => _videoDiagnostics(videoPlatform),
    );
    expect(videoPlatform.disposedIds, contains(1));
  });

  testWidgets('refreshes authorization once after initialization failure', (
    tester,
  ) async {
    videoPlatform = FakeVideoPlayerPlatform(
      initializations: [
        FakeVideoInitialization.failure(StateError('HTTP 401')),
        const FakeVideoInitialization.success(),
      ],
    );
    VideoPlayerPlatform.instance = videoPlatform;
    var token = 'expired-token';
    var refreshCalls = 0;
    final repository = _repository(
      tokenProvider: () => token,
      onUnauthorized: () async {
        refreshCalls += 1;
        token = 'fresh-token';
        return true;
      },
    );

    await tester.pumpWidget(_host(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-player')),
      diagnostics: () => _videoDiagnostics(videoPlatform),
    );

    expect(refreshCalls, 1);
    expect(videoPlatform.createdSources, hasLength(2));
    expect(
      videoPlatform.createdSources.first.httpHeaders['Authorization'],
      'Bearer expired-token',
    );
    expect(
      videoPlatform.createdSources.last.httpHeaders['Authorization'],
      'Bearer fresh-token',
    );
    expect(videoPlatform.disposedIds, contains(1));
  });

  testWidgets('shows a retry that rebuilds the failed video controller', (
    tester,
  ) async {
    videoPlatform = FakeVideoPlayerPlatform(
      initializations: [
        FakeVideoInitialization.failure(StateError('network failed')),
        FakeVideoInitialization.failure(StateError('retry failed')),
        const FakeVideoInitialization.success(),
      ],
    );
    VideoPlayerPlatform.instance = videoPlatform;
    final repository = _repository(onUnauthorized: () async => true);

    await tester.pumpWidget(_host(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-error')),
      diagnostics: () => _videoDiagnostics(videoPlatform),
    );
    expect(videoPlatform.createdSources, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('product-asset-video-retry')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-player')),
    );

    expect(videoPlatform.createdSources, hasLength(3));
    expect(videoPlatform.disposedIds, containsAll([1, 2]));
  });

  testWidgets('fullscreen interruption returns to a retryable player', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_repository()));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-player')),
    );
    await tester.tap(
      find.byKey(const ValueKey('product-asset-video-fullscreen')),
    );
    await tester.pumpAndSettle();
    videoPlatform.emitError(1, StateError('stream interrupted'));
    await tester.pumpAndSettle();
    expect(find.text('Video playback interrupted'), findsOneWidget);
    await tester.tap(find.text('Back to video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-asset-video-retry')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-player')),
    );
    expect(videoPlatform.createdSources, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('turns a runtime playback failure into a retryable state', (
    tester,
  ) async {
    final repository = _repository();

    await tester.pumpWidget(_host(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-player')),
    );
    videoPlatform.emitError(1, StateError('stream interrupted'));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('product-asset-video-error')),
      diagnostics: () => _videoDiagnostics(videoPlatform),
    );

    expect(videoPlatform.disposedIds, contains(1));
    expect(
      find.byKey(const ValueKey('product-asset-video-retry')),
      findsOneWidget,
    );
  });
}

Widget _host(ProductAssetRepository repository) {
  return MaterialApp(
    home: Scaffold(
      body: ProductAssetVideoPlayer(
        reference: ProductAssetReference.tryParse(
          '/v1/assets/asset-video?kind=video',
        )!,
        repository: repository,
      ),
    ),
  );
}

ProductAssetRepository _repository({
  String? Function()? tokenProvider,
  Future<bool> Function()? onUnauthorized,
}) {
  return ProductAssetRepository(
    baseUri: Uri.parse('https://api.example.test'),
    tokenProvider: tokenProvider,
    onUnauthorized: onUnauthorized,
    connector: const _UnusedConnector(),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  String Function()? diagnostics,
}) async {
  await _pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    diagnostics: diagnostics,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String Function()? diagnostics,
}) async {
  for (var frame = 0; frame < 80; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (condition()) return;
  }
  fail('Expected video state did not appear. ${diagnostics?.call() ?? ''}');
}

String _videoDiagnostics(FakeVideoPlayerPlatform platform) {
  return 'created=${platform.createdSources.length}, '
      'disposed=${platform.disposedIds}, '
      'loading=${find.byKey(const ValueKey('product-asset-video-loading')).evaluate().length}, '
      'error=${find.byKey(const ValueKey('product-asset-video-error')).evaluate().length}, '
      'player=${find.byKey(const ValueKey('product-asset-video-player')).evaluate().length}';
}

class _UnusedConnector implements ProductAssetHttpConnector {
  const _UnusedConnector();

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) => throw UnsupportedError('Video must use a streaming network request.');
}

Future<void> _captureVideo(
  WidgetTester tester,
  String state,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/design_system/media-video-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
    ),
  );
}

class _DeferredVideoPlatform extends FakeVideoPlayerPlatform {
  _DeferredVideoPlatform()
    : super(
        initializations: [
          const FakeVideoInitialization.success(
            duration: Duration(hours: 12, minutes: 34, seconds: 56),
          ),
        ],
      );
  final ready = Completer<void>();
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) async* {
    await ready.future;
    yield* super.videoEventsFor(playerId);
  }
}
