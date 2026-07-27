import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/core/auth/momcozy_session.dart';
import 'package:app/features/schedule/data/milk_plan_change_persistence.dart';
import 'package:app/features/schedule/domain/milk_plan_change_store.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('same authenticated account preserves its milk plan store', () {
    final initial = _runtime(userId: 'same-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.milkPlanChangeStore.record(_change('same-event'));

    controller.replaceSession(
      initial.session.copyWith(accessToken: 'fresh-access'),
    );

    expect(
      controller.runtime.milkPlanChangeStore,
      same(initial.milkPlanChangeStore),
    );
    expect(controller.runtime.milkPlanChangeStore.hasUnread, isTrue);
  });

  test('logout never inherits authenticated milk plan dates', () {
    final initial = _runtime(userId: 'logout-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.milkPlanChangeStore.record(_change('logout-event'));

    controller.replaceSession(initial.session.loggedOut());

    final loggedOutStore = controller.runtime.milkPlanChangeStore;
    expect(loggedOutStore, isNot(same(initial.milkPlanChangeStore)));
    expect(loggedOutStore.hasUnread, isFalse);
    final persistence =
        loggedOutStore.persistence! as FlutterSecureMilkPlanChangePersistence;
    expect(persistence.userId, isEmpty);
  });

  test('user switch isolates late events delivered to the old runtime', () {
    final initial = _runtime(userId: 'first-user');
    final firstStore = initial.milkPlanChangeStore;
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);

    controller.replaceSession(
      initial.session.copyWith(
        userId: 'second-user',
        accessToken: 'second-access',
      ),
    );
    firstStore.record(_change('late-first-user-event'));

    expect(controller.runtime.milkPlanChangeStore, isNot(same(firstStore)));
    expect(controller.runtime.milkPlanChangeStore.hasUnread, isFalse);
    expect(firstStore.hasUnread, isTrue);
  });
}

MomCozyApiRuntime _runtime({required String userId}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransport(const {}),
    milkPlanChangeStore: MilkPlanChangeStore(),
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

MilkPlanChange _change(String eventId) {
  return MilkPlanChange(
    eventId: eventId,
    operation: MilkPlanChangeOperation.updated,
    affectedDateKeys: const ['2026-07-13'],
  );
}
