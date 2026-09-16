import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/cards/agent_artifact_card_registry.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_conversation_panel.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

const _form = AgentArtifactCardView(
  id: 'design-form',
  title: '喂养记录与支持偏好',
  presentationKind: AgentArtifactPresentationKind.form,
  formFields: [
    AgentArtifactFormFieldView(
      id: 'notes',
      label: '希望获得哪些支持？',
      type: 'text',
      required: true,
      placeholder: '请描述你的问题',
    ),
    AgentArtifactFormFieldView(
      id: 'feeding',
      label: '目前的喂养方式',
      type: 'radio',
      options: ['母乳喂养', '混合喂养'],
      defaultValue: '母乳喂养',
    ),
  ],
);

const _consult = AgentArtifactCardView(
  id: 'design-consult',
  title: '专业泌乳支持',
  presentationKind: AgentArtifactPresentationKind.ibclcConsultCard,
  specializedView: AgentIbclcConsultCardView(
    title: '专业泌乳支持',
    consultId: 'consult',
    sourceArtifactId: 'design-consult',
    consultantName: 'Mia · 泌乳顾问',
    consultantCredentials: 'IBCLC',
    consultantExperience: '十年支持经验',
    consultantBio: '一起了解你的喂养情况，找到适合你与宝宝的支持。',
    chatLabel: '了解咨询服务',
    chatNote: '咨询资料仅在授权范围内使用。',
  ),
);

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('conversation drawer long titles at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final canSwitch = ValueNotifier(true);
      addTearDown(canSwitch.dispose);
      String? selected;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAgentConversationPanel(
                context: context,
                repository: _Conversations(),
                activeThreadId: null,
                canSwitchListenable: canSwitch,
                onSelected: (id) async {
                  selected = id;
                  return true;
                },
                onDismissed: () {},
              ),
              child: const Text('打开历史'),
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tap(find.text('打开历史'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-history-${width.toInt()}.png',
        ),
      );
      await tester.tap(find.byKey(const ValueKey('agent-conversation-one')));
      await tester.pumpAndSettle();
      expect(selected, 'one');
      expect(
        find.byKey(const ValueKey('agent-conversation-panel')),
        findsNothing,
      );
    });
    for (final scale in [1.0, 2.0]) {
      testWidgets('Agent cards and dialog at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AgentArtifactActionView? action;
        await tester.pumpWidget(
          _host(
            SingleChildScrollView(
              padding: MomCozyInsets.page,
              child: Column(
                children: [
                  AgentArtifactCardRegistry.build(
                    card: _consult,
                    onAction: (value) => action = value,
                  )!,
                  const SizedBox(height: MomCozySpacing.section),
                  AgentArtifactFormEntry(
                    card: _form,
                    onSubmit: (value) async {
                      action = value;
                      return true;
                    },
                  ),
                ],
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        await _loadImages(tester);
        expect(tester.takeException(), isNull);
        {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/agent-cards-${width.toInt()}${scale == 2 ? "-2x" : ""}.png',
            ),
          );
        }
        final consent = find.byKey(
          const ValueKey('agent-ibclc-agreement-design-consult'),
        );
        await tester.ensureVisible(consent);
        await tester.tap(consent);
        await tester.pump();
        final open = find.byKey(
          const ValueKey('agent-ibclc-open-design-consult'),
        );
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/agent-cards-ready-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );
        await tester.tap(open);
        expect(action?.routePath, '/services');
        final entry = find.byKey(
          const ValueKey('agent-artifact-form-entry-design-form'),
        );
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/agent-form-${width.toInt()}.png',
            ),
          );
        }
        // The shared theme must reach embedded fields without a local scale or palette.
        final fieldContext = tester.element(find.byType(TextFormField).first);
        expect(
          Theme.of(fieldContext).textTheme.bodyMedium?.fontSize,
          MomCozyTypography.bodySize,
        );
        await tester.enterText(find.byType(TextFormField).first, '需要帮助安排喂养记录');
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final submit = find.byKey(
          const ValueKey('agent-artifact-form-submit-design-form'),
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(action?.value, contains('需要帮助安排喂养记录'));
        expect(find.byType(AgentArtifactFormDialog), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final scale in [1.0, 2.0]) {
      testWidgets('Agent home and keyboard at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_host(const AgentHubPage(), scale: scale));
        await tester.pumpAndSettle();
        await _loadImages(tester);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/agent-home-${width.toInt()}.png',
            ),
          );
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('agent-composer-input')),
          '想聊聊今天的喂养情况',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final input = tester.getRect(
          find.byKey(const ValueKey('agent-composer-input')),
        );
        expect(input.bottom, lessThanOrEqualTo(544));
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets('Agent transcript at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          const AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent:
                  '我们可以一起整理今天的记录。\n\n**下一步**\n\n- 查看宝宝的喂养与睡眠记录\n- 记录你今天的休息情况',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _loadImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-chat-${width.toInt()}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

Future<void> _loadImages(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in [
        MomCozyAssets.ibclcConsultantAvatar,
        MomCozyAssets.agentAvatar,
      ])
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pumpAndSettle();
}

class _Conversations extends Fake implements AgentConversationRepository {
  @override
  Future<List<AgentConversationSummary>> listConversations({
    int limit = 50,
  }) async => [
    AgentConversationSummary(
      id: 'one',
      title: '讨论宝宝的喂养、休息与后续支持安排 / Feeding support',
      status: 'active',
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 10),
    ),
  ];
}
