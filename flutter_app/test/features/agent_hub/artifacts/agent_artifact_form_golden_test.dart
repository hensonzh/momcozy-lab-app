import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final viewport in _viewports) {
    testWidgets('collection form matches ${viewport.label} baseline', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('artifact-form-golden-surface'),
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
                        child: AgentArtifactForm(
                          card: _hospitalBagForm,
                          onSubmit: (_) async => true,
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
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('artifact-form-golden-surface')),
        matchesGoldenFile(viewport.filePath),
      );

      if (viewport.size == const Size(390, 844)) {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2400),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('artifact-form-golden-surface')),
          matchesGoldenFile(
            '../../../goldens/agent_hub/artifacts/hospital_bag_intake_footer.png',
          ),
        );
      }
    });
  }
}

const _hospitalBagForm = AgentArtifactCardView(
  id: 'hospital-bag-intake-golden',
  title: '信息采集',
  description: '这些信息将用于生成更适合你的待产包清单。',
  artifactType: 'form',
  schemaVersion: '1.0',
  presentationKind: AgentArtifactPresentationKind.form,
  formId: 'hospital_bag_intake',
  formSubmitLabel: '提交',
  formFields: [
    AgentArtifactFormFieldView(
      id: 'due_date_or_week',
      label: '基本信息｜预产期或当前孕周',
      type: 'text',
      required: true,
      placeholder: '例如：2026-08-20 或 32 周',
    ),
    AgentArtifactFormFieldView(
      id: 'first_birth',
      label: '基本信息｜是否第一胎',
      type: 'select',
      required: true,
      options: ['是', '否'],
      placeholder: '请选择',
    ),
    AgentArtifactFormFieldView(
      id: 'fetus_count',
      label: '基本信息｜单胎或多胎',
      type: 'select',
      required: true,
      options: ['单胎', '双胎', '多胎'],
      placeholder: '请选择',
    ),
    AgentArtifactFormFieldView(
      id: 'pregnancy_history_or_notes',
      label: '生产信息｜孕产史或需要注意的信息',
      type: 'multi_select',
      options: ['无特殊情况', '妊娠糖尿病', '妊娠高血压', '其它'],
      allowOtherInput: true,
    ),
    AgentArtifactFormFieldView(
      id: 'birth_path',
      label: '生产信息｜分娩方式',
      type: 'select',
      required: true,
      options: ['顺产', '剖宫产', '还不确定'],
    ),
    AgentArtifactFormFieldView(
      id: 'feeding_intention',
      label: '偏好信息｜喂养意向',
      type: 'select',
      options: ['母乳喂养', '混合喂养', '配方奶喂养', '还不确定'],
    ),
    AgentArtifactFormFieldView(
      id: 'return_to_work_timing',
      label: '偏好信息｜预计返工时间',
      type: 'text',
      placeholder: '例如：产后 6 个月',
    ),
    AgentArtifactFormFieldView(
      id: 'support_person',
      label: '偏好信息｜主要陪护人',
      type: 'select',
      options: ['伴侣', '父母', '月嫂', '其他亲友'],
    ),
    AgentArtifactFormFieldView(
      id: 'top_worries',
      label: '偏好信息｜最担心的问题',
      type: 'multi_select',
      options: ['漏带重要物品', '预算超支', '医院临时要求', '产后喂养'],
    ),
  ],
);

const _viewports = [
  _FormGoldenViewport(
    label: 'narrow mobile 360x800',
    size: Size(360, 800),
    filePath:
        '../../../goldens/agent_hub/artifacts/narrow_360x800/hospital_bag_intake.png',
  ),
  _FormGoldenViewport(
    label: 'compact mobile 390x844',
    size: Size(390, 844),
    filePath: '../../../goldens/agent_hub/artifacts/hospital_bag_intake.png',
  ),
  _FormGoldenViewport(
    label: 'large mobile 430x932',
    size: Size(430, 932),
    filePath:
        '../../../goldens/agent_hub/artifacts/large_430x932/hospital_bag_intake.png',
  ),
];

class _FormGoldenViewport {
  const _FormGoldenViewport({
    required this.label,
    required this.size,
    required this.filePath,
  });

  final String label;
  final Size size;
  final String filePath;
}
