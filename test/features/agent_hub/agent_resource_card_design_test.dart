import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('resource card reading and original actions $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <AgentArtifactActionView>[];
        const links = {
          '阅读资料 PDF': '/v1/assets/fixture-document?kind=pdf',
          '播放指导视频': '/v1/assets/fixture-video?kind=video',
          '查看示意图片': '/v1/assets/fixture-image?kind=image',
          '继续查看支持方案': '/services/renew',
        };
        final event = AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'resource-entry',
          'payload': {
            'artifact_type': 'rich_text',
            'title': '资料与支持',
            'content': '从下方入口继续查看。',
            'actions': [
              for (final e in links.entries)
                {
                  'kind': e.value.contains('kind=')
                      ? e.value.split('kind=').last
                      : 'open_url',
                  'label': e.key,
                  'value': e.value,
                },
            ],
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: AgentHubPage(
                state: AgentStreamRunState(
                  phase: AgentStreamRunPhase.finished,
                  textContent: '你可以从资料卡片继续查看。',
                  events: [event],
                  artifactEvents: {'resource-entry': event},
                ),
                onArtifactAction: actions.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(MomCozyAssets.agentAvatar),
            tester.element(find.byType(AgentHubPage)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('资料与支持'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/agent-resource-top-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );
        for (final e in links.entries) {
          final label = find.text(e.key);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final button = find
              .ancestor(
                of: label,
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first;
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(actions.last.label, e.key);
          expect(actions.last.value, e.value);
        }
        expect(actions, hasLength(4));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/agent-resource-actions-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
