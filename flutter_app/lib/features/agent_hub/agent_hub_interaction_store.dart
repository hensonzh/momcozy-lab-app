import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

class AgentHubInteractionSnapshot {
  const AgentHubInteractionSnapshot({
    this.runState = const AgentStreamRunState(),
    this.historyMessages = const <AgentHubHistorySnapshot>[],
    this.composerText = '',
    this.attachedImages = const <AgentStreamImageInput>[],
    this.autoVoiceEnabled = true,
    this.activeRequest,
    this.localActionStatuses = const <String, String>{},
    this.formSubmissions = const <String, AgentArtifactFormSubmission>{},
  });

  final AgentStreamRunState runState;
  final List<AgentHubHistorySnapshot> historyMessages;
  final String composerText;
  final List<AgentStreamImageInput> attachedImages;
  final bool autoVoiceEnabled;
  final AgentStreamRequest? activeRequest;
  final Map<String, String> localActionStatuses;
  final Map<String, AgentArtifactFormSubmission> formSubmissions;

  bool get hasContent {
    return runState.events.isNotEmpty ||
        runState.textContent.trim().isNotEmpty ||
        runState.provisionalTextContent.trim().isNotEmpty ||
        runState.threadId?.trim().isNotEmpty == true ||
        runState.runId?.trim().isNotEmpty == true ||
        historyMessages.isNotEmpty ||
        composerText.trim().isNotEmpty ||
        attachedImages.isNotEmpty ||
        activeRequest != null ||
        localActionStatuses.isNotEmpty ||
        formSubmissions.isNotEmpty ||
        !autoVoiceEnabled;
  }

  Map<String, Object?> toMap({bool includeImageData = true}) => {
    'runState': runState.toMap(),
    if (historyMessages.any(
      (message) =>
          includeImageData ||
          message.content.trim().isNotEmpty ||
          message.runState != null,
    ))
      'historyMessages': historyMessages
          .where(
            (message) =>
                includeImageData ||
                message.content.trim().isNotEmpty ||
                message.runState != null,
          )
          .map((message) => message.toMap(includeImageData: includeImageData))
          .toList(growable: false),
    if (composerText.isNotEmpty) 'composerText': composerText,
    if (includeImageData && attachedImages.isNotEmpty)
      'attachedImages': attachedImages.map(_imageToMap).toList(growable: false),
    'autoVoiceEnabled': autoVoiceEnabled,
    if (activeRequest != null &&
        (includeImageData || activeRequest!.images.isEmpty))
      'activeRequest': _requestToPersistenceMap(
        activeRequest!,
        historyMessages,
        includeImageData: includeImageData,
      ),
    if (localActionStatuses.isNotEmpty)
      'localActionStatuses': localActionStatuses,
    if (formSubmissions.values.any((submission) => submission.isSubmitted))
      'formSubmissions': {
        for (final entry in formSubmissions.entries)
          if (entry.value.isSubmitted) entry.key: entry.value.toMap(),
      },
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
      autoVoiceEnabled: map['autoVoiceEnabled'] != false,
      activeRequest: activeRequest,
      localActionStatuses: _stringMap(map['localActionStatuses']),
      formSubmissions: _formSubmissionsFromMap(map['formSubmissions']),
    );
  }
}

class AgentHubHistorySnapshot {
  const AgentHubHistorySnapshot({
    required this.role,
    required this.content,
    this.runState,
    this.images = const <AgentStreamImageInput>[],
  });

  final String role;
  final String content;
  final AgentStreamRunState? runState;
  final List<AgentStreamImageInput> images;

  Map<String, Object?> toMap({bool includeImageData = true}) => {
    'role': role,
    'content': content,
    if (runState != null) 'runState': runState!.toMap(),
    if (includeImageData && images.isNotEmpty)
      'images': images.map(_imageToMap).toList(growable: false),
  };

  static AgentHubHistorySnapshot? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final content = _string(map['content'])?.trim() ?? '';
    final images = _imagesFromList(map['images']);
    if (content.isEmpty && images.isEmpty) return null;
    final role = _string(map['role']) == 'user' ? 'user' : 'assistant';
    final runStateValue = map['runState'] ?? map['run_state'];
    return AgentHubHistorySnapshot(
      role: role,
      content: content,
      images: images,
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

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  final result = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final item = entry.value;
    if (key is String && item is String && key.trim().isNotEmpty) {
      result[key] = item;
    }
  }
  return Map<String, String>.unmodifiable(result);
}

Map<String, AgentArtifactFormSubmission> _formSubmissionsFromMap(
  Object? value,
) {
  if (value is! Map) {
    return const <String, AgentArtifactFormSubmission>{};
  }
  final result = <String, AgentArtifactFormSubmission>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final submission = AgentArtifactFormSubmission.tryFromMap(entry.value);
    if (key is String &&
        key.trim().isNotEmpty &&
        submission?.isSubmitted == true) {
      result[key] = submission!;
    }
  }
  return Map<String, AgentArtifactFormSubmission>.unmodifiable(result);
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
  if (request.metadata.isNotEmpty) 'metadata': request.metadata,
  if (request.idempotencyKey != null) 'idempotencyKey': request.idempotencyKey,
};

Map<String, Object?> _requestToPersistenceMap(
  AgentStreamRequest request,
  List<AgentHubHistorySnapshot> historyMessages, {
  bool includeImageData = true,
}) {
  if (!includeImageData) {
    return _requestToMap(_requestWithImages(request, const []));
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
    metadata: metadata is Map
        ? Map<String, Object?>.from(metadata)
        : const <String, Object?>{},
    idempotencyKey:
        _string(map['idempotencyKey']) ?? _string(map['idempotency_key']),
  );
}

Map<String, Object?> _imageToMap(AgentStreamImageInput image) => {
  'dataUrl': image.dataUrl,
  'mimeType': image.mimeType,
  'name': image.name,
  'size': image.size,
  'detail': image.detail,
};

AgentStreamImageInput? _imageFromMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final dataUrl = _string(map['dataUrl']) ?? _string(map['data_url']);
  if (dataUrl == null || dataUrl.trim().isEmpty) return null;
  return AgentStreamImageInput(
    dataUrl: dataUrl,
    mimeType:
        _string(map['mimeType']) ?? _string(map['mime_type']) ?? 'image/png',
    name: _string(map['name']) ?? 'image.png',
    size: _int(map['size']),
    detail: _string(map['detail']) ?? 'auto',
  );
}
