import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('support ticket draft retry and read-only $width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final attempts = <Completer<bool>>[];
      final actions = <AgentArtifactActionView>[];
      final session = AgentArtifactFormPresentationSession()
        ..registerLiveFormIds(['ticket']);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Cozymate')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AgentArtifactFormEntry(
                autoPresent: true,
                presentationSession: session,
                card: const AgentArtifactCardView(
                  id: 'ticket',
                  title: '售后支持信息',
                  formId: 'support_ticket',
                  formSubmitLabel: '提交信息',
                  presentationKind: AgentArtifactPresentationKind.form,
                  formFields: [
                    AgentArtifactFormFieldView(
                      id: 'issue_summary',
                      label: '问题说明',
                      type: 'textarea',
                      required: true,
                    ),
                    AgentArtifactFormFieldView(
                      id: 'issue_type',
                      label: '问题类型',
                      type: 'select',
                      options: ['设备故障', '使用帮助'],
                      defaultValue: '使用帮助',
                    ),
                    AgentArtifactFormFieldView(
                      id: 'user_contact',
                      label: '联系邮箱',
                      type: 'text',
                    ),
                  ],
                ),
                onSubmit: (action) {
                  actions.add(action);
                  final attempt = Completer<bool>();
                  attempts.add(attempt);
                  return attempt.future;
                },
              ),
            ),
          ),
        ),
      );
      Finder key(String prefix) =>
          find.byKey(ValueKey('agent-artifact-form-$prefix-ticket'));
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(String state) async => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-ticket-form-$state-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      expect(find.text('正在准备表单…'), findsOneWidget);
      await tester.pump(agentArtifactFormAutoOpenDelay);
      await tester.pumpAndSettle();
      expect(key('dialog'), findsOneWidget);
      await capture('top');
      final notes = find.descendant(
        of: find.byKey(
          const ValueKey('agent-artifact-form-field-ticket-issue_summary'),
        ),
        matching: find.byType(TextFormField),
      );
      final email = find.descendant(
        of: find.byKey(
          const ValueKey('agent-artifact-form-field-ticket-user_contact'),
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(notes);
      await tester.enterText(notes, '测试设备的使用说明问题。');
      await tester.ensureVisible(email);
      await tester.enterText(email, 'inventory@example.invalid');
      await tap(key('cancel'));
      await tap(key('entry'));
      expect(tester.widget<TextFormField>(notes).initialValue, '测试设备的使用说明问题。');
      await tester.ensureVisible(key('submit'));
      await tester.tap(key('submit'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(attempts, hasLength(1));
      expect(tester.widget<FilledButton>(key('submit')).onPressed, isNull);
      await capture('pending');
      attempts.single.complete(false);
      await tester.pumpAndSettle();
      final error = find.text('提交失败，请重试');
      expect(error, findsOneWidget);
      expect(
        find.ancestor(
          of: error,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      await capture('failed');
      await tester.ensureVisible(key('submit'));
      await tester.tap(key('submit'));
      await tester.pump();
      expect(attempts, hasLength(2));
      expect(actions.last.value, actions.first.value);
      attempts.last.complete(true);
      await tester.pumpAndSettle();
      expect(key('dialog'), findsNothing);
      await tap(key('entry'));
      expect(key('submit'), findsNothing);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: notes, matching: find.byType(EditableText)),
            )
            .readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: email, matching: find.byType(EditableText)),
            )
            .readOnly,
        isTrue,
      );
      await tester.ensureVisible(email);
      await tester.pumpAndSettle();
      await capture('readonly');
      await tap(key('cancel'));
      await tester.pump(const Duration(seconds: 2));
      expect(key('dialog'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
