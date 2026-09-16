import 'dart:async';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form.dart';
import '../../support/agent_form_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('form state rejects duplicate and completed submissions', (
    tester,
  ) async {
    final key = GlobalKey<AgentArtifactFormState>();
    final pending = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentArtifactForm(
            key: key,
            card: const AgentArtifactCardView(
              id: 'single',
              title: 'Submit once',
              formFields: [],
            ),
            onSubmit: (_) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    final first = key.currentState!.submit();
    expect(await key.currentState!.submit(), isFalse);
    expect(calls, 1);
    pending.complete(true);
    expect(await first, isTrue);
    expect(await key.currentState!.submit(), isFalse);
    expect(calls, 1);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('form states $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyAgentForm(
          tester,
          scale: scale,
          capture: (state) async {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/agent-form-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          },
        );
      });
    }
  }

  testWidgets(
    'short screen keyboard leaves form content and actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: AgentArtifactFormEntry(
              card: const AgentArtifactCardView(
                id: 'short',
                title: 'Recovery support information',
                formSubmitLabel: 'Submit your information',
                presentationKind: AgentArtifactPresentationKind.form,
                formFields: [
                  AgentArtifactFormFieldView(
                    id: 'notes',
                    label: 'Your notes',
                    type: 'textarea',
                    required: true,
                  ),
                ],
              ),
              onSubmit: (_) async => false,
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-artifact-form-entry-short')),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'Keep these notes');
      final submit = find.byKey(
        const ValueKey('agent-artifact-form-submit-short'),
      );
      await tester.drag(
        find.byKey(const ValueKey('agent-artifact-form-scroll-short')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-form-short-keyboard.png',
        ),
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('提交失败，请重试'), findsOneWidget);
    },
  );
}
