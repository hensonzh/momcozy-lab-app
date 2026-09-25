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
      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('No clear mood statements yet.'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/product_baseline/ibclc-report-${width.toInt()}.png',
        ),
      );
      await tester.ensureVisible(find.text('Clinical review').last);
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
      await tester.tap(find.text('Day 1 · Needs review'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('AI summary'));
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
      await tester.ensureVisible(find.text('Suggest changes'));
      await tester.tap(find.text('Suggest changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter at least 5 characters of specific feedback.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '请进一步核对亲喂表现和宝宝实际摄入量。');
      await tester.tap(find.text('Submit feedback'));
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
      await tester.ensureVisible(find.byTooltip('Refresh report'));
      await tester.tap(find.byTooltip('Refresh report'));
      await tester.pumpAndSettle();
      expect(find.text('请进一步核对亲喂表现和宝宝实际摄入量。'), findsOneWidget);
      harness.reportsDenied = true;
      await tester.tap(find.byTooltip('Refresh report'));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for AI consent'), findsOneWidget);
      expect(find.text('请进一步核对亲喂表现和宝宝实际摄入量。'), findsNothing);
      expect(find.text('AI summary'), findsNothing);
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
      await tester.ensureVisible(find.text('Suggest changes'));
      await tester.tap(find.text('Suggest changes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
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
      expect(find.text('AI summary'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
