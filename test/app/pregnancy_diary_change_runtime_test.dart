import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/core/agent_stream/agent_stream_event.dart';
import 'package:app/core/auth/momcozy_session.dart';
import 'package:app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';
import 'package:app/features/status/presentation/status_dashboard_cache.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('pregnancy diary unread state is scoped to its runtime', () {
    final first = _runtime(userId: 'first-user');
    final second = _runtime(userId: 'second-user');

    first.pregnancyDiaryChangeStore.record(_change());

    expect(first.pregnancyDiaryChangeStore.hasUnread, isTrue);
    expect(second.pregnancyDiaryChangeStore.hasUnread, isFalse);
    expect(
      second.pregnancyDiaryChangeStore,
      isNot(same(first.pregnancyDiaryChangeStore)),
    );
  });

  test('recording an Agent diary change invalidates the shared cache', () {
    final runtime = _runtime(userId: 'cache-user');
    runtime.statusDashboardCache.pregnancyDiaryEntries = StatusCacheEntry(
      value: [
        PregnancyDiaryEntry(
          id: 'cached-diary',
          entryDate: DateTime(2026, 7, 12),
          content: 'cached',
        ),
      ],
      fetchedAt: DateTime(2026, 7, 12, 8),
    );

    expect(runtime.recordPregnancyDiaryChange(_change()), isTrue);

    expect(runtime.statusDashboardCache.pregnancyDiaryEntries, isNull);
    expect(runtime.pregnancyDiaryChangeStore.hasUnread, isTrue);
  });

  test('same-user session refresh preserves the runtime-scoped store', () {
    final initial = _runtime(userId: 'same-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.pregnancyDiaryChangeStore.record(_change());

    controller.replaceSession(
      initial.session.copyWith(
        accessToken: 'fresh-access',
        refreshToken: 'fresh-refresh',
      ),
    );

    expect(
      controller.runtime.pregnancyDiaryChangeStore,
      same(initial.pregnancyDiaryChangeStore),
    );
    expect(controller.runtime.pregnancyDiaryChangeStore.hasUnread, isTrue);
  });

  test('switching users does not carry pregnancy diary unread state', () {
    final initial = _runtime(userId: 'first-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.pregnancyDiaryChangeStore.record(_change());

    controller.replaceSession(
      initial.session.copyWith(
        userId: 'second-user',
        accessToken: 'second-access',
      ),
    );

    expect(
      controller.runtime.pregnancyDiaryChangeStore,
      isNot(same(initial.pregnancyDiaryChangeStore)),
    );
    expect(controller.runtime.pregnancyDiaryChangeStore.hasUnread, isFalse);
  });
}

MomCozyApiRuntime _runtime({required String userId}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransport(const {}),
    pregnancyDiaryChangeStore: PregnancyDiaryChangeStore(),
    session: MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: userId,
      babyId: '$userId-baby',
      locale: 'zh-CN',
      accessToken: '$userId-access',
      refreshToken: '$userId-refresh',
    ),
  );
}

PregnancyDiaryChange _change() {
  return PregnancyDiaryChange.tryFromEvent(
    AgentStreamEvent(const {
      'event_id': 'evt-runtime-diary-change',
      'type': 'pregnancy_diary.changed',
      'payload': {
        'operation': 'created',
        'entry_id': 'diary-runtime',
        'entry_date': '2026-07-12',
        'updated_at': '2026-07-12T08:30:00Z',
        'source': 'agent',
      },
    }),
  )!;
}
