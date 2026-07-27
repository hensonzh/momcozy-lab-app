import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/agent_hub/agent_hub_page.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final viewport in _viewports) {
    testWidgets('IBCLC consult card matches ${viewport.label} baseline', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('ibclc-card-responsive-golden-surface'),
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
                      const Expanded(
                        child: AgentArtifactPanel(
                          cards: [_ibclcCard],
                          onAction: _ignoreAction,
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
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(MomCozyAssets.ibclcConsultantAvatar),
          context,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('ibclc-card-responsive-golden-surface')),
        matchesGoldenFile(viewport.filePath),
      );
    });
  }
}

void _ignoreAction(AgentArtifactActionView _) {}

const _ibclcCard = AgentArtifactCardView(
  id: 'ibclc-responsive',
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
    consultId: 'ibclc-responsive',
    sourceArtifactId: 'ibclc-responsive',
    consultantName: 'Emily Chen',
    consultantCredentials: 'IBCLC 国际认证哺乳顾问',
    consultantExperience: '8 年产后哺乳支持经验',
    consultantBio: '拥有 8 年产后哺乳支持经验，核心擅长含乳评估、有效吸吮与母乳移出观察。可结合宝宝尿布、体重和吃奶表现判断摄入信号。',
    chatLabel: '咨询 IBCLC',
    chatNote: '启动咨询后，会自动将你的问题同步给顾问',
    reason: '含乳疼痛',
    feedingContext: '左侧喂养后持续疼痛。',
    urgency: 'soon',
  ),
);

const _viewports = [
  _IbclcViewport(
    label: 'narrow mobile 360x640',
    size: Size(360, 640),
    filePath:
        '../../../goldens/agent_hub/artifacts/cards/ibclc_consult_narrow_360.png',
  ),
  _IbclcViewport(
    label: 'large mobile 430x640',
    size: Size(430, 640),
    filePath:
        '../../../goldens/agent_hub/artifacts/cards/ibclc_consult_large_430.png',
  ),
];

class _IbclcViewport {
  const _IbclcViewport({
    required this.label,
    required this.size,
    required this.filePath,
  });

  final String label;
  final Size size;
  final String filePath;
}
