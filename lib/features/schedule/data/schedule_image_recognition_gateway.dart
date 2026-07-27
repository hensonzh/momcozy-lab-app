import 'dart:async';
import 'dart:convert';

import 'package:app/core/agent_stream/agent_stream_event.dart';
import 'package:app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/core/network/transport_security_policy.dart';
import 'package:app/features/agent_hub/domain/agent_image_input.dart';
import 'package:app/features/media/domain/media_upload.dart';
import 'package:app/features/schedule/domain/schedule_image_recognition.dart';

const _maxPreviewTasks = 32;
const _supportedScheduleImageTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
};

class ApiScheduleImageRecognitionGateway
    implements ScheduleImageRecognitionGateway {
  ApiScheduleImageRecognitionGateway({
    required this.imagePicker,
    required this.mediaRepository,
    required Uri baseUri,
    this.tokenProvider,
    this.onUnauthorized,
    this.headers = const {'X-Momcozy-Client': 'flutter'},
    this.requestTimeout = const Duration(seconds: 30),
    AgentStreamSseGetConnector? connector,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector = connector ?? IoAgentStreamSseGetConnector();

  final AgentHubImagePicker imagePicker;
  final MediaRepository mediaRepository;
  final Uri baseUri;
  final String? Function()? tokenProvider;
  final FutureOr<bool> Function()? onUnauthorized;
  final Map<String, String> headers;
  final Duration requestTimeout;
  final AgentStreamSseGetConnector connector;

  @override
  Future<ScheduleImageRecognitionResult> pickAndRecognize() async {
    try {
      final image = await imagePicker(AgentImageInputSource.gallery);
      if (image == null) {
        return const ScheduleImageRecognitionResult.cancelled();
      }
      final mimeType = image.mimeType.trim().toLowerCase();
      if (!_supportedScheduleImageTypes.contains(mimeType)) {
        throw const ScheduleImageRecognitionException(
          'unsupported_image',
          '请选择 PNG、JPG 或 WEBP 格式的日程截图。',
        );
      }
      final bytes = _decodeImageBytes(image.dataUrl, mimeType: mimeType);
      final uploaded = await mediaRepository.uploadFile(
        file: ApiUploadFile(
          name: image.name.trim().isEmpty
              ? _defaultImageName(mimeType)
              : image.name.trim(),
          mimeType: mimeType,
          sizeBytes: bytes.length,
          bytes: bytes,
        ),
        idempotencyKey: _uploadIdempotencyKey(),
      );
      final fileId = uploaded.id.trim();
      if (fileId.isEmpty) {
        throw const ScheduleImageRecognitionException(
          'invalid_upload_response',
          '截图上传结果无效，请重试。',
        );
      }
      return ScheduleImageRecognitionResult.preview(
        await _readPreviewTasks(fileId),
      );
    } on ScheduleImageRecognitionException {
      rethrow;
    } on ApiRequestCancelledException {
      return const ScheduleImageRecognitionResult.cancelled();
    } on ApiRequestTimeoutException {
      throw const ScheduleImageRecognitionException(
        'request_timeout',
        '截图识别超时，请稍后重试。',
      );
    } on TimeoutException {
      throw const ScheduleImageRecognitionException(
        'request_timeout',
        '截图识别超时，请稍后重试。',
      );
    } catch (_) {
      throw const ScheduleImageRecognitionException(
        'request_failed',
        '截图识别暂时不可用，请稍后重试。',
      );
    }
  }

  Future<List<ScheduleImageTaskPreview>> _readPreviewTasks(
    String fileId,
  ) async {
    final uri = _visionUri(fileId);
    try {
      return await _collectPreview(
        connector.get(uri, headers: _headers()).timeout(requestTimeout),
      );
    } on AgentStreamTransportException catch (error) {
      if (!_isUnauthorized(error) || !await _refreshSession()) rethrow;
      return _collectPreview(
        connector.get(uri, headers: _headers()).timeout(requestTimeout),
      );
    }
  }

  Future<List<ScheduleImageTaskPreview>> _collectPreview(
    Stream<String> frames,
  ) async {
    final tasks = <ScheduleImageTaskPreview>[];
    var started = false;
    await for (final frame in frames) {
      for (final event in parseAgentEventStream(frame)) {
        switch (event.type) {
          case 'vision.started':
            if (started || tasks.isNotEmpty) throw _invalidResponse();
            started = event.payload['purpose'] == 'schedule';
            if (!started) throw _invalidResponse();
          case 'vision.schedule_task.preview':
            if (!started || tasks.length >= _maxPreviewTasks) {
              throw _invalidResponse();
            }
            tasks.add(_taskFromPayload(event.payload));
          case 'vision.completed':
            if (!started || event.payload['purpose'] != 'schedule') {
              throw _invalidResponse();
            }
            final expectedCount = _int(event.payload['event_count']) ?? -1;
            if (expectedCount != tasks.length) throw _invalidResponse();
            return List<ScheduleImageTaskPreview>.unmodifiable(tasks);
          default:
            throw _invalidResponse();
        }
      }
    }
    throw _invalidResponse();
  }

  Uri _visionUri(String fileId) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(
      path:
          '${basePath}v1/files/${Uri.encodeComponent(fileId)}/vision/events/stream',
      queryParameters: const {'purpose': 'schedule'},
    );
  }

  Map<String, String> _headers() {
    final token = tokenProvider?.call()?.trim();
    return {
      ...headers,
      'Accept': 'text/event-stream',
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

ScheduleImageTaskPreview _taskFromPayload(Map<String, Object?> payload) {
  if (payload['purpose'] != 'schedule') throw _invalidResponse();
  final time = payload['time'];
  final title = payload['event'];
  final type = payload['event_type'];
  if (time is! String ||
      !_scheduleTime.hasMatch(time) ||
      title is! String ||
      title.trim().isEmpty ||
      title.trim().length > 80 ||
      type is! String) {
    throw _invalidResponse();
  }
  final kind = switch (type) {
    'pump' => ScheduleImageTaskKind.pumping,
    'breastfeed' => ScheduleImageTaskKind.feeding,
    'custom' => ScheduleImageTaskKind.other,
    _ => throw _invalidResponse(),
  };
  return ScheduleImageTaskPreview(time: time, title: title.trim(), kind: kind);
}

List<int> _decodeImageBytes(String dataUrl, {required String mimeType}) {
  final prefix = 'data:$mimeType;base64,';
  if (!dataUrl.startsWith(prefix)) {
    throw const ScheduleImageRecognitionException(
      'invalid_image',
      '所选截图无法读取，请重新选择。',
    );
  }
  try {
    final bytes = base64Decode(dataUrl.substring(prefix.length));
    if (bytes.isEmpty) throw const FormatException('empty image');
    return bytes;
  } on FormatException {
    throw const ScheduleImageRecognitionException(
      'invalid_image',
      '所选截图无法读取，请重新选择。',
    );
  }
}

ScheduleImageRecognitionException _invalidResponse() =>
    const ScheduleImageRecognitionException(
      'invalid_response',
      '截图识别结果格式异常，请重试。',
    );

int? _int(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _isUnauthorized(AgentStreamTransportException error) =>
    error.message.contains('401');

String _uploadIdempotencyKey() =>
    'schedule-image-${DateTime.now().microsecondsSinceEpoch}';

String _defaultImageName(String mimeType) => switch (mimeType) {
  'image/jpeg' => 'schedule.jpg',
  'image/webp' => 'schedule.webp',
  _ => 'schedule.png',
};

final _scheduleTime = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
