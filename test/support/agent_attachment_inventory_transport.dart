import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'agent_inventory_transport.dart';

/// File picker/HTTP boundaries; production upload/delete and image codecs run.
class AgentAttachmentInventoryTransport extends AgentInventoryTransport
    implements ApiMultipartTransport, ProductAssetHttpConnector {
  final imageBytes = File('assets/images/mom/milk-hero.png').readAsBytesSync();
  final pdfBytes = File(
    'test/fixtures/media/local-preview.pdf',
  ).readAsBytesSync();
  final imageSources = <AgentImageInputSource>[];
  final uploads = <ApiUploadFile>[];
  final uploaded = <String, ApiUploadFile>{};
  final deleteRequests = <String>[];
  final deleteKeys = <String?>[];
  final contentRequests = <Uri>[];
  Completer<void>? pickerGate, uploadGate, deleteGate, contentGate;
  bool cancelPick = false, failPick = false, failUpload = false;
  bool brokenImage = false;
  String documentMode = 'pdf';
  int deleteStatus = 200, contentStatus = 200;
  int documentPicks = 0;

  Future<AgentStreamImageInput?> pickImage(AgentImageInputSource source) async {
    imageSources.add(source);
    await pickerGate?.future;
    if (failPick) throw StateError('Isolated picker failure');
    if (cancelPick) return null;
    final bytes = brokenImage
        ? Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])
        : imageBytes;
    return AgentStreamImageInput(
      dataUrl: '',
      localBytes: bytes,
      mimeType: 'image/png',
      name: 'Inventory illustration.png',
      size: bytes.length,
    );
  }

  Future<AgentHubLocalDocument?> pickDocument() =>
      AgentHubPlatformDocumentPicker(
        openDocument: () async {
          documentPicks++;
          await pickerGate?.future;
          if (failPick) throw StateError('Isolated document picker failure');
          if (cancelPick) return null;
          final bytes = switch (documentMode) {
            'oversized' => Uint8List(10 * 1024 * 1024 + 1),
            'unsupported' => imageBytes,
            'empty' => Uint8List(0),
            _ => pdfBytes,
          };
          return XFile.fromData(
            bytes,
            name: 'Inventory notes.pdf',
            mimeType: 'application/pdf',
          );
        },
      ).pick();

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    if (path != '/v1/files/upload') throw StateError('Unexpected upload path');
    uploads.add(file);
    file.onProgress?.call(file.sizeBytes ~/ 2, file.sizeBytes);
    await uploadGate?.future;
    if (failUpload) {
      throw const ApiHttpException(
        statusCode: 503,
        statusText: 'Unavailable',
        body: null,
      );
    }
    file.onProgress?.call(file.sizeBytes, file.sizeBytes);
    final id =
        '22222222-2222-4222-8222-${uploads.length.toString().padLeft(12, '0')}';
    uploaded[id] = file;
    return {
      'id': id,
      'original_filename': file.name,
      'content_type': file.mimeType,
      'size_bytes': file.sizeBytes,
    };
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    if (!path.startsWith('/v1/files/')) {
      return super.deleteJson(path, headers: headers);
    }
    final id = Uri.decodeComponent(path.substring('/v1/files/'.length));
    deleteRequests.add(id);
    deleteKeys.add(headers['Idempotency-Key']);
    await deleteGate?.future;
    if (deleteStatus != 200) {
      throw ApiHttpException(
        statusCode: deleteStatus,
        statusText: 'Isolated failure',
        body: null,
      );
    }
    uploaded.remove(id);
    return {};
  }

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    contentRequests.add(uri);
    // Deliver HTTP completion on a later event turn, like the real connector.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await contentGate?.future;
    return ProductAssetHttpResponse(
      statusCode: contentStatus,
      statusText: 'Isolated response',
      contentType: 'image/png',
      body: imageBytes,
    );
  }

  void releaseMediaGates() {
    for (final gate in [pickerGate, uploadGate, deleteGate, contentGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
  }
}
