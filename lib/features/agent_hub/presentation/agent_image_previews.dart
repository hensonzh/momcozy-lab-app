import 'dart:convert';
import 'agent_attachment_tile.dart';
import 'package:momcozy_flutter_app/features/media/presentation/media_viewer_header.dart';
import 'package:momcozy_flutter_app/features/media/presentation/media_viewer_feedback.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

typedef AgentImageContentLoader = Future<Uint8List> Function(String fileId);

class AgentSentImages extends StatelessWidget {
  const AgentSentImages({
    super.key,
    required this.images,
    this.loadImageThumbnail,
    this.loadImageContent,
  });

  final List<AgentStreamImageInput> images;
  final AgentImageContentLoader? loadImageThumbnail;
  final AgentImageContentLoader? loadImageContent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < images.length; index++) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('agent-sent-image-$index'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showSentImage(
                context,
                images[index],
                loadImageContent: loadImageContent,
              ),
              child: SizedBox(
                width: 112,
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _AgentDataUrlImage(
                    image: images[index],
                    loadImageContent: loadImageThumbnail,
                    fit: BoxFit.contain,
                    cacheWidth: 336,
                  ),
                ),
              ),
            ),
          ),
          if (index != images.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class AgentComposerImageAttachment extends StatelessWidget {
  const AgentComposerImageAttachment({
    super.key,
    required this.image,
    required this.removeButtonKey,
    required this.onRemove,
  });

  final AgentStreamImageInput image;
  final Key removeButtonKey;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return AgentAttachmentTile(
      name: image.name,
      size: image.size,
      removeButtonKey: removeButtonKey,
      removeLabel: 'Remove image',
      onRemove: onRemove,
      preview: _AgentDataUrlImage(
        image: image,
        fit: BoxFit.cover,
        cacheWidth: 192,
      ),
    );
  }
}

Future<void> _showSentImage(
  BuildContext context,
  AgentStreamImageInput image, {
  AgentImageContentLoader? loadImageContent,
}) {
  return showDialog<void>(
    context: context,
    animationStyle: MomCozyMotion.animationStyle(context),
    barrierColor: MomCozyColors.mediaBackground.withValues(alpha: 0.92),
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: MomCozyColors.mediaBackground,
        child: Column(
          children: [
            MediaViewerHeader(
              title: image.name,
              returnButtonKey: const ValueKey('agent-sent-image-close'),
              onBack: () => Navigator.of(dialogContext).pop(),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: _AgentFullScreenImage(
                  image: image,
                  loadImageContent: loadImageContent,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AgentFullScreenImage extends StatefulWidget {
  const _AgentFullScreenImage({
    required this.image,
    required this.loadImageContent,
  });

  final AgentStreamImageInput image;
  final AgentImageContentLoader? loadImageContent;

  @override
  State<_AgentFullScreenImage> createState() => _AgentFullScreenImageState();
}

class _AgentFullScreenImageState extends State<_AgentFullScreenImage> {
  late Future<Uint8List> _content;
  final _transformation = TransformationController();
  var _useRemote = false;

  bool get _canReload =>
      widget.image.fileId.trim().isNotEmpty && widget.loadImageContent != null;

  @override
  void initState() {
    super.initState();
    _content = _load();
  }

  Future<Uint8List> _load() => Future<Uint8List>.sync(() {
    final localBytes =
        widget.image.localBytes ?? _decodeDataUrl(widget.image.dataUrl);
    if (!_useRemote && localBytes != null) return localBytes;
    if (_canReload) return widget.loadImageContent!(widget.image.fileId.trim());
    throw StateError('image_unavailable');
  });

  void _retry() => setState(() {
    _useRemote = true;
    _transformation.value = Matrix4.identity();
    _content = _load();
  });

  Widget _error() => MediaViewerLoadError(
    message: _canReload ? 'Could not load image' : 'Could not display this image. Go back and choose it again.',
    onRetry: _canReload ? _retry : null,
  );

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _content,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const MediaViewerLoading(label: 'Loading image…');
      }
      final bytes = snapshot.data;
      if (snapshot.hasError || bytes == null || bytes.isEmpty) return _error();
      return Image.memory(
        bytes,
        key: const ValueKey('agent-original-image'),
        fit: BoxFit.contain,
        semanticLabel: widget.image.name,
        errorBuilder: (_, _, _) => _error(),
        frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
          if (frame == null && !wasSynchronouslyLoaded) {
            return const MediaViewerLoading(label: 'Loading image…');
          }
          return InteractiveViewer(
            key: const ValueKey('agent-image-stage'),
            transformationController: _transformation,
            minScale: 1,
            maxScale: 4,
            child: SizedBox.expand(child: image),
          );
        },
      );
    },
  );
}

class _AgentDataUrlImage extends StatefulWidget {
  const _AgentDataUrlImage({
    required this.image,
    required this.fit,
    this.loadImageContent,
    this.cacheWidth,
  });

  final AgentStreamImageInput image;
  final BoxFit fit;
  final AgentImageContentLoader? loadImageContent;
  final int? cacheWidth;

  @override
  State<_AgentDataUrlImage> createState() => _AgentDataUrlImageState();
}

class _AgentDataUrlImageState extends State<_AgentDataUrlImage> {
  late Uint8List? _bytes;
  Future<Uint8List>? _remoteBytes;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _AgentDataUrlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.dataUrl != widget.image.dataUrl ||
        !identical(oldWidget.image.localBytes, widget.image.localBytes) ||
        oldWidget.image.fileId != widget.image.fileId ||
        (oldWidget.loadImageContent == null &&
            widget.loadImageContent != null)) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    _bytes = widget.image.localBytes ?? _decodeDataUrl(widget.image.dataUrl);
    _remoteBytes = null;
    final fileId = widget.image.fileId.trim();
    final loader = widget.loadImageContent;
    if (_bytes == null && fileId.isNotEmpty && loader != null) {
      _remoteBytes = Future<Uint8List>.sync(() => loader(fileId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _AgentImageFallback(),
      );
    }
    final remoteBytes = _remoteBytes;
    if (remoteBytes != null) {
      return FutureBuilder<Uint8List>(
        future: remoteBytes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final loadedBytes = snapshot.data;
          if (loadedBytes != null && loadedBytes.isNotEmpty) {
            return Image.memory(
              loadedBytes,
              fit: widget.fit,
              cacheWidth: widget.cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const _AgentImageFallback(),
            );
          }
          return const _AgentImageFallback();
        },
      );
    }
    return const _AgentImageFallback();
  }
}

class _AgentImageFallback extends StatelessWidget {
  const _AgentImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: MomCozyColors.muted,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 20,
        color: MomCozyColors.mutedForeground,
      ),
    ),
  );
}

Uint8List? _decodeDataUrl(String dataUrl) {
  final marker = dataUrl.indexOf(',');
  if (marker < 0 || !dataUrl.substring(0, marker).contains(';base64')) {
    return null;
  }
  try {
    return base64Decode(dataUrl.substring(marker + 1));
  } catch (_) {
    return null;
  }
}
