import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/documentation.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/application/summary_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/consultation_summary_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import '../ibclc/documentation_test_support.dart';

class Repository extends TestPatientPlanRepository {
  bool offline = false;
  Completer<void>? pending;
  @override
  Future<PatientCareSummary> summary(String id) async {
    if (pending != null) await pending!.future;
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    return super.summary(id);
  }
}

void localize(Repository repository) {
  final plan = repository.json['publication'] as Map;
  plan['title'] = 'Your next steps, together';
  plan['summary'] =
      'Start with a small note today. We can review the changes we discussed at your next follow-up.';
  plan['goals'] = ['Record how you feel', 'Review changes together'];
  final tasks = plan['tasks'] as List;
  final task = tasks.first as Map;
  task['title'] = 'Note one observation today';
  task['description'] =
      'Record one observation related to your goal and discuss it at your next follow-up.';
  tasks.add({
    ...task,
    'source_key': 'review',
    'title': 'Review your notes together',
    'description':
        'Gather the changes you notice over the next few days for your follow-up.',
    'due_label': 'Over the next few days',
  });
}

Future<void> mount(
  WidgetTester tester,
  Repository repository, {
  double width = 390,
  double scale = 1,
  double height = 844,
  bool includePlan = true,
  ValueChanged<CareSummaryController>? onController,
  Future<void> Function()? onPlan,
  VoidCallback? onProgress,
  bool settle = true,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
      home: ConsultationSummaryPage(
        createController: () {
          final controller = CareSummaryController(
            repository: repository,
            appointmentId: 'appointment',
          );
          onController?.call(controller);
          return controller;
        },
        onBack: () {},
        onProgress: (_) => onProgress?.call(),
        onPlan: includePlan ? onPlan ?? () async {} : null,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String label) async {
  final finder = label == 'Close'
      ? find.byTooltip('Close action details').last
      : find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/summary-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}${tester.view.physicalSize.height == 568 ? '-short' : ''}.png',
      ),
    );
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('summary content task and destinations $width / $scale', (
        tester,
      ) async {
        final repository = Repository();
        localize(repository);
        var plans = 0, progress = 0;
        await mount(
          tester,
          repository,
          width: width,
          scale: scale,
          onPlan: () async {
            plans++;
          },
          onProgress: () {
            progress++;
          },
        );
        await shot(tester, 'published', width, scale);
        await click(tester, 'See how');
        expect(repository.calls, isEmpty);
        await shot(tester, 'task', width, scale);
        await click(tester, 'Close');
        await click(tester, 'Review your notes together');
        expect(repository.calls, isEmpty);
        await click(tester, 'Close');
        await click(tester, 'View full care plan →');
        expect(plans, 1);
        await click(tester, 'Consultation & service details');
        await tester.ensureVisible(find.text('View service progress'));
        await tester.pumpAndSettle();
        await shot(tester, 'metadata', width, scale);
        await click(tester, 'View service progress');
        expect(progress, 1);
        expect(repository.calls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        for (final state in ['pending', 'empty', 'offline']) {
          final empty = Repository();
          empty.json['publication'] = null;
          if (state == 'empty') {
            (empty.json['appointment'] as Map)['status'] = 'confirmed';
          }
          if (state == 'offline') empty.offline = true;
          await mount(tester, empty, width: width, scale: scale);
          expect(
            find.text(
              state == 'pending'
                  ? 'Summary in progress'
                  : state == 'empty'
                  ? 'No summary available yet'
                  : 'Could not load summary',
            ),
            findsOneWidget,
          );
          await shot(tester, state, width, scale);
          if (state == 'offline') {
            empty.offline = false;
            await click(tester, 'Reload');
            expect(find.text('Summary in progress'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
  testWidgets(
    'published legacy consultant identity stays English at 320px / 2x',
    (tester) async {
      final repository = Repository();
      localize(repository);
      final publication = repository.json['publication'] as Map;
      publication['publisher_name'] = 'CozyMate 王老师';
      final appointment = repository.json['appointment'] as Map;
      appointment['provider_name'] = 'CozyMate 王老师';
      CareSummaryController? loaded;
      await mount(
        tester,
        repository,
        width: 320,
        scale: 2,
        onController: (value) => loaded = value,
      );
      final publicName = loaded!.data!.appointment.publicProviderName;
      expect(publicName, startsWith('IBCLC consultant · '));
      expect(find.text(publicName), findsOneWidget);
      expect(find.textContaining('王老师'), findsNothing);
      expect(find.textContaining('CozyMate'), findsNothing);
      await tester.ensureVisible(find.text('Consultation & service details'));
      await tester.pumpAndSettle();
      expect(find.textContaining(publicName), findsWidgets);
      expect(publication['publisher_name'], 'CozyMate 王老师');
      expect(loaded!.data!.publication!.publisherName, 'CozyMate 王老师');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'task uncertainty retries original version and locks competing updates',
    (tester) async {
      final repository = Repository();
      localize(repository);
      final pending = Completer<void>();
      repository.onUpdate = () => pending.future;
      await mount(tester, repository);
      await click(tester, 'See how');
      await tester.tap(find.text('Completed'));
      await tester.pump();
      expect(repository.calls, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('My progress'), findsOneWidget);
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await tester.pumpAndSettle();
      await shot(tester, 'uncertain', 390, 1);
      await click(tester, 'Skip for now');
      expect(repository.calls, hasLength(1));
      repository.onUpdate = () async {
        final task =
            ((repository.json['publication'] as Map)['tasks'] as List).first
                as Map;
        task['status'] = 'completed';
        task['progress_version'] = 2;
      };
      await click(tester, 'Try again');
      expect(repository.calls, hasLength(2));
      expect(repository.calls.first, repository.calls.last);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('loading finishes into pending and refreshed publication', (
    tester,
  ) async {
    final repository = Repository()..pending = Completer<void>();
    final plan = repository.json['publication'];
    repository.json['publication'] = null;
    await mount(tester, repository, settle: false);
    await tester.pump();
    expect(find.text('Loading consultation summary'), findsOneWidget);
    await shot(tester, 'loading', 390, 1);
    repository.pending!.complete();
    repository.pending = null;
    await tester.pumpAndSettle();
    expect(find.text('Summary in progress'), findsOneWidget);
    repository.json['publication'] = plan;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('See how'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('superseded plan reloads before accepting another task update', (
    tester,
  ) async {
    final repository = Repository();
    localize(repository);
    repository.onUpdate = () async {
      throw const ProductFailure(
        ProductFailureKind.conflict,
        code: 'plan_superseded',
      );
    };
    await mount(tester, repository);
    await click(tester, 'See how');
    await click(tester, 'Completed');
    expect(repository.calls, hasLength(1));
    await click(tester, 'In progress');
    expect(repository.calls, hasLength(1));
    final plan = repository.json['publication'] as Map;
    plan['id'] = 'replacement-publication';
    plan['revision'] = 2;
    final task = (plan['tasks'] as List).first as Map;
    task['progress_version'] = 4;
    repository.onUpdate = null;
    await click(tester, 'Reload');
    await click(tester, 'In progress');
    expect(repository.calls.last.publication, 'replacement-publication');
    expect(repository.calls.last.version, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('short large task keeps pending updates locked and retryable', (
    tester,
  ) async {
    final repository = Repository();
    localize(repository);
    final task =
        ((repository.json['publication'] as Map)['tasks'] as List).first as Map;
    task['scheduled_date'] = '2026-09-15';
    await mount(tester, repository, width: 320, height: 568, scale: 2);
    await click(tester, 'See how');
    expect(find.text('Scheduled date: 2026-09-15'), findsOneWidget);
    await tester.ensureVisible(find.text('Completed'));
    await tester.pumpAndSettle();
    await shot(tester, 'short-progress', 320, 2);
    final pending = Completer<void>();
    repository.onUpdate = () => pending.future;
    await tester.tap(find.text('Completed'));
    await tester.pump();
    expect(repository.calls, hasLength(1));
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Close action details',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('My progress'), findsOneWidget);
    await shot(tester, 'short-updating', 320, 2);
    pending.completeError(const ProductFailure(ProductFailureKind.offline));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try again').last);
    await tester.pumpAndSettle();
    await shot(tester, 'short-uncertain', 320, 2);
    await click(tester, 'In progress');
    expect(repository.calls, hasLength(1));
    repository.onUpdate = () async {
      task['status'] = repository.calls.last.status.name;
      task['progress_version'] = 2;
    };
    await click(tester, 'Try again');
    expect(repository.calls, hasLength(2));
    expect(repository.calls.first, repository.calls.last);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
          .selected,
      isTrue,
    );
    await click(tester, 'Skip for now');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Skip for now'))
          .selected,
      isTrue,
    );
    await click(tester, 'Close');
    expect(find.text('My progress'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'superseded action removed by reload remains safely closable at large text',
    (tester) async {
      final repository = Repository();
      localize(repository);
      repository.onUpdate = () async {
        throw const ProductFailure(
          ProductFailureKind.conflict,
          code: 'plan_superseded',
        );
      };
      await mount(tester, repository, width: 320, scale: 2);
      await click(tester, 'See how');
      await click(tester, 'Completed');
      await tester.ensureVisible(find.text('Reload').last);
      await tester.pumpAndSettle();
      await shot(tester, 'superseded', 320, 2);
      final plan = repository.json['publication'] as Map;
      plan['tasks'] = <Object?>[];
      await click(tester, 'Reload');
      expect(find.text('Plan updated'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await shot(tester, 'removed-action', 320, 2);
      await click(tester, 'Close');
      expect(find.text('See how'), findsNothing);
      expect(repository.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refresh failure retains publication and reloads without a task mutation',
    (tester) async {
      final repository = Repository();
      localize(repository);
      late CareSummaryController controller;
      await mount(
        tester,
        repository,
        onController: (value) => controller = value,
      );
      repository.offline = true;
      await controller.load();
      await tester.pumpAndSettle();
      expect(find.text('Your next steps, together'), findsOneWidget);
      expect(
        find.text('You\'re offline. Connect and try again.'),
        findsOneWidget,
      );
      await shot(tester, 'refresh-error', 390, 1);
      repository.offline = false;
      await click(tester, 'Try again');
      expect(
        find.text('You\'re offline. Connect and try again.'),
        findsNothing,
      );
      expect(repository.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'empty action list and unsuccessful consultation keep appropriate destinations',
    (tester) async {
      final repository = Repository();
      localize(repository);
      (repository.json['publication'] as Map)['tasks'] = <Object?>[];
      var progress = 0;
      await mount(
        tester,
        repository,
        width: 320,
        height: 568,
        scale: 2,
        includePlan: false,
        onProgress: () => progress++,
      );
      expect(find.text('See how'), findsNothing);
      expect(find.text('Over the next few days'), findsNothing);
      expect(find.text('View full care plan →'), findsNothing);
      await click(tester, 'Consultation & service details');
      await click(tester, 'View service progress');
      expect(progress, 1);
      await shot(tester, 'no-actions-information', 320, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      repository.json['publication'] = null;
      (repository.json['consultation'] as Map)['status'] = 'failed';
      await mount(
        tester,
        repository,
        width: 320,
        height: 568,
        scale: 2,
        onProgress: () => progress++,
      );
      expect(find.text('This consultation was not completed'), findsOneWidget);
      expect(find.text('Summary in progress'), findsNothing);
      await shot(tester, 'failed', 320, 2);
      await click(tester, 'View service progress');
      expect(progress, 2);
      expect(repository.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
