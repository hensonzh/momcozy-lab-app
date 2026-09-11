import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/ibclc/workbench_app.dart';
import '../../support/momcozy_test_fonts.dart';
import 'workbench_test_support.dart';

String reportRoute() =>
    '/ibclc/followups/${(workbenchFixture('report_client')['client'] as Map)['patient_ref']}';
void main() {
  for (final width in [1024.0, 1280.0]) {
    testWidgets('report detail at $width', (tester) async {
      await loadMomCozyTestFonts();
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: reportRoute(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/momcozy_logo.png'),
          tester.element(find.byType(MaterialApp)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('智能体整理'), findsOneWidget);
      expect(find.text('暂无明确的情绪自述。'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/product_baseline/ibclc-report-${width.toInt()}.png',
        ),
      );
      await tester.ensureVisible(find.text('专业复核'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/product_baseline/ibclc-report-review-${width.toInt()}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'report day selection updates the deep link and reloads its scope',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: reportRoute(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day 1 · 待复核'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('智能体整理'));
      final uri = GoRouter.of(context).routeInformationProvider.value.uri;
      expect(uri.queryParameters['date'], harness.reportJson['report_date']);
      expect(
        uri.queryParameters['episode'],
        (harness.reportJson['report'] as Map)['episode_id'],
      );
      expect(
        harness.requests.where(
          (r) =>
              r.url.path.endsWith('/reports') &&
              r.url.queryParameters['report_date'] ==
                  uri.queryParameters['date'],
        ),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'feedback validates, persists and remains linked to the report on reload',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: reportRoute(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('反馈修改'));
      await tester.tap(find.text('反馈修改'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交反馈'));
      await tester.pumpAndSettle();
      expect(find.text('请填写至少 5 个字的具体意见。'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '请进一步核对亲喂表现和宝宝实际摄入量。');
      await tester.tap(find.text('提交反馈'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('请进一步核对亲喂表现和宝宝实际摄入量。'), findsOneWidget);
      expect(
        harness.requests.where(
          (value) =>
              value.method == 'POST' && value.url.path.endsWith('/reviews'),
        ),
        hasLength(1),
      );
      await tester.ensureVisible(find.byTooltip('刷新报告'));
      await tester.tap(find.byTooltip('刷新报告'));
      await tester.pumpAndSettle();
      expect(find.text('请进一步核对亲喂表现和宝宝实际摄入量。'), findsOneWidget);
      harness.reportsDenied = true;
      await tester.tap(find.byTooltip('刷新报告'));
      await tester.pumpAndSettle();
      expect(find.text('等待 AI 授权'), findsOneWidget);
      expect(find.text('请进一步核对亲喂表现和宝宝实际摄入量。'), findsNothing);
      expect(find.text('智能体整理'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'report and feedback dialog support narrow width and double text scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: reportRoute(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('反馈修改'));
      await tester.tap(find.text('反馈修改'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('取消'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'followup filter is restored from URL and the queue links to the client report',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: '/ibclc/followups?q=林晓&status=pending',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('林晓'), findsWidgets);
      expect(
        harness.requests.any(
          (value) =>
              value.url.path == '/v1/ibclc/followups' &&
              value.url.queryParameters['status'] == 'pending',
        ),
        isTrue,
      );
      await tester.tap(find.text('林晓').last);
      await tester.pumpAndSettle();
      expect(find.text('智能体整理'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
