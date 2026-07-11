import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_media_voice.dart';

void main() {
  test('normalizes production media voice metadata and URL aliases', () {
    final event = AgentStreamEvent(const {
      'type': 'tool.completed',
      'tool_call_id': 'tool-media-1',
      'payload': {
        'safe_output': {
          'media_voice': [
            {
              'media_id': '/v1/assets/asset-image?kind=image',
              'kind': 'image',
              'visual_label': 'Air1 核心部件',
              'voice_policy': 'announce',
              'priority': 'instructional',
              'spoken_label': '我放了一张当前步骤的对照图。',
            },
            {
              'mediaId': '/v1/assets/asset-image?kind=image',
              'voicePolicy': 'announce',
              'spokenLabel': '我放了一张当前步骤的对照图。',
            },
            {
              'media_id': '/v1/assets/decorative?kind=image',
              'voice_policy': 'silent',
              'spoken_label': '这句不应该播。',
            },
          ],
        },
      },
    });

    final index = AgentMediaVoiceNarrationIndex.fromEvents([event]);

    expect(index.items, hasLength(2));
    expect(index.autoSpeakableTexts, ['我放了一张当前步骤的对照图。']);
    expect(
      index.resolve('/v1/assets/asset-image?kind=image'),
      '我放了一张当前步骤的对照图。',
    );
    expect(
      index.resolve(
        'https://api.example.test/v1/assets/asset-image?kind=image#step',
      ),
      '我放了一张当前步骤的对照图。',
    );
    expect(index.resolve('/v1/assets/decorative?kind=image'), isNull);
  });

  test('normalizes legacy tool result JSON and spoken detail fallback', () {
    final event = AgentStreamEvent({
      'type': 'TOOL_CALL_RESULT',
      'content': jsonEncode({
        'mediaVoice': [
          {
            'url': '/skill-assets/device-guidance/air1/images/step.png',
            'voicePolicy': 'read_text',
            'spokenDetail': '请确认阀门方向与图中一致。',
          },
          {
            'url': '/skill-assets/device-guidance/air1/guide.pdf',
            'voicePolicy': 'describe_on_request',
            'spokenLabel': '按需打开说明书。',
          },
        ],
      }),
    });

    final index = AgentMediaVoiceNarrationIndex.fromEvents([event]);

    expect(index.autoSpeakableTexts, ['请确认阀门方向与图中一致。']);

    expect(
      index.resolve('/skill-assets/device-guidance/air1/images/step.png'),
      '请确认阀门方向与图中一致。',
    );
    expect(
      index.resolve('/skill-assets/device-guidance/air1/guide.pdf'),
      isNull,
    );
  });

  test('uses the legacy fallback only for device guidance images', () {
    expect(
      fallbackAgentMediaVoiceNarration(
        'https://api.example.test/skill-assets/device-guidance/air1/images/charging.png',
      ),
      '我放了一张当前步骤的对照图，你可以边看图边完成这一步。',
    );
    expect(
      fallbackAgentMediaVoiceNarration(
        '/skill-assets/device-guidance/air1/videos/operation.mp4',
      ),
      isNull,
    );
  });
}
