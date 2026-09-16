import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_message_menu.dart';
import '../../support/agent_message_menu_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('message menu $width/$scale', (tester) async {
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            if (call.method == 'Clipboard.getData') return {'text': clipboard};
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyAgentMessageMenu(
          tester,
          scale: scale,
          capture: (state) async {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/agent-menu-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          },
        );
      });
    }
  }

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('copy failure and recovery feedback $width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var unavailable = true;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (unavailable) throw PlatformException(code: 'unavailable');
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const text = 'Your notes\nOne observation at a time.';
      await tester.pumpWidget(
        messageMenuHost(
          const AgentMessageMenu(text: text, child: Text(text)),
          scale: scale,
        ),
      );
      for (final state in ['copy-failed', 'copy-success']) {
        await tester.longPress(find.text(text));
        await tester.pumpAndSettle();
        await tester.tap(find.text('复制'));
        await tester.pumpAndSettle();
        expect(find.text(unavailable ? '复制失败，请重试' : '已复制'), findsOneWidget);
        expect(copied, unavailable ? isNull : text);
        expect(find.text(text), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/agent-menu-$state-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );
        unavailable = false;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
