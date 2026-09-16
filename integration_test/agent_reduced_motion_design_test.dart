import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

// Local render fixtures. No runner, microphone, provider request or saved message.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android reduced motion keeps status readable and frames still',
    (tester) async {
      var converted = false;
      for (final scale in [1.0, 2.0]) {
        final reduced = ValueNotifier(true);
        final body = ValueNotifier<Widget>(
          AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.streaming,
              events: [
                AgentStreamEvent({
                  'type': 'run.progress',
                  'payload': {'label': '我想一下'},
                }),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => ValueListenableBuilder<bool>(
              valueListenable: reduced,
              builder: (context, value, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: value,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: SafeArea(
                child: ValueListenableBuilder<Widget>(
                  valueListenable: body,
                  builder: (_, value, _) => value,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await precacheImage(
          const AssetImage(MomCozyAssets.agentAvatar),
          tester.element(find.byType(AgentHubPage)),
        );
        await tester.pumpAndSettle();
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pump();
        }
        expect(tester.binding.transientCallbackCount, 0);
        final first = await _capture(
          binding,
          'native-agent-reduced-thinking-${scale.toInt()}x',
        );
        await tester.pump(const Duration(milliseconds: 500));
        final later = await _capture(
          binding,
          'native-agent-reduced-still-${scale.toInt()}x',
        );
        expect(
          listEquals(first, later),
          isTrue,
          reason: 'Decorative frames must remain unchanged',
        );
        body.value = const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AgentRunStatusLine(title: '正在整理今天的记录，稍后会显示完整回复'),
              SizedBox(height: 16),
              AgentThinkingNote(title: '我想一下，正在核对这些记录之间的变化'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _capture(
          binding,
          'native-agent-reduced-status-${scale.toInt()}x',
        );
        expect(tester.binding.transientCallbackCount, 0);
        reduced.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        reduced.value = true;
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        body.dispose();
        reduced.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<List<int>> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final directory = await getApplicationDocumentsDirectory();
  await File('${directory.path}/$name.png').writeAsBytes(bytes);
  return bytes;
}
