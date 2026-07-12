import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_image_recognition_gateway.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_image_recognition.dart';

void main() {
  test(
    'picker cancellation performs no upload or recognition request',
    () async {
      final media = _FakeMediaRepository();
      final connector = _FakeSseConnector(const []);
      final gateway = _gateway(
        picker: (_) async => null,
        media: media,
        connector: connector,
      );

      final result = await gateway.pickAndRecognize();

      expect(result.cancelled, isTrue);
      expect(result.tasks, isEmpty);
      expect(media.files, isEmpty);
      expect(connector.uris, isEmpty);
    },
  );

  test('uploads private image and parses bounded typed preview', () async {
    final media = _FakeMediaRepository();
    final connector = _FakeSseConnector([
      _event('vision.started', 1, {'purpose': 'schedule'}),
      _event('vision.schedule_task.preview', 2, {
        'provider': 'local_stub',
        'purpose': 'schedule',
        'time': '08:30',
        'event': '吸奶',
        'event_type': 'pump',
      }),
      _event('vision.schedule_task.preview', 3, {
        'provider': 'local_stub',
        'purpose': 'schedule',
        'time': '11:45',
        'event': '散步',
        'event_type': 'custom',
      }),
      _event('vision.completed', 4, {'purpose': 'schedule', 'event_count': 2}),
    ]);
    final gateway = _gateway(media: media, connector: connector);

    final result = await gateway.pickAndRecognize();

    expect(result.cancelled, isFalse);
    expect(result.tasks.map((task) => [task.time, task.title, task.kind]), [
      ['08:30', '吸奶', ScheduleImageTaskKind.pumping],
      ['11:45', '散步', ScheduleImageTaskKind.other],
    ]);
    expect(media.files.single.name, 'private.png');
    expect(media.files.single.mimeType, 'image/png');
    expect(media.files.single.bytes, [1, 2, 3, 4]);
    expect(media.idempotencyKeys.single, startsWith('schedule-image-'));
    expect(
      connector.uris.single.path,
      '/v1/files/file-123/vision/events/stream',
    );
    expect(connector.uris.single.queryParameters, {'purpose': 'schedule'});
    expect(connector.uris.single.queryParameters, isNot(contains('token')));
    expect(connector.headers.single['Authorization'], 'Bearer private-token');
    expect(connector.headers.single['Accept'], 'text/event-stream');
  });

  test(
    'valid task-free screenshot returns an editable empty preview',
    () async {
      final result = await _gateway(
        connector: _FakeSseConnector([
          _event('vision.started', 1, {'purpose': 'schedule'}),
          _event('vision.completed', 2, {
            'purpose': 'schedule',
            'event_count': 0,
          }),
        ]),
      ).pickAndRecognize();

      expect(result.cancelled, isFalse);
      expect(result.tasks, isEmpty);
    },
  );

  test('401 stream refreshes once and keeps token out of URL', () async {
    var token = 'expired';
    var refreshes = 0;
    final connector = _RetrySseConnector([
      _event('vision.started', 1, {'purpose': 'schedule'}),
      _event('vision.completed', 2, {'purpose': 'schedule', 'event_count': 0}),
    ]);
    final gateway = ApiScheduleImageRecognitionGateway(
      imagePicker: _imagePicker,
      mediaRepository: _FakeMediaRepository(),
      baseUri: Uri.parse('https://api.example.test'),
      tokenProvider: () => token,
      onUnauthorized: () async {
        refreshes += 1;
        token = 'refreshed';
        return true;
      },
      connector: connector,
    );

    final result = await gateway.pickAndRecognize();

    expect(result.tasks, isEmpty);
    expect(refreshes, 1);
    expect(connector.headers, hasLength(2));
    expect(connector.headers.first['Authorization'], 'Bearer expired');
    expect(connector.headers.last['Authorization'], 'Bearer refreshed');
    expect(
      connector.uris.every((uri) => !uri.queryParameters.containsKey('token')),
      isTrue,
    );
  });

  test('rejects malformed or incomplete provider event sequences', () async {
    final cases = <List<String>>[
      [
        _event('vision.started', 1, {'purpose': 'schedule'}),
        _event('vision.schedule_task.preview', 2, {
          'purpose': 'schedule',
          'time': '8:30',
          'event': '吸奶',
          'event_type': 'pump',
        }),
        _event('vision.completed', 3, {
          'purpose': 'schedule',
          'event_count': 1,
        }),
      ],
      [
        _event('vision.started', 1, {'purpose': 'schedule'}),
        _event('vision.completed', 2, {
          'purpose': 'schedule',
          'event_count': 1,
        }),
      ],
      [
        _event('vision.started', 1, {'purpose': 'schedule'}),
      ],
    ];

    for (final frames in cases) {
      await expectLater(
        _gateway(connector: _FakeSseConnector(frames)).pickAndRecognize(),
        throwsA(
          isA<ScheduleImageRecognitionException>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    }
  });

  test('rejects unsupported GIF before upload', () async {
    final media = _FakeMediaRepository();
    final gateway = _gateway(
      picker: (_) async => const AgentStreamImageInput(
        dataUrl: 'data:image/gif;base64,R0lGODlh',
        mimeType: 'image/gif',
        name: 'schedule.gif',
        size: 6,
      ),
      media: media,
    );

    await expectLater(
      gateway.pickAndRecognize(),
      throwsA(
        isA<ScheduleImageRecognitionException>().having(
          (error) => error.code,
          'code',
          'unsupported_image',
        ),
      ),
    );
    expect(media.files, isEmpty);
  });

  test('bounds a stream that never reaches provider completion', () async {
    final gateway = ApiScheduleImageRecognitionGateway(
      imagePicker: _imagePicker,
      mediaRepository: _FakeMediaRepository(),
      baseUri: Uri.parse('https://api.example.test'),
      connector: _NeverSseConnector(),
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      gateway.pickAndRecognize(),
      throwsA(
        isA<ScheduleImageRecognitionException>().having(
          (error) => error.code,
          'code',
          'request_timeout',
        ),
      ),
    );
  });
}

ApiScheduleImageRecognitionGateway _gateway({
  AgentHubImagePicker picker = _imagePicker,
  _FakeMediaRepository? media,
  AgentStreamSseGetConnector? connector,
}) {
  return ApiScheduleImageRecognitionGateway(
    imagePicker: picker,
    mediaRepository: media ?? _FakeMediaRepository(),
    baseUri: Uri.parse('https://api.example.test'),
    tokenProvider: () => 'private-token',
    connector: connector ?? _FakeSseConnector(const []),
  );
}

Future<AgentStreamImageInput?> _imagePicker(
  AgentImageInputSource source,
) async {
  expect(source, AgentImageInputSource.gallery);
  return AgentStreamImageInput(
    dataUrl: 'data:image/png;base64,${base64Encode([1, 2, 3, 4])}',
    mimeType: 'image/png',
    name: 'private.png',
    size: 4,
  );
}

String _event(String type, int sequence, Map<String, Object?> payload) {
  return 'id: $sequence\nevent: $type\ndata: '
      '${jsonEncode({'type': type, 'sequence': sequence, 'file_id': 'file-123', 'payload': payload})}\n\n';
}

class _FakeMediaRepository implements MediaRepository {
  final List<ApiUploadFile> files = [];
  final List<String?> idempotencyKeys = [];

  @override
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
  }) async {
    files.add(file);
    idempotencyKeys.add(idempotencyKey);
    return const UploadedMediaFile(
      id: 'file-123',
      name: 'private.png',
      sizeBytes: 4,
      extension: 'png',
      mimeType: 'image/png',
    );
  }
}

class _FakeSseConnector implements AgentStreamSseGetConnector {
  _FakeSseConnector(this.frames);

  final List<String> frames;
  final List<Uri> uris = [];
  final List<Map<String, String>> headers = [];

  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) {
    uris.add(uri);
    this.headers.add(Map<String, String>.from(headers));
    return Stream<String>.fromIterable(frames);
  }
}

class _RetrySseConnector extends _FakeSseConnector {
  _RetrySseConnector(super.frames);

  var requests = 0;

  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) async* {
    uris.add(uri);
    this.headers.add(Map<String, String>.from(headers));
    requests += 1;
    if (requests == 1) {
      throw const AgentStreamTransportException('SSE request failed: 401');
    }
    yield* Stream<String>.fromIterable(frames);
  }
}

class _NeverSseConnector implements AgentStreamSseGetConnector {
  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) {
    return Stream<String>.periodic(const Duration(hours: 1), (_) => '');
  }
}
