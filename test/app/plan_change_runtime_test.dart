import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_change_persistence.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_change_store.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('same authenticated account preserves its Plan change store', () {
    final initial = _runtime(userId: 'same-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.planChangeStore.record(_change('same-event'));

    controller.replaceSession(
      initial.session.copyWith(accessToken: 'fresh-access'),
    );

    expect(controller.runtime.planChangeStore, same(initial.planChangeStore));
    expect(controller.runtime.planChangeStore.hasUnread, isTrue);
  });

  test('logout never inherits authenticated Plan notifications', () {
    final initial = _runtime(userId: 'logout-user');
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);
    initial.planChangeStore.record(_change('logout-event'));

    controller.replaceSession(initial.session.loggedOut());

    final loggedOutStore = controller.runtime.planChangeStore;
    expect(loggedOutStore, isNot(same(initial.planChangeStore)));
    expect(loggedOutStore.hasUnread, isFalse);
    final persistence =
        loggedOutStore.persistence! as FlutterSecurePlanChangePersistence;
    expect(persistence.userId, isEmpty);
  });

  test('user switch isolates late events delivered to the old runtime', () {
    final initial = _runtime(userId: 'first-user');
    final firstStore = initial.planChangeStore;
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);

    controller.replaceSession(
      initial.session.copyWith(
        userId: 'second-user',
        accessToken: 'second-access',
      ),
    );
    firstStore.record(_change('late-first-user-event'));

    expect(controller.runtime.planChangeStore, isNot(same(firstStore)));
    expect(controller.runtime.planChangeStore.hasUnread, isFalse);
    expect(firstStore.hasUnread, isTrue);
  });
}

MomCozyApiRuntime _runtime({required String userId}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransport(const {}),
    planChangeStore: PlanChangeStore(),
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

PlanChange _change(String eventId) => PlanChange(eventId: eventId);
