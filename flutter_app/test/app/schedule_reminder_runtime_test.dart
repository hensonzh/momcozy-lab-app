import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_reminder.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('same authenticated account preserves its native reminder gateway', () {
    final gateway = _RecordingReminderGateway();
    final initial = _runtime(userId: 'same-user', gateway: gateway);
    final controller = MomCozyRuntimeController(initial);
    addTearDown(controller.dispose);

    controller.replaceSession(
      initial.session.copyWith(accessToken: 'refreshed-access'),
    );

    expect(controller.runtime.scheduleReminderGateway, same(gateway));
    expect(gateway.calls, isEmpty);
  });

  test('logout and account switch cancel the previous owner alarms', () async {
    final logoutGateway = _RecordingReminderGateway();
    final logoutRuntime = _runtime(
      userId: 'logout-user',
      gateway: logoutGateway,
    );
    final logoutController = MomCozyRuntimeController(logoutRuntime);
    addTearDown(logoutController.dispose);

    logoutController.replaceSession(logoutRuntime.session.loggedOut());
    await Future<void>.delayed(Duration.zero);
    expect(logoutGateway.calls, [(enabled: false, taskCount: 0)]);

    final switchGateway = _RecordingReminderGateway();
    final switchRuntime = _runtime(
      userId: 'first-user',
      gateway: switchGateway,
    );
    final switchController = MomCozyRuntimeController(switchRuntime);
    addTearDown(switchController.dispose);

    switchController.replaceSession(
      switchRuntime.session.copyWith(
        userId: 'second-user',
        accessToken: 'second-access',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(switchGateway.calls, [(enabled: false, taskCount: 0)]);
  });
}

MomCozyApiRuntime _runtime({
  required String userId,
  required ScheduleReminderGateway gateway,
}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransport(const {}),
    scheduleReminderGateway: gateway,
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

class _RecordingReminderGateway implements ScheduleReminderGateway {
  final List<({bool enabled, int taskCount})> calls = [];

  @override
  bool get isSupported => true;

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required List<ScheduleTask> tasks,
  }) async {
    calls.add((enabled: enabled, taskCount: tasks.length));
    return true;
  }
}
