import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
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
import '../../support/notification_inventory_transport.dart';
import '../../support/notification_fakes.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late _Transport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late String variant;
  late String entry;
  var narrow = false;
  late FakePlatform permissions;
  late FakeGateway gateway;
  late NotificationCoordinator coordinator;
  Future<void> mount(
    WidgetTester tester, {
    void Function(_Transport)? prepare,
    void Function(FakePlatform, FakeGateway)? preparePlatform,
  }) async {
    previous = null;
    variant = narrow ? '320-2x' : '393-1x';
    tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    permissions = FakePlatform();
    gateway = FakeGateway();
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(narrow ? 320 : 393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _Transport();
    prepare?.call(transport);
    preparePlatform?.call(permissions, gateway);
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
    // The reminder remains busy underneath permission education until a choice.
    if (find.text('Receive reminders?').evaluate().isNotEmpty ||
        find.text('Notifications are off').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 8000));
      await tester.pumpAndSettle();
    }
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
    String route = '/notifications',
  }) async {
    if (route == '/more') {
      await tester.drag(find.byType(ListView).last, const Offset(0, 8000));
      await tester.pumpAndSettle();
      action = '$action; scroll More back to top';
    }
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final source =
        'test/goldens/ui_inventory/notification-navigation-current-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/notification-navigation-current-$state-$variant.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': router.state.uri.toString(),
      'trigger': action,
      'root_entry': 'Authenticated More page',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter, production notification coordinator/repository/controller; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push',
      'test':
          'test/features/notifications/notification_navigation_current_inventory_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/notification-navigation-current-$state-$variant.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  Future<void> inboxEntry(WidgetTester tester) async {
    await capture(
      tester,
      '$entry-more',
      'Authenticated More before notifications',
      route: '/more',
    );

    await tap(tester, find.text('通知'));
    expect(router.state.uri.path, '/notifications');
  }

  Future<void> dismissSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  const appointmentRoute =
      '/services/appointments/$inventoryNotificationAppointment';
  const uuid = '22222222-2222-4222-8222-222222222222';
  for (final compact in [false, true]) {
    for (final target in [
      'intake',
      'room',
      'summary',
      'episode',
      'conversation',
    ]) {
      testWidgets('notification safe target $target $compact', (tester) async {
        narrow = compact;
        entry = target;
        await mount(
          tester,
          prepare: (t) {
            t.seedInbox(1);
            if (target == 'episode') {
              t.episode!['id'] = uuid;
              t.appointment!['episode_id'] = uuid;
              t.target = '/services/episodes/$uuid';
            } else if (target == 'conversation') {
              t.target = '/?conversationId=$uuid';
            } else {
              t.target = '$appointmentRoute/$target';
              if (target == 'summary') {
                t.consultation(
                  status: 'closed',
                  roomStatus: 'closed',
                  endReason: 'completed',
                );
                t.publishSummary();
                t.failingReads.add(
                  '/v1/care/appointments/$inventoryNotificationAppointment/summary',
                );
              }
            }
          },
        );
        await inboxEntry(tester);
        await capture(
          tester,
          '$target-inbox',
          'Notification center before $target target',
        );
        if (target == 'conversation') {
          await tester.ensureVisible(find.text('Service update 1'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Service update 1'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final failure = tester.takeException();
          expect(failure, isArgumentError);
          expect(failure.toString(), contains('Cannot be a string'));
          expect(find.byType(ErrorWidget), findsOneWidget);
        } else {
          await tap(tester, find.text('Service update 1'));
        }
        await tester.pumpAndSettle();
        final route = Uri.parse(transport.target).path;
        expect(router.state.uri.path, route);
        expect(transport.notifications.single['status'], 'read');
        if (target == 'conversation') {
          expect(router.state.uri.queryParameters['conversationId'], uuid);
          expect(find.text('Notification conversation fixture.'), findsNothing);
        }
        if (target == 'summary') {
          expect(find.text('暂时无法读取总结'), findsOneWidget);
          await capture(
            tester,
            'summary-load-error',
            'Notification → summary GET 503 → unavailable card with retry',
            route: route,
          );
          transport.failingReads.clear();
          await tap(tester, find.text('重新加载'));
          expect(find.text('暂时无法读取总结'), findsNothing);
          expect(find.text('Published client-facing summary'), findsOneWidget);
        }
        await capture(
          tester,
          '$target-opened',
          target == 'conversation'
              ? 'Tap notification → conversation route throws Expando string-key ArgumentError and renders ErrorWidget; item is read'
              : 'Tap notification → validated $target target, notification marked read',
          route: route,
        );
        if (target == 'conversation') {
          await tap(tester, find.text('More'));
          await capture(
            tester,
            '$target-more-return',
            'Conversation More tab → no unread badge',
            route: '/more',
          );
          await tap(tester, find.text('通知'));
        } else {
          await tap(
            tester,
            target == 'room' ? find.byTooltip('关闭预约详情') : find.text('返回').first,
          );
          await capture(
            tester,
            '$target-home-return',
            'Target Back/Close → mother home (notification route was replaced)',
            route: '/me',
          );
          await tap(tester, find.text('More'));
          await capture(
            tester,
            '$target-more-return',
            'Mother home More tab → updated unread badge',
            route: '/more',
          );
          await tap(tester, find.text('通知'));
        }
        await capture(
          tester,
          '$target-inbox-return',
          'Target return → notification center with read item',
        );
        await tap(tester, find.byTooltip('Back'));
        await capture(
          tester,
          '$target-final-more',
          'Notification center back → More',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets(
      'notification unsafe target and forbidden not found requests $compact',
      (tester) async {
        narrow = compact;
        entry = 'rejections';
        await mount(
          tester,
          prepare: (t) {
            t.seedInbox(3);
            t.target = '/privacy';
          },
        );
        await inboxEntry(tester);
        await capture(
          tester,
          'rejection-inbox',
          'Three unread updates before route validation',
        );
        await tap(tester, find.text('Service update 1'));
        expect(router.state.uri.path, '/notifications');
        expect(
          find.text('This update is no longer available.'),
          findsOneWidget,
        );
        expect(transport.notifications.first['status'], 'read');
        await capture(
          tester,
          'rejection-unsafe-route',
          'Server target outside allowed notification routes → no navigation, unavailable Snackbar',
        );
        await dismissSnackbar(tester);
        for (final code in [403, 404]) {
          transport.openFailure = code;
          await tap(tester, find.text('Service update 2'));
          expect(router.state.uri.path, '/notifications');
          expect(transport.notifications[1]['status'], 'unread');
          await capture(
            tester,
            'rejection-$code',
            'Open notification returns $code → retained unread item and open-error Snackbar',
          );
          await dismissSnackbar(tester);
          await capture(
            tester,
            'rejection-$code-dismissed',
            'Open-error feedback timeout → retained notification center',
          );
        }
        transport.openFailure = null;
        transport.target = appointmentRoute;
        await tap(tester, find.text('Service update 2'));
        await capture(
          tester,
          'rejection-recovered-target',
          'Retry after access restoration → appointment detail',
          route: appointmentRoute,
        );
        await tap(tester, find.text('返回').first);
        await capture(
          tester,
          'rejection-recovered-inbox',
          'Appointment return → unread count updated',
        );
        await tap(tester, find.byTooltip('Back'));
        await capture(
          tester,
          'rejection-more-return',
          'Notification center back → More',
          route: '/more',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _Transport extends NotificationInventoryTransport {
  String target = '/services/appointments/$inventoryNotificationAppointment';
  int? openFailure;
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.endsWith('/open') && openFailure != null) {
      await writeNotification(path, body);
      throw ApiHttpException(
        statusCode: openFailure!,
        statusText: 'Isolated notification rejection',
        body: const {},
      );
    }
    final result = await super.postJson(path, body: body, headers: headers);
    if (path.endsWith('/open')) {
      return {...result, 'route': target};
    }
    return result;
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path.startsWith('/v1/agent/threads/') && path.endsWith('/history')) {
      await readNotification(path);
      return {
        'thread': {
          'id': path.split('/')[4],
          'title': 'Notification conversation',
          'status': 'active',
          'created_at': inventoryMomNow.toIso8601String(),
          'updated_at': inventoryMomNow.toIso8601String(),
        },
        'items': [
          {
            'id': 'notification-history-message',
            'role': 'assistant',
            'content': {'text': 'Notification conversation fixture.'},
          },
        ],
        'events': [],
        'next_before_sequence': null,
      };
    }
    return super.getJson(path, query: query);
  }
}
