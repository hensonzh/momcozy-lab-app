import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_card_export.dart';

void main() {
  test('builds the approved sanitized UTC card filename', () {
    expect(
      buildAgentCardExportFilename(
        cardType: 'IBCLC consult/card',
        now: DateTime.parse('2026-07-11T23:30:00-08:00'),
      ),
      'comate-ibclc-consult-card-2026-07-12.png',
    );
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('supported cards fit the $width px viewport without exports', (
      tester,
    ) async {
      await _pumpPanel(tester, width: width);

      expect(tester.takeException(), isNull);
      expect(find.text('保存图片'), findsNothing);
      expect(find.text('IBCLC 在线咨询'), findsOneWidget);
    });
  }
}

Future<void> _pumpPanel(WidgetTester tester, {required double width}) async {
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
            cards: const [_ibclcCard],
            onAction: (_) {},
            cardExportService: _NoopCardExportService(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoopCardExportService implements AgentCardExportService {
  @override
  Future<void> sharePng({
    required Uint8List bytes,
    required String filename,
  }) async {}
}

const _ibclcCard = AgentArtifactCardView(
  id: 'ibclc',
  title: 'IBCLC 在线咨询',
  artifactType: 'ibclc_consult_card',
  schemaVersion: 'v1',
  presentationKind: AgentArtifactPresentationKind.ibclcConsultCard,
  specializedView: AgentIbclcConsultCardView(
    title: 'IBCLC 在线咨询',
    consultId: 'ibclc',
    sourceArtifactId: 'ibclc',
    consultantName: 'Emily Chen',
    consultantCredentials: 'IBCLC 国际认证哺乳顾问',
    consultantExperience: '8 年产后哺乳支持经验',
    consultantBio: '擅长含乳评估、有效吸吮与母乳移出观察。',
    chatLabel: '咨询 IBCLC',
    chatNote: '启动咨询后，会自动将你的问题同步给顾问',
  ),
);
