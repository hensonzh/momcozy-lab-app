import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/fixture_api_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/baby_inventory_transport.dart';
import '../../support/momcozy_test_fonts.dart';

MomCozyApiRuntime _runtime(
  BabyInventoryTransport t,
  MomCozySession s, {
  bool supportsPersistence = false,
}) => MomCozyApiRuntime(
  jsonTransport: t,
  multipartTransport: FixtureApiMultipartTransport({}),
  agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
  supportsSessionAutoRefresh: supportsPersistence,
  session: s,
  now: () => t.clock,
  timezoneProvider: () async => 'Asia/Shanghai',
);

class _Controller extends MomCozyRuntimeController {
  _Controller(this.transport, MomCozySession s)
    : super(_runtime(transport, s, supportsPersistence: true));
  final BabyInventoryTransport transport;
  @override
  void replaceRuntime(MomCozyApiRuntime value) =>
      super.replaceRuntime(_runtime(transport, value.session));
}

class _ProfileTransport extends BabyInventoryTransport {
  Completer<void>? profileReadGate;
  int? profileReadError, profileWriteError;
  int writeAttempts = 0;
  Never reject(int status) => throw ApiHttpException.fromBody({
    'http_status': status,
    'body': {
      'error': {'code': 'inventory_profile_failure'},
    },
  });
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/babies') {
      await profileReadGate?.future;
      if (profileReadError case final status?) reject(status);
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/babies/inventory-baby') {
      writeAttempts++;
      if (profileWriteError case final status?) reject(status);
      if (body['expected_version'] != profiles.first['version']) reject(409);
    }
    return super.putJson(path, body: body, headers: headers);
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  late _ProfileTransport transport;
  late _Controller runtime;
  late GoRouter router;
  String? previous;
  late String variant;
  Future<void> mount(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
    bool empty = false,
    bool failRecords = false,
    bool loading = false,
  }) async {
    previous = null;
    FlutterSecureStorage.setMockInitialValues({});
    variant = '${width.toInt()}-${scale.toInt()}x';
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _ProfileTransport();
    if (empty) transport.profiles.clear();
    transport.failRead = failRecords;
    if (loading) transport.readGate = Completer<void>();
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = _Controller(transport, session);
    final store = MemoryMomCozySessionStore(session);
    runtime.enableSessionAutoRefresh(store);
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
        'assets/images/me_baby_overview/nursery_camera_clean.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.text('Baby'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/baby');
    if (!empty) expect(find.text('Luna'), findsOneWidget);
    addTearDown(() async {
      if (transport.readGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      if (transport.profileReadGate case final gate? when !gate.isCompleted) {
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
        scrollable: find.byType(Scrollable).first,
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
    String route = '/baby',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/baby-profile-boundaries-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-profile-boundaries-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Baby bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone',
      'test': 'test/modules/baby/baby_profile_boundary_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-profile-boundaries-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  BabyProfileController profile(WidgetTester tester) => tester
      .widget<BabyProfileEditor>(find.byType(BabyProfileEditor))
      .controller;
  Future<void> edit(WidgetTester tester, String name) async {
    await tap(tester, find.text(name));
    await tap(tester, find.text('编辑当前宝宝资料'));
  }

  Future<void> input(WidgetTester tester, Finder field, String text) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'inventory Baby profile boundaries ${narrow ? '320/2x' : '393/1x'}',
      (tester) async {
        await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
        await capture(
          tester,
          'home-entry',
          'More → Baby for profile boundary controls',
        );
        await edit(tester, 'Luna');
        final name = find.descendant(
          of: find.byType(BabyProfileEditor),
          matching: find.byType(TextField),
        );
        final at119 = 'Luna ${List.filled(23, 'Care').join(' ')}';
        final at120 = '${at119}Z';
        expect(at119.length, 119);
        expect(at120.length, 120);
        await input(tester, name, at119);
        expect(profile(tester).name, at119);
        await capture(tester, 'name-119', 'Enter 119-character profile name');
        await input(tester, name, at120);
        expect(profile(tester).name, at120);
        await capture(tester, 'name-120', 'Enter maximum 120-character name');
        await input(tester, name, '${at120}X');
        expect(profile(tester).name, at120);
        expect(tester.widget<TextField>(name).controller!.text, at120);
        await capture(
          tester,
          'name-121-truncated',
          'Enter 121 characters → TextField preserves first 120',
        );
        final scroll = find.descendant(
          of: name,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.axis, Axis.horizontal);
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(scroll, Offset(position.maxScrollExtent + 300, 0));
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(0, .1));
        await capture(
          tester,
          'name-scroll-start',
          'Drag name field right → beginning of maximum-length name',
        );
        await tester.drag(scroll, Offset(-position.maxScrollExtent - 300, 0));
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, .1));
        await capture(
          tester,
          'name-scroll-end',
          'Drag name field left → final character of maximum-length name',
        );
        // TextField counts graphemes; domain validation counts Unicode runes.
        final combinedName = List.filled(61, 'e\u0301').join();
        await input(tester, name, combinedName);
        expect(profile(tester).name, combinedName);
        await tap(tester, find.text('保存宝宝资料'));
        expect(profile(tester).validation, '宝宝称呼不能超过 120 字。');
        expect(transport.writeAttempts, 0);
        await capture(
          tester,
          'unicode-length-validation',
          '61 combining-accent letters exceed 120 Unicode code points → domain length validation',
        );
        await input(tester, name, at120);
        await tap(tester, find.text('保存宝宝资料'));
        expect(find.byType(BabyProfileEditor), findsNothing);
        expect(transport.profiles.first['name'], at120);
        expect(transport.profiles.first['version'], 2);
        await capture(
          tester,
          'maximum-name-saved',
          'Save 120-character name → home identity and knowledge label update',
        );
        await edit(tester, at120);
        expect(profile(tester).name, at120);
        await capture(
          tester,
          'maximum-name-reopened',
          'Reopen maximum-length saved name',
        );
        await input(tester, name, 'Luna');
        await tap(tester, find.text('保存宝宝资料'));
        await capture(
          tester,
          'short-name-restored',
          'Save short name again → home header returns to compact layout',
        );
        await edit(tester, 'Luna');
        final picker = find.byType(DatePickerDialog);
        final calendarButton = find.widgetWithIcon(
          OutlinedButton,
          Icons.calendar_month_outlined,
        );
        await tap(tester, calendarButton);
        final strings = MaterialLocalizations.of(tester.element(picker));
        await capture(
          tester,
          'birth-open',
          'Open birth date calendar or large-text input',
        );
        if (!narrow) {
          await tap(tester, find.byTooltip(strings.previousMonthTooltip));
          expect(
            find.text(strings.formatMonthYear(DateTime(2026, 7))),
            findsOneWidget,
          );
          await capture(
            tester,
            'previous-month',
            'Calendar previous month → July 2026',
          );
          await tap(tester, find.byTooltip(strings.nextMonthTooltip));
          await capture(
            tester,
            'next-month',
            'Calendar next month → August 2026',
          );
          await tap(tester, find.byTooltip(strings.nextMonthTooltip));
          expect(
            find.text(strings.formatMonthYear(DateTime(2026, 9))),
            findsOneWidget,
          );
          await capture(
            tester,
            'latest-month',
            'Calendar next month → current month, future navigation disabled',
          );
          await tap(
            tester,
            find.text(strings.formatMonthYear(DateTime(2026, 9))),
          );
          expect(find.byType(YearPicker), findsOneWidget);
          await capture(
            tester,
            'year-list',
            'Tap calendar month header → year picker',
          );
          await tap(
            tester,
            find.descendant(
              of: find.byType(YearPicker),
              matching: find.text(strings.formatYear(DateTime(2025))),
            ),
          );
          expect(
            find.text(strings.formatMonthYear(DateTime(2025, 9))),
            findsOneWidget,
          );
          await capture(
            tester,
            'year-selected',
            'Choose year 2025 → September calendar',
          );
          await tap(
            tester,
            find.descendant(
              of: find.byType(CalendarDatePicker),
              matching: find.text('15'),
            ),
          );
          await capture(
            tester,
            'day-selected',
            'Choose September 15 in calendar',
          );
          await tap(
            tester,
            find.descendant(
              of: picker,
              matching: find.text(strings.okButtonLabel),
            ),
          );
          expect(profile(tester).birthDate.toString(), '2025-09-15');
          await capture(
            tester,
            'calendar-confirmed',
            'Confirm calendar selection → profile draft date changes',
          );
          await tap(tester, calendarButton);
          await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
        }
        final dateField = find.descendant(
          of: picker,
          matching: find.byType(TextFormField),
        );
        await input(tester, dateField, 'abc');
        await tap(
          tester,
          find.descendant(
            of: picker,
            matching: find.text(strings.okButtonLabel),
          ),
        );
        expect(find.text(strings.invalidDateFormatLabel), findsOneWidget);
        await capture(
          tester,
          'invalid-date-format',
          'Submit malformed date → localized format validation',
        );
        await input(
          tester,
          dateField,
          strings.formatCompactDate(DateTime(1899, 12, 31)),
        );
        await tap(
          tester,
          find.descendant(
            of: picker,
            matching: find.text(strings.okButtonLabel),
          ),
        );
        expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
        await capture(
          tester,
          'date-before-minimum',
          'Submit date before 1900 → range validation',
        );
        await input(
          tester,
          dateField,
          strings.formatCompactDate(DateTime(2026, 9, 1)),
        );
        if (!narrow) {
          await tap(tester, find.byTooltip(strings.calendarModeButtonLabel));
          expect(find.byType(CalendarDatePicker), findsOneWidget);
          await capture(
            tester,
            'input-to-calendar',
            'Correct typed date then return to calendar preview',
          );
        }
        await tap(
          tester,
          find.descendant(
            of: picker,
            matching: find.text(strings.okButtonLabel),
          ),
        );
        expect(profile(tester).birthDate.toString(), '2026-09-01');
        await capture(
          tester,
          'date-corrected',
          'Confirm valid date → draft September 1',
        );
        await tap(tester, find.text('保存宝宝资料'));
        expect(transport.profiles.first['birth_date'], '2026-09-01');
        await capture(
          tester,
          'date-saved',
          'Save new birth date → home age and growth range refresh',
        );
        await edit(tester, 'Luna');
        await input(tester, name, 'Luna removed');
        transport.profiles.first['version'] =
            (transport.profiles.first['version'] as int) + 1;
        await tap(tester, find.text('保存宝宝资料'));
        expect(profile(tester).failure?.kind, ProductFailureKind.conflict);
        await capture(
          tester,
          'removed-before-reload-conflict',
          'Concurrent profile update → conflict before membership is removed',
        );
        transport.profiles.removeAt(0);
        await tap(tester, find.text('重新载入'));
        expect(profile(tester).failure?.kind, ProductFailureKind.forbidden);
        expect(profile(tester).name, 'Luna removed');
        await capture(
          tester,
          'removed-on-reload',
          'Reload list no longer contains current baby → access error and draft retained',
        );
        await tap(tester, find.byTooltip('关闭宝宝资料'));
        await capture(
          tester,
          'removed-leave-confirm',
          'Close removed profile draft → discard confirmation',
        );
        await tap(tester, find.text('离开'));
        expect(find.byType(BabyProfileEditor), findsNothing);
        expect(find.text('Leo'), findsOneWidget);
        await capture(
          tester,
          'remaining-baby-selected',
          'Leave → refreshed home selects remaining accessible baby Leo',
        );
        await tap(tester, find.text('More'));
        await capture(
          tester,
          'more-return',
          'Baby → More after profile boundary journey',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
