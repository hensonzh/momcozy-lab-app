import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_mapper.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';

void main() {
  test('maps the motion assessment artifact to a dedicated card contract', () {
    final card = AgentArtifactMapper.cardFromEvent(_motionArtifactEvent());

    expect(card, isNotNull);
    expect(
      card!.presentationKind,
      AgentArtifactPresentationKind.motionAssessmentCard,
    );
    final data = card.specializedView as AgentMotionAssessmentCardView;
    expect(data.target, 'forward_head');
    expect(data.startLabel, '开始动态评估');
    expect(data.routeLocation, '/motion-assessment?target=forward_head');
    expect(data.videoUploadEnabled, isFalse);
    expect(data.landmarkUploadEnabled, isFalse);
  });

  test('does not expose a legacy target without an implemented evaluator', () {
    expect(
      AgentArtifactMapper.cardFromEvent(_motionArtifactEvent(target: 'squat')),
      isNull,
    );
  });

  testWidgets('motion assessment card emits only its dedicated route action', (
    tester,
  ) async {
    final card = AgentArtifactMapper.cardFromEvent(_motionArtifactEvent())!;
    AgentArtifactActionView? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentArtifactPanel(
            cards: [card],
            onAction: (action) => selected = action,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-motion-assessment-card-motion-1')),
      findsOneWidget,
    );
    expect(find.text('视频与关键点默认只在本机处理'), findsOneWidget);
    await tester.tap(find.text('开始动态评估'));
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.routePath, '/motion-assessment');
    expect(selected!.value, '/motion-assessment?target=forward_head');
    expect(selected!.kind, 'motion_assessment.open');
  });
}

AgentStreamEvent _motionArtifactEvent({String target = 'forward_head'}) {
  return AgentStreamEvent({
    'type': 'artifact.created',
    'artifact_id': 'motion-1',
    'payload': {
      'artifact_type': 'motion_assessment_card',
      'schema_version': 'v1',
      'artifact': {
        'id': 'motion-1',
        'artifact_type': 'motion_assessment_card',
        'schema_version': 'v1',
        'payload': {
          'title': '肩颈前倾动态评估',
          'target': target,
          'user_goal': '看看我是否有肩颈前倾',
          'description': '按语音提示侧身站立，系统会实时检查取景和动作。',
          'entry': {
            'url': '/motion-assessment?target=$target',
            'label': '开始动态评估',
          },
          'privacy': {
            'video_upload_enabled': false,
            'landmark_upload_enabled': false,
          },
          'disclaimer': '结果只反映当前画面，不替代医疗诊断。',
        },
      },
    },
  });
}
