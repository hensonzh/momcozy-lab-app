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
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector = connector ?? IoProductAssetHttpConnector();

  final Uri baseUri;
  final String? Function()? tokenProvider;
  final Future<bool> Function()? onUnauthorized;
  final ProductAssetHttpConnector connector;
  final Map<String, String> headers;
  final int maxImageBytes;

  Future<Uint8List> loadImage(String fileId) async {
    final normalizedFileId = fileId.trim();
    if (!_uuidPattern.hasMatch(normalizedFileId)) {
      throw const MediaContentLoadException(code: 'invalid_file_id');
    }
    try {
      var response = await _get(normalizedFileId);
      if (response.statusCode == HttpStatus.unauthorized &&
          await _refreshSession()) {
        response = await _get(normalizedFileId);
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
      if (response.body.isEmpty || response.body.length > maxImageBytes) {
        throw const MediaContentLoadException(code: 'image_size_invalid');
      }
      return response.body;
    } on MediaContentLoadException {
      rethrow;
    } catch (_) {
      throw const MediaContentLoadException(code: 'network_error');
    }
  }

  Future<ProductAssetHttpResponse> _get(String fileId) {
    return connector.get(
      _resolve(fileId),
      headers: _requestHeaders(),
      maxBytes: maxImageBytes,
    );
  }

  Uri _resolve(String fileId) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(
      path: '${basePath}v1/files/${Uri.encodeComponent(fileId)}/content',
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
