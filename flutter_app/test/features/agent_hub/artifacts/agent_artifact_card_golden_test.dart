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
    label: 'milk plan card',
    fileName: 'milk_plan',
    card: AgentArtifactCardView(
      id: 'milk-plan-golden',
      title: '三天泵奶计划',
      artifactType: 'milk_plan_card',
      schemaVersion: '1.0',
      presentationKind: AgentArtifactPresentationKind.milkPlanCard,
      cardJson: {
        'subtitle': '结合最近记录生成',
        'headline': '保持舒适的前提下，把晚间泵奶稍微提前。',
        'sections': [
          {
            'title': '计划',
            'metrics': [
              {'label': '周期', 'value': '3 天', 'detail': '从明天开始'},
            ],
            'items': ['20:00 泵奶并记录舒适度', '观察三天后再调整节奏'],
          },
        ],
      },
    ),
  ),
  _CardGoldenCase(
    label: 'birth journey card',
    fileName: 'birth_journey',
    card: AgentArtifactCardView(
      id: 'journey-golden',
      title: '孕期计划',
      artifactType: 'birth_journey_plan_card',
      schemaVersion: '1.0',
      presentationKind: AgentArtifactPresentationKind.birthJourneyPlanCard,
      cardJson: {
        'owner': {'current_week': '孕 25 周', 'birth_path': '顺产'},
        'todo_plan': {
          'periods': [
            {
              'title': '孕 25-27 周',
              'subtitle': '重点完成糖耐和血压复查。',
              'status': 'current',
              'items': [
                {
                  'title': '完成糖耐检查',
                  'priority_label': '重要',
                  'steps': ['确认检查时间', '检查结束后及时进餐'],
                },
              ],
            },
            {
              'title': '孕 28-30 周',
              'items': [
                {'title': '开始整理待产包'},
              ],
            },
          ],
        },
      },
    ),
  ),
  _CardGoldenCase(
    label: 'birth plan card',
    fileName: 'birth_plan',
    card: AgentArtifactCardView(
      id: 'birth-plan-golden',
      title: '分娩沟通单',
      artifactType: 'birth_plan_card',
      schemaVersion: '1.0',
      presentationKind: AgentArtifactPresentationKind.birthPlanCard,
      cardJson: {
        'communication': ['希望每一步操作前先解释'],
        'pain_relief': ['优先尝试非药物缓解方式'],
        'baby_after_birth': ['情况允许时尽早肌肤接触'],
        'medical_notes': ['妊娠糖尿病史'],
      },
    ),
  ),
  _CardGoldenCase(
    label: 'hospital bag card',
    fileName: 'hospital_bag',
    card: AgentArtifactCardView(
      id: 'hospital-bag-golden',
      title: '待产包',
      artifactType: 'hospital_bag_card',
      schemaVersion: '1.0',
      presentationKind: AgentArtifactPresentationKind.hospitalBagCard,
      cardJson: {
        'packing_groups': [
          {
            'title': '妈妈住院包',
            'items': [
              {
                'label': '产褥垫组合装',
                'quantity': '1 包',
                'priority': 'must',
                'reason': '产后前几天更换频繁',
              },
            ],
          },
          {
            'title': '先和医院确认',
            'items': [
              {'label': '宝宝配方奶', 'priority': 'confirm_first'},
            ],
          },
        ],
        'disclaimer': '最终请以医院实际要求为准。',
      },
    ),
  ),
  _CardGoldenCase(
    label: 'milk plan preview',
    fileName: 'milk_plan_preview',
    card: AgentArtifactCardView(
      id: 'milk-preview-golden',
      title: '三天泵奶计划',
      artifactType: 'milk_plan_preview',
      schemaVersion: 'v1',
      presentationKind: AgentArtifactPresentationKind.milkPlanPreview,
      payload: {
        'summary': '将晚间泵奶提前，先观察三天。',
        'direction': 'maintain',
        'days': 3,
        'tasks': [
          {'title': '20:00 泵奶', 'detail': '保持舒适档位'},
        ],
        'reminders': [
          {'title': '及时补水'},
        ],
      },
    ),
  ),
  _CardGoldenCase(
    label: 'IBCLC consult card',
    fileName: 'ibclc_consult',
    card: AgentArtifactCardView(
      id: 'ibclc-golden',
      title: 'IBCLC 咨询入口',
      artifactType: 'ibclc_consult_card',
      schemaVersion: 'v1',
      presentationKind: AgentArtifactPresentationKind.ibclcConsultCard,
      payload: {
        'reason': '含乳疼痛',
        'feeding_context': '左侧喂养后持续疼痛。',
        'urgency': 'soon',
      },
    ),
  ),
  _CardGoldenCase(
    label: 'hospital bag cart card',
    fileName: 'hospital_bag_cart',
    card: AgentArtifactCardView(
      id: 'cart-golden',
      title: '待产包',
      artifactType: 'hospital_bag_cart',
      schemaVersion: 'v1',
      presentationKind: AgentArtifactPresentationKind.hospitalBagCart,
      payload: {
        'cart_update': {
          'message': '已经更新待产包购物车。',
          'groups': [
            {
              'title': '妈妈护理',
              'items': [
                {'name': '产褥垫组合装'},
                {'name': '一次性内裤'},
              ],
            },
          ],
          'totals': {'item_count': 2, 'total': 101.02},
        },
      },
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
