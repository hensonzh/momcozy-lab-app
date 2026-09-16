import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/schedule_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late ScheduleInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  Future<void> mount(
    WidgetTester tester, {
    void Function(ScheduleInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = ScheduleInventoryTransport();
    prepare?.call(transport);
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),
        agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
        session: session,
        supportsSessionAutoRefresh: false,
        now: () => inventoryMomNow,
        timezoneProvider: () async => 'Asia/Shanghai',
      ),
    );
    final store = MemoryMomCozySessionStore(session);
    final platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: runtime,
      sessionStore: store,
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        sessionStore: store,
        routeIntentPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Long capture visits lazy children. Decode both local images before
      // comparing any viewport so later dialogs see the same loaded page.
      for (final asset in [
        MomCozyAssets.agentAvatar,
        'assets/images/mom_home/cozymate_avatar.png',
        'assets/images/mom_home/expert_group.png',
        'assets/images/mom/milk-hero.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.text('Schedule'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/schedule');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.restorationId != 'editable' &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/schedule',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final suffix =
        '${tester.view.physicalSize.width.round()}${tester.platformDispatcher.textScaleFactor > 1 ? '-2x' : ''}';
    final source =
        'test/goldens/ui_inventory/schedule-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/schedule-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Schedule bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test': 'test/modules/schedule/schedule_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/schedule-journey-$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> add(WidgetTester tester, String title) async {
    await tap(tester, find.byTooltip('添加日程'));
    await tester.enterText(find.byKey(const ValueKey('schedule-title')), title);
    await tester.pump();
  }

  Future<void> menu(WidgetTester tester, String title) =>
      tap(tester, find.byTooltip('更多$title选项'));

  testWidgets('inventory schedule calendar create edit delete', (tester) async {
    await mount(tester);
    await capture(tester, 'empty', 'More → Schedule bottom tab');
    await tap(tester, find.byTooltip('下个月'));
    await capture(tester, 'next-month', 'Next month → October calendar');
    await tap(tester, find.byTooltip('上个月'));
    await capture(
      tester,
      'previous-month',
      'Previous month → September first day',
    );
    await tap(tester, find.text('2026年9月'));
    await tap(tester, find.byTooltip('添加日程'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('schedule-save')))
          .onPressed,
      isNull,
    );
    await capture(
      tester,
      'create-empty',
      'Today heading → add; empty title disables save',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Inventory walk',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-note')),
      'Isolated schedule note',
    );
    await capture(tester, 'create-filled', 'Enter title and note');
    await tap(tester, find.byKey(const ValueKey('schedule-date')));
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .currentDate,
      DateUtils.dateOnly(inventoryMomNow),
    );
    await capture(tester, 'date-picker', 'Date field → calendar dialog');
    await tap(tester, find.text('14').last);
    await tap(tester, find.text('确定'));
    await capture(tester, 'date-changed', 'Select September 14 → OK');
    await tap(tester, find.byKey(const ValueKey('schedule-time')));
    await capture(tester, 'time-picker', 'Start time field → clock dialog');
    await tap(tester, find.text('确定'));
    await tap(tester, find.byKey(const ValueKey('schedule-save')));
    expect(transport.personal.single['date'], '2026-09-14');
    await capture(
      tester,
      'created',
      'Save → refresh selected September 14 agenda',
    );
    await menu(tester, 'Inventory walk');
    await capture(tester, 'personal-menu', 'Personal event more options');
    await tap(tester, find.text('修改'));
    await capture(tester, 'edit', 'Modify → persisted fields');
    await tester.enterText(
      find.byKey(const ValueKey('schedule-title')),
      'Inventory walk updated',
    );
    await tap(tester, find.text('保存修改'));
    expect(transport.personal.single['title'], 'Inventory walk updated');
    await capture(tester, 'edited', 'Save modification → updated agenda');
    await menu(tester, 'Inventory walk updated');
    await tap(tester, find.text('删除'));
    await capture(tester, 'delete-confirm', 'Delete → confirmation');
    await tap(tester, find.text('保留日程'));
    await capture(tester, 'delete-cancelled', 'Keep event → agenda unchanged');
    await menu(tester, 'Inventory walk updated');
    await tap(tester, find.text('删除'));
    await tap(tester, find.text('确认删除'));
    expect(transport.personal, isEmpty);
    await capture(tester, 'deleted', 'Confirm delete → empty selected day');
  });

  testWidgets('inventory schedule discard and save retry', (tester) async {
    await mount(tester);
    await add(tester, 'Inventory draft');
    await tap(tester, find.text('关闭'));
    await capture(
      tester,
      'discard-confirm',
      'Close dirty editor → discard confirmation',
    );
    await tap(tester, find.text('继续填写'));
    await capture(tester, 'draft-kept', 'Continue filling → draft retained');
    transport.failWrite = true;
    await tap(tester, find.byKey(const ValueKey('schedule-save')));
    expect(find.text('重试确认保存'), findsOneWidget);
    await capture(
      tester,
      'save-uncertain',
      'Save HTTP 503 → uncertain result and locked fields',
    );
    await tap(tester, find.text('关闭'));
    await capture(
      tester,
      'uncertain-discard',
      'Close uncertain save → reconciliation warning',
    );
    await tap(tester, find.text('继续填写'));
    transport.failWrite = false;
    final gate = Completer<void>();
    transport.writeGate = gate;
    await tester.tap(find.text('重试确认保存'));
    await capture(
      tester,
      'save-pending',
      'Retry same idempotency key → request pending',
    );
    gate.complete();
    transport.writeGate = null;
    await tester.pumpAndSettle();
    expect(transport.createKeys.toSet().length, 1);
    expect(transport.personal.length, 1);
    await capture(
      tester,
      'save-recovered',
      'Retry response → one persisted event',
    );
    await menu(tester, 'Inventory draft');
    await tap(tester, find.text('修改'));
    await tester.enterText(
      find.byKey(const ValueKey('schedule-note')),
      'Discard me',
    );
    await tap(tester, find.text('关闭'));
    await tap(tester, find.text('离开'));
    expect(transport.personal.single['note'], '');
    await capture(tester, 'discarded', 'Leave → unsaved note discarded');
  });

  testWidgets('inventory schedule read and delete failure recovery', (
    tester,
  ) async {
    final gate = Completer<void>();
    await mount(
      tester,
      loading: true,
      prepare: (t) => t.readGates['/v1/schedule'] = gate,
    );
    await capture(tester, 'loading', 'Schedule tab → first read pending');
    transport.failingReads.add('/v1/schedule');
    gate.complete();
    transport.readGates.clear();
    await tester.pumpAndSettle();
    await capture(tester, 'read-error', 'First read fails → retry view');
    transport.failingReads.clear();
    await tap(tester, find.text('重试'));
    await capture(tester, 'read-recovered', 'Retry → empty calendar');
    await add(tester, 'Inventory delete');
    await tap(tester, find.text('添加到日程'));
    await menu(tester, 'Inventory delete');
    await tap(tester, find.text('删除'));
    transport.failWrite = true;
    await tap(tester, find.text('确认删除'));
    expect(find.text('暂时无法确认删除结果。请刷新日程后核对。'), findsOneWidget);
    await capture(
      tester,
      'delete-error',
      'Delete fails → uncertain snackbar, event retained',
    );
    await tester.pump(const Duration(seconds: 5));
    transport.failWrite = false;
    await menu(tester, 'Inventory delete');
    await tap(tester, find.text('删除'));
    await tap(tester, find.text('确认删除'));
    await capture(
      tester,
      'delete-recovered',
      'Reopen delete and confirm → event removed',
    );
    transport.failingReads.add('/v1/schedule');
    await tap(tester, find.byTooltip('下个月'));
    await capture(
      tester,
      'refresh-error',
      'Next month read fails with cached page retained',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('重试'));
    await capture(
      tester,
      'refresh-recovered',
      'Retry → requested month loaded',
    );
  });

  testWidgets('inventory schedule server validation and conflict', (
    tester,
  ) async {
    await mount(tester);
    await add(tester, 'Inventory validation');
    transport.failWrite = true;
    transport.failureStatus = 422;
    await tap(tester, find.text('添加到日程'));
    await capture(
      tester,
      'invalid',
      'Save HTTP 422 → editable draft and validation feedback',
    );
    transport.failureStatus = 409;
    await tap(tester, find.text('添加到日程'));
    await capture(tester, 'conflict', 'Retry HTTP 409 → conflict feedback');
    transport.failWrite = false;
    await tap(tester, find.text('添加到日程'));
    await capture(tester, 'validation-recovered', 'Retry accepted → agenda');
  });

  testWidgets('inventory schedule care task statuses and plan', (tester) async {
    await mount(tester, prepare: (t) => t.seedCare());
    await capture(
      tester,
      'care',
      'Schedule tab → appointment and published task',
    );
    await menu(tester, 'Record an observation');
    await capture(
      tester,
      'task-menu',
      'Task more options → statuses and service link',
    );
    await tap(tester, find.text('标记进行中'));
    await capture(
      tester,
      'task-in-progress',
      'Mark in progress → refreshed task badge',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('暂时跳过'));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    await capture(
      tester,
      'task-skipped',
      'Skip → disabled completion checkbox',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('恢复待完成'));
    await capture(tester, 'task-pending', 'Restore pending → checkbox enabled');
    await tap(tester, find.byType(Checkbox));
    await capture(
      tester,
      'task-completed',
      'Checkbox → completed task and progress count',
    );
    await tap(tester, find.byType(Checkbox));
    transport.failWrite = true;
    await tap(tester, find.byType(Checkbox));
    await capture(
      tester,
      'task-error',
      'Status write fails → refresh reconciliation message',
    );
    transport.failWrite = false;
    await tap(tester, find.text('刷新日程'));
    await capture(
      tester,
      'task-reconciled',
      'Refresh → server pending state restored',
    );
    await tap(tester, find.text('当前照护方案'));
    await capture(
      tester,
      'plan-expanded',
      'Expand current care plan → full summary and progress',
    );
    await tap(tester, find.text('查看照护方案 →'));
    await capture(
      tester,
      'plan-route',
      'View care plan → actual episode route',
      route: '/services/episodes/service-episode',
    );
  });
  testWidgets('inventory schedule service filters and appointment summary', (
    tester,
  ) async {
    await mount(
      tester,
      prepare: (t) {
        t.seedCare();
        t.appointment!['status'] = 'completed';
        t.extraEpisodes.add({
          ...t.episode!,
          'id': 'second-episode',
          'remaining_sessions': 1,
          'starts_at': '2026-09-18T08:00:00Z',
          'ends_at': '2026-09-25T08:00:00Z',
        });
      },
    );
    await capture(
      tester,
      'multiple-services',
      'Schedule tab → two service periods and completed consultation',
    );
    await tap(tester, find.byTooltip('切换日历显示的服务包'));
    await capture(
      tester,
      'service-filter-menu',
      'Service period selector → all and individual plans',
    );
    await tap(tester, find.textContaining('余 1 次').last);
    await capture(
      tester,
      'service-filter-selected',
      'Choose second service → only its dates highlighted',
    );
    await tap(tester, find.byTooltip('切换日历显示的服务包'));
    await tap(tester, find.text('全部服务'));
    await capture(
      tester,
      'service-filter-reset',
      'All services → restore both date periods',
    );
    await tap(tester, find.text('总结'));
    await capture(
      tester,
      'consultation-summary-route',
      'Completed appointment summary → actual published summary route',
      route: '/services/appointments/service-appointment/summary',
    );
  });

  testWidgets('inventory schedule picker cancel and task menu route', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.seedCare());
    await tap(tester, find.byTooltip('添加日程'));
    await tap(tester, find.byKey(const ValueKey('schedule-date')));
    await tap(tester, find.byIcon(Icons.edit_outlined));
    await capture(tester, 'date-input', 'Date calendar → text input mode');
    await tap(tester, find.text('取消'));
    await capture(
      tester,
      'date-cancelled',
      'Cancel date picker → original date retained',
    );
    await tap(tester, find.byKey(const ValueKey('schedule-time')));
    await tap(tester, find.byIcon(Icons.keyboard_outlined));
    await capture(tester, 'time-input', 'Clock → keyboard time input');
    await tap(tester, find.text('取消'));
    await capture(
      tester,
      'time-cancelled',
      'Cancel time input → original time retained',
    );
    await tap(tester, find.text('关闭'));
    await capture(
      tester,
      'clean-editor-closed',
      'Close unchanged editor → agenda without discard prompt',
    );
    await menu(tester, 'Record an observation');
    await tap(tester, find.text('查看服务计划'));
    await capture(
      tester,
      'task-plan-route',
      'Task menu view service plan → actual episode route',
      route: '/services/episodes/service-episode',
    );
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'inventory schedule picker validation and changed time $scale',
      (tester) async {
        await mount(tester, width: scale == 1 ? 393 : 320, textScale: scale);
        final tag = scale == 1 ? 'picker' : 'large-picker';
        await add(tester, 'Inventory input');
        await capture(tester, '$tag-editor', 'Add event → responsive editor');
        await tap(tester, find.byKey(const ValueKey('schedule-date')));
        if (scale == 1) {
          await tap(tester, find.byIcon(Icons.edit_outlined));
        }
        final dateField = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(dateField, 'bad date');
        await tap(tester, find.text('确定'));
        final strings = MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)),
        );
        expect(find.text(strings.invalidDateFormatLabel), findsOneWidget);
        await capture(
          tester,
          '$tag-date-invalid',
          'Enter invalid date → validation without dismissal',
        );
        await tester.enterText(dateField, '2030/9/13');
        await tap(tester, find.text('确定'));
        expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
        await capture(
          tester,
          '$tag-date-out-of-range',
          'Enter date beyond allowed years → range error',
        );
        await tester.enterText(dateField, '2026/9/15');
        await tap(tester, find.text('确定'));
        await capture(
          tester,
          '$tag-date-corrected',
          'Correct date → editor retains September 15',
        );
        await tap(tester, find.byKey(const ValueKey('schedule-time')));
        if (scale == 1) await tap(tester, find.byIcon(Icons.keyboard_outlined));
        final inputs = find.byType(TextFormField);
        await tester.enterText(inputs.first, '25');
        await tap(tester, find.text('确定'));
        await capture(
          tester,
          '$tag-time-invalid',
          'Enter hour 25 → time validation',
        );
        expect(inputs.evaluate().length, 2);
        await tester.enterText(inputs.first, '10');
        await tester.enterText(inputs.last, '45');
        await tap(tester, find.text('确定'));
        await capture(
          tester,
          '$tag-time-corrected',
          'Correct time to 10:45 → editor',
        );
        await tap(tester, find.text('添加到日程'));
        expect(transport.personal.single['start_time'], '10:45');
        expect(transport.personal.single['date'], '2026-09-15');
        await capture(
          tester,
          '$tag-saved',
          'Save corrected date/time → selected day agenda',
        );
      },
    );
  }

  testWidgets('inventory schedule calendar year and tooltips', (tester) async {
    await mount(tester);
    await tester.longPress(find.byTooltip('添加日程'));
    await capture(tester, 'add-tooltip', 'Long press add → tooltip');
    await tester.pump(const Duration(seconds: 3));
    await add(tester, 'Inventory year');
    await tap(tester, find.byKey(const ValueKey('schedule-date')));
    await tap(
      tester,
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('2026年9月'),
      ),
    );
    await capture(tester, 'year-selector', 'Date header → year selector');
    await tap(tester, find.text('2027年'));
    await capture(
      tester,
      'year-selected',
      'Choose 2027 → calendar for selected year',
    );
    await tap(tester, find.text('确定'));
    await capture(tester, 'year-editor', 'Confirm future year → editor');
    await tap(tester, find.text('关闭'));
    await tap(tester, find.text('离开'));
    await tester.longPress(find.byTooltip('下个月'));
    await capture(tester, 'next-tooltip', 'Long press next month → tooltip');
  });

  testWidgets(
    'inventory schedule task pending and personal conflict reconciliation',
    (tester) async {
      await mount(tester, prepare: (t) => t.seedCare());
      final gate = Completer<void>();
      transport.writeGate = gate;
      await tester.tap(find.byType(Checkbox));
      await capture(
        tester,
        'task-write-pending',
        'Complete task → request pending; controls disabled',
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      gate.complete();
      transport.writeGate = null;
      await tester.pumpAndSettle();
      await capture(tester, 'task-write-finished', 'Response → completed task');
      await add(tester, 'Inventory conflict');
      await tap(tester, find.text('添加到日程'));
      await menu(tester, 'Inventory conflict');
      await tap(tester, find.text('修改'));
      await tester.enterText(
        find.byKey(const ValueKey('schedule-note')),
        'Changed draft',
      );
      transport.failWrite = true;
      transport.failureStatus = 409;
      await tap(tester, find.text('保存修改'));
      await capture(
        tester,
        'edit-conflict',
        'Existing event changed on server → update conflict',
      );
      await tap(tester, find.text('关闭'));
      await tap(tester, find.text('离开'));
      await menu(tester, 'Inventory conflict');
      await tap(tester, find.text('删除'));
      await tap(tester, find.text('确认删除'));
      await capture(
        tester,
        'delete-conflict',
        'Delete stale event → uncertain deletion feedback',
      );
      await tester.pump(const Duration(seconds: 5));
      transport.failWrite = false;
      final scroll = find.byType(Scrollable).last;
      await tester.drag(scroll, const Offset(0, 900));
      await tester.pumpAndSettle();
      await tester.drag(scroll, const Offset(0, 450));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'pull-refresh-reconciled',
        'Pull refresh → event retained with server state',
      );
      expect(transport.personal.single['note'], '');
    },
  );

  testWidgets('inventory schedule current visible feedback gaps', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.seedCare());
    await tester.longPress(find.byTooltip('添加日程'));
    await capture(tester, 'current-add-tooltip', 'Long press add → tooltip');
    await tester.pump(const Duration(seconds: 3));
    await tester.longPress(find.byTooltip('下个月'));
    await capture(
      tester,
      'current-next-tooltip',
      'Long press next month → tooltip',
    );
    await tester.pump(const Duration(seconds: 3));
    await add(tester, 'Inventory conflict');
    transport.failWrite = true;
    transport.failureStatus = 422;
    await tap(tester, find.text('添加到日程'));
    await capture(
      tester,
      'current-create-invalid',
      'Create validation rejected → editable draft and feedback',
    );
    transport.failureStatus = 409;
    await tap(tester, find.text('添加到日程'));
    await capture(
      tester,
      'current-create-conflict',
      'Create conflicts → conflict message with draft retained',
    );
    transport.failWrite = false;
    await tap(tester, find.text('添加到日程'));
    await menu(tester, 'Inventory conflict');
    await tap(tester, find.text('修改'));
    await tester.enterText(
      find.byKey(const ValueKey('schedule-note')),
      'Changed draft',
    );
    transport.failWrite = true;
    await tap(tester, find.text('保存修改'));
    await capture(
      tester,
      'current-edit-conflict',
      'Edit conflicts → changed note retained in edit form',
    );
    await tap(tester, find.byTooltip('关闭日程'));
    await tap(tester, find.text('离开'));
    await menu(tester, 'Inventory conflict');
    await tap(tester, find.text('删除'));
    await tap(tester, find.text('确认删除'));
    expect(find.text('暂时无法确认删除结果。请刷新日程后核对。'), findsOneWidget);
    await capture(
      tester,
      'current-delete-error',
      'Delete cannot be confirmed → snackbar and retained event',
    );
    await tester.pump(const Duration(seconds: 5));
    transport.failureStatus = 503;
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await capture(
      tester,
      'current-task-error',
      'Care task write fails → reconciliation feedback',
    );
    transport.failWrite = false;
    await tap(tester, find.text('刷新日程'));
    expect(transport.personal.single['note'], '');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory schedule confirmed appointment entry and return', (
    tester,
  ) async {
    await mount(tester, prepare: (t) => t.seedCare());
    await capture(
      tester,
      'appointment-entry',
      'Schedule → confirmed consultation',
    );
    await tap(tester, find.text('查看'));
    await capture(
      tester,
      'appointment-room-route',
      'Confirmed consultation view → real preparation route',
      route: '/services/appointments/service-appointment/room',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await capture(
      tester,
      'appointment-return',
      'System back from preparation → Schedule',
    );
  });

  testWidgets(
    'inventory schedule first page limit has no continuation control',
    (tester) async {
      await mount(
        tester,
        prepare: (t) {
          for (var i = 1; i <= 101; i++) {
            t.personal.add({
              'id': 'page-$i',
              'title': 'Inventory event $i',
              'date': i <= 100 ? '2026-09-13' : '2026-09-14',
              'start_time': '09:00',
              'note': '',
              'updated_at': inventoryMomNow.toIso8601String(),
            });
          }
        },
      );
      await capture(
        tester,
        'first-page-overflow',
        '101 server events → first 100 rendered; full scroll evidence',
      );
      final scroll = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('Inventory event 100'),
        600,
        scrollable: scroll,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        'first-page-end',
        'Scroll to final loaded event → no load-more control',
      );
      expect(transport.queries.every((q) => q['offset'] == 0), isTrue);
      expect(find.text('Inventory event 101'), findsNothing);
      final state = tester.state<ScrollableState>(scroll);
      state.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tap(tester, find.bySemanticsLabel('9月14日'));
      expect(find.text('这一天没有安排'), findsOneWidget);
      await capture(
        tester,
        'unloaded-day-empty',
        'Select day of unrequested event 101 → empty agenda; product gap',
      );
      expect(transport.queries.length, 1);
    },
  );
  for (final status in ['held', 'cancelled', 'expired']) {
    testWidgets('inventory schedule appointment $status entry', (tester) async {
      await mount(
        tester,
        prepare: (t) {
          t.seedCare();
          t.appointment!['status'] = status;
          if (status == 'held' || status == 'expired') {
            t.intake = null;
            t.appointment!['intake_version'] = 0;
            t.appointment!['confirmed_at'] = null;
            t.roomData['intake_ready'] = false;
          }
          if (status == 'expired') {
            t.appointment!['hold_expires_at'] = inventoryMomNow
                .subtract(const Duration(minutes: 1))
                .toIso8601String();
          }
          if (status == 'held') {
            t.appointment!['hold_expires_at'] = inventoryMomNow
                .add(const Duration(minutes: 10))
                .toIso8601String();
          }
        },
      );
      await capture(
        tester,
        'appointment-$status',
        'Schedule → appointment status $status',
      );
      await tap(tester, find.text(status == 'held' ? '确认' : '查看'));
      await capture(
        tester,
        'appointment-$status-route',
        'Appointment action → actual room preparation for $status',
        route: '/services/appointments/service-appointment/room',
      );
      if (status == 'held' || status == 'expired') {
        await tap(tester, find.text('查看信息采集表'));
        await capture(
          tester,
          'appointment-$status-intake',
          'Preparation intake link → actual intake route for $status',
          route: '/services/appointments/service-appointment/intake',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await capture(
          tester,
          'appointment-$status-intake-return',
          'Unchanged intake system back → preparation',
          route: '/services/appointments/service-appointment/room',
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await capture(
        tester,
        'appointment-$status-return',
        'System back → $status agenda retained',
      );
    });
  }
}
