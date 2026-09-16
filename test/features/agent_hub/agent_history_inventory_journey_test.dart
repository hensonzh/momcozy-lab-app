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
import '../../support/agent_history_inventory_transport.dart';
import '../../support/notification_fakes.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late AgentHistoryInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late FakePlatform permissions;
  late FakeGateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentHistoryInventoryTransport)? prepare,
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
    transport = AgentHistoryInventoryTransport();
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
    String route = '/',
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
        'test/goldens/ui_inventory/agent-history-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/agent-history-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': router.state.uri.toString(),
      'trigger': action,
      'root_entry': 'Authenticated More page',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, notification coordinator and default Agent builder; isolated notification HTTP and push/permission boundaries. Target route crashes before history repository invocation; no page/feature flag override.',
      'test':
          'test/features/agent_hub/agent_history_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/agent-history-journey-$state-$suffix.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  final errorDetails = <FlutterErrorDetails>[];
  Future<void> observeFailure(
    WidgetTester tester,
    Future<void> Function() action, {
    required bool initializing,
  }) async {
    errorDetails.clear();
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errorDetails.add(details);
      oldHandler?.call(details);
    };
    try {
      await action();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final error = tester.takeException();
      if (initializing) {
        expect(error, isA<ArgumentError>());
        expect(error.toString(), contains('Cannot be a string'));
        expect(
          errorDetails.single.stack.toString(),
          contains('_restoreCachedInteractionState'),
        );
      } else {
        expect(error, isNull);
        expect(errorDetails, isEmpty);
      }
      final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
      if (output != null) {
        final width = tester.view.physicalSize.width.round();
        File(
          '$output/agent-target-${initializing ? 'init' : 'dispose'}-$width-error.txt',
        ).writeAsStringSync(
          errorDetails
              .map((e) => '${e.exceptionAsString()}\n${e.stack}')
              .join('\n'),
        );
      }
    } finally {
      FlutterError.onError = oldHandler;
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'inventory notification conversation actual initialization error ${size.$1}',
      (tester) async {
        await mount(tester, width: size.$1, textScale: size.$2);
        await tap(tester, find.text('通知'));
        await capture(
          tester,
          'notification-entry',
          'More → notification inbox with conversation update',
          route: '/notifications',
        );
        await observeFailure(
          tester,
          () => tester.tap(find.text('Conversation ready')),
          initializing: true,
        );
        expect(
          router.state.uri.toString(),
          '/?conversationId=$inventoryHistoryThread',
        );
        expect(find.byType(ErrorWidget), findsOneWidget);
        expect(
          transport.getPaths.where((e) => e.startsWith('/v1/agent/threads')),
          isEmpty,
        );
        expect(
          transport.requests.any(
            (e) => e['path'] == '/v1/notifications/notice-1/open',
          ),
          isTrue,
        );
        await capture(
          tester,
          'target-error',
          'Open notification → default target route throws ArgumentError for string Expando key before history HTTP',
        );
        await observeFailure(
          tester,
          () => tester.tap(find.text('More')),
          initializing: false,
        );
        expect(router.state.uri.path, '/more');
        await capture(
          tester,
          'error-away',
          'Bottom More → leave failed target route; More renders without another exception',
          route: '/more',
        );
        await tap(tester, find.text('Cozymate'));
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.byTooltip('打开会话历史'), findsNothing);
        await capture(
          tester,
          'default-recovered',
          'Bottom Cozymate → normal / page recovers without history button',
        );
        await tap(tester, find.text('More'));
        await tap(tester, find.text('通知'));
        expect(transport.notifications.single['status'], 'read');
        await capture(
          tester,
          'read-notification',
          'Return to inbox → conversation notification marked read despite target initialization error',
          route: '/notifications',
        );
        await finish(tester);
      },
    );
    testWidgets(
      'inventory notification conversation rejected targets ${size.$1}',
      (tester) async {
        await mount(tester, width: size.$1, textScale: size.$2);
        await tap(tester, find.text('通知'));
        for (final item in [
          ('invalid-id', '/?conversationId=not-a-uuid'),
          ('extra-query', '/?conversationId=$inventoryHistoryThread&extra=1'),
          (
            'external-target',
            'https://example.invalid/?conversationId=$inventoryHistoryThread',
          ),
        ]) {
          transport.targetRoute = item.$2;
          await tap(tester, find.text('Conversation ready'));
          expect(router.state.uri.path, '/notifications');
          expect(find.byType(SnackBar), findsOneWidget);
          await capture(
            tester,
            item.$1,
            'Open notification → route allowlist rejects ${item.$1}; inbox and message retained',
            route: '/notifications',
          );
          await tester.drag(find.byType(SnackBar), const Offset(0, 200));
          await tester.pumpAndSettle();
        }
        expect(
          transport.getPaths.where((e) => e.startsWith('/v1/agent/threads')),
          isEmpty,
        );
        await capture(
          tester,
          'rejected-dismissed',
          'Dismiss target unavailable message → read inbox remains',
          route: '/notifications',
        );
        await finish(tester);
      },
    );
  }
}
