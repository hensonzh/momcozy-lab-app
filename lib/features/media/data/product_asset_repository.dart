import 'dart:async';
import 'dart:collection';
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

abstract interface class ProductAssetPersistentCache {
  Future<ProductAssetContent?> read(
    ProductAssetReference reference, {
    required ProductAssetVariant variant,
  });

  Future<void> write(
    ProductAssetContent content, {
    required ProductAssetVariant variant,
  });
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
    this.maxMemoryCacheBytes = 24 * 1024 * 1024,
    this.persistentCache,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector = connector ?? IoProductAssetHttpConnector();

  final Uri baseUri;
  final String? Function()? tokenProvider;
  final Future<bool> Function()? onUnauthorized;
  final ProductAssetHttpConnector connector;
  final Map<String, String> headers;
  final int maxImageBytes;
  final int maxPdfBytes;
  final int maxMemoryCacheBytes;
  final ProductAssetPersistentCache? persistentCache;
  final LinkedHashMap<String, ProductAssetContent> _memoryCache =
      LinkedHashMap<String, ProductAssetContent>();
  final Map<String, Future<ProductAssetContent>> _inFlight =
      <String, Future<ProductAssetContent>>{};
  int _memoryCacheBytes = 0;

  Future<ProductAssetContent> load(
    ProductAssetReference reference, {
    ProductAssetVariant variant = ProductAssetVariant.original,
  }) {
    if (reference.kind == ProductAssetKind.video) {
      return Future<ProductAssetContent>.error(
        const ProductAssetLoadException(code: 'streaming_asset_required'),
      );
    }
    if (variant == ProductAssetVariant.display &&
        reference.kind != ProductAssetKind.image) {
      return Future<ProductAssetContent>.error(
        const ProductAssetLoadException(code: 'unsupported_asset_variant'),
      );
    }
    final cacheKey = _cacheKey(reference, variant);
    final memoryCached = _takeMemoryCached(cacheKey);
    if (memoryCached != null) return Future.value(memoryCached);
    final pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    final future = _loadAndCache(
      reference,
      variant: variant,
      cacheKey: cacheKey,
    );
    _inFlight[cacheKey] = future;
    return future;
  }

  Future<ProductAssetContent> _loadAndCache(
    ProductAssetReference reference, {
    required ProductAssetVariant variant,
    required String cacheKey,
  }) async {
    final maxBytes = reference.kind == ProductAssetKind.image
        ? maxImageBytes
        : maxPdfBytes;
    try {
      final diskCached = await _readPersistentCache(
        reference,
        variant: variant,
      );
      if (diskCached != null) {
        _storeMemoryCached(cacheKey, diskCached);
        return diskCached;
      }

      var response = await _get(
        reference,
        variant: variant,
        maxBytes: maxBytes,
      );
      if (response.statusCode == HttpStatus.unauthorized &&
          await _refreshSession()) {
        response = await _get(reference, variant: variant, maxBytes: maxBytes);
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
      final content = ProductAssetContent(
        reference: reference,
        contentType: response.contentType,
        bytes: response.body,
      );
      _storeMemoryCached(cacheKey, content);
      unawaited(_writePersistentCache(content, variant: variant));
      return content;
    } on ProductAssetLoadException {
      rethrow;
    } catch (_) {
      throw const ProductAssetLoadException(code: 'network_error');
    } finally {
      _inFlight.remove(cacheKey);
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
    required ProductAssetVariant variant,
    required int maxBytes,
  }) {
    return connector.get(
      _resolve(reference, variant: variant),
      headers: _requestHeaders(reference),
      maxBytes: maxBytes,
    );
  }

  Uri _resolve(
    ProductAssetReference reference, {
    ProductAssetVariant variant = ProductAssetVariant.original,
  }) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final queryParameters = {
      ...baseUri.queryParameters,
      if (variant != ProductAssetVariant.original) 'variant': variant.name,
    };
    return baseUri.replace(
      path: '$basePath${reference.requestPath.substring(1)}',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
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

  String _cacheKey(
    ProductAssetReference reference,
    ProductAssetVariant variant,
  ) => '${reference.assetId}:${reference.kind.name}:${variant.name}';

  ProductAssetContent? _takeMemoryCached(String key) {
    final cached = _memoryCache.remove(key);
    if (cached == null) return null;
    _memoryCache[key] = cached;
    return cached;
  }

  void _storeMemoryCached(String key, ProductAssetContent content) {
    if (maxMemoryCacheBytes <= 0 ||
        content.bytes.length > maxMemoryCacheBytes) {
      return;
    }
    final previous = _memoryCache.remove(key);
    if (previous != null) _memoryCacheBytes -= previous.bytes.length;
    _memoryCache[key] = content;
    _memoryCacheBytes += content.bytes.length;
    while (_memoryCacheBytes > maxMemoryCacheBytes && _memoryCache.isNotEmpty) {
      final oldestKey = _memoryCache.keys.first;
      final oldest = _memoryCache.remove(oldestKey);
      if (oldest != null) _memoryCacheBytes -= oldest.bytes.length;
    }
  }

  Future<ProductAssetContent?> _readPersistentCache(
    ProductAssetReference reference, {
    required ProductAssetVariant variant,
  }) async {
    try {
      return await persistentCache?.read(reference, variant: variant);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistentCache(
    ProductAssetContent content, {
    required ProductAssetVariant variant,
  }) async {
    try {
      await persistentCache?.write(content, variant: variant);
    } catch (_) {
      // Cache failures must not turn a successful network load into an error.
    }
  }
}
