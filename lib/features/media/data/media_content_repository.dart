import 'dart:io';
import 'dart:typed_data';

import 'package:momcozy_flutter_app/core/network/transport_security_policy.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';

class MediaContentLoadException implements Exception {
  const MediaContentLoadException({required this.code, this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'MediaContentLoadException($code)';
}

class MediaContentRepository {
  MediaContentRepository({
    required Uri baseUri,
    this.tokenProvider,
    this.onUnauthorized,
    ProductAssetHttpConnector? connector,
    this.headers = const {'X-Momcozy-Client': 'flutter'},
    this.maxImageBytes = 10 * 1024 * 1024,
    this.maxThumbnailBytes = 1024 * 1024,
    this.maxCachedImages = 4,
    this.maxCachedThumbnails = 64,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector = connector ?? IoProductAssetHttpConnector();

  final Uri baseUri;
  final String? Function()? tokenProvider;
  final Future<bool> Function()? onUnauthorized;
  final ProductAssetHttpConnector connector;
  final Map<String, String> headers;
  final int maxImageBytes;
  final int maxThumbnailBytes;
  final int maxCachedImages;
  final int maxCachedThumbnails;
  final Map<String, Future<Uint8List>> _imageLoads = {};
  final Map<String, Uint8List> _imageBytes = {};
  final Map<String, Future<Uint8List>> _thumbnailLoads = {};
  final Map<String, Uint8List> _thumbnailBytes = {};

  Future<Uint8List> loadImage(String fileId) {
    final normalizedFileId = _validateFileId(fileId);
    final cached = cachedImage(normalizedFileId);
    if (cached != null) return Future.value(cached);
    final existing = _imageLoads[normalizedFileId];
    if (existing != null) return existing;

    late final Future<Uint8List> load;
    load =
        _loadImageVariant(
          fileId: normalizedFileId,
          variant: 'content',
          maxBytes: maxImageBytes,
        ).then(
          (bytes) {
            if (identical(_imageLoads[normalizedFileId], load)) {
              _imageLoads.remove(normalizedFileId);
              _rememberImage(normalizedFileId, bytes);
            }
            return bytes;
          },
          onError: (Object error, StackTrace stackTrace) {
            if (identical(_imageLoads[normalizedFileId], load)) {
              _imageLoads.remove(normalizedFileId);
            }
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
    _imageLoads[normalizedFileId] = load;
    return load;
  }

  Uint8List? cachedImage(String fileId) {
    final normalizedFileId = _validateFileId(fileId);
    final bytes = _imageBytes.remove(normalizedFileId);
    if (bytes != null) _imageBytes[normalizedFileId] = bytes;
    return bytes;
  }

  Future<Uint8List> loadImageThumbnail(String fileId) {
    final normalizedFileId = _validateFileId(fileId);
    final cached = _thumbnailLoads[normalizedFileId];
    if (cached != null) return cached;

    late final Future<Uint8List> load;
    load =
        _loadImageVariant(
          fileId: normalizedFileId,
          variant: 'thumbnail',
          maxBytes: maxThumbnailBytes,
        ).then(
          (bytes) {
            if (identical(_thumbnailLoads[normalizedFileId], load)) {
              _thumbnailBytes[normalizedFileId] = bytes;
            }
            return bytes;
          },
          onError: (Object error, StackTrace stackTrace) {
            if (identical(_thumbnailLoads[normalizedFileId], load)) {
              _thumbnailLoads.remove(normalizedFileId);
              _thumbnailBytes.remove(normalizedFileId);
            }
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
    _thumbnailLoads[normalizedFileId] = load;
    while (_thumbnailLoads.length > maxCachedThumbnails) {
      final evictedFileId = _thumbnailLoads.keys.first;
      _thumbnailLoads.remove(evictedFileId);
      _thumbnailBytes.remove(evictedFileId);
    }
    return load;
  }

  Uint8List? cachedImageThumbnail(String fileId) {
    return _thumbnailBytes[_validateFileId(fileId)];
  }

  void _rememberImage(String fileId, Uint8List bytes) {
    _imageBytes.remove(fileId);
    _imageBytes[fileId] = bytes;
    while (_imageBytes.length > maxCachedImages) {
      _imageBytes.remove(_imageBytes.keys.first);
    }
  }

  String _validateFileId(String fileId) {
    final normalizedFileId = fileId.trim();
    if (!_uuidPattern.hasMatch(normalizedFileId)) {
      throw const MediaContentLoadException(code: 'invalid_file_id');
    }
    return normalizedFileId;
  }

  Future<Uint8List> _loadImageVariant({
    required String fileId,
    required String variant,
    required int maxBytes,
  }) async {
    try {
      var response = await _get(fileId, variant: variant, maxBytes: maxBytes);
      if (response.statusCode == HttpStatus.unauthorized &&
          await _refreshSession()) {
        response = await _get(fileId, variant: variant, maxBytes: maxBytes);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaContentLoadException(
          code: 'http_error',
          statusCode: response.statusCode,
        );
      }
      if (!response.contentType.toLowerCase().startsWith('image/')) {
        throw const MediaContentLoadException(code: 'content_type_mismatch');
      }
      if (response.body.isEmpty || response.body.length > maxBytes) {
        throw const MediaContentLoadException(code: 'image_size_invalid');
      }
      return response.body;
    } on MediaContentLoadException {
      rethrow;
    } catch (_) {
      throw const MediaContentLoadException(code: 'network_error');
    }
  }

  Future<ProductAssetHttpResponse> _get(
    String fileId, {
    required String variant,
    required int maxBytes,
  }) {
    return connector.get(
      _resolve(fileId, variant: variant),
      headers: _requestHeaders(),
      maxBytes: maxBytes,
    );
  }

  Uri _resolve(String fileId, {required String variant}) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(
      path: '${basePath}v1/files/${Uri.encodeComponent(fileId)}/$variant',
      queryParameters: baseUri.queryParameters.isEmpty
          ? null
          : baseUri.queryParameters,
    );
  }

  Map<String, String> _requestHeaders() {
    final token = tokenProvider?.call()?.trim();
    return {
      ...headers,
      'Accept': 'image/*',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refreshSession() async {
    final callback = onUnauthorized;
    if (callback == null) return false;
    try {
      return await callback();
    } catch (_) {
      return false;
    }
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
