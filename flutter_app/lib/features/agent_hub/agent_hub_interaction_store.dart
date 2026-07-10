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
    this.autoVoiceEnabled = true,
    this.activeRequest,
    this.localActionStatuses = const <String, String>{},
  });

  final AgentStreamRunState runState;
  final List<AgentHubHistorySnapshot> historyMessages;
  final String composerText;
  final List<AgentStreamImageInput> attachedImages;
  final bool autoVoiceEnabled;
  final AgentStreamRequest? activeRequest;
  final Map<String, String> localActionStatuses;

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
        !autoVoiceEnabled;
  }

  Map<String, Object?> toMap() => {
    'runState': runState.toMap(),
    if (historyMessages.isNotEmpty)
      'historyMessages': historyMessages
          .map((message) => message.toMap())
          .toList(growable: false),
    if (composerText.isNotEmpty) 'composerText': composerText,
    if (attachedImages.isNotEmpty)
      'attachedImages': attachedImages.map(_imageToMap).toList(growable: false),
    'autoVoiceEnabled': autoVoiceEnabled,
    if (activeRequest != null) 'activeRequest': _requestToMap(activeRequest!),
    if (localActionStatuses.isNotEmpty)
      'localActionStatuses': localActionStatuses,
  };

  static AgentHubInteractionSnapshot fromMap(Map<String, Object?> map) {
    return AgentHubInteractionSnapshot(
      runState: _runStateFromMap(map['runState']),
      historyMessages: _historyFromList(map['historyMessages']),
      composerText: _string(map['composerText']) ?? '',
      attachedImages: _imagesFromList(map['attachedImages']),
      autoVoiceEnabled: map['autoVoiceEnabled'] != false,
      activeRequest: _requestFromMap(map['activeRequest']),
      localActionStatuses: _stringMap(map['localActionStatuses']),
    );
  }
}

class AgentHubHistorySnapshot {
  const AgentHubHistorySnapshot({
    required this.role,
    required this.content,
    this.runState,
  });

  final String role;
  final String content;
  final AgentStreamRunState? runState;

  Map<String, Object?> toMap() => {
    'role': role,
    'content': content,
    if (runState != null) 'runState': runState!.toMap(),
  };

  static AgentHubHistorySnapshot? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    final content = _string(map['content'])?.trim();
    if (content == null || content.isEmpty) return null;
    final role = _string(map['role']) == 'user' ? 'user' : 'assistant';
    final runStateValue = map['runState'] ?? map['run_state'];
    return AgentHubHistorySnapshot(
      role: role,
      content: content,
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
    return storage.write(key: _key, value: jsonEncode(snapshot.toMap()));
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
};

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
