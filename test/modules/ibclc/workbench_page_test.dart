import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/ibclc/workbench_app.dart';
import 'package:momcozy_flutter_app/modules/ibclc/users/presentation/clients_page.dart';
import '../../support/momcozy_test_fonts.dart';
import 'workbench_test_support.dart';

void main() {
  for (final width in [1024.0, 1280.0]) {
    for (final page in [
      'appointments',
      'clients',
      'calendar',
      'reminders',
      'followups',
    ]) {
      testWidgets('independent workbench $page at $width', (tester) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = WorkbenchHttpHarness();
        await tester.pumpWidget(
          MomCozyWorkbenchApp(
            runtime: harness.runtime,
            initialLocation: '/ibclc/$page',
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
        expect(find.textContaining('林晓'), findsWidgets);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/product_baseline/ibclc-$page-${width.toInt()}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'workbench navigation remains in the accessibility tree beside its nested route',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(1280, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = WorkbenchHttpHarness();
        await tester.pumpWidget(
          MomCozyWorkbenchApp(
            runtime: harness.runtime,
            initialLocation: '/ibclc/appointments',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel('我的客户'), findsOne);
        expect(
          find.semantics.byPredicate(
            (node) => node.getSemanticsData().tooltip == '工作账号',
          ),
          findsOne,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'work reminders persist read state and retain it after reloading',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: '/ibclc/reminders',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 条未读'), findsOneWidget);
      await tester.tap(find.text('标记已读').first);
      await tester.pumpAndSettle();
      expect(find.text('1 条未读'), findsOneWidget);
      expect(find.text('已读'), findsOneWidget);
      await tester.tap(find.byTooltip('刷新工作提醒'));
      await tester.pumpAndSettle();
      expect(find.text('1 条未读'), findsOneWidget);
      expect(
        harness.requests.where((request) => request.method == 'PUT'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'work reminders remain readable and operable on a narrow screen with large text',
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
          initialLocation: '/ibclc/reminders',
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('标记已读').first);
      await tester.tap(find.text('标记已读').first);
      await tester.pumpAndSettle();
      expect(find.text('已读'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'calendar month navigation is accessible with large text on a narrow screen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
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
            initialLocation: '/ibclc/calendar',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('下个月'));
        await tester.tap(find.byTooltip('下个月'));
        await tester.pumpAndSettle();
        expect(harness.requests.last.url.queryParameters['date'], '2026-10-10');
        expect(find.semantics.byLabel('2026年10月10日'), findsOne);
        expect(find.text('这一天没有预约'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'login protects a client deep link until both factors and the identity response succeed',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = WorkbenchHttpHarness(signedIn: false);
      final id = (workbenchFixture('client')['client'] as Map)['patient_ref'];
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: '/ibclc/clients/$id',
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.requests, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, '工作邮箱'),
        'jamie@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '密码'),
        'synthetic-password',
      );
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
      expect(harness.requests.map((r) => r.url.path), ['/v1/ibclc/auth/login']);
      expect(find.text('验证你的身份'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '认证器验证码'),
        '123456',
      );
      await tester.tap(find.text('进入工作台'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkbenchClientPage), findsOneWidget);
      expect(find.text('林晓'), findsWidgets);
      expect(harness.store.saved, isNotNull);
      await tester.tap(find.byTooltip('工作账号'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      expect(find.text('进入病例环境'), findsOneWidget);
      expect(find.text('林晓'), findsNothing);
      expect(harness.store.saved, isNull);
      expect(harness.requests.last.url.path, '/v1/auth/logout');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'small workbench with large text keeps navigation and appointment actions usable',
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
          initialLocation: '/ibclc/appointments',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('打开工作台导航'));
      await tester.pumpAndSettle();
      expect(find.text('我的客户'), findsOneWidget);
      await tester.tap(find.text('我的客户'));
      await tester.pumpAndSettle();
      expect(find.text('林晓'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'opening a client updates the browser route for reload and sharing',
    (tester) async {
      final harness = WorkbenchHttpHarness();
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation: '/ibclc/appointments',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('林晓'));
      await tester.pumpAndSettle();
      final client = workbenchFixture('client')['client'] as Map;
      final router = GoRouter.of(
        tester.element(find.byType(WorkbenchClientPage)),
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/ibclc/clients/${client['patient_ref']}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('consultation intake values are available to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final harness = WorkbenchHttpHarness();
      final intake = workbenchFixture('intake');
      await tester.pumpWidget(
        MomCozyWorkbenchApp(
          runtime: harness.runtime,
          initialLocation:
              '/ibclc/appointments/${intake['appointment_id']}/intake',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.semantics.byLabel(RegExp(intake['feeding_goal'] as String)),
        findsOne,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });
}
