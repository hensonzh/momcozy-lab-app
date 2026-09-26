import 'media_viewer_header.dart';
import 'media_viewer_feedback.dart';
import 'dart:async';
import 'pdf_document_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_image.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_video_player.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Uri? routeUri;
  final Object? routeExtra;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  void _returnFromMediaViewer() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final media = _MediaViewerRouteState.from(
      routeUri: widget.routeUri,
      routeExtra: widget.routeExtra,
    );
    final headerTitle = media?.title ?? 'Media';

    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: MomHomeTokens.background,
      child: Column(
        children: [
          MediaViewerHeader(title: headerTitle, onBack: _returnFromMediaViewer),
          Expanded(
            child: media == null
                ? const _MediaViewerMissingResource()
                : _MediaViewerContent(media: media),
          ),
        ],
      ),
    );
  }
}

class _MediaViewerMissingResource extends StatelessWidget {
  const _MediaViewerMissingResource();

  @override
  Widget build(BuildContext context) {
    return const MediaViewerLoadError(
      message: 'No resource to view',
      description: 'Open an image, video, or document from a resource card.',
      darkBackground: false,
      icon: Icons.description_outlined,
    );
  }
}

class _MediaViewerContent extends StatelessWidget {
  const _MediaViewerContent({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    return switch (media.kind) {
      'image' => _ImageViewerStage(media: media),
      'video' => _VideoViewerStage(media: media),
      _ => _PdfViewerStage(media: media),
    };
  }
}

class _PdfViewerStage extends StatefulWidget {
  const _PdfViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  State<_PdfViewerStage> createState() => _PdfViewerStageState();
}

class _PdfViewerStageState extends State<_PdfViewerStage> {
  ProductAssetReference? _reference;
  ProductAssetRepository? _repository;
  Future<ProductAssetContent>? _content;
  var _documentRevision = 0;
  int _page = 0, _pageCount = 0;
  final _pdfController = PdfViewerController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncContent();
  }

  @override
  void didUpdateWidget(_PdfViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url ||
        oldWidget.media.kind != widget.media.kind) {
      _syncContent();
    }
  }

  void _syncContent() {
    final reference = ProductAssetReference.tryParse(
      widget.media.url,
      kind: widget.media.kind,
      title: widget.media.title,
    );
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;
    if (_reference?.assetId == reference?.assetId &&
        _reference?.kind == reference?.kind &&
        identical(_repository, repository)) {
      return;
    }
    _reference = reference;
    _repository = repository;
    _documentRevision += 1;
    _page = 0;
    _pageCount = 0;
    _content = _load();
  }

  Future<ProductAssetContent>? _load() {
    final reference = _reference;
    final repository = _repository;
    if (reference == null || repository == null) {
      return null;
    }
    return repository.load(reference);
  }

  void _retry() {
    setState(() {
      _documentRevision += 1;
      _page = 0;
      _pageCount = 0;
      _content = _load();
      // Keep fast failures handled until FutureBuilder subscribes next frame.
      _content?.ignore();
    });
  }

  void _updatePager(int revision) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _documentRevision ||
          !_pdfController.isReady) {
        return;
      }
      final page = _pdfController.pageNumber ?? 1;
      final count = _pdfController.pageCount;
      if (page != _page || count != _pageCount) {
        setState(() {
          _page = page;
          _pageCount = count;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reference = _reference;
    final content = _content;
    if (reference == null || content == null) {
      return const MediaViewerLoadError(
        message: 'Could not load PDF',
        darkBackground: false,
        icon: Icons.picture_as_pdf_outlined,
      );
    }
    return FutureBuilder<ProductAssetContent>(
      future: content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MediaViewerLoading(
            label: 'Loading PDF…',
            darkBackground: false,
          );
        }
        if (snapshot.hasError) {
          return MediaViewerLoadError(
            message: 'Could not load PDF',
            darkBackground: false,
            icon: Icons.picture_as_pdf_outlined,
            onRetry: _retry,
          );
        }
        final loaded = snapshot.data;
        if (loaded == null) {
          return const ColoredBox(
            color: MomCozyColors.background,
            child: MediaViewerLoading(
              label: 'Loading PDF…',
              darkBackground: false,
            ),
          );
        }
        final revision = _documentRevision;
        return Column(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('media-pdf-viewer'),
                child: PdfViewer.data(
                  loaded.bytes,
                  key: ValueKey('media-pdf-document-$_documentRevision'),
                  sourceName: reference.assetId,
                  controller: _pdfController,
                  params: PdfViewerParams(
                    onViewerReady: (_, _) => _updatePager(revision),
                    onPageChanged: (_) => _updatePager(revision),
                    onGeneralTap: (_, controller, details) {
                      if (details.type != PdfViewerGeneralTapType.doubleTap) {
                        return false;
                      }
                      unawaited(
                        controller.zoomUpOnLocalPosition(
                          localPosition: details.localPosition,
                          loop: true,
                        ),
                      );
                      return true;
                    },
                    margin: MomCozySpacing.compact,
                    backgroundColor: MomHomeTokens.background,
                    minScale: 0.1,
                    maxScale: 4,
                    panAxis: PanAxis.free,
                    pageDropShadow: MomCozyShadows.documentPage,
                    loadingBannerBuilder: (context, downloaded, total) {
                      return const MediaViewerLoading(
                        label: 'Opening PDF…',
                        darkBackground: false,
                      );
                    },
                    errorBannerBuilder:
                        (context, error, stackTrace, documentRef) {
                          return MediaViewerLoadError(
                            message: 'Could not load PDF',
                            darkBackground: false,
                            icon: Icons.picture_as_pdf_outlined,
                            onRetry: _retry,
                          );
                        },
                  ),
                ),
              ),
            ),
            PdfDocumentToolbar(
              page: _page,
              pageCount: _pageCount,
              onPrevious: () => _pdfController.goToPage(pageNumber: _page - 1),
              onNext: () => _pdfController.goToPage(pageNumber: _page + 1),
              onZoomIn: () => _pdfController.zoomUp(),
              onZoomOut: () => _pdfController.zoomDown(),
            ),
          ],
        );
      },
    );
  }
}

class _ImageViewerStage extends StatefulWidget {
  const _ImageViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  State<_ImageViewerStage> createState() => _ImageViewerStageState();
}

class _ImageViewerStageState extends State<_ImageViewerStage> {
  static const _doubleTapScale = 2.5;

  final _transformationController = TransformationController();
  Offset? _doubleTapPosition;

  @override
  void didUpdateWidget(_ImageViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url) {
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.01) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapPosition ?? Offset.zero;
    _transformationController.value =
        Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
          ..setTranslationRaw(
            -position.dx * (_doubleTapScale - 1),
            -position.dy * (_doubleTapScale - 1),
            0,
          );
  }

  @override
  Widget build(BuildContext context) {
    final reference = ProductAssetReference.tryParse(
      widget.media.url,
      kind: widget.media.kind,
      title: widget.media.title,
    );
    if (reference == null) {
      return const MediaViewerLoadError(message: 'Could not load image');
    }
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;

    return ColoredBox(
      color: MomCozyColors.mediaBackground,
      child: ProductAssetImage(
        reference: reference,
        repository: repository,
        fit: BoxFit.contain,
        semanticLabel: widget.media.title,
        loadingBuilder: (context) {
          return const MediaViewerLoading(label: 'Loading image…');
        },
        errorBuilder: (context, error, retry) {
          return MediaViewerLoadError(
            message: 'Could not load image',
            onRetry: retry,
          );
        },
        loadedBuilder: (context, content, image) {
          return GestureDetector(
            key: const ValueKey('media-image-viewer'),
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) {
              _doubleTapPosition = details.localPosition;
            },
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              key: const ValueKey('media-image-interactive-viewer'),
              transformationController: _transformationController,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.expand(child: image),
            ),
          );
        },
      ),
    );
  }
}

class _VideoViewerStage extends StatelessWidget {
  const _VideoViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    final reference = ProductAssetReference.tryParse(
      media.url,
      kind: media.kind,
      title: media.title,
    );
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;
    if (reference == null || repository == null) {
      return const MediaViewerLoadError(
        message: 'Could not load video',
        icon: Icons.videocam_off_outlined,
      );
    }
    return ProductAssetVideoPlayer(
      reference: reference,
      repository: repository,
    );
  }
}

class _MediaViewerRouteState {
  const _MediaViewerRouteState({
    required this.kind,
    required this.url,
    required this.title,
  });

  final String kind;
  final String url;
  final String title;

  static const _supportedKinds = {'pdf', 'image', 'video'};

  static _MediaViewerRouteState? from({
    required Uri? routeUri,
    required Object? routeExtra,
  }) {
    final extra = routeExtra is Map ? routeExtra : null;
    final query = routeUri?.queryParameters ?? const <String, String>{};
    final kind = _normalizeKind(
      _stringFromMap(extra, 'kind') ?? _stringFromQuery(query, 'kind'),
    );
    final url = _nonEmpty(
      _stringFromMap(extra, 'url') ?? _stringFromQuery(query, 'url'),
    );
    if (kind == null || url == null) return null;
    final title =
        _nonEmpty(
          _stringFromMap(extra, 'title') ?? _stringFromQuery(query, 'title'),
        ) ??
        _defaultTitleForKind(kind);
    // Use the English half of a bilingual title when present. Otherwise keep
    // route metadata intact and show the media kind, not untranslated copy.
    final englishParts = _unsupportedTitleScript.hasMatch(title)
        ? title
              .split(RegExp(r'\s+[·|｜]\s+'))
              .map((part) => part.trim())
              .where(
                (part) =>
                    !_unsupportedTitleScript.hasMatch(part) &&
                    RegExp(r'[A-Za-z]').hasMatch(part),
              )
              .toList()
        : [title];
    final displayTitle = englishParts.isEmpty
        ? _defaultTitleForKind(kind)
        : englishParts.join(' · ').replaceAll(_retiredTitleBrand, 'Momcozy AI');
    return _MediaViewerRouteState(kind: kind, url: url, title: displayTitle);
  }

  static final _unsupportedTitleScript = RegExp(
    r'[\u3400-\u9fff\u{20000}-\u{323af}\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u0400-\u052f\u0600-\u06ff\u0900-\u097f\u0370-\u03ff\u0590-\u05ff\u0e00-\u0e7f]',
    unicode: true,
  );
  static final _retiredTitleBrand = RegExp(
    r'cozy[\s-]*mate',
    caseSensitive: false,
  );

  static String? _normalizeKind(String? value) {
    final normalized = _nonEmpty(value)?.toLowerCase();
    if (normalized == null || !_supportedKinds.contains(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _stringFromMap(Map<Object?, Object?>? map, String key) {
    final value = map?[key];
    return value is String ? value : null;
  }

  static String? _stringFromQuery(Map<String, String> query, String key) {
    final value = query[key];
    return value;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _defaultTitleForKind(String kind) {
    return switch (kind) {
      'image' => 'Image',
      'video' => 'Video',
      _ => 'PDF',
    };
  }
}
