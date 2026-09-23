import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

class AgentHubInteractionSnapshot {
  const AgentHubInteractionSnapshot({
    this.runState = const AgentStreamRunState(),
    this.historyMessages = const <AgentHubHistorySnapshot>[],
    this.composerText = '',
    this.attachedImages = const <AgentStreamImageInput>[],
    this.attachedFiles = const <AgentStreamFileInput>[],
    this.pendingAttachmentCleanupIds = const <String>[],
    this.activeRequest,
    this.nextBeforeSequence,
  });

  final int? nextBeforeSequence;
  final AgentStreamRunState runState;
  final List<AgentHubHistorySnapshot> historyMessages;
  final String composerText;
  final List<AgentStreamImageInput> attachedImages;
  final List<AgentStreamFileInput> attachedFiles;
  final List<String> pendingAttachmentCleanupIds;

  final AgentStreamRequest? activeRequest;

  bool get hasContent {
    return runState.events.isNotEmpty ||
        runState.textContent.trim().isNotEmpty ||
        runState.provisionalTextContent.trim().isNotEmpty ||
        runState.threadId?.trim().isNotEmpty == true ||
        runState.runId?.trim().isNotEmpty == true ||
        historyMessages.isNotEmpty ||
        composerText.trim().isNotEmpty ||
        attachedImages.isNotEmpty ||
        attachedFiles.isNotEmpty ||
        pendingAttachmentCleanupIds.isNotEmpty ||
        activeRequest != null;
  }

  bool get hasConversationHistory {
    return historyMessages.isNotEmpty ||
        runState.events.isNotEmpty ||
        runState.textContent.trim().isNotEmpty ||
        runState.provisionalTextContent.trim().isNotEmpty;
  }

  Map<String, Object?> toMap({bool includeImageData = true}) => {
    'runState': runState.toMap(),
    if (nextBeforeSequence != null) 'nextBeforeSequence': nextBeforeSequence,
    if (historyMessages.any(
      (message) =>
          includeImageData ||
          message.content.trim().isNotEmpty ||
          message.images.any(_hasFileReference) ||
          message.files.isNotEmpty ||
          message.runState != null,
    ))
      'historyMessages': historyMessages
          .where(
            (message) =>
                includeImageData ||
                message.content.trim().isNotEmpty ||
                message.images.any(_hasFileReference) ||
                message.files.isNotEmpty ||
                message.runState != null,
          )
          .map((message) => message.toMap(includeImageData: includeImageData))
          .toList(growable: false),
    if (composerText.isNotEmpty) 'composerText': composerText,
    if (attachedImages.any(
      (image) => includeImageData || _hasFileReference(image),
    ))
      'attachedImages': _imagesToPersistenceMaps(
        attachedImages,
        includeImageData: includeImageData,
      ),
    if (attachedFiles.isNotEmpty)
      'attachedFiles': attachedFiles.map(_fileToMap).toList(growable: false),
    if (pendingAttachmentCleanupIds.isNotEmpty)
      'pendingAttachmentCleanupIds': pendingAttachmentCleanupIds,
    if (activeRequest != null &&
        (includeImageData || activeRequest!.images.every(_hasFileReference)))
      'activeRequest': _requestToPersistenceMap(
        activeRequest!,
        historyMessages,
        includeImageData: includeImageData,
      ),
  };

  static AgentHubInteractionSnapshot fromMap(Map<String, Object?> map) {
    final historyMessages = _historyFromList(map['historyMessages']);
    final activeRequest = _requestFromPersistenceMap(
      map['activeRequest'],
      historyMessages,
    );
    return AgentHubInteractionSnapshot(
      runState: _runStateFromMap(map['runState']),
      historyMessages: historyMessages,
      composerText: _string(map['composerText']) ?? '',
      attachedImages: _imagesFromList(map['attachedImages']),
      attachedFiles: _filesFromList(map['attachedFiles']),
      pendingAttachmentCleanupIds:
          (map['pendingAttachmentCleanupIds'] as List? ?? const [])
              .whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList(growable: false),
      activeRequest: activeRequest,
      nextBeforeSequence: map['nextBeforeSequence'] is int
          ? map['nextBeforeSequence'] as int
          : null,
    );
  }
}

class AgentHubHistorySnapshot {
  const AgentHubHistorySnapshot({
    required this.role,
    required this.content,
    this.id,
    this.sequence,
    this.createdAt,
    this.runState,
    this.images = const <AgentStreamImageInput>[],
    this.files = const <AgentStreamFileInput>[],
  });

  final String? id;
  final int? sequence;
  final DateTime? createdAt;
  final String role;
  final String content;
  final AgentStreamRunState? runState;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;

  Map<String, Object?> toMap({bool includeImageData = true}) => {
    'role': role,
    if (id != null) 'id': id,
    if (sequence != null) 'sequence': sequence,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    'content': content,
    if (runState != null) 'runState': runState!.toMap(),
    if (images.any((image) => includeImageData || _hasFileReference(image)))
      'images': _imagesToPersistenceMaps(
        images,
        includeImageData: includeImageData,
      ),
    if (files.isNotEmpty)
      'files': files.map(_fileToMap).toList(growable: false),
  };

  static AgentHubHistorySnapshot? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final content = _string(map['content'])?.trim() ?? '';
    final images = _imagesFromList(map['images']);
    final files = _filesFromList(map['files']);
    if (content.isEmpty && images.isEmpty && files.isEmpty) return null;
    final role = _string(map['role']) == 'user' ? 'user' : 'assistant';
    final runStateValue = map['runState'] ?? map['run_state'];
    return AgentHubHistorySnapshot(
      role: role,
      id: _string(map['id']),
      sequence: map['sequence'] is int ? map['sequence'] as int : null,
      createdAt: DateTime.tryParse(_string(map['createdAt']) ?? ''),
      content: content,
      images: images,
      files: files,
      runState: runStateValue is Map
          ? AgentStreamRunState.fromMap(
              Map<String, Object?>.from(runStateValue),
            )
          : null,
    );
  }
}

abstract interface class AgentHubInteractionStateStore {
  Future<AgentHubInteractionSnapshot?> read();

  Future<void> write(AgentHubInteractionSnapshot snapshot);

  Future<void> clear();
}

class FlutterSecureAgentHubInteractionStateStore
    implements AgentHubInteractionStateStore {
  const FlutterSecureAgentHubInteractionStateStore({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.agentHub.v1',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<AgentHubInteractionSnapshot?> read() async {
    final raw = await storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AgentHubInteractionSnapshot.fromMap(
        Map<String, Object?>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) {
    if (!snapshot.hasContent) return clear();
    return storage.write(
      key: _key,
      value: jsonEncode(snapshot.toMap(includeImageData: false)),
    );
  }

  @override
  Future<void> clear() {
    return storage.delete(key: _key);
  }

  String get _key {
    final scopedUserId = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scopedUserId)}.snapshot';
  }
}

AgentStreamRunState _runStateFromMap(Object? value) {
  if (value is! Map) return const AgentStreamRunState();
  return AgentStreamRunState.fromMap(Map<String, Object?>.from(value));
}

List<AgentHubHistorySnapshot> _historyFromList(Object? value) {
  if (value is! List) return const <AgentHubHistorySnapshot>[];
  return List<AgentHubHistorySnapshot>.unmodifiable(
    value
        .map(AgentHubHistorySnapshot.fromMap)
        .whereType<AgentHubHistorySnapshot>(),
  );
}

List<AgentStreamImageInput> _imagesFromList(Object? value) {
  if (value is! List) return const <AgentStreamImageInput>[];
  return List<AgentStreamImageInput>.unmodifiable(
    value.map(_imageFromMap).whereType<AgentStreamImageInput>(),
  );
}

List<AgentStreamFileInput> _filesFromList(Object? value) {
  if (value is! List) return const <AgentStreamFileInput>[];
  return List<AgentStreamFileInput>.unmodifiable(
    value.map(_fileFromMap).whereType<AgentStreamFileInput>(),
  );
}

String? _string(Object? value) => value is String ? value : null;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

Map<String, Object?> _requestToMap(AgentStreamRequest request) => {
  'message': request.message,
  if (request.threadId != null) 'threadId': request.threadId,
  if (request.runId != null) 'runId': request.runId,
  'afterSequence': request.afterSequence,
  'locale': request.locale,
  if (request.images.isNotEmpty)
    'images': request.images.map(_imageToMap).toList(growable: false),
  if (request.files.isNotEmpty)
    'files': request.files.map(_fileToMap).toList(growable: false),
  if (request.metadata.isNotEmpty) 'metadata': request.metadata,
  if (request.idempotencyKey != null) 'idempotencyKey': request.idempotencyKey,
};

Map<String, Object?> _requestToPersistenceMap(
  AgentStreamRequest request,
  List<AgentHubHistorySnapshot> historyMessages, {
  bool includeImageData = true,
}) {
  if (!includeImageData) {
    return {
      ..._requestToMap(_requestWithImages(request, const [])),
      if (request.images.isNotEmpty)
        'images': _imagesToPersistenceMaps(
          request.images,
          includeImageData: false,
        ),
    };
  }
  if (request.images.isEmpty) return _requestToMap(request);
  for (final message in historyMessages.reversed) {
    if (message.role != 'user') continue;
    if (!_sameImages(message.images, request.images)) break;
    return {
      ..._requestToMap(_requestWithImages(request, const [])),
      'imagesFromHistory': true,
    };
  }
  return _requestToMap(request);
}

AgentStreamRequest? _requestFromPersistenceMap(
  Object? value,
  List<AgentHubHistorySnapshot> historyMessages,
) {
  final request = _requestFromMap(value);
  if (request == null || value is! Map || value['imagesFromHistory'] != true) {
    return request;
  }
  for (final message in historyMessages.reversed) {
    if (message.role == 'user') {
      return _requestWithImages(request, message.images);
    }
  }
  return request;
}

AgentStreamRequest _requestWithImages(
  AgentStreamRequest request,
  List<AgentStreamImageInput> images,
) {
  return AgentStreamRequest(
    message: request.message,
    threadId: request.threadId,
    runId: request.runId,
    afterSequence: request.afterSequence,
    locale: request.locale,
    images: images,
    files: request.files,
    metadata: request.metadata,
    idempotencyKey: request.idempotencyKey,
  );
}

bool _sameImages(
  List<AgentStreamImageInput> left,
  List<AgentStreamImageInput> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    if (a.dataUrl != b.dataUrl ||
        a.assetId != b.assetId ||
        a.fileId != b.fileId ||
        a.mimeType != b.mimeType ||
        a.name != b.name ||
        a.size != b.size ||
        a.detail != b.detail) {
      return false;
    }
  }
  return true;
}

AgentStreamRequest? _requestFromMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final message = _string(map['message']) ?? '';
  final metadata = map['metadata'];
  return AgentStreamRequest(
    message: message,
    threadId: _string(map['threadId']) ?? _string(map['thread_id']),
    runId: _string(map['runId']) ?? _string(map['run_id']),
    afterSequence: _int(map['afterSequence']) == 0
        ? _int(map['after_sequence'])
        : _int(map['afterSequence']),
    locale: _string(map['locale']) ?? 'zh-CN',
    images: _imagesFromList(map['images']),
    files: _filesFromList(map['files']),
    metadata: metadata is Map
        ? Map<String, Object?>.from(metadata)
        : const <String, Object?>{},
    idempotencyKey:
        _string(map['idempotencyKey']) ?? _string(map['idempotency_key']),
  );
}

Map<String, Object?> _imageToMap(AgentStreamImageInput image) => {
  'dataUrl': image.dataUrl,
  if (image.assetId.trim().isNotEmpty) 'assetId': image.assetId.trim(),
  if (image.fileId.trim().isNotEmpty) 'fileId': image.fileId.trim(),
  'mimeType': image.mimeType,
  'name': image.name,
  'size': image.size,
  'detail': image.detail,
};

bool _hasFileReference(AgentStreamImageInput image) =>
    image.assetId.trim().isNotEmpty || image.fileId.trim().isNotEmpty;

List<Map<String, Object?>> _imagesToPersistenceMaps(
  List<AgentStreamImageInput> images, {
  required bool includeImageData,
}) {
  return images
      .where((image) => includeImageData || _hasFileReference(image))
      .map(
        (image) => includeImageData
            ? _imageToMap(image)
            : <String, Object?>{
                if (image.assetId.trim().isNotEmpty)
                  'assetId': image.assetId.trim(),
                if (image.fileId.trim().isNotEmpty)
                  'fileId': image.fileId.trim(),
                'mimeType': image.mimeType,
                'name': image.name,
                'size': image.size,
                'detail': image.detail,
              },
      )
      .toList(growable: false);
}

AgentStreamImageInput? _imageFromMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final dataUrl = _string(map['dataUrl']) ?? _string(map['data_url']);
  final assetId = _string(map['assetId']) ?? _string(map['asset_id']) ?? '';
  final fileId = _string(map['fileId']) ?? _string(map['file_id']) ?? assetId;
  if ((dataUrl == null || dataUrl.trim().isEmpty) &&
      assetId.trim().isEmpty &&
      fileId.trim().isEmpty) {
    return null;
  }
  return AgentStreamImageInput(
    dataUrl: dataUrl ?? '',
    assetId: assetId,
    fileId: fileId,
    mimeType:
        _string(map['mimeType']) ?? _string(map['mime_type']) ?? 'image/png',
    name: _string(map['name']) ?? 'image.png',
    size: _int(map['size']),
    detail: _string(map['detail']) ?? 'auto',
  );
}

Map<String, Object?> _fileToMap(AgentStreamFileInput file) => {
  'fileId': file.fileId,
  'mimeType': file.mimeType,
  'name': file.name,
  'size': file.size,
};

AgentStreamFileInput? _fileFromMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final fileId = _string(map['fileId']) ?? _string(map['file_id']) ?? '';
  if (fileId.trim().isEmpty) return null;
  return AgentStreamFileInput(
    fileId: fileId,
    mimeType:
        _string(map['mimeType']) ??
        _string(map['mime_type']) ??
        _string(map['content_type']) ??
        'application/pdf',
    name:
        _string(map['name']) ??
        _string(map['original_filename']) ??
        'document.pdf',
    size: _int(map['size']),
  );
}
