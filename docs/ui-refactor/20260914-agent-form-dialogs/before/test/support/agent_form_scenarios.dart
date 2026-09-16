import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentForm(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final attempts = <Completer<bool>>[];
  final submitted = <AgentArtifactActionView>[];
  final session = AgentArtifactFormPresentationSession();
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
          padding: const EdgeInsets.fromLTRB(52, 16, 16, 24),
          child: AgentArtifactFormEntry(
            card: formScenarioCard,
            presentationSession: session,
            onSubmit: (action) {
              submitted.add(action);
              final attempt = Completer<bool>();
              attempts.add(attempt);
              return attempt.future;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await capture('entry');
  final entry = find.byKey(const ValueKey('agent-artifact-form-entry-intake'));
  final submit = find.byKey(
    const ValueKey('agent-artifact-form-submit-intake'),
  );
  final dialog = find.byType(AgentArtifactFormDialog);
  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder field(String id) => find.descendant(
    of: find.byKey(ValueKey('agent-artifact-form-field-intake-$id')),
    matching: find.byType(TextFormField),
  );
  await tap(entry);
  await capture('top');
  await tap(submit);
  expect(attempts, isEmpty);
  expect(find.text('请补充：Your notes'), findsOneWidget);
  await capture('validation');
  await tester.ensureVisible(field('notes'));
  await tester.enterText(
    field('notes'),
    'A little help with feeding\nKeep my draft.',
  );
  await tester.pumpAndSettle();
  await tap(find.text('Morning support'));
  final select = find.byType(DropdownButtonFormField<String>);
  await tap(select);
  await tap(
    find
        .text('A longer follow-up option that can wrap on a narrow screen')
        .last,
  );
  await tap(field('date'));
  final ok = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  ).okButtonLabel;
  await tap(find.text(ok));
  await tap(find.text('其它'));
  final other = find.byKey(
    const ValueKey('agent-artifact-form-other-intake-concerns'),
  );
  await tester.ensureVisible(other);
  await tester.enterText(other, 'Comfort during feeding');
  await tester.pumpAndSettle();
  await capture('choices');
  final cancel = find.byKey(
    const ValueKey('agent-artifact-form-cancel-intake'),
  );
  await tap(cancel);
  expect(dialog, findsNothing);
  await tap(entry);
  expect(
    tester.widget<TextFormField>(field('notes')).initialValue,
    contains('Keep my draft.'),
  );
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  expect(attempts, hasLength(1));
  expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  await tester.tapAt(const Offset(2, 2));
  await tester.pump();
  await tester.binding.handlePopRoute();
  await tester.pump();
  expect(dialog, findsOneWidget);
  await capture('pending');
  attempts.single.completeError(StateError('offline'));
  await tester.pumpAndSettle();
  expect(find.text('提交失败，请重试'), findsOneWidget);
  await capture('failed');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pump();
  expect(attempts, hasLength(2));
  expect(submitted[0].value, submitted[1].value);
  final values = (submitted.last.routeExtra! as Map)['values'] as Map;
  expect(values['date'], '2026-09-12');
  expect(values['time'], 'Morning support');
  expect(
    values['followup'],
    'A longer follow-up option that can wrap on a narrow screen',
  );
  expect(values['concerns'], contains('其它：Comfort during feeding'));
  attempts.last.complete(true);
  await tester.pumpAndSettle();
  expect(dialog, findsNothing);
  expect(find.text('已提交，可点击查看'), findsOneWidget);
  await capture('submitted-entry');
  await tap(entry);
  await tester.ensureVisible(field('notes'));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<EditableText>(
          find.descendant(
            of: field('notes'),
            matching: find.byType(EditableText),
          ),
        )
        .readOnly,
    isTrue,
  );
  expect(submit, findsNothing);
  await capture('submitted-detail');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(dialog, findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

const formScenarioCard = AgentArtifactCardView(
  id: 'intake',
  title: 'Your feeding support',
  description: 'Share what would make today a little easier.',
  presentationKind: AgentArtifactPresentationKind.form,
  formId: 'support_intake',
  formSubmitLabel: 'Send your information',
  formFields: [
    AgentArtifactFormFieldView(
      id: 'notes',
      label: 'About you｜Your notes',
      type: 'textarea',
      required: true,
    ),
    AgentArtifactFormFieldView(
      id: 'time',
      label: 'Preferences｜Best time',
      type: 'radio',
      options: ['Morning support', 'Evening support'],
    ),
    AgentArtifactFormFieldView(
      id: 'followup',
      label: 'Preferences｜Follow-up',
      type: 'select',
      options: [
        'Brief check-in',
        'A longer follow-up option that can wrap on a narrow screen',
      ],
    ),
    AgentArtifactFormFieldView(
      id: 'date',
      label: 'Preferences｜Start date',
      type: 'date',
      defaultValue: '2026-09-12',
    ),
    AgentArtifactFormFieldView(
      id: 'concerns',
      label: 'Your questions｜What matters to you',
      type: 'multi_select',
      options: ['Comfort', '其它'],
      allowOtherInput: true,
    ),
  ],
);
