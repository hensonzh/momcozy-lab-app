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
import 'package:momcozy_flutter_app/domain/care/intake.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/privacy_inventory_transport.dart';
import '../../support/notification_fakes.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late PrivacyInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late FakePlatform permissions;
  late FakeGateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(PrivacyInventoryTransport)? prepare,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
    permissions = FakePlatform();
    gateway = FakeGateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = PrivacyInventoryTransport();
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
    coordinator = NotificationCoordinator(
      permission: NotificationPermissionController(permissions),
      gateway: gateway,
      store: FakeStore(),
      platformName: 'android',
      onNavigate: (route) => router.go(route),
      onMessage: (message) {
        final context = tester.element(find.byType(Scaffold).last);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      onForeground: (_) {},
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        notificationCoordinator: coordinator,
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
    expect(router.state.uri.path, '/more');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      if (transport.consentGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      coordinator.dispose();
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
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
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/privacy',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final width = tester.view.physicalSize.width.round();
    final scale = tester.platformDispatcher.textScaleFactor;
    final suffix = '$width${scale == 1 ? '' : '-${scale.round()}x'}';
    final source =
        'test/goldens/ui_inventory/privacy-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/privacy-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More page',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production privacy page/controllers and Care/Intake API repositories; isolated HTTP with versioned per-service consent storage; actual More/privacy/notification routes and notification coordinator, no real user permissions mutated',
      'test': 'test/modules/profile/privacy_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/privacy-journey-$state-$suffix.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  final picker = find.byType(DropdownButtonFormField<String>);
  Finder scope(CareConsentScope value) => find.byKey(ValueKey(value));
  Future<void> toggle(WidgetTester tester, CareConsentScope value) =>
      tap(tester, scope(value));
  Future<void> entry(WidgetTester tester) async {
    await tap(tester, find.text('Privacy'));
    expect(router.state.uri.path, '/privacy');
  }

  Future<void> chooseOther(WidgetTester tester, {bool reopened = false}) async {
    await tap(tester, picker);
    await capture(
      tester,
      reopened ? 'service-picker-reopened' : 'service-picker',
      'Tap service picker → list of owned services',
    );
    await tap(tester, find.textContaining('Expert support service').last);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'inventory privacy grant revoke confirm and notification roundtrip ${size.$1}',
      (tester) async {
        await mount(tester, width: size.$1, textScale: size.$2);
        await entry(tester);
        await capture(
          tester,
          'loaded',
          'More privacy → first service three editable permissions',
        );
        await toggle(tester, CareConsentScope.aiContext);
        await capture(
          tester,
          'optional-dirty',
          'Turn off Momcozy AI context → unsaved draft',
        );
        await tap(tester, find.text('Save changes'));
        expect(transport.consentWrites.single['scope'], 'ai_context');
        expect(find.text('Privacy settings saved'), findsOneWidget);
        await capture(
          tester,
          'optional-saved',
          'Save optional change → versioned HTTP write and saved message',
        );
        await toggle(tester, CareConsentScope.ibclcCase);
        await toggle(tester, CareConsentScope.video);
        await tap(tester, find.text('Save changes'));
        await capture(
          tester,
          'revoke-confirm',
          'Disable case and video → save requests required-scope confirmation',
        );
        await tap(tester, find.text('Keep access'));
        expect(transport.consentWrites, hasLength(1));
        await capture(
          tester,
          'revoke-kept',
          'Keep authorization → dialog closes; toggled draft remains unsaved',
        );
        await tap(tester, find.text('Save changes'));
        await tap(tester, find.byTooltip('Close'));
        await capture(
          tester,
          'revoke-closed',
          'Close confirmation icon → draft remains, no write',
        );
        await tap(tester, find.text('Save changes'));
        await tap(tester, find.text('Turn off access'));
        expect(transport.consentWrites.map((e) => e['scope']), [
          'ai_context',
          'ibclc_case',
          'video',
        ]);
        await capture(
          tester,
          'revoked',
          'Confirm required revocation → both HTTP writes and saved state',
        );
        await toggle(tester, CareConsentScope.ibclcCase);
        await toggle(tester, CareConsentScope.video);
        await toggle(tester, CareConsentScope.aiContext);
        await tap(tester, find.text('Save changes'));
        expect(find.text('Turn off service access?'), findsNothing);
        await capture(
          tester,
          'granted',
          'Re-enable three permissions → save without revocation confirmation',
        );
        await toggle(tester, CareConsentScope.aiContext);
        await tap(tester, find.text('Manage notifications & reminders'));
        await capture(
          tester,
          'notification-settings',
          'Manage reminders → actual notification settings route with privacy draft underneath',
          route: '/notifications/settings',
        );
        await tap(tester, find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Switch>(scope(CareConsentScope.aiContext)).value,
          isFalse,
        );
        await capture(
          tester,
          'notifications-return',
          'Back from notification settings → unsaved privacy draft retained',
        );
        await tap(tester, find.text('Back'));
        await capture(
          tester,
          'leave-confirm',
          'Back with draft → discard confirmation',
        );
        await tap(tester, find.text('Keep reviewing'));
        await capture(
          tester,
          'leave-kept',
          'Continue viewing → draft retained',
        );
        await tap(tester, find.text('Back'));
        await tap(tester, find.text('Discard and leave'));
        await capture(
          tester,
          'leave-discarded',
          'Discard and leave → original More route',
          route: '/more',
        );
        await entry(tester);
        expect(
          tester.widget<Switch>(scope(CareConsentScope.aiContext)).value,
          isTrue,
        );
        await capture(
          tester,
          'reentered',
          'Re-enter privacy → persisted server values, discarded draft absent',
        );
        await finish(tester);
      },
    );

    testWidgets(
      'inventory privacy service switch discards correctly ${size.$1}',
      (tester) async {
        await mount(tester, width: size.$1, textScale: size.$2);
        await entry(tester);
        await toggle(tester, CareConsentScope.aiContext);
        await chooseOther(tester);
        await capture(
          tester,
          'switch-confirm',
          'Select another service with dirty draft → discard confirmation',
        );
        await tap(tester, find.text('Keep reviewing'));
        expect(
          tester.state<FormFieldState<String>>(picker).value,
          'service-episode',
        );
        await capture(
          tester,
          'switch-cancelled',
          'Keep draft → picker rolls back to original service',
        );
        await chooseOther(tester, reopened: true);
        await tap(tester, find.text('Discard and leave'));
        expect(
          tester.state<FormFieldState<String>>(picker).value,
          'other-episode',
        );
        expect(transport.consentWrites, isEmpty);
        await capture(
          tester,
          'switched',
          'Discard previous draft → second service permissions loaded',
        );
        await toggle(tester, CareConsentScope.aiContext);
        await tap(tester, find.text('Save changes'));
        expect(transport.consentWrites.single['episode_id'], 'other-episode');
        expect(
          transport.byEpisode['service-episode']!['ai_context']!['active'],
          isTrue,
        );
        await capture(
          tester,
          'second-service-saved',
          'Save second service → first service stays unchanged',
        );
        await finish(tester);
      },
    );

    testWidgets(
      'inventory privacy pending uncertain retry and partial save ${size.$1}',
      (tester) async {
        await mount(tester, width: size.$1, textScale: size.$2);
        await entry(tester);
        await toggle(tester, CareConsentScope.ibclcCase);
        await toggle(tester, CareConsentScope.aiContext);
        transport.failScope = 'ai_context';
        transport.writeStatus = 503;
        transport.consentGate = Completer<void>();
        await tap(tester, find.text('Save changes'));
        await tap(tester, find.text('Turn off access'));
        expect(
          tester.widget<Switch>(scope(CareConsentScope.video)).onChanged,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
              .onPressed,
          isNull,
        );
        await capture(
          tester,
          'saving',
          'Confirm revocation → pending HTTP locks back, selector and switches',
        );
        transport.consentGate!.complete();
        await settle(tester);
        expect(transport.consentWrites, hasLength(2));
        expect(
          transport.byEpisode['service-episode']!['ibclc_case']!['active'],
          isFalse,
        );
        expect(
          transport.byEpisode['service-episode']!['ai_context']!['active'],
          isTrue,
        );
        await capture(
          tester,
          'partial-uncertain',
          'Required revocation succeeds; optional write 503 → unresolved change and retry',
        );
        await tap(tester, find.text('Back'));
        await capture(
          tester,
          'uncertain-leave-confirm',
          'Back while result uncertain → explanation to re-read on return',
        );
        await tap(tester, find.text('Keep reviewing'));
        transport.writeStatus = null;
        transport.consentGate = null;
        await tap(tester, find.text('Try saving again'));
        expect(transport.consentWrites, hasLength(3));
        expect(transport.consentWrites[1], transport.consentWrites[2]);
        expect(
          transport.consentWrites.where((e) => e['scope'] == 'ibclc_case'),
          hasLength(1),
        );
        await capture(
          tester,
          'uncertain-retried',
          'Retry only unresolved optional write with same version; saved required scope not resent',
        );
        await finish(tester);
      },
    );
  }

  testWidgets('inventory privacy overview loading error and empty entry', (
    tester,
  ) async {
    await mount(
      tester,
      prepare: (t) => t.readGates['/v1/care/overview'] = Completer<void>(),
    );
    await entry(tester);
    await capture(
      tester,
      'overview-loading',
      'Privacy entry → overview HTTP pending',
    );
    transport.failingReads.add('/v1/care/overview');
    transport.readGates.remove('/v1/care/overview')!.complete();
    await settle(tester);
    await capture(
      tester,
      'overview-error',
      'Overview HTTP failure → error and retry',
    );
    transport.failingReads.clear();
    transport.emptyEpisodes = true;
    await tap(tester, find.text('Try again'));
    expect(find.byType(Switch), findsNothing);
    await capture(
      tester,
      'empty-services',
      'Retry with no owned services → empty state and no editable defaults',
    );
    await tap(tester, find.text('Back'));
    await capture(
      tester,
      'empty-back',
      'Empty page back → More',
      route: '/more',
    );
    await finish(tester);
  });

  testWidgets('inventory privacy consent read loading error retry and reread', (
    tester,
  ) async {
    await mount(
      tester,
      prepare: (t) => t.readGates[inventoryConsentPath] = Completer<void>(),
    );
    await entry(tester);
    await capture(
      tester,
      'consent-loading',
      'Overview loads → selected consent read pending',
    );
    transport.failingReads.add(inventoryConsentPath);
    transport.readGates.remove(inventoryConsentPath)!.complete();
    await settle(tester);
    expect(find.byType(Switch), findsNothing);
    await capture(
      tester,
      'consent-read-error',
      'Consent read fails → retry, no fake unchecked controls',
    );
    transport.failingReads.clear();
    await tap(tester, find.text('Try again'));
    await capture(
      tester,
      'consent-read-retried',
      'Retry consent HTTP → editable existing values',
    );
    await toggle(tester, CareConsentScope.aiContext);
    transport.writeStatus = 503;
    await tap(tester, find.text('Save changes'));
    await capture(
      tester,
      'optional-uncertain',
      'Optional write HTTP failure → uncertain state',
    );
    transport.writeStatus = null;
    await tap(tester, find.text('Reload consent'));
    expect(transport.consentWrites, hasLength(1));
    expect(
      tester.widget<Switch>(scope(CareConsentScope.aiContext)).value,
      isTrue,
    );
    await capture(
      tester,
      'reread',
      'Re-read discards unresolved draft; uses stored consent without retrying write',
    );
    await finish(tester);
  });

  testWidgets('inventory privacy conflict requires reloading before edit', (
    tester,
  ) async {
    await mount(tester);
    await entry(tester);
    await toggle(tester, CareConsentScope.aiContext);
    transport.writeStatus = 409;
    await tap(tester, find.text('Save changes'));
    expect(
      tester.widget<Switch>(scope(CareConsentScope.aiContext)).onChanged,
      isNull,
    );
    await capture(
      tester,
      'version-conflict',
      'Consent write 409 → reload required and switches locked',
    );
    transport.writeStatus = null;
    await tap(tester, find.text('Reload'));
    await capture(
      tester,
      'conflict-reloaded',
      'Reload latest consent versions → editing unlocked',
    );
    await toggle(tester, CareConsentScope.aiContext);
    await tap(tester, find.text('Save changes'));
    await capture(
      tester,
      'conflict-resaved',
      'Edit after reload → successful new save',
    );
    await finish(tester);
  });
}
