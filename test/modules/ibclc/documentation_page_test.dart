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
  plan['title'] = '接下来，一起记录和观察';
  plan['summary'] = '先从今天的小记录开始。把我们共同确认的变化记下来，下次跟进时一起回顾。';
  plan['goals'] = ['记录真实感受', '共同回顾这段时间的变化'];
  final task = (plan['tasks'] as List).first as Map;
  task['title'] = '记下今天的一次观察';
  task['description'] = '记录今天与你的目标相关的一次观察，下次跟进时一起讨论。';
  task['due_label'] = '今天';
}

void main() {
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
          'subjective': '用户描述了本次希望讨论的变化。',
          'objective': '记录本次共同确认的观察。',
          'assessment': '依据本次咨询信息形成的专业评估。',
          'plan': '在下次跟进时回顾记录与变化。',
        };
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
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
          theme: momCozyTheme(),
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
      await tester.tap(find.text('签署记录'));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      await tester.tap(find.text('确认签署'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((value) => value.readOnly),
        isTrue,
      );
      await tester.tap(find.text('创建修订'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '补充本次观察',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('创建修订'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.calls.last.body['reason'], '补充本次观察');
      expect(find.text('修订理由：补充本次观察'), findsOneWidget);
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
        find.text('查看怎么做'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看怎么做'));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      await tester.ensureVisible(find.text('已完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已完成'));
      await tester.pumpAndSettle();
      expect(repository.calls.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
