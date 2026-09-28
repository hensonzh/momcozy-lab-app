@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/agent_conversation_scenarios.dart';
import '../../support/fake_video_player_platform.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());
  testWidgets(
    'composer send, disabled, and stop visuals retain a 44dp target',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      Widget composer({required bool canSend, required bool isRunning}) =>
          MaterialApp(
            theme: momCozyTheme(),
            home: Scaffold(
              body: AgentComposerBar(
                controller: controller,
                canSend: canSend,
                isRunning: isRunning,
                isInputLocked: false,
                images: const [],
                files: const [],
                canAttachImage: false,
                canAttachFile: false,
                isAttachmentPending: false,
                attachmentUploadProgress: null,
                onChanged: (_) {},
                onSend: () {},
                onCancel: () {},
                onTakePhoto: () {},
                onPickPhoto: () {},
                onPickFile: () {},
                onRemoveImage: (_) {},
                onRemoveFile: (_) {},
              ),
            ),
          );

      BoxDecoration decoration() =>
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('agent-send-button-visual')),
                  )
                  .decoration
              as BoxDecoration;

      await tester.pumpWidget(composer(canSend: false, isRunning: false));
      final send = find.byKey(const ValueKey('agent-send-button'));
      final visual = find.byKey(const ValueKey('agent-send-button-visual'));
      expect(tester.getSize(send), const Size(44, 44));
      expect(tester.getSize(visual), const Size(36, 36));
      expect(decoration().color, const Color(0xFFFAF6F3));
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      controller.text = 'Hello';
      await tester.pumpWidget(composer(canSend: true, isRunning: false));
      expect(decoration().color, MomHomeTokens.rose);
      expect(decoration().boxShadow, isNotEmpty);
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);

      controller.clear();
      await tester.pumpWidget(composer(canSend: false, isRunning: true));
      expect(find.byKey(const ValueKey('agent-stop-button')), findsOneWidget);
      expect(decoration().color, const Color(0xFFF9EDF2));
      expect(decoration().border, isNotNull);
    },
  );

  testWidgets(
    'large text placeholder and drafts keep composer controls below the text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: AgentHubPage()),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('agent-composer-input'));
      for (final draft in [
        '',
        'Another draft, not sent yet.',
        'A longer follow-up question about today\'s notes.',
      ]) {
        await tester.enterText(input, draft);
        await tester.pumpAndSettle();
        final field = tester.getRect(input);
        for (final key in ['agent-attachment-button', 'agent-send-button']) {
          final control = tester.getRect(find.byKey(ValueKey(key)));
          expect(control.top, greaterThanOrEqualTo(field.bottom));
          expect(control.width, greaterThanOrEqualTo(44));
          expect(control.height, greaterThanOrEqualTo(44));
        }
        expect(tester.widget<TextField>(input).controller!.text, draft);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('conversation recovery $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyAgentConversation(
          tester,
          scale: scale,
          capture: (state) async {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/agent-conversation-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          },
        );
      });
    }
  }
}
