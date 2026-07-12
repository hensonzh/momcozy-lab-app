import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_change_persistence.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('pregnancy plan unread state is scoped to its runtime', () {
    final first = _runtime(userId: 'first-user');
    final second = _runtime(userId: 'second-user');

    first.pregnancyPlanChangeStore.record(_change());

    expect(first.pregnancyPlanChangeStore.hasUnread, isTrue);
    expect(second.pregnancyPlanChangeStore.hasUnread, isFalse);
    expect(
      second.pregnancyPlanChangeStore,
      isNot(same(first.pregnancyPlanChangeStore)),
    );
  });

  test('same-user session refresh preserves the runtime-scoped store', () {
    final initial = _runtime(userId: 'same-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.pregnancyPlanChangeStore.record(_change());

    controller.replaceSession(
      initial.session.copyWith(
        accessToken: 'fresh-access',
        refreshToken: 'fresh-refresh',
      ),
    );

    expect(
      controller.runtime.pregnancyPlanChangeStore,
      same(initial.pregnancyPlanChangeStore),
    );
    expect(controller.runtime.pregnancyPlanChangeStore.hasUnread, isTrue);
  });

  test('switching users does not carry pregnancy plan unread state', () {
    final initial = _runtime(userId: 'first-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.pregnancyPlanChangeStore.record(_change());

    controller.replaceSession(
      initial.session.copyWith(
        userId: 'second-user',
        accessToken: 'second-access',
      ),
    );

    expect(
      controller.runtime.pregnancyPlanChangeStore,
      isNot(same(initial.pregnancyPlanChangeStore)),
    );
    expect(controller.runtime.pregnancyPlanChangeStore.hasUnread, isFalse);
  });

  test(
    'logout drops the authenticated plan store and uses anonymous scope',
    () {
      final initial = _runtime(userId: 'logout-user');
      final controller = MomCozyRuntimeController(initial);
      addTearDown(controller.dispose);
      initial.pregnancyPlanChangeStore.record(_change());

      controller.replaceSession(initial.session.loggedOut());

      final loggedOutStore = controller.runtime.pregnancyPlanChangeStore;
      expect(loggedOutStore, isNot(same(initial.pregnancyPlanChangeStore)));
      expect(loggedOutStore.hasUnread, isFalse);
      final persistence = loggedOutStore.persistence;
      expect(persistence, isA<FlutterSecurePregnancyPlanChangePersistence>());
      expect(
        (persistence! as FlutterSecurePregnancyPlanChangePersistence).userId,
        isEmpty,
      );
    },
  );
}

MomCozyApiRuntime _runtime({required String userId}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransport(const {}),
    pregnancyPlanChangeStore: PregnancyPlanChangeStore(),
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

PregnancyPlanChange _change() {
  return PregnancyPlanChange.tryFromEvent(
    AgentStreamEvent(const {
      'event_id': 'evt-runtime-plan-change',
      'type': 'pregnancy_plan.changed',
      'payload': {
        'operation': 'created',
        'plan_id': 'plan-runtime',
        'plan_type': 'pregnancy',
        'source': 'agent_action',
        'action_id': 'action-runtime',
      },
    }),
  )!;
}
