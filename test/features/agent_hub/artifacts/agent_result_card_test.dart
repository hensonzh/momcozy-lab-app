import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';

void main() {
  testWidgets('unavailable card action is disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgentArtifactPanel(
            cards: [
              AgentArtifactCardView(
                id: 'result',
                title: 'Your summary',
                actions: [
                  AgentArtifactActionView(
                    label: 'View details',
                    icon: Icons.arrow_forward,
                    kind: 'route',
                    value: '/services',
                    routePath: '/services',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final button = tester.widget<ButtonStyleButton>(
      find
          .ancestor(
            of: find.text('View details'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first,
    );
    expect(button.onPressed, isNull);
  });
}
