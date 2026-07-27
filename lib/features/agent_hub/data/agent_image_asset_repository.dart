import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/network/api_json_transport.dart';
import 'package:app/core/network/transport_security_policy.dart';
import 'package:app/features/media/data/product_asset_repository.dart';

class AgentImageAssetException implements Exception {
  const AgentImageAssetException({required this.code, this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'AgentImageAssetException($code)';
}

class AgentImageAssetRepository {
  AgentImageAssetRepository({
    required this.mutationTransport,
    required Uri baseUri,
    this.tokenProvider,
    this.onUnauthorized,
    ProductAssetHttpConnector? connector,
    this.headers = const {'X-Momcozy-Client': 'flutter'},
    this.maxBytes = 10 * 1024 * 1024,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector = connector ?? IoProductAssetHttpConnector();

  final ApiJsonTransport mutationTransport;
  final Uri baseUri;
  final String? Function()? tokenProvider;
  final Future<bool> Function()? onUnauthorized;
  final ProductAssetHttpConnector connector;
  final Map<String, String> headers;
  final int maxBytes;

  Future<void> discard(String assetId) async {
    final normalizedAssetId = _normalizedAssetId(assetId);
    final transport = mutationTransport;
    if (transport is! ApiJsonMutationTransport) {
      throw const AgentImageAssetException(
        code: 'mutation_transport_unavailable',
      );
    }
    final mutations = transport as ApiJsonMutationTransport;
    try {
      await mutations.deleteJson(
        '/v1/files/${Uri.encodeComponent(normalizedAssetId)}',
        headers: {'Idempotency-Key': 'agent-image-discard-$normalizedAssetId'},
      );
    } on ApiHttpException catch (error) {
      if (error.statusCode == HttpStatus.notFound) return;
      rethrow;
    }
  }

  Future<Uint8List> loadBytes(String assetId) async {
    final normalizedAssetId = _normalizedAssetId(assetId);
    try {
      var response = await _get(normalizedAssetId);
      if (response.statusCode == HttpStatus.unauthorized &&
          await _refreshSession()) {
        response = await _get(normalizedAssetId);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AgentImageAssetException(
          code: 'http_error',
          statusCode: response.statusCode,
        );
      }
      if (!response.contentType.toLowerCase().startsWith('image/')) {
        throw const AgentImageAssetException(code: 'content_type_mismatch');
      }
      if (response.body.length > maxBytes) {
        throw const AgentImageAssetException(code: 'asset_too_large');
      }
      return response.body;
    } on AgentImageAssetException {
      rethrow;
    } on ProductAssetLoadException catch (error) {
      throw AgentImageAssetException(
        code: error.code,
        statusCode: error.statusCode,
      );
    } catch (_) {
      throw const AgentImageAssetException(code: 'network_error');
    }
  }

  Future<ProductAssetHttpResponse> _get(String assetId) {
    return connector.get(
      _resolve(assetId),
      headers: _requestHeaders(),
      maxBytes: maxBytes,
    );
  }

  Uri _resolve(String assetId) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(
      path: '${basePath}v1/files/${Uri.encodeComponent(assetId)}/content',
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

String _normalizedAssetId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw const AgentImageAssetException(code: 'invalid_asset_id');
  }
  return normalized;
}
