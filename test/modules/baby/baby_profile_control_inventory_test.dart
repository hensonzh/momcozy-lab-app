import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_labels.dart';
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
import 'package:momcozy_flutter_app/shared/widgets/knowledge_banner.dart';
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

void main() {
  setUpAll(loadMomCozyTestFonts);
  late BabyInventoryTransport transport;
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
    transport = BabyInventoryTransport();
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
        'test/goldens/ui_inventory/baby-profile-controls-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/baby-profile-controls-$state-$variant.png',
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
      'test': 'test/modules/baby/baby_profile_control_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/baby-profile-controls-$state-$variant.json',
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

  final datePicker = find.byType(DatePickerDialog);
  final dateField = find.descendant(
    of: datePicker,
    matching: find.byType(TextFormField),
  );
  Future<void> openDate(WidgetTester tester) => tap(
    tester,
    find.widgetWithIcon(OutlinedButton, Icons.calendar_month_outlined),
  );
  for (final narrow in [false, true]) {
    testWidgets('inventory Baby profile controls ${narrow ? '320/2x' : '393/1x'}', (
      tester,
    ) async {
      await mount(tester, width: narrow ? 320 : 393, scale: narrow ? 2 : 1);
      await capture(tester, 'home-entry', 'More → Baby');
      await edit(tester, 'Luna');
      await capture(tester, 'editor', 'Baby switcher → edit Luna profile');
      for (final sex in [BabySex.male, BabySex.unspecified, BabySex.female]) {
        await tap(
          tester,
          find.descendant(
            of: find.byType(BabyProfileEditor),
            matching: find.text(
              sex == BabySex.unspecified ? '暂不填写' : babySexLabel(sex),
            ),
          ),
        );
        expect(profile(tester).sex, sex);
        await capture(
          tester,
          'sex-${sex.name}',
          'Select profile sex ${sex.name}',
        );
      }
      for (final mode in FeedingMode.values) {
        await tap(tester, find.byType(DropdownButtonFormField<FeedingMode>));
        await capture(
          tester,
          'feeding-menu-${mode.name}',
          'Open feeding mode menu before choosing ${mode.name}',
        );
        await tap(tester, find.text(feedingModeLabel(mode)).last);
        expect(profile(tester).feedingMode, mode);
        await capture(
          tester,
          'feeding-${mode.name}',
          'Select feeding mode ${mode.name}',
        );
      }
      await openDate(tester);
      expect(
        tester.widget<DatePickerDialog>(datePicker).currentDate,
        DateUtils.dateOnly(transport.clock),
      );
      final strings = MaterialLocalizations.of(tester.element(datePicker));
      await capture(tester, 'birth-open', 'Open existing birth date picker');
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
        await capture(tester, 'birth-input', 'Calendar → birth date input');
      }
      await input(
        tester,
        dateField,
        strings.formatCompactDate(DateTime(2099, 1, 1)),
      );
      await tap(
        tester,
        find.descendant(
          of: datePicker,
          matching: find.text(strings.okButtonLabel),
        ),
      );
      expect(datePicker, findsOneWidget);
      expect(profile(tester).birthDate.toString(), '2026-08-22');
      await capture(
        tester,
        'birth-future-rejected',
        'Confirm future birth date → picker range error; original date preserved',
      );
      await input(
        tester,
        dateField,
        strings.formatCompactDate(DateTime(2026, 8, 10)),
      );
      await tap(
        tester,
        find.descendant(
          of: datePicker,
          matching: find.text(strings.okButtonLabel),
        ),
      );
      expect(profile(tester).birthDate.toString(), '2026-08-10');
      await capture(
        tester,
        'birth-changed',
        'Confirm valid birth date August 10',
      );
      await tap(tester, find.text('清除日期'));
      expect(profile(tester).birthDate, isNull);
      await capture(
        tester,
        'birth-cleared',
        'Clear birth date → draft unregistered',
      );
      await tap(tester, find.text('保存宝宝资料'));
      expect(find.byType(BabyProfileEditor), findsNothing);
      expect(transport.profiles.first['birth_date'], isNull);
      expect(transport.profiles.first['version'], 2);
      await capture(
        tester,
        'missing-birth-saved',
        'Save cleared birth date → home missing age and growth reference',
      );
      await edit(tester, 'Luna');
      expect(profile(tester).birthDate, isNull);
      await capture(
        tester,
        'missing-birth-reopened',
        'Reopen profile → cleared date persisted',
      );
      await openDate(tester);
      expect(
        tester.widget<DatePickerDialog>(datePicker).currentDate,
        DateUtils.dateOnly(transport.clock),
      );
      await capture(
        tester,
        'missing-birth-picker',
        'Open missing birth date → initial date is injected today',
      );
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      }
      await input(
        tester,
        dateField,
        strings.formatCompactDate(DateTime(2026, 8, 22)),
      );
      await tap(
        tester,
        find.descendant(
          of: datePicker,
          matching: find.text(strings.cancelButtonLabel),
        ),
      );
      expect(profile(tester).birthDate, isNull);
      await capture(
        tester,
        'birth-cancelled',
        'Cancel typed birth date → draft remains empty',
      );
      await openDate(tester);
      if (!narrow) {
        await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
      }
      await input(
        tester,
        dateField,
        strings.formatCompactDate(DateTime(2026, 8, 22)),
      );
      await tap(
        tester,
        find.descendant(
          of: datePicker,
          matching: find.text(strings.okButtonLabel),
        ),
      );
      await capture(
        tester,
        'birth-restored',
        'Confirm restored birth date August 22',
      );
      final name = find.descendant(
        of: find.byType(BabyProfileEditor),
        matching: find.byType(TextField),
      );
      await input(tester, name, '   ');
      await tap(tester, find.text('保存宝宝资料'));
      expect(profile(tester).validation, '请填写宝宝称呼。');
      expect(transport.profiles.first['version'], 2);
      await capture(
        tester,
        'name-empty-validation',
        'Save whitespace name → required validation, saved profile untouched',
      );
      await input(tester, name, 'Luna updated');
      await capture(
        tester,
        'name-corrected',
        'Correct profile name → validation clears',
      );
      transport.failWrite = true;
      await tap(tester, find.text('保存宝宝资料'));
      expect(profile(tester).uncertain, isTrue);
      expect(profile(tester).editable, isFalse);
      expect(transport.profiles.first['version'], 2);
      await capture(
        tester,
        'save-unconfirmed',
        'Profile PUT returns 503 → locked draft and retry confirmation',
      );
      await tap(tester, find.byTooltip('关闭宝宝资料'));
      await capture(
        tester,
        'uncertain-leave-confirm',
        'Close unconfirmed save → uncertain-result leave dialog',
      );
      await tap(tester, find.text('继续填写'));
      expect(profile(tester).uncertain, isTrue);
      await capture(
        tester,
        'uncertain-stay',
        'Continue filling → same locked pending draft',
      );
      transport.failWrite = false;
      await tap(tester, find.text('重试确认保存'));
      expect(find.byType(BabyProfileEditor), findsNothing);
      expect(transport.profiles.first['name'], 'Luna updated');
      expect(transport.profiles.first['birth_date'], '2026-08-22');
      expect(transport.profiles.first['version'], 3);
      await capture(
        tester,
        'retry-saved',
        'Retry confirms save → home identity and age restored',
      );
      await edit(tester, 'Luna updated');
      expect(profile(tester).name, 'Luna updated');
      expect(profile(tester).birthDate.toString(), '2026-08-22');
      expect(profile(tester).sex, BabySex.female);
      expect(profile(tester).feedingMode, FeedingMode.unknown);
      await capture(
        tester,
        'saved-reopened',
        'Reopen saved profile → all saved fields restored',
      );
      await tap(tester, find.byTooltip('关闭宝宝资料'));
      expect(find.text('离开这次记录？'), findsNothing);
      await capture(
        tester,
        'unchanged-close',
        'Close unchanged profile → home without discard confirmation',
      );
      final banner = tester.widget<KnowledgeBanner>(
        find.byType(KnowledgeBanner),
      );
      final title = banner.article.title;
      await tap(tester, find.byType(KnowledgeBanner));
      await capture(
        tester,
        'knowledge-detail',
        'Tap knowledge card → full article',
      );
      await tap(tester, find.text('问问 Cozymate'));
      expect(router.state.uri.path, '/');
      expect(find.text(title), findsWidgets);
      expect(
        transport.mutationPaths.where((p) => p.contains('/runs')),
        isEmpty,
      );
      await capture(
        tester,
        'knowledge-agent-prefill',
        'Ask Cozymate → normal Agent route with article title prefilled, not sent',
        route: '/',
      );
      await tap(tester, find.text('Baby'));
      await capture(
        tester,
        'knowledge-baby-return',
        'Cozymate → Baby, saved profile retained',
      );
      await tap(tester, find.text('More'));
      await capture(tester, 'more-return', 'Baby → More', route: '/more');
    });
  }
}
