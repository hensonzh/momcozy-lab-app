import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/ibclc/documentation/application/documentation_controller.dart';
import 'package:momcozy_flutter_app/modules/ibclc/documentation/presentation/documentation_page.dart';
import 'package:momcozy_flutter_app/modules/services/application/summary_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/consultation_summary_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'documentation_test_support.dart';

void localizePlan(Map plan) {
  plan['title'] = 'Your next steps, together';
  plan['summary'] =
      'Start with a small note today. We can review the changes we discussed at your next follow-up.';
  plan['goals'] = ['Record how you feel', 'Review changes together'];
  final task = (plan['tasks'] as List).first as Map;
  task['title'] = 'Note one observation today';
  task['description'] =
      'Record one observation related to your goal and discuss it at your next follow-up.';
  task['category'] = 'Observation';
  task['due_label'] = 'Today';
}

void main() {
  testWidgets('legacy plan shows review guidance at 320px and 2x text', (
    tester,
  ) async {
    await loadMomCozyTestFonts();
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = TestDocumentationRepository()
      ..json = documentationFixture('documentation_published');
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(isWorkbench: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DocumentationPage(
          createController: () => DocumentationController(
            repository: repository,
            appointmentId: 'appointment',
          ),
          initialTab: DocumentationTab.plan,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hint = find.textContaining('Review the title, summary, goals');
    await tester.ensureVisible(hint);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Publish new version'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [1024.0, 1280.0]) {
    for (final tab in DocumentationTab.values) {
      testWidgets('professional ${tab.name} editor at $width', (tester) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = TestDocumentationRepository();
        localizePlan((repository.json['plan'] as Map)['content'] as Map);
        (repository.json['note'] as Map)['content'] = {
          'subjective':
              'The client described changes they would like to discuss.',
          'objective': 'Record the observations confirmed together.',
          'assessment': 'Clinical assessment based on this consultation.',
          'plan': 'Review notes and changes at the next follow-up.',
        };
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(isWorkbench: true),
            home: DocumentationPage(
              createController: () => DocumentationController(
                repository: repository,
                appointmentId: 'appointment',
              ),
              initialTab: tab,
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(DocumentationPage),
          matchesGoldenFile(
            '../../goldens/product_baseline/ibclc-${tab.name}-${width.toInt()}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('published consultation summary at $width', (tester) async {
      await loadMomCozyTestFonts();
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = TestPatientPlanRepository();
      localizePlan(repository.json['publication'] as Map);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          home: ConsultationSummaryPage(
            createController: () => CareSummaryController(
              repository: repository,
              appointmentId: 'appointment',
            ),
            onBack: () {},
            onProgress: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ConsultationSummaryPage),
        matchesGoldenFile(
          '../../goldens/product_baseline/care-summary-${width.toInt()}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'signed note is read-only and amendment requires a reason in a new dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = TestDocumentationRepository();
      repository.onCall = (action, body) async {
        final note = repository.json['note'] as Map;
        if (action == 'sign') {
          note['status'] = 'signed';
          note['version'] = 2;
          note['signed_at'] = '2026-09-09T12:05:00Z';
        } else if (action == 'amend') {
          note['status'] = 'draft';
          note['version'] = 1;
          note['revision'] = 2;
          note['signed_at'] = null;
          note['amendment_reason'] = body['reason'];
        }
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(isWorkbench: true),
          home: DocumentationPage(
            createController: () => DocumentationController(
              repository: repository,
              appointmentId: 'appointment',
            ),
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign note').first);
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Sign note'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((value) => value.readOnly),
        isTrue,
      );
      await tester.tap(find.text('Create revision'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Additional observations',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Create revision'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.calls.last.body['reason'], 'Additional observations');
      expect(
        find.text('Reason for revision: Additional observations'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'summary supports large text and records feedback only after an explicit choice',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = TestPatientPlanRepository();
      localizePlan(repository.json['publication'] as Map);
      repository.onUpdate = () async {
        final task =
            ((repository.json['publication'] as Map)['tasks'] as List).first
                as Map;
        task['status'] = 'completed';
        task['progress_version'] = 2;
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ConsultationSummaryPage(
            createController: () => CareSummaryController(
              repository: repository,
              appointmentId: 'appointment',
            ),
            onBack: () {},
            onProgress: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('See how'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('See how'));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      await tester.ensureVisible(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(repository.calls.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
