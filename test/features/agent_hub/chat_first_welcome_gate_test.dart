import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_welcome_coordinator.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_welcome_gate.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('an open chat prepares the next local day without app resume', (
    tester,
  ) async {
    var clock = DateTime(2026, 10, 15, 23, 59, 50);
    final product = FixtureApiJsonTransportByPath({
      '/v1/profile/me-experience': {
        'profile': {
          'age': 30,
          'delivery_count': 1,
          'actual_delivery_date': '2026-10-12',
          'gestation_weeks': 38,
          'gestation_days': 0,
          'baby_count': 1,
        },
        'concerns': <Object>[],
      },
    });
    final agent = FixtureApiJsonTransportByPath(const {
      '/v1/agent/threads': {'items': <Object>[]},
    });
    final coordinator = ChatFirstWelcomeCoordinator(
      product: product,
      agent: agent,
      store: MemoryChatFirstWelcomeStore(),
      ownerUserId: 'owner-1',
      role: FamilyRole.mother,
      now: () => clock,
    );
    Widget gate(bool visible) => MaterialApp(
      home: Scaffold(
        body: ChatFirstWelcomeGate(
          activationKey: 'owner-1',
          coordinator: coordinator,
          visible: visible,
          builder: (context, request, currentKey, accepted, rejected, retry) =>
              Text(currentKey, key: const ValueKey('welcome-key')),
        ),
      ),
    );
    await tester.pumpWidget(gate(true));
    await tester.pumpAndSettle();
    final first = tester
        .widget<Text>(find.byKey(const ValueKey('welcome-key')))
        .data!;
    expect(first, startsWith('chat-first-welcome:'));
    clock = DateTime(2026, 10, 16, 0, 0, 1);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    final next = tester
        .widget<Text>(find.byKey(const ValueKey('welcome-key')))
        .data!;
    expect(next, startsWith('chat-first-welcome:'));
    expect(next, isNot(first));
    expect(
      agent.getPaths.where((path) => path == '/v1/agent/threads'),
      hasLength(2),
    );
    await tester.pumpWidget(gate(false));
    clock = DateTime(2026, 10, 17, 0, 0, 1);
    await tester.pump(const Duration(days: 1));
    expect(
      agent.getPaths.where((path) => path == '/v1/agent/threads'),
      hasLength(2),
      reason: 'Hidden chat must not start another welcome at midnight.',
    );
    await tester.pumpWidget(gate(true));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('welcome-key'))).data,
      isNot(next),
    );
    expect(
      agent.getPaths.where((path) => path == '/v1/agent/threads'),
      hasLength(3),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'an existing registered account does not receive a new welcome after update',
    (tester) async {
      final coordinator = ChatFirstWelcomeCoordinator(
        product: FixtureApiJsonTransportByPath({
          '/v1/profile/me-experience': {
            'profile': {
              'age': 30,
              'delivery_count': 1,
              'actual_delivery_date': '2026-10-12',
              'gestation_weeks': 38,
              'gestation_days': 0,
              'baby_count': 1,
            },
            'concerns': <Object>[],
          },
        }),
        agent: FixtureApiJsonTransportByPath(const {
          '/v1/agent/threads': {
            'items': [
              {'id': 'old-thread'},
            ],
          },
          '/v1/agent/threads/old-thread/history': {
            'items': [
              {
                'role': 'user',
                'content': {'text': '过去的聊天'},
              },
            ],
            'next_before_sequence': null,
          },
        }),
        store: MemoryChatFirstWelcomeStore(),
        ownerUserId: 'registered-owner',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 25),
      );
      final result = await coordinator.prepareState();
      expect(result.request, isNull);
      expect((await coordinator.prepareState()).request, isNull);
    },
  );

  testWidgets(
    'failed preparation and rejected run keep chat usable and retryable',
    (tester) async {
      final product = FixtureApiJsonTransportByPath({});
      final agent = FixtureApiJsonTransportByPath(const {
        '/v1/agent/threads': {'items': <Object>[]},
      });
      final coordinator = ChatFirstWelcomeCoordinator(
        product: product,
        agent: agent,
        store: MemoryChatFirstWelcomeStore(),
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 15),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstWelcomeGate(
              activationKey: 'owner-1',
              coordinator: coordinator,
              visible: true,
              builder:
                  (
                    context,
                    request,
                    currentKey,
                    onAccepted,
                    onRejected,
                    retryToken,
                  ) => Column(
                    children: [
                      const Text('聊天仍可使用'),
                      Text(request?.idempotencyKey ?? 'none'),
                      Text('retry:$retryToken'),
                      TextButton(
                        onPressed: onRejected,
                        child: const Text('模拟运行失败'),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('聊天仍可使用'), findsOneWidget);
      expect(find.text('none'), findsOneWidget);
      expect(find.textContaining('欢迎语暂时无法生成'), findsOneWidget);

      product.responsesByPath['/v1/profile/me-experience'] = {
        'profile': {
          'age': 30,
          'delivery_count': 1,
          'actual_delivery_date': '2026-10-12',
          'gestation_weeks': 38,
          'gestation_days': 0,
          'baby_count': 1,
        },
        'concerns': <Object>[],
      };
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chat-first-welcome:'), findsOneWidget);
      await tester.tap(find.text('模拟运行失败'));
      await tester.pumpAndSettle();
      expect(find.textContaining('欢迎语暂时无法生成'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('retry:1'), findsOneWidget);
      expect(find.textContaining('欢迎语暂时无法生成'), findsNothing);
      expect(find.text('聊天仍可使用'), findsOneWidget);
    },
  );

  testWidgets(
    'gate prepares a real-profile run, marks accepted, and rechecks on return',
    (tester) async {
      final product = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': {
          'profile': {
            'age': 30,
            'delivery_count': 1,
            'actual_delivery_date': '2026-10-12',
            'gestation_weeks': 38,
            'gestation_days': 0,
            'baby_count': 1,
          },
          'concerns': <Object>[],
        },
      });
      final agent = FixtureApiJsonTransportByPath(const {
        '/v1/agent/threads': {'items': <Object>[]},
      });
      final store = MemoryChatFirstWelcomeStore();
      final coordinator = ChatFirstWelcomeCoordinator(
        product: product,
        agent: agent,
        store: store,
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 15),
      );
      Widget app(bool visible) => MaterialApp(
        home: Scaffold(
          body: ChatFirstWelcomeGate(
            activationKey: 'owner-1',
            coordinator: coordinator,
            visible: visible,
            builder:
                (
                  context,
                  request,
                  currentKey,
                  onAccepted,
                  onRejected,
                  retryToken,
                ) => Column(
                  children: [
                    Text(
                      request?.idempotencyKey ?? 'none',
                      key: const ValueKey('welcome-key'),
                    ),
                    ElevatedButton(
                      onPressed: request == null
                          ? null
                          : () => onAccepted(request.idempotencyKey),
                      child: const Text('accept'),
                    ),
                  ],
                ),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final initial = tester
          .widget<Text>(find.byKey(const ValueKey('welcome-key')))
          .data!;
      expect(initial, startsWith('chat-first-welcome:'));
      await tester.tap(find.text('accept'));
      await tester.pumpAndSettle();
      expect(find.text('none'), findsOneWidget);
      expect(await store.read('owner-1'), initial);
      await tester.pumpWidget(app(false));
      product.responsesByPath['/v1/profile/me-experience'] = {
        'profile': {
          'age': 31,
          'delivery_count': 1,
          'actual_delivery_date': '2026-10-12',
          'gestation_weeks': 38,
          'gestation_days': 0,
          'baby_count': 1,
        },
        'concerns': <Object>[],
      };
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final next = tester
          .widget<Text>(find.byKey(const ValueKey('welcome-key')))
          .data!;
      expect(next, isNot(initial));
    },
  );

  testWidgets(
    'foreground resume rechecks the same account without duplicating a welcome',
    (tester) async {
      final product = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': {
          'profile': {
            'age': 30,
            'delivery_count': 1,
            'actual_delivery_date': '2026-10-12',
            'gestation_weeks': 38,
            'gestation_days': 0,
            'baby_count': 1,
          },
          'concerns': <Object>[],
        },
      });
      final store = MemoryChatFirstWelcomeStore();
      final agent = FixtureApiJsonTransportByPath({
        '/v1/agent/threads': {'items': <Object>[]},
      });
      final coordinator = ChatFirstWelcomeCoordinator(
        product: product,
        agent: agent,
        store: store,
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 15),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstWelcomeGate(
              activationKey: 'owner-1',
              coordinator: coordinator,
              visible: true,
              builder:
                  (
                    context,
                    request,
                    currentKey,
                    onAccepted,
                    onRejected,
                    retryToken,
                  ) => Column(
                    children: [
                      Text(
                        currentKey,
                        key: const ValueKey('current-welcome-key'),
                      ),
                      Text(
                        request == null ? 'none' : 'pending',
                        key: const ValueKey('welcome-request-state'),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester
          .widget<Text>(find.byKey(const ValueKey('current-welcome-key')))
          .data!;
      await coordinator.markAccepted(first);
      agent.responsesByPath['/v1/agent/threads'] = const {
        'items': [
          {'id': 'thread-1'},
        ],
      };
      agent.responsesByPath['/v1/agent/threads/thread-1/history'] = {
        'items': [
          {
            'role': 'user',
            'content': {
              'text': '[Momcozy Chat 欢迎引导][${first.split(':').last}] 已创建',
              'client_context': {'source': 'chat_first_welcome'},
            },
          },
        ],
        'next_before_sequence': null,
      };

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('current-welcome-key')))
            .data,
        first,
      );
      expect(find.text('none'), findsOneWidget);

      product.responsesByPath['/v1/profile/me-experience'] = {
        'profile': {
          'age': 31,
          'delivery_count': 1,
          'actual_delivery_date': '2026-10-12',
          'gestation_weeks': 38,
          'gestation_days': 0,
          'baby_count': 1,
        },
        'concerns': <Object>[],
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final next = tester
          .widget<Text>(find.byKey(const ValueKey('current-welcome-key')))
          .data!;
      expect(next, first);
      expect(find.text('none'), findsOneWidget);
    },
  );
}
