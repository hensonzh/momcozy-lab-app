import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/network/transport_security_policy.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';

import '../domain/stool_analysis.dart';

const stoolAnalysisEndpoint = '/v1/stool-analyses';

/// Independent specialty transport. Availability and thread binding are server-owned.
class StoolAnalysisApiRepository implements StoolAnalysisRepository {
  StoolAnalysisApiRepository({
    required this.jsonTransport,
    required this.streamConnector,
    required this.apiBaseUri,
    required this.accessTokenProvider,
    String Function()? languageProvider,
    this.onUnauthorized,
    ProductAssetHttpConnector? thumbnailConnector,
    this.deleteTransport,
  }) : languageProvider = languageProvider ?? (() => 'en'),
       thumbnailConnector = thumbnailConnector ?? IoProductAssetHttpConnector();

  final ApiJsonTransport jsonTransport;
  final AgentStreamSseGetConnector streamConnector;
  final Uri apiBaseUri;
  final String Function() accessTokenProvider;
  final String Function() languageProvider;
  final FutureOr<bool> Function()? onUnauthorized;
  final ProductAssetHttpConnector thumbnailConnector;
  final ApiJsonMutationTransport? deleteTransport;

  @override
  Future<bool> isAnalysisAvailable() async {
    final capability = await jsonTransport.getJson(
      '/v1/stool-photos/capability',
    );
    return capability['analysis_available'] == true;
  }

  @override
  Future<StoolAnalysisSnapshot> submit({
    required String babyId,
    required String threadId,
    required List<String> photoIds,
    required String idempotencyKey,
  }) async {
    if (babyId.isEmpty ||
        threadId.isEmpty ||
        idempotencyKey.isEmpty ||
        photoIds.isEmpty ||
        photoIds.length > 3 ||
        photoIds.any((id) => id.isEmpty) ||
        photoIds.toSet().length != photoIds.length) {
      throw const FormatException('Invalid stool analysis selection.');
    }
    final language = languageProvider()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    if (language != 'zh' && language != 'en') {
      throw const FormatException('Unsupported stool analysis language.');
    }
    return StoolAnalysisSnapshot.fromJson(
      await jsonTransport.postJson(
        stoolAnalysisEndpoint,
        headers: {
          'Idempotency-Key': idempotencyKey,
          'Accept-Language': language,
        },
        body: {'baby_id': babyId, 'thread_id': threadId, 'photo_ids': photoIds},
      ),
    );
  }

  @override
  Future<StoolAnalysisHistoryPage> listForThread({
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    if (threadId.isEmpty || limit < 1 || limit > 50 || cursor == '') {
      throw const FormatException('Invalid stool history request.');
    }
    final query = <String, Object?>{'thread_id': threadId, 'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    return StoolAnalysisHistoryPage.fromJson(
      await jsonTransport.getJson(stoolAnalysisEndpoint, query: query),
    );
  }

  @override
  Future<StoolAnalysisSnapshot> getStatus(String analysisId) async {
    if (analysisId.isEmpty) throw const FormatException('Missing analysis ID.');
    final result = StoolAnalysisSnapshot.fromJson(
      await jsonTransport.getJson(
        '$stoolAnalysisEndpoint/${Uri.encodeComponent(analysisId)}',
      ),
    );
    if (result.analysisId != analysisId) {
      throw const FormatException('Analysis ID mismatch.');
    }
    return result;
  }

  @override
  Future<void> deleteAnalysis(String analysisId) async {
    if (analysisId.isEmpty || deleteTransport == null) {
      throw const FormatException('Analysis deletion is unavailable.');
    }
    await deleteTransport!.deleteJson(
      '$stoolAnalysisEndpoint/${Uri.encodeComponent(analysisId)}',
    );
  }

  @override
  Future<StoolAnalysisPhotos> listPhotos(String analysisId) async {
    if (analysisId.isEmpty) throw const FormatException('Missing analysis ID.');
    return StoolAnalysisPhotos.fromJson(
      await jsonTransport.getJson(
        '$stoolAnalysisEndpoint/${Uri.encodeComponent(analysisId)}/photos',
      ),
    );
  }

  @override
  Future<Uint8List> loadThumbnail(String analysisId, String photoId) async {
    if (analysisId.isEmpty || photoId.isEmpty) {
      throw const FormatException('Missing analysis photo reference.');
    }
    final basePath = apiBaseUri.path.endsWith('/')
        ? apiBaseUri.path
        : '${apiBaseUri.path}/';
    final uri = TransportSecurityPolicy.requireSecureHttp(
      apiBaseUri.replace(
        path:
            '$basePath${stoolAnalysisEndpoint.substring(1)}/${Uri.encodeComponent(analysisId)}/photos/${Uri.encodeComponent(photoId)}/thumbnail',
      ),
    );
    Future<ProductAssetHttpResponse> get() async {
      final token = accessTokenProvider().trim();
      if (token.isEmpty) throw const FormatException('Missing access token.');
      return thumbnailConnector.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'image/jpeg'},
        maxBytes: 2 * 1024 * 1024,
      );
    }

    var response = await get();
    if (response.statusCode == HttpStatus.unauthorized &&
        onUnauthorized != null &&
        await onUnauthorized!()) {
      response = await get();
    }
    if (response.statusCode != 200 ||
        response.contentType != 'image/jpeg' ||
        response.body.length < 4 ||
        response.body.length > 2 * 1024 * 1024 ||
        response.body[0] != 0xff ||
        response.body[1] != 0xd8 ||
        response.body[2] != 0xff) {
      throw const FormatException('Thumbnail is unavailable.');
    }
    return response.body;
  }

  /// Server returns a finite committed page; reconnect with the last applied cursor.
  @override
  Stream<StoolAnalysisEvent> eventsAfter(
    String analysisId,
    int afterSequence,
  ) async* {
    if (analysisId.isEmpty || afterSequence < 0) {
      throw const FormatException('Invalid cursor.');
    }
    final basePath = apiBaseUri.path.endsWith('/')
        ? apiBaseUri.path
        : '${apiBaseUri.path}/';
    final uri = apiBaseUri.replace(
      path:
          '$basePath${stoolAnalysisEndpoint.substring(1)}/${Uri.encodeComponent(analysisId)}/events/stream',
      queryParameters: {'after_sequence': afterSequence.toString()},
    );
    TransportSecurityPolicy.requireSecureHttpOrWebSocket(uri);
    var refreshed = false;
    while (true) {
      final token = accessTokenProvider().trim();
      if (token.isEmpty) throw const FormatException('Missing access token.');
      try {
        await for (final frame in streamConnector.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          },
        )) {
          final lines = frame.trim().split(RegExp(r'\r?\n'));
          final data = lines
              .where((line) => line.startsWith('data: '))
              .toList();
          final ids = lines.where((line) => line.startsWith('id: ')).toList();
          final types = lines
              .where((line) => line.startsWith('event: '))
              .toList();
          if (data.length != 1 || ids.length != 1 || types.length != 1) {
            throw const FormatException('Invalid stool SSE envelope.');
          }
          final decoded = jsonDecode(data.single.substring(6));
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Invalid event data.');
          }
          final event = StoolAnalysisEvent.fromJson(decoded);
          if (event.analysisId != analysisId ||
              ids.single.substring(4) != event.sequence.toString() ||
              types.single.substring(7) != decoded['event_type']) {
            throw const FormatException('Stool SSE binding mismatch.');
          }
          yield event;
        }
        break;
      } on AgentStreamTransportException catch (error) {
        if (refreshed ||
            error.statusCode != 401 ||
            onUnauthorized == null ||
            !await onUnauthorized!()) {
          rethrow;
        }
        refreshed = true;
      }
    }
  }
}
