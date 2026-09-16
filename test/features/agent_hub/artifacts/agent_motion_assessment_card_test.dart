import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
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
    expect(data.title, '头颈姿态动态评估');
    expect(data.target, 'forward_head');
    expect(data.sourceArtifactId, 'motion-1');
    expect(data.startLabel, '开始评估');
    expect(
      data.routeLocation,
      '/motion-assessment?target=forward_head&source_artifact_id=motion-1',
    );
    expect(data.videoUploadEnabled, isFalse);
    expect(data.landmarkUploadEnabled, isFalse);
  });

  test('does not expose a legacy target without an implemented evaluator', () {
    expect(
      AgentArtifactMapper.cardFromEvent(_motionArtifactEvent(target: 'squat')),
      isNull,
    );
  });

  test(
    'maps the generic posture screen entry without narrowing it to neck',
    () {
      final card = AgentArtifactMapper.cardFromEvent(
        _motionArtifactEvent(target: 'posture_screen'),
      )!;
      final data = card.specializedView as AgentMotionAssessmentCardView;

      expect(data.title, '体态动态评估');
      expect(data.target, 'posture_screen');
      expect(
        data.routeLocation,
        '/motion-assessment?target=posture_screen&source_artifact_id=motion-1',
      );
      expect(data.description, contains('语音选择评估项目'));
    },
  );

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
    expect(find.text('头颈姿态动态评估'), findsOneWidget);
    expect(find.text('实时取景与语音动作指导'), findsNothing);
    expect(find.text('按语音提示侧身站立，系统会实时检查取景和动作。'), findsNothing);
    expect(find.text('视频与关键点默认只在本机处理'), findsNothing);
    expect(find.text('结果只反映当前画面，不替代医疗诊断。'), findsNothing);

    final leadingIcon = find.byIcon(Icons.accessibility_new_rounded);
    final title = find.text('头颈姿态动态评估');
    final brandLogo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == MomCozyAssets.momcozyLogo,
    );
    expect(leadingIcon, findsOneWidget);
    expect(brandLogo, findsNothing);
    final titleCenterY = tester.getCenter(title).dy;
    expect(tester.getCenter(leadingIcon).dy, closeTo(titleCenterY, 0.5));

    await tester.tap(find.text('开始评估'));
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.routePath, '/motion-assessment');
    expect(
      selected!.value,
      '/motion-assessment?target=forward_head&source_artifact_id=motion-1',
    );
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
          if (target == 'forward_head')
            'description': '按语音提示侧身站立，系统会实时检查取景和动作。',
          'entry': {
            'url': '/motion-assessment?target=$target',
            'label': '开始评估',
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
