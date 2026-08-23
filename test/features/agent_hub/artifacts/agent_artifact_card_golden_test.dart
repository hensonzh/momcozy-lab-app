import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final goldenCase in _cardCases) {
    testWidgets('${goldenCase.label} matches the artifact card baseline', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('artifact-card-golden-surface'),
          child: MaterialApp(
            theme: momCozyTheme(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: MomCozyColors.background,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 42),
                      Expanded(
                        child: AgentArtifactPanel(
                          cards: [goldenCase.card],
                          onAction: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(AgentArtifactPanel));
      await tester.runAsync(() async {
        for (final asset in [
          MomCozyAssets.momcozyLogo,
          MomCozyAssets.ibclcConsultantAvatar,
        ]) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('artifact-card-golden-surface')),
        matchesGoldenFile(
          '../../../goldens/agent_hub/artifacts/cards/${goldenCase.fileName}.png',
        ),
      );
    });
  }
}

const _cardCases = [
  _CardGoldenCase(
    label: 'IBCLC consult card',
    fileName: 'ibclc_consult',
    card: AgentArtifactCardView(
      id: 'ibclc-golden',
      title: 'IBCLC 在线咨询',
      artifactType: 'ibclc_consult_card',
      schemaVersion: 'v1',
      presentationKind: AgentArtifactPresentationKind.ibclcConsultCard,
      payload: {
        'reason': '含乳疼痛',
        'feeding_context': '左侧喂养后持续疼痛。',
        'urgency': 'soon',
      },
      specializedView: AgentIbclcConsultCardView(
        title: 'IBCLC 在线咨询',
        consultId: 'ibclc-golden',
        sourceArtifactId: 'ibclc-golden',
        consultantName: 'Emily Chen',
        consultantCredentials: 'IBCLC 国际认证哺乳顾问',
        consultantExperience: '8 年产后哺乳支持经验',
        consultantBio:
            '拥有 8 年产后哺乳支持经验，核心擅长含乳评估、有效吸吮与母乳移出观察。可结合宝宝尿布、体重和吃奶表现判断摄入信号。',
        chatLabel: '咨询 IBCLC',
        chatNote: '启动咨询后，会自动将你的问题同步给顾问',
        reason: '含乳疼痛',
        feedingContext: '左侧喂养后持续疼痛。',
        urgency: 'soon',
      ),
    ),
  ),
];

class _CardGoldenCase {
  const _CardGoldenCase({
    required this.label,
    required this.fileName,
    required this.card,
  });

  final String label;
  final String fileName;
  final AgentArtifactCardView card;
}
