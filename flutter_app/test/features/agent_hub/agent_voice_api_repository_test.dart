import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';

void main() {
  group('Agent voice API repository', () {
    test('transcribes a speech chunk through multipart contract', () async {
      final multipart = FixtureApiMultipartTransport({
        'status': 200,
        'data': {'text': '  hello from voice  '},
      });
      final repository = AgentVoiceApiRepository(
        multipartTransport: multipart,
        baseUri: Uri.parse('http://127.0.0.1:8769'),
      );

      final text = await repository.transcribeSpeechChunk(
        userId: 'demo-user-fixture',
        language: 'zh-CN',
        file: const ApiUploadFile(
          name: 'speech.wav',
          mimeType: 'audio/wav',
          sizeBytes: 4,
          bytes: [1, 2, 3, 4],
        ),
      );

      expect(text, 'hello from voice');
      expect(multipart.lastPath, speechTranscribeChunkEndpoint);
      expect(multipart.lastFields, {
        'user_id': 'demo-user-fixture',
        'language': 'zh-CN',
      });
      expect(multipart.lastFile!.mimeType, 'audio/wav');
    });

    test('returns null for ignorable single chunk timeout fixture', () async {
      final fixture = readFixtureMap(
        'api/voice/speech_transcribe_chunk_timeout.json',
      );
      final behavior = fixture['expected_client_behavior']! as Map;
      final multipart = FixtureApiMultipartTransport(const {
        'status': 200,
        'data': {},
      }, failure: const ApiRequestTimeoutException());
      final repository = AgentVoiceApiRepository(
        multipartTransport: multipart,
        baseUri: Uri.parse('http://127.0.0.1:8769'),
      );

      final text = await repository.transcribeSpeechChunk(
        userId: 'demo-user-fixture',
        file: const ApiUploadFile(
          name: 'speech.webm',
          mimeType: 'audio/webm',
          sizeBytes: 3,
          bytes: [1, 2, 3],
        ),
      );

      expect(behavior['ignore_single_chunk'], isTrue);
      expect(text, isNull);
      expect(multipart.lastPath, speechTranscribeChunkEndpoint);
    });

    test('rethrows speech chunk cancellation for user barge-in', () async {
      final multipart = FixtureApiMultipartTransport(const {
        'status': 200,
        'data': {},
      }, failure: const ApiRequestCancelledException());
      final repository = AgentVoiceApiRepository(
        multipartTransport: multipart,
        baseUri: Uri.parse('http://127.0.0.1:8769'),
      );

      expect(
        repository.transcribeSpeechChunk(
          userId: 'demo-user-fixture',
          file: const ApiUploadFile(
            name: 'speech.webm',
            mimeType: 'audio/webm',
            sizeBytes: 3,
          ),
        ),
        throwsA(isA<ApiRequestCancelledException>()),
      );
    });

    test(
      'opens realtime PCM stream without using text stream parser',
      () async {
        final connector = _RecordingBinaryConnector([
          [1, 2],
          [3, 4],
        ]);
        final repository = AgentVoiceApiRepository(
          multipartTransport: FixtureApiMultipartTransport(const {
            'status': 200,
            'data': {},
          }),
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          token: 'voice-token',
          headers: const {'X-Momcozy-Client': 'flutter'},
          binaryConnector: connector,
        );

        final chunks = await repository
            .realtimeVoicePcmStream(
              userId: 'demo-user-fixture',
              text: 'Short fixture text for playback.',
            )
            .toList();

        expect(chunks, [
          [1, 2],
          [3, 4],
        ]);
        expect(connector.uri!.path, realtimeVoiceStreamEndpoint);
        expect(connector.uri!.queryParameters, {
          'user_id': 'demo-user-fixture',
          'text': 'Short fixture text for playback.',
        });
        expect(connector.headers, containsPair('Accept', 'audio/pcm'));
        expect(
          connector.headers,
          containsPair('Authorization', 'Bearer voice-token'),
        );
      },
    );

    test('realtime PCM stream cancellation follows voice fixture behavior', () {
      final fixture = readFixtureMap(
        'api/voice/realtime_voice_stream_cancelled.json',
      );
      final behavior = fixture['expected_client_behavior']! as Map;
      final connector = _RecordingBinaryConnector(
        const [],
        failure: const ApiRequestCancelledException(),
      );
      final repository = AgentVoiceApiRepository(
        multipartTransport: FixtureApiMultipartTransport(const {
          'status': 200,
          'data': {},
        }),
        baseUri: Uri.parse('http://127.0.0.1:8769'),
        binaryConnector: connector,
      );

      expect(behavior['stop_playback'], isTrue);
      expect(behavior['show_error_toast'], isFalse);
      expect(
        repository.realtimeVoicePcmStream(
          userId: 'demo-user-fixture',
          text: 'Short fixture text for playback.',
        ),
        emitsError(isA<ApiRequestCancelledException>()),
      );
    });

    test(
      'parses realtime voice session frames and closes connection',
      () async {
        final connection = _RecordingVoiceWebSocketConnection(
          readMigrationFixture(
            'api/voice/realtime_voice_session_frames.jsonl',
          ).trim().split('\n'),
        );
        final connector = _RecordingVoiceWebSocketConnector(connection);
        final repository = AgentVoiceApiRepository(
          multipartTransport: FixtureApiMultipartTransport(const {
            'status': 200,
            'data': {},
          }),
          baseUri: Uri.parse('https://api.example.test/base'),
          token: 'voice-token',
          websocketConnector: connector,
        );

        final events = await repository
            .realtimeVoiceSession(userId: 'demo-user-fixture')
            .toList();

        expect(connector.uri!.scheme, 'wss');
        expect(connector.uri!.path, '/base/v1/realtime-voice-session');
        expect(connector.uri!.queryParameters, {
          'user_id': 'demo-user-fixture',
          'token': 'voice-token',
        });
        expect(events.map((event) => event.type), [
          AgentVoiceSessionEventType.opened,
          AgentVoiceSessionEventType.audioChunk,
          AgentVoiceSessionEventType.completed,
        ]);
        expect(events[1].audioBytes, [0, 1, 2]);
        expect(connection.closeCount, 1);
      },
    );

    test(
      'realtime voice session disconnect does not touch text run state',
      () async {
        final fixture = readFixtureMap(
          'api/voice/realtime_voice_session_ws_disconnect.json',
        );
        final behavior = fixture['expected_client_behavior']! as Map;
        final connection = _RecordingVoiceWebSocketConnection(
          const [
            '{"type":"session.open","session_id":"voice-session-fixture"}',
            '{"type":"audio.chunk","audio_base64":"AAEC","sequence":1}',
          ],
          failure: const AgentVoiceSessionDisconnectedException(
            code: 1006,
            wasClean: false,
          ),
        );
        final repository = AgentVoiceApiRepository(
          multipartTransport: FixtureApiMultipartTransport(const {
            'status': 200,
            'data': {},
          }),
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          websocketConnector: _RecordingVoiceWebSocketConnector(connection),
        );
        final textRunState = const AgentStreamRunState(
          phase: AgentStreamRunPhase.streaming,
          textContent: 'Partial text answer',
        );
        final voiceState = const AgentVoiceState().startPlayback('reply-1');

        expect(behavior['preserve_text_stream'], isTrue);
        expect(textRunState.phase, AgentStreamRunPhase.streaming);
        expect(voiceState.phase, AgentVoicePhase.playing);
        await expectLater(
          repository.realtimeVoiceSession(userId: 'demo-user-fixture'),
          emitsInOrder([
            isA<AgentVoiceSessionEvent>().having(
              (event) => event.type,
              'type',
              AgentVoiceSessionEventType.opened,
            ),
            isA<AgentVoiceSessionEvent>().having(
              (event) => event.type,
              'type',
              AgentVoiceSessionEventType.audioChunk,
            ),
            emitsError(isA<AgentVoiceSessionDisconnectedException>()),
          ]),
        );
        expect(connection.closeCount, 1);
      },
    );
  });
}

class _RecordingBinaryConnector implements AgentVoiceBinaryStreamConnector {
  _RecordingBinaryConnector(this.chunks, {this.failure});

  final List<List<int>> chunks;
  final Object? failure;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Stream<List<int>> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async* {
    this.uri = uri;
    this.headers = headers;
    final failure = this.failure;
    if (failure != null) throw failure;
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}

class _RecordingVoiceWebSocketConnector
    implements AgentVoiceWebSocketConnector {
  _RecordingVoiceWebSocketConnector(this.connection);

  final _RecordingVoiceWebSocketConnection connection;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Future<AgentVoiceWebSocketConnection> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    this.uri = uri;
    this.headers = headers;
    return connection;
  }
}

class _RecordingVoiceWebSocketConnection
    implements AgentVoiceWebSocketConnection {
  _RecordingVoiceWebSocketConnection(this.rawFrames, {this.failure});

  final List<String> rawFrames;
  final Object? failure;
  int closeCount = 0;

  @override
  Stream<String> get frames async* {
    for (final frame in rawFrames) {
      await Future<void>.delayed(Duration.zero);
      yield frame;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> close() async {
    closeCount += 1;
  }
}
