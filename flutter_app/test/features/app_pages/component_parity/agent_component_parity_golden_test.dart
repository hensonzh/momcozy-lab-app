import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Agent component parity goldens', () {
    testWidgets('composer bar matches compact baseline', (tester) async {
      tester.view.physicalSize = const Size(390, 120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: MomCozyColors.background,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AgentComposerBar(
                controller: controller,
                canSend: false,
                isRunning: false,
                isInputLocked: false,
                imageCount: 0,
                showPhotoMenu: false,
                canAttachImage: true,
                canUseVoice: true,
                voicePhase: AgentVoicePhase.idle,
                onChanged: (_) {},
                onSend: () {},
                onCancel: () {},
                onTogglePhotoMenu: () {},
                onAttachImage: () {},
                onRemoveImages: () {},
                onVoiceInput: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composer = find.byKey(const ValueKey('agent-composer-bar'));
      expect(composer, findsOneWidget);
      expect(find.text('和 CozyMate 聊聊...'), findsOneWidget);

      await expectLater(
        composer,
        matchesGoldenFile(
          '../../../goldens/component_parity/agent_composer_bar.png',
        ),
      );
    });
  });
}
