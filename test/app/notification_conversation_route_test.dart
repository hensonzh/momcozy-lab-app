import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

import '../support/fixture_api_transport.dart';
import '../support/mom_inventory_transport.dart';
import '../support/momcozy_test_fonts.dart';
import '../support/notification_fakes.dart';
import '../support/notification_inventory_transport.dart';

const _first = '22222222-2222-4222-8222-222222222222';
const _second = '33333333-3333-4333-8333-333333333333';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final (width, scale) in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'notification conversation opens and keeps drafts scoped to its runtime and thread $width / $scale',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final transport = _ConversationTransport()..seedInbox(1);
        const session = MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'route-user',
          babyId: 'route-baby',
          locale: 'en',
          accessToken: 'fixture-access',
          refreshToken: 'fixture-refresh',
        );
        MomCozyApiRuntime newRuntime() => MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: FixtureApiMultipartTransport({}),

          session: session,
          now: () => inventoryMomNow,
          timezoneProvider: () async => 'Asia/Shanghai',
        );
        final runtime = MomCozyRuntimeController(newRuntime());
        final store = MemoryMomCozySessionStore(session);
        final platform = FakeRouteIntentPlatform();
        final router = createMomCozyRouter(
          initialLocation: '/notifications',
          runtimeController: runtime,
          sessionStore: store,
        );
        final coordinator = NotificationCoordinator(
          permission: NotificationPermissionController(FakePlatform()),
          gateway: FakeGateway(),
          store: FakeStore(),
          platformName: 'android',
          onNavigate: router.go,
          onMessage: (_) {},
          onForeground: (_) {},
        );
        addTearDown(() async {
          coordinator.dispose();
          router.dispose();
          runtime.dispose();
          await platform.dispose();
        });
        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: router,
            runtimeController: runtime,
            sessionStore: store,
            routeIntentPlatform: platform,
            notificationCoordinator: coordinator,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Service update 1'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.byType(AgentHubPage, skipOffstage: false), findsOneWidget);
        expect(router.state.uri.queryParameters['conversationId'], _first);
        expect(transport.notifications.single['status'], 'read');
        await tester.scrollUntilVisible(
          find.text('History for $_first'),
          -240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('History for $_first'), findsOneWidget);
        expect(
          transport.getPaths,
          contains('/v1/agent/threads/$_first/history'),
        );

        final context = tester.element(find.byType(Scaffold).first);
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(MomCozyAssets.agentAvatar),
            context,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MomCozyFlutterApp),
          matchesGoldenFile(
            '../goldens/design_system/notification-conversation-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );

        expect(find.byTooltip('打开会话历史'), findsNothing);
        expect(
          find.byKey(const ValueKey('agent-new-session-button')),
          findsNothing,
        );
        expect(transport.getPaths, isNot(contains('/v1/agent/threads')));
        final inventoryOutput =
            Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
        if (inventoryOutput != null) {
          final source =
              'test/goldens/design_system/notification-conversation-${width.toInt()}-${scale.toInt()}x.png';
          final file = File(
            '$inventoryOutput/journeys/notification-conversation-current-${width.toInt()}.json',
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(
            jsonEncode({
              'source': source,
              'previous_source': null,
              'route': router.state.uri.toString(),
              'trigger':
                  'Notification list → Service update 1 → target transcript loads without history-management controls',
              'root_entry': 'Authenticated notification list',
              'evidence':
                  'Actual default MomCozyFlutterApp/createMomCozyRouter; isolated HTTP and native channels; target transcript loads; session list and history drawer are removed',
              'test': 'test/app/notification_conversation_route_test.dart',
            }),
          );
        }

        final composer = find.byKey(const ValueKey('agent-composer-input'));
        String draft() => tester.widget<TextField>(composer).controller!.text;
        await tester.enterText(composer, 'Draft for first conversation');
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        router.go('/?conversationId=$_second');
        await tester.pumpAndSettle();
        expect(draft(), isEmpty);
        await tester.scrollUntilVisible(
          find.text('History for $_second'),
          -240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('History for $_second'), findsOneWidget);
        await tester.enterText(composer, 'Draft for second conversation');

        router.go('/?conversationId=$_first');
        await tester.pumpAndSettle();
        expect(draft(), 'Draft for first conversation');
        expect(find.text('History for $_second'), findsNothing);
        router.go('/?conversationId=$_second');
        await tester.pumpAndSettle();
        expect(draft(), 'Draft for second conversation');

        // A fresh authenticated runtime, even for the same user, must not reuse
        // private in-memory interaction state from the previous login.
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        // Simulate the cleared persistent session on logout; the new runtime
        // must also discard the previous runtime's in-memory per-thread cache.
        FlutterSecureStorage.setMockInitialValues({});
        runtime.replaceRuntime(newRuntime());
        await tester.pumpAndSettle();
        router.go('/?conversationId=$_first');
        await tester.pumpAndSettle();
        expect(draft(), isEmpty);
        await tester.scrollUntilVisible(
          find.text('History for $_first'),
          -240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('History for $_first'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _ConversationTransport extends NotificationInventoryTransport {
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final result = await super.postJson(path, body: body, headers: headers);
    return path.endsWith('/open')
        ? {...result, 'route': '/?conversationId=$_first'}
        : result;
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/agent/threads') {
      await readNotification(path);
      return {
        'items': [
          for (final id in [_first, _second])
            {
              'id': id,
              'title': 'Notification conversation $id',
              'status': 'active',
              'created_at': inventoryMomNow.toIso8601String(),
              'updated_at': inventoryMomNow.toIso8601String(),
            },
        ],
      };
    }
    if (path.startsWith('/v1/agent/threads/') && path.endsWith('/history')) {
      await readNotification(path);
      final id = path.split('/')[4];
      return {
        'thread': {
          'id': id,
          'title': 'Notification conversation',
          'status': 'active',
          'created_at': inventoryMomNow.toIso8601String(),
          'updated_at': inventoryMomNow.toIso8601String(),
        },
        'items': [
          {
            'id': 'message-$id',
            'role': 'assistant',
            'content': {'text': 'History for $id'},
          },
        ],
        'events': [],
        'next_before_sequence': null,
      };
    }
    return super.getJson(path, query: query);
  }
}
