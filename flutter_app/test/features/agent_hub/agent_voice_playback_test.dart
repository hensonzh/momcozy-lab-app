import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

void main() {
  group('Agent voice playback text', () {
    test('keeps readable markdown labels and removes URLs', () {
      expect(
        sanitizeAgentVoicePlaybackText(
          '请看 [查看报告](https://example.com/report?id=1)。',
        ),
        '请看 查看报告 。',
      );
      expect(
        sanitizeAgentVoicePlaybackText(
          '详情见 https://example.com/a?x=1 或 www.example.com/path。',
        ),
        '详情见 或 。',
      );
    });

    test('removes media paths and hospital bag cart link labels', () {
      expect(
        sanitizeAgentVoicePlaybackText(
          '请看 pump_step_3.png 和 /skill-assets/device/videos/demo.mp4。',
        ),
        '请看 和 。',
      );
      expect(
        sanitizeAgentVoicePlaybackText(
          '**[打开待产包一键打包下单页](/hospital-bag-cart)**',
        ),
        isEmpty,
      );
    });

    test('removes markdown decorations and normalizes slash text', () {
      expect(
        sanitizeAgentVoicePlaybackText(
          '## **重点**\n- 每天 6-8 次，80ml/次\n> 详情：`code` | A/B',
        ),
        '重点 每天 6到8 次，80ml 每次 详情： A B',
      );
    });

    test('segments sanitized text without exceeding the chunk limit', () {
      final chunks = buildAgentVoicePlaybackTextChunks(
        '${List.filled(16, '第一段内容').join()}。'
        '${List.filled(16, '第二段内容').join()}。'
        '${List.filled(16, '第三段内容').join()}。',
        maxChars: 80,
      );

      expect(chunks.length, greaterThan(1));
      expect(chunks.every((chunk) => chunk.length <= 80), isTrue);
      expect(chunks.join(), contains('第一段内容'));
    });

    test('keeps chunk bounds as integer string indexes', () {
      final tinyChunks = buildAgentVoicePlaybackTextChunks(
        'abcdef',
        maxChars: 1,
      );
      final disabledLimitChunks = buildAgentVoicePlaybackTextChunks(
        'abcdef',
        maxChars: 0,
      );

      expect(tinyChunks, ['a', 'b', 'c', 'd', 'e', 'f']);
      expect(disabledLimitChunks, ['abcdef']);
    });
  });

  test(
    'AgentVoiceApiPlaybackPlayer sends sanitized chunks to realtime PCM',
    () async {
      final repository = _RecordingVoiceRepository();
      final pcmPlayer = _RecordingPcmPlayer();
      final player = AgentVoiceApiPlaybackPlayer(
        repository: repository,
        pcmPlayer: pcmPlayer,
      );

      await player.playText(
        '请看 [报告](https://example.com/report)。'
        '${List.filled(950, '好').join()}',
      );

      expect(repository.texts.length, greaterThan(1));
      expect(
        repository.texts.every(
          (text) =>
              text.length <= agentVoicePlaybackMaxChunkChars &&
              !text.contains('http') &&
              !text.contains('[') &&
              !text.contains(']'),
        ),
        isTrue,
      );
      expect(repository.texts.join(), contains('报告'));
      expect(pcmPlayer.starts, 1);
      expect(pcmPlayer.writes, [
        [1, 2],
        [1, 2],
      ]);
      expect(pcmPlayer.stops, 1);
    },
  );
}

class _RecordingVoiceRepository implements AgentVoiceRepository {
  final texts = <String>[];

  @override
  Stream<List<int>> realtimeVoicePcmStream({required String text}) async* {
    texts.add(text);
    yield [1, 2];
  }

  @override
  Stream<AgentVoiceSessionEvent> realtimeVoiceSession() {
    return const Stream<AgentVoiceSessionEvent>.empty();
  }

  @override
  Future<String?> transcribeSpeechChunk({
    required ApiUploadFile file,
    String? language,
  }) async {
    return null;
  }
}

class _RecordingPcmPlayer implements AgentVoicePcmPlayer {
  var starts = 0;
  var stops = 0;
  final writes = <List<int>>[];

  @override
  Future<void> start({int sampleRate = 24000, int channels = 1}) async {
    starts += 1;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(bytes);
  }
}
