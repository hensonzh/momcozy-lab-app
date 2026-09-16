import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentResults(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
  bool includeRecordLinks = false,
}) async {
  final actions = <AgentArtifactActionView>[];
  Future<void> show(AgentArtifactCardView card, {bool enabled = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Cozymate')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(52, 16, 16, 24),
            child: AgentArtifactPanel(
              cards: [card],
              onAction: enabled ? actions.add : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> press(String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  ButtonStyleButton button(String label) => tester.widget<ButtonStyleButton>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        )
        .first,
  );
  const generic = AgentArtifactCardView(
    id: 'summary',
    title: 'Your feeding notes and next steps',
    statusLabel: 'Ready to review with your care team',
    content: 'These are the notes you shared today.',
    rows: [
      'Morning: comfortable feeding.',
      'Evening: review your notes together.',
    ],
    actions: [
      AgentArtifactActionView(
        label: 'Review support options',
        icon: Icons.arrow_forward,
        kind: 'route',
        value: '/services',
        routePath: '/services',
      ),
    ],
  );
  await show(generic, enabled: false);
  expect(button('Review support options').onPressed, isNull);
  await capture('disabled');
  await show(generic);
  await capture('summary');
  await press('Review support options');
  expect(actions.single.routePath, '/services');
  actions.clear();
  await show(resultConsult('first'));
  expect(button('Explore support').onPressed, isNull);
  await capture('consult');
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  expect(button('Explore support').onPressed, isNotNull);
  await tester.ensureVisible(find.text('Explore support'));
  await tester.pumpAndSettle();
  await capture('consent-accepted');
  await press('Explore support');
  expect(actions.single.routePath, '/services');
  actions.clear();
  await show(resultConsult('second'));
  expect(button('Explore support').onPressed, isNull);
  const motion = AgentArtifactCardView(
    id: 'motion',
    title: 'Posture assessment',
    presentationKind: AgentArtifactPresentationKind.motionAssessmentCard,
    specializedView: AgentMotionAssessmentCardView(
      title: 'Posture assessment',
      target: 'posture_screen',
      sourceArtifactId: 'motion',
      description: 'Private assessment',
      startLabel: 'Start assessment',
      routeLocation:
          '/motion-assessment?target=posture_screen&source_artifact_id=motion',
      videoUploadEnabled: false,
      landmarkUploadEnabled: false,
      disclaimer: 'Not a diagnosis',
    ),
  );
  await show(motion, enabled: false);
  expect(button('Start assessment').onPressed, isNull);
  await show(motion);
  await capture('motion');
  await press('Start assessment');
  expect(actions.single.routePath, '/motion-assessment');
  expect(Uri.parse(actions.single.value!).queryParameters, {
    'target': 'posture_screen',
    'source_artifact_id': 'motion',
  });
  if (includeRecordLinks) {
    actions.clear();
    await show(
      const AgentArtifactCardView(
        id: 'record-links',
        title: '记录入口',
        content: '以下入口用于查看当前记录。',
        rows: ['泌乳记录包含每次保存的内容。', '身体记录用于回顾今日状态。'],
        actions: [
          AgentArtifactActionView(
            label: '查看泌乳记录',
            icon: Icons.open_in_new,
            kind: 'route',
            value: '/me/lactation',
            routePath: '/me/lactation',
          ),
          AgentArtifactActionView(
            label: '查看身体记录',
            icon: Icons.open_in_new,
            kind: 'route',
            value: '/me/diary',
            routePath: '/me/diary',
          ),
        ],
      ),
    );
    await capture('milk');
    await press('查看泌乳记录');
    await press('查看身体记录');
    expect(actions.map((action) => action.routePath), [
      '/me/lactation',
      '/me/diary',
    ]);
    await capture('milk-actions');
  }
  await show(
    const AgentArtifactCardView(
      id: 'unsupported',
      title: 'A shared result',
      schemaVersion: 'internal-v99',
      presentationKind: AgentArtifactPresentationKind.unsupported,
    ),
  );
  await capture('unsupported');
  expect(find.textContaining('internal-v99'), findsNothing);
  expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

AgentArtifactCardView resultConsult(String id) => AgentArtifactCardView(
  id: 'consult',
  title: 'Feeding support',
  presentationKind: AgentArtifactPresentationKind.ibclcConsultCard,
  specializedView: AgentIbclcConsultCardView(
    title: 'Feeding support',
    consultId: id,
    sourceArtifactId: 'consult',
    consultantName: 'Emily Chen',
    consultantCredentials: 'IBCLC',
    consultantExperience: '8 years of feeding support',
    consultantBio: 'Support with latch and comfortable feeding.',
    reason: 'A little support for your feeding questions.',
    chatLabel: 'Explore support',
    chatNote: 'Review the available service before booking.',
  ),
);
