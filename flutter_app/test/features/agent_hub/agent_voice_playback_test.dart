import 'dart:async';

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

    test('replaces media markdown with explicit narration once', () {
      final spoken = sanitizeAgentVoicePlaybackText(
        '先看 ![Air1 核心部件](/v1/assets/asset-image?kind=image)，'
        '再看 [同一张图](/v1/assets/asset-image?kind=image)。',
        mediaNarrationResolver: ({required url, required alt}) {
          return url == '/v1/assets/asset-image?kind=image'
              ? '我放了一张当前步骤的对照图。'
              : null;
        },
      );

      expect(spoken, '先看 我放了一张当前步骤的对照图。 ，再看 。');
      expect(spoken, isNot(contains('Air1 核心部件')));
      expect(spoken, isNot(contains('/v1/assets')));
    });

    test('removes markdown decorations and normalizes slash text', () {
      expect(
        sanitizeAgentVoicePlaybackText(
          '## **重点**\n- 每天 6-8 次，80ml/次\n> 详情：`code` | A/B',
        ),
        '重点 每天 6到8 次，80ml 每次 详情： A B',
      );
    });

    test('matches legacy URL labels, routes, and unfinished markup', () {
      expect(
        sanitizeAgentVoicePlaybackText(
          '[https://example.com](https://example.com) 已生成',
        ),
        '已生成',
      );
      expect(
        sanitizeAgentVoicePlaybackText('请看 [日程页面](/schedule?tab=ready)。'),
        '请看 日程页面 。',
      );
      expect(
        sanitizeAgentVoicePlaybackText('请打开 /hospital-bag-cart?tab=ready 查看。'),
        '请打开 查看。',
      );
      expect(
        sanitizeAgentVoicePlaybackText('**重点：每天 80ml/次。'),
        '重点：每天 80ml 每次。',
      );
      expect(sanitizeAgentVoicePlaybackText('建议每天 6~8 次。'), '建议每天 6到8 次。');
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

  group('Agent voice stream filter parity', () {
    test('skips a markdown link href split across deltas', () {
      final filter = AgentVoiceTextStreamFilter();

      expect(filter.push('请看 [查看报告]('), '请看 ');
      expect(filter.push('https://example.com/report?id=1'), isEmpty);
      expect(filter.push(')，然后继续。'), ' 查看报告 ，然后继续。');
      expect(filter.flush(), isEmpty);
    });

    test('skips a hospital bag cart link split across deltas', () {
      final filter = AgentVoiceTextStreamFilter();

      expect(filter.push('请看 [打开待产包购物车]('), '请看 ');
      expect(filter.push('/hospital-bag-cart?tab=ready'), isEmpty);
      expect(filter.push(')，然后继续。'), ' ，然后继续。');
      expect(filter.flush(), isEmpty);
    });

    test('skips a bare URL split across deltas', () {
      final filter = AgentVoiceTextStreamFilter();

      expect(filter.push('详情见 https://exa'), '详情见 ');
      expect(filter.push('mple.com/report?id=1'), isEmpty);
      expect(filter.push(' 再继续。'), '  再继续。');
      expect(filter.flush(), isEmpty);
    });

    test('skips markdown image alt text split across deltas', () {
      final filter = AgentVoiceTextStreamFilter();

      expect(filter.push('先看这张图：!'), '先看这张图：');
      expect(filter.push('[Air1 核心部件]('), isEmpty);
      expect(
        filter.push(
          '/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png',
        ),
        isEmpty,
      );
      expect(filter.push(')，然后继续。'), ' ，然后继续。');
      expect(filter.flush(), isEmpty);
    });

    test('speaks explicit media narration for split markdown once', () {
      const mediaPath =
          '/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png';
      const narration = '我放了一张当前步骤的对照图，你可以边看图边完成这一步。';
      final filter = AgentVoiceTextStreamFilter(
        mediaNarrationResolver: ({required url, required alt}) =>
            url == mediaPath ? narration : null,
      );

      expect(filter.push('先看这张图：!'), '先看这张图：');
      expect(filter.push('[Air1 核心部件]('), isEmpty);
      expect(filter.push(mediaPath), isEmpty);
      expect(filter.push(')，然后继续。'), ' $narration ，然后继续。');
      expect(filter.flush(), isEmpty);
    });

    test('speaks media narration for links, paths, and absolute URLs', () {
      const mediaPath =
          '/skill-assets/device-guidance/air1/images/air1_guide_parts_components.png';
      const absoluteMediaUrl = 'http://127.0.0.1:17769$mediaPath';
      const narration = '我放了一张当前步骤的对照图，你可以边看图边完成这一步。';

      AgentVoiceTextStreamFilter filterFor(String expectedUrl) {
        return AgentVoiceTextStreamFilter(
          mediaNarrationResolver: ({required url, required alt}) =>
              url == expectedUrl ? narration : null,
        );
      }

      expect(
        filterFor(mediaPath).push('先看 [查看图片]($mediaPath)，然后继续。'),
        '先看  $narration ，然后继续。',
      );
      expect(
        filterFor(mediaPath).push('先看 $mediaPath，然后继续。'),
        '先看 $narration ，然后继续。',
      );
      expect(
        filterFor(absoluteMediaUrl).push('先看 $absoluteMediaUrl，然后继续。'),
        '先看 $narration ，然后继续。',
      );
    });

    test('releases body after a URL terminated by a newline', () {
      final filter = AgentVoiceTextStreamFilter();

      expect(filter.push('详情见 https://example.com/report'), '详情见 ');
      final released = filter.push('\n下一行正文应该立即继续播报。');

      expect(released, contains('下一行正文应该立即继续播报。'));
      expect(released, isNot(contains('https://example.com/report')));
      expect(filter.flush(), isEmpty);
    });

    test('releases body after route and domain lines', () {
      for (final prefix in const [
        '/hospital-bag-cart?tab=ready',
        'docs.example.com/guide',
      ]) {
        final filter = AgentVoiceTextStreamFilter();

        expect(filter.push('详情见 $prefix'), '详情见 ');
        final released = filter.push('\n下一行正文继续播报。');

        expect(released, contains('下一行正文继续播报。'));
        expect(released, isNot(contains(prefix)));
        expect(filter.flush(), isEmpty);
      }
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
      expect(pcmPlayer.finishes, 1);
      expect(pcmPlayer.stops, 0);
    },
  );

  test('AgentVoiceApiPlaybackPlayer streams realtime appended text', () async {
    final connection = _RecordingRealtimeSessionConnection();
    final repository = _RecordingVoiceRepository(connection: connection);
    final pcmPlayer = _RecordingPcmPlayer();
    final player = AgentVoiceApiPlaybackPlayer(
      repository: repository,
      pcmPlayer: pcmPlayer,
    );

    final session = player.startRealtimeSession();
    await Future<void>.delayed(Duration.zero);

    session.append('第一段内容，第二段内容');
    session.finish();
    connection.emitOpened();
    await Future<void>.delayed(Duration.zero);
    connection.emitAudio([3, 4]);
    connection.emitCompleted();
    await session.done;

    expect(repository.openRealtimeSessionCount, 1);
    expect(pcmPlayer.starts, 1);
    expect(pcmPlayer.writes, [
      [3, 4],
    ]);
    expect(pcmPlayer.finishes, 1);
    expect(pcmPlayer.stops, 0);
    expect(connection.appendedTexts.join(), contains('第一段内容'));
    expect(connection.finishCount, 1);
  });

  test('realtime voice sends body after a URL line before finish', () async {
    final connection = _RecordingRealtimeSessionConnection();
    final player = AgentVoiceApiPlaybackPlayer(
      repository: _RecordingVoiceRepository(connection: connection),
      pcmPlayer: _RecordingPcmPlayer(),
    );
    final session = player.startRealtimeSession();
    await Future<void>.delayed(Duration.zero);

    session.append('详情见 https://example.com/report');
    session.append('\n下一行正文应该立即继续播报。');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(connection.appendedTexts.join(), contains('下一行正文应该立即继续播报。'));
    expect(connection.appendedTexts.join(), isNot(contains('example.com')));
    expect(connection.finishCount, 0);

    session.finish();
    connection.emitCompleted();
    await session.done;
    expect(connection.finishCount, 1);
  });

  test(
    'realtime voice holds split media markdown and narrates it once',
    () async {
      final connection = _RecordingRealtimeSessionConnection();
      final repository = _RecordingVoiceRepository(connection: connection);
      final player = AgentVoiceApiPlaybackPlayer(
        repository: repository,
        pcmPlayer: _RecordingPcmPlayer(),
      );
      const narration = '我放了一张当前步骤的对照图，你可以边看图边完成这一步。';

      final session = player.startRealtimeSession(
        mediaNarrationResolver: ({required url, required alt}) {
          return url == '/v1/assets/asset-image?kind=image' ? narration : null;
        },
      );
      await Future<void>.delayed(Duration.zero);

      session.append('先看这张图：!');
      session.append('[Air1 核心部件](');
      session.append('/v1/assets/asset-image?kind=image');
      session.append(')，再看 ![重复](/v1/assets/asset-image?kind=image)。');
      session.finish();
      connection.emitOpened();
      await Future<void>.delayed(Duration.zero);
      connection.emitCompleted();
      await session.done;

      final submitted = connection.appendedTexts.join();
      expect(narration.allMatches(submitted), hasLength(1));
      expect(submitted, isNot(contains('Air1 核心部件')));
      expect(submitted, isNot(contains('/v1/assets')));
      expect(connection.finishCount, 1);
    },
  );
}

class _RecordingVoiceRepository implements AgentVoiceRepository {
  _RecordingVoiceRepository({this.connection});

  final texts = <String>[];
  final _RecordingRealtimeSessionConnection? connection;
  var openRealtimeSessionCount = 0;

  @override
  Stream<List<int>> realtimeVoicePcmStream({required String text}) async* {
    texts.add(text);
    yield [1, 2];
  }

  @override
  Future<AgentVoiceRealtimeSessionConnection> openRealtimeVoiceSession() async {
    openRealtimeSessionCount += 1;
    return connection ?? _RecordingRealtimeSessionConnection();
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
  var finishes = 0;
  var stops = 0;
  final writes = <List<int>>[];

  @override
  Future<void> start({int sampleRate = 24000, int channels = 1}) async {
    starts += 1;
  }

  @override
  Future<void> finish() async {
    finishes += 1;
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

class _RecordingRealtimeSessionConnection
    implements AgentVoiceRealtimeSessionConnection {
  final _controller = StreamController<AgentVoiceSessionEvent>();
  final appendedTexts = <String>[];
  var finishCount = 0;
  var cancelCount = 0;
  var closeCount = 0;

  @override
  Stream<AgentVoiceSessionEvent> get events => _controller.stream;

  @override
  Future<void> append(String text) async {
    appendedTexts.add(text);
  }

  @override
  Future<void> finish() async {
    finishCount += 1;
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
  }

  @override
  Future<void> close() async {
    closeCount += 1;
    await _controller.close();
  }

  void emitOpened() {
    _controller.add(
      const AgentVoiceSessionEvent(type: AgentVoiceSessionEventType.opened),
    );
  }

  void emitAudio(List<int> bytes) {
    _controller.add(
      AgentVoiceSessionEvent(
        type: AgentVoiceSessionEventType.audioChunk,
        audioBytes: bytes,
      ),
    );
  }

  void emitCompleted() {
    _controller.add(
      const AgentVoiceSessionEvent(type: AgentVoiceSessionEventType.completed),
    );
  }
}
