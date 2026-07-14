import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:momcozy_flutter_app/core/network/transport_security_policy.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';

class ProductAssetContent {
  const ProductAssetContent({
    required this.reference,
    required this.contentType,
    required this.bytes,
  });

  final ProductAssetReference reference;
  final String contentType;
  final Uint8List bytes;
}

class ProductAssetNetworkRequest {
  const ProductAssetNetworkRequest({required this.uri, required this.headers});

  final Uri uri;
  final Map<String, String> headers;
}

class ProductAssetLoadException implements Exception {
  const ProductAssetLoadException({required this.code, this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'ProductAssetLoadException($code)';
}

class ProductAssetHttpResponse {
  const ProductAssetHttpResponse({
    required this.statusCode,
    required this.statusText,
    required this.contentType,
    required this.body,
  });

  final int statusCode;
  final String statusText;
  final String contentType;
  final Uint8List body;
}

abstract interface class ProductAssetHttpConnector {
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  });
}

class IoProductAssetHttpConnector implements ProductAssetHttpConnector {
  IoProductAssetHttpConnector({
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 60),
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final Duration timeout;

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(timeout);
    final declaredLength = response.contentLength;
    if (declaredLength > maxBytes) {
      throw const ProductAssetLoadException(code: 'asset_too_large');
    }

    final body = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(timeout)) {
      if (body.length + chunk.length > maxBytes) {
        throw const ProductAssetLoadException(code: 'asset_too_large');
      }
      body.add(chunk);
    }
    return ProductAssetHttpResponse(
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
      contentType: response.headers.contentType?.mimeType ?? '',
      body: body.takeBytes(),
    );
  }
}

class ProductAssetRepository {
  ProductAssetRepository({
    required Uri baseUri,
    this.tokenProvider,
    this.onUnauthorized,
    ProductAssetHttpConnector? connector,
    this.headers = const {'X-Momcozy-Client': 'flutter'},
    this.maxImageBytes = 16 * 1024 * 1024,
    this.maxPdfBytes = 32 * 1024 * 1024,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector = connector ?? IoProductAssetHttpConnector();

  final Uri baseUri;
  final String? Function()? tokenProvider;
  final Future<bool> Function()? onUnauthorized;
  final ProductAssetHttpConnector connector;
  final Map<String, String> headers;
  final int maxImageBytes;
  final int maxPdfBytes;

  Future<ProductAssetContent> load(ProductAssetReference reference) async {
    if (reference.kind == ProductAssetKind.video) {
      throw const ProductAssetLoadException(code: 'streaming_asset_required');
    }
    final maxBytes = reference.kind == ProductAssetKind.image
        ? maxImageBytes
        : maxPdfBytes;
    try {
      var response = await _get(reference, maxBytes: maxBytes);
      if (response.statusCode == HttpStatus.unauthorized &&
          await _refreshSession()) {
        response = await _get(reference, maxBytes: maxBytes);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProductAssetLoadException(
          code: 'http_error',
          statusCode: response.statusCode,
        );
      }
      if (response.body.length > maxBytes) {
        throw const ProductAssetLoadException(code: 'asset_too_large');
      }
      final actualKind = ProductAssetKind.fromContentType(response.contentType);
      if (actualKind != reference.kind) {
        throw const ProductAssetLoadException(code: 'content_type_mismatch');
      }
      return ProductAssetContent(
        reference: reference,
        contentType: response.contentType,
        bytes: response.body,
      );
    } on ProductAssetLoadException {
      rethrow;
    } catch (_) {
      throw const ProductAssetLoadException(code: 'network_error');
    }
  }

  ProductAssetNetworkRequest networkRequest(ProductAssetReference reference) {
    return ProductAssetNetworkRequest(
      uri: _resolve(reference),
      headers: Map<String, String>.unmodifiable(_requestHeaders(reference)),
    );
  }

  Future<ProductAssetNetworkRequest?> refreshNetworkRequest(
    ProductAssetReference reference,
  ) async {
    if (!await _refreshSession()) return null;
    return networkRequest(reference);
  }

  Future<ProductAssetHttpResponse> _get(
    ProductAssetReference reference, {
    required int maxBytes,
  }) {
    return connector.get(
      _resolve(reference),
      headers: _requestHeaders(reference),
      maxBytes: maxBytes,
    );
  }

  Uri _resolve(ProductAssetReference reference) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(
      path: '$basePath${reference.requestPath.substring(1)}',
      queryParameters: baseUri.queryParameters.isEmpty
          ? null
          : baseUri.queryParameters,
    );
  }

  Map<String, String> _requestHeaders(ProductAssetReference reference) {
    final token = tokenProvider?.call()?.trim();
    return {
      ...headers,
      'Accept': reference.kind.acceptHeader,
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
