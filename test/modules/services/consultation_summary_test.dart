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
  plan['title'] = '接下来，一起记录和观察';
  plan['summary'] = '先从今天的小记录开始。把我们共同确认的变化记下来，下次跟进时一起回顾。';
  plan['goals'] = ['记录真实感受', '共同回顾这段时间的变化'];
  final tasks = plan['tasks'] as List;
  final task = tasks.first as Map;
  task['title'] = '记下今天的一次观察';
  task['description'] = '记录今天与你的目标相关的一次观察，下次跟进时一起讨论。';
  tasks.add({
    ...task,
    'source_key': 'review',
    'title': '一起回顾记录',
    'description': '整理这几天的变化，在下次跟进时讨论。',
    'due_label': '接下来几天',
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
  final finder = label == '关闭'
      ? find.byTooltip('关闭行动详情').last
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
        await click(tester, '查看怎么做');
        expect(repository.calls, isEmpty);
        await shot(tester, 'task', width, scale);
        await click(tester, '关闭');
        await click(tester, '一起回顾记录');
        expect(repository.calls, isEmpty);
        await click(tester, '关闭');
        await click(tester, '查看完整行动计划 →');
        expect(plans, 1);
        await click(tester, '咨询与服务信息');
        await tester.ensureVisible(find.text('查看服务进度'));
        await tester.pumpAndSettle();
        await shot(tester, 'metadata', width, scale);
        await click(tester, '查看服务进度');
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
                  ? '总结整理中'
                  : state == 'empty'
                  ? '还没有可查看的总结'
                  : '暂时无法读取总结',
            ),
            findsOneWidget,
          );
          await shot(tester, state, width, scale);
          if (state == 'offline') {
            empty.offline = false;
            await click(tester, '重新加载');
            expect(find.text('总结整理中'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
  testWidgets(
    'task uncertainty retries original version and locks competing updates',
    (tester) async {
      final repository = Repository();
      localize(repository);
      final pending = Completer<void>();
      repository.onUpdate = () => pending.future;
      await mount(tester, repository);
      await click(tester, '查看怎么做');
      await tester.tap(find.text('已完成'));
      await tester.pump();
      expect(repository.calls, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('我的进度'), findsOneWidget);
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await tester.pumpAndSettle();
      await shot(tester, 'uncertain', 390, 1);
      await click(tester, '暂时跳过');
      expect(repository.calls, hasLength(1));
      repository.onUpdate = () async {
        final task =
            ((repository.json['publication'] as Map)['tasks'] as List).first
                as Map;
        task['status'] = 'completed';
        task['progress_version'] = 2;
      };
      await click(tester, '重试');
      expect(repository.calls, hasLength(2));
      expect(repository.calls.first, repository.calls.last);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '已完成'))
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
    expect(find.text('正在读取本次咨询总结'), findsOneWidget);
    await shot(tester, 'loading', 390, 1);
    repository.pending!.complete();
    repository.pending = null;
    await tester.pumpAndSettle();
    expect(find.text('总结整理中'), findsOneWidget);
    repository.json['publication'] = plan;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('查看怎么做'), findsOneWidget);
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
    await click(tester, '查看怎么做');
    await click(tester, '已完成');
    expect(repository.calls, hasLength(1));
    await click(tester, '进行中');
    expect(repository.calls, hasLength(1));
    final plan = repository.json['publication'] as Map;
    plan['id'] = 'replacement-publication';
    plan['revision'] = 2;
    final task = (plan['tasks'] as List).first as Map;
    task['progress_version'] = 4;
    repository.onUpdate = null;
    await click(tester, '重新载入');
    await click(tester, '进行中');
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
    await click(tester, '查看怎么做');
    expect(find.text('安排日期：2026-09-15'), findsOneWidget);
    await tester.ensureVisible(find.text('已完成'));
    await tester.pumpAndSettle();
    await shot(tester, 'short-progress', 320, 2);
    final pending = Completer<void>();
    repository.onUpdate = () => pending.future;
    await tester.tap(find.text('已完成'));
    await tester.pump();
    expect(repository.calls, hasLength(1));
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == '关闭行动详情',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('我的进度'), findsOneWidget);
    await shot(tester, 'short-updating', 320, 2);
    pending.completeError(const ProductFailure(ProductFailureKind.offline));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('重试').last);
    await tester.pumpAndSettle();
    await shot(tester, 'short-uncertain', 320, 2);
    await click(tester, '进行中');
    expect(repository.calls, hasLength(1));
    repository.onUpdate = () async {
      task['status'] = repository.calls.last.status.name;
      task['progress_version'] = 2;
    };
    await click(tester, '重试');
    expect(repository.calls, hasLength(2));
    expect(repository.calls.first, repository.calls.last);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '已完成'))
          .selected,
      isTrue,
    );
    await click(tester, '暂时跳过');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '暂时跳过'))
          .selected,
      isTrue,
    );
    await click(tester, '关闭');
    expect(find.text('我的进度'), findsNothing);
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
      await click(tester, '查看怎么做');
      await click(tester, '已完成');
      await tester.ensureVisible(find.text('重新载入').last);
      await tester.pumpAndSettle();
      await shot(tester, 'superseded', 320, 2);
      final plan = repository.json['publication'] as Map;
      plan['tasks'] = <Object?>[];
      await click(tester, '重新载入');
      expect(find.text('方案已更新'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await shot(tester, 'removed-action', 320, 2);
      await click(tester, '关闭');
      expect(find.text('查看怎么做'), findsNothing);
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
      expect(find.text('接下来，一起记录和观察'), findsOneWidget);
      expect(find.text('网络未连接，请连接后重试'), findsOneWidget);
      await shot(tester, 'refresh-error', 390, 1);
      repository.offline = false;
      await click(tester, '重试');
      expect(find.text('网络未连接，请连接后重试'), findsNothing);
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
      expect(find.text('查看怎么做'), findsNothing);
      expect(find.text('接下来几天'), findsNothing);
      expect(find.text('查看完整行动计划 →'), findsNothing);
      await click(tester, '咨询与服务信息');
      await click(tester, '查看服务进度');
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
      expect(find.text('本次咨询未完成'), findsOneWidget);
      expect(find.text('总结整理中'), findsNothing);
      await shot(tester, 'failed', 320, 2);
      await click(tester, '查看服务进度');
      expect(progress, 2);
      expect(repository.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
