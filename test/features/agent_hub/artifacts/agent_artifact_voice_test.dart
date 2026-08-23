import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_voice.dart';

void main() {
  test('projects only the latest artifact title and safe body copy', () {
    final text = agentArtifactVoiceFallbackText(const [
      AgentArtifactCardView(id: 'old', title: '旧卡片', content: '旧内容'),
      AgentArtifactCardView(
        id: 'current',
        title: '泌乳支持清单',
        content: '我已经帮你整理好了。',
        actions: [
          AgentArtifactActionView(
            label: '打开泌乳计划',
            icon: Icons.water_drop_outlined,
            kind: 'navigate',
            value: '/plan',
            routePath: '/plan',
          ),
        ],
      ),
    ]);

    expect(text, '泌乳支持清单 我已经帮你整理好了。');
    expect(text, isNot(contains('打开泌乳计划')));
    expect(text, isNot(contains('/plan')));
    expect(text, isNot(contains('旧卡片')));
  });

  test('uses a form description only when artifact content is absent', () {
    expect(
      agentArtifactVoiceFallbackText(const [
        AgentArtifactCardView(
          id: 'form',
          title: '泌乳支持信息',
          description: '请补充以下信息。',
        ),
      ]),
      '泌乳支持信息 请补充以下信息。',
    );
  });

  test('does not project an unsupported latest artifact', () {
    expect(
      agentArtifactVoiceFallbackText(const [
        AgentArtifactCardView(
          id: 'unsupported',
          title: '未知卡片',
          presentationKind: AgentArtifactPresentationKind.unsupported,
        ),
      ]),
      isNull,
    );
  });
}
