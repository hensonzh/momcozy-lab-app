import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_welcome_coordinator.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  Map<String, Object?> profile(int age) => {
    'profile': {
      'age': age,
      'delivery_count': 1,
      'actual_delivery_date': '2026-10-12',
      'gestation_weeks': 38,
      'gestation_days': 0,
      'baby_count': 1,
    },
    'concerns': const <Object>[],
  };

  test(
    'first welcome is requested, durable history survives reload, changes create a new key',
    () async {
      final saved = MemoryChatFirstWelcomeStore();
      final product = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile(30),
      });
      final agent = FixtureApiJsonTransportByPath({
        '/v1/agent/threads': {'items': <Object>[]},
      });
      ChatFirstWelcomeCoordinator coordinator(DateTime now) =>
          ChatFirstWelcomeCoordinator(
            product: product,
            agent: agent,
            store: saved,
            ownerUserId: 'owner-1',
            role: FamilyRole.mother,
            now: () => now,
          );
      final first = await coordinator(DateTime(2026, 10, 15)).prepare();
      expect(first, isNotNull);
      expect(agent.getPaths, ['/v1/agent/threads']);
      await coordinator(
        DateTime(2026, 10, 15),
      ).markAccepted(first!.idempotencyKey);
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
              'text': first.message,
              'client_context': {'source': 'chat_first_welcome'},
            },
          },
        ],
        'next_before_sequence': null,
      };
      expect(await coordinator(DateTime(2026, 10, 15)).prepare(), isNull);
      expect(agent.getPaths, contains('/v1/agent/threads/thread-1/history'));
      final nextDay = await coordinator(DateTime(2026, 10, 16)).prepare();
      expect(nextDay, isNotNull);
      expect(nextDay?.idempotencyKey, isNot(first.idempotencyKey));
      product.responsesByPath['/v1/profile/me-experience'] = profile(31);
      final changed = await coordinator(DateTime(2026, 10, 15)).prepare();
      expect(changed, isNotNull);
      expect(changed?.idempotencyKey, isNot(first.idempotencyKey));
    },
  );

  test(
    'a local receipt without a durable run must retry with the same key',
    () async {
      final product = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile(30),
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
      final first = (await coordinator.prepare())!;
      await coordinator.markAccepted(first.idempotencyKey);
      final recovered = await coordinator.prepare();
      expect(recovered?.idempotencyKey, first.idempotencyKey);
      expect(agent.getPaths, ['/v1/agent/threads', '/v1/agent/threads']);
    },
  );

  test(
    'history marker stops duplicate welcome when local receipt is missing',
    () async {
      final product = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile(30),
      });
      final initial = ChatFirstWelcomeCoordinator(
        product: product,
        agent: FixtureApiJsonTransportByPath(const {
          '/v1/agent/threads': {'items': <Object>[]},
        }),
        store: MemoryChatFirstWelcomeStore(),
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 15),
      );
      final first = (await initial.prepare())!;
      final agent = FixtureApiJsonTransportByPath({
        '/v1/agent/threads': const {
          'items': [
            {'id': 'thread-1'},
          ],
        },
        '/v1/agent/threads/thread-1/history': {
          'items': [
            {
              'role': 'user',
              'content': {
                'text': first.message,
                'client_context': {'source': 'chat_first_welcome'},
              },
            },
          ],
          'next_before_sequence': null,
        },
      });
      final store = MemoryChatFirstWelcomeStore();
      final recovered = ChatFirstWelcomeCoordinator(
        product: product,
        agent: agent,
        store: store,
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 15),
      );
      expect(await recovered.prepare(), isNull);
      expect(await store.read('owner-1'), first.idempotencyKey);
    },
  );

  test(
    'old signed welcomes and shared prefix cannot suppress a new profile',
    () async {
      final product = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile(30),
      });
      final emptyAgent = FixtureApiJsonTransportByPath(const {
        '/v1/agent/threads': {'items': <Object>[]},
      });
      ChatFirstWelcomeCoordinator coordinator(
        FixtureApiJsonTransportByPath agent,
        ChatFirstWelcomeStore store,
      ) => ChatFirstWelcomeCoordinator(
        product: product,
        agent: agent,
        store: store,
        ownerUserId: 'owner-1',
        role: FamilyRole.mother,
        now: () => DateTime(2026, 10, 15),
      );
      final old = (await coordinator(
        emptyAgent,
        MemoryChatFirstWelcomeStore(),
      ).prepare())!;
      product.responsesByPath['/v1/profile/me-experience'] = profile(31);
      final newRequest = (await coordinator(
        emptyAgent,
        MemoryChatFirstWelcomeStore(),
      ).prepare())!;
      final receipt = MemoryChatFirstWelcomeStore();
      await receipt.save('owner-1', newRequest.idempotencyKey);
      final history = FixtureApiJsonTransportByPath({
        '/v1/agent/threads': const {
          'items': [
            {'id': 'thread-1'},
          ],
        },
        '/v1/agent/threads/thread-1/history': {
          'items': [
            {
              'role': 'user',
              'content': {
                'text': old.message,
                'client_context': {'source': 'chat_first_welcome'},
              },
            },
            {
              'role': 'user',
              'content': {
                'text': '[Momcozy unexpected text]',
                'client_context': {'source': 'chat_first_welcome'},
              },
            },
          ],
          'next_before_sequence': null,
        },
      });
      final prepared = await coordinator(history, receipt).prepare();
      expect(prepared?.idempotencyKey, newRequest.idempotencyKey);
      expect(prepared!.idempotencyKey, isNot(old.idempotencyKey));
    },
  );

  test(
    'non-mother never reads maternal facts or sends a synthetic welcome',
    () async {
      final product = FixtureApiJsonTransportByPath(const {});
      final agent = FixtureApiJsonTransportByPath(const {});
      final coordinator = ChatFirstWelcomeCoordinator(
        product: product,
        agent: agent,
        store: MemoryChatFirstWelcomeStore(),
        ownerUserId: 'father-1',
        role: FamilyRole.father,
        now: () => DateTime(2026, 10, 15),
      );
      expect(await coordinator.prepare(), isNull);
      expect(product.getPaths, isEmpty);
      expect(agent.getPaths, isEmpty);
    },
  );

  test('local receipt and hash never cross account identities', () async {
    final store = MemoryChatFirstWelcomeStore();
    final product = FixtureApiJsonTransportByPath({
      '/v1/profile/me-experience': profile(30),
    });
    final agent = FixtureApiJsonTransportByPath(const {
      '/v1/agent/threads': {'items': <Object>[]},
    });
    ChatFirstWelcomeCoordinator forOwner(String owner) =>
        ChatFirstWelcomeCoordinator(
          product: product,
          agent: agent,
          store: store,
          ownerUserId: owner,
          role: FamilyRole.mother,
          now: () => DateTime(2026, 10, 15),
        );
    final first = (await forOwner('owner-1').prepare())!;
    await forOwner('owner-1').markAccepted(first.idempotencyKey);
    expect(
      (await forOwner('owner-1').prepare())?.idempotencyKey,
      first.idempotencyKey,
    );
    final second = (await forOwner('owner-2').prepare())!;
    expect(second.idempotencyKey, isNot(first.idempotencyKey));
    expect(await store.read('owner-2'), isNull);
    await forOwner('owner-2').markAccepted(second.idempotencyKey);
    expect(await store.read('owner-1'), first.idempotencyKey);
    expect(await store.read('owner-2'), second.idempotencyKey);
  });
}
