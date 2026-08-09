import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_card_export.dart';

void main() {
  test('builds the approved sanitized UTC card filename', () {
    expect(
      buildAgentCardExportFilename(
        cardType: 'birth plan/card',
        now: DateTime.parse('2026-07-11T23:30:00-08:00'),
      ),
      'comate-birth-plan-card-2026-07-12.png',
    );
  });

  testWidgets('specialized cards no longer expose save controls', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      cards: _exportScopeCards,
      exportService: _RecordingCardExportService(),
    );

    expect(find.text('保存图片'), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-card-export-journey')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-card-export-birth-plan')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-card-export-hospital-bag')),
      findsNothing,
    );
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
      'specialized cards fit the $width px viewport without exports',
      (tester) async {
        await _pumpPanel(
          tester,
          cards: _exportScopeCards,
          exportService: _RecordingCardExportService(),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('保存图片'), findsNothing);
      },
    );
  }

  testWidgets('journey stages follow legacy expansion rules', (tester) async {
    await _pumpPanel(
      tester,
      cards: const [_journeyCard],
      exportService: _RecordingCardExportService(),
    );

    expect(find.text('完成糖耐检查'), findsOneWidget);
    expect(find.text('开始整理待产包'), findsNothing);

    await tester.tap(find.text('孕 28-30 周'));
    await tester.pumpAndSettle();
    expect(find.text('开始整理待产包'), findsOneWidget);

    await tester.tap(find.text('孕 25-27 周'));
    await tester.pumpAndSettle();
    expect(find.text('完成糖耐检查'), findsNothing);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<AgentArtifactCardView> cards,
  required AgentCardExportService exportService,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: AgentArtifactPanel(
            cards: cards,
            onAction: (_) {},
            cardExportService: exportService,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingCardExportService implements AgentCardExportService {
  @override
  Future<void> sharePng({
    required Uint8List bytes,
    required String filename,
  }) async {}
}

const _exportScopeCards = [_journeyCard, _birthPlanCard, _hospitalBagCard];

const _journeyCard = AgentArtifactCardView(
  id: 'journey',
  title: '孕期计划',
  artifactType: 'birth_journey_plan_card',
  schemaVersion: '1.0',
  presentationKind: AgentArtifactPresentationKind.birthJourneyPlanCard,
  cardJson: {
    'owner': {'current_week': '孕 25 周'},
    'todo_plan': {
      'periods': [
        {
          'id': 'current-stage',
          'title': '孕 25-27 周',
          'status': 'current',
          'items': [
            {'title': '完成糖耐检查'},
          ],
        },
        {
          'id': 'future-stage',
          'title': '孕 28-30 周',
          'items': [
            {'title': '开始整理待产包'},
          ],
        },
      ],
    },
  },
);

const _birthPlanCard = AgentArtifactCardView(
  id: 'birth-plan',
  title: '分娩沟通单',
  artifactType: 'birth_plan_card',
  schemaVersion: '1.0',
  presentationKind: AgentArtifactPresentationKind.birthPlanCard,
  specializedView: AgentBirthPlanCardView(
    title: '分娩沟通单',
    sections: [
      AgentBirthPlanSectionView(
        id: 'communication',
        title: '沟通方式',
        values: ['每一步操作前先解释'],
      ),
    ],
    medicalNotes: [],
    disclaimer: '请优先遵循医生和医院建议。',
  ),
);

const _hospitalBagCard = AgentArtifactCardView(
  id: 'hospital-bag',
  title: '待产包',
  artifactType: 'hospital_bag_card',
  schemaVersion: '1.0',
  presentationKind: AgentArtifactPresentationKind.hospitalBagCard,
  specializedView: AgentHospitalBagCardView(
    title: '待产包',
    subtitle: '住院母婴必备用品',
    groups: [],
  ),
);
