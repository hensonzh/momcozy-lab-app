@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';
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
                          card: _lactationSupportForm,
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
            '../../../goldens/agent_hub/artifacts/collection_form_footer.png',
          ),
        );
      }
    });
  }

  testWidgets('collection form entry and dialog match the mobile baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('artifact-form-dialog-golden-surface'),
        child: MaterialApp(
          theme: momCozyTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: MomCozyColors.background,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 42),
                    Expanded(
                      child: AgentArtifactPanel(
                        cards: const [_lactationSupportForm],
                        onFormSubmit: (_) async => true,
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
      find.byKey(const ValueKey('artifact-form-dialog-golden-surface')),
      matchesGoldenFile(
        '../../../goldens/agent_hub/artifacts/form_entry_390x844.png',
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey(
          'agent-artifact-form-entry-lactation-support-intake-golden',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('artifact-form-dialog-golden-surface')),
      matchesGoldenFile(
        '../../../goldens/agent_hub/artifacts/form_dialog_390x844.png',
      ),
    );
  });
}

const _lactationSupportForm = AgentArtifactCardView(
  id: 'lactation-support-intake-golden',
  title: '哺乳支持信息',
  description: '这些信息将用于提供更贴合当前情况的哺乳支持。',
  artifactType: 'form',
  schemaVersion: '1.0',
  presentationKind: AgentArtifactPresentationKind.form,
  formId: 'lactation_support_intake',
  formSubmitLabel: '提交',
  formFields: [
    AgentArtifactFormFieldView(
      id: 'baby_age_days',
      label: '基本信息｜宝宝日龄',
      type: 'number',
      required: true,
      placeholder: '例如：42',
    ),
    AgentArtifactFormFieldView(
      id: 'feeding_method',
      label: '基本信息｜主要喂养方式',
      type: 'select',
      required: true,
      options: ['亲喂', '瓶喂母乳', '混合喂养', '配方奶喂养'],
      placeholder: '请选择',
    ),
    AgentArtifactFormFieldView(
      id: 'pain_or_discomfort',
      label: '当前情况｜疼痛或不适',
      type: 'multi_select',
      options: ['无明显不适', '含乳疼痛', '乳房胀痛', '乳头破损', '其它'],
      allowOtherInput: true,
    ),
    AgentArtifactFormFieldView(
      id: 'feeding_context',
      label: '当前情况｜补充说明',
      type: 'textarea',
      placeholder: '例如：左侧亲喂后持续疼痛',
    ),
    AgentArtifactFormFieldView(
      id: 'pumping_frequency',
      label: '当前情况｜每日吸乳次数',
      type: 'select',
      options: ['暂不吸乳', '1–3 次', '4–6 次', '7 次及以上'],
    ),
    AgentArtifactFormFieldView(
      id: 'milk_supply_concern',
      label: '当前情况｜奶量关注',
      type: 'select',
      options: ['没有明显担心', '担心偏少', '担心过多', '左右差异明显'],
    ),
    AgentArtifactFormFieldView(
      id: 'return_to_work_timing',
      label: '偏好信息｜预计返工时间',
      type: 'text',
      placeholder: '例如：宝宝 6 个月时',
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
      options: ['含乳疼痛', '奶量变化', '吸乳安排', '宝宝摄入'],
    ),
  ],
);

const _viewports = [
  _FormGoldenViewport(
    label: 'narrow mobile 360x800',
    size: Size(360, 800),
    filePath:
        '../../../goldens/agent_hub/artifacts/narrow_360x800/collection_form.png',
  ),
  _FormGoldenViewport(
    label: 'compact mobile 390x844',
    size: Size(390, 844),
    filePath: '../../../goldens/agent_hub/artifacts/collection_form.png',
  ),
  _FormGoldenViewport(
    label: 'large mobile 430x932',
    size: Size(430, 932),
    filePath:
        '../../../goldens/agent_hub/artifacts/large_430x932/collection_form.png',
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
