import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('default runtime builds JSON transport from dart-define defaults', () {
    final runtime = MomCozyApiRuntime.fromEnvironment();
    final transport = runtime.jsonTransport as IoApiJsonTransport;

    expect(runtime.userId, 'demo-user');
    expect(runtime.babyId, 'demo-baby');
    expect(runtime.locale, 'zh-CN');
    expect(transport.baseUri, Uri.parse('http://127.0.0.1:8769'));
    expect(transport.token, isNull);
    expect(transport.headers, containsPair('X-Momcozy-Client', 'flutter'));
  });

  test('runtime creates typed repositories over the injected transport', () {
    final transport = FixtureApiJsonTransport({
      'status': 200,
      'data': {
        'mom': {'stage': 'postpartum', 'postpartum_day': 21},
      },
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );

    expect(runtime.statusRepository, isA<StatusApiRepository>());
    expect(runtime.scheduleRepository.transport, same(transport));
    expect(runtime.recordsRepository.transport, same(transport));
    expect(runtime.pumpWorkstateRepository.transport, same(transport));
  });

  test('runtime exposes an injected BLE platform lazily', () async {
    final ble = FakeBlePlatform(
      initialPermission: BlePermissionState.granted,
      seedDevices: const [
        BleDeviceSnapshot(
          side: 'L',
          deviceId: 'ble-left-fixture',
          deviceName: 'S12 Pro L',
          connected: true,
        ),
      ],
    );
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport({'status': 200, 'data': {}}),
      blePlatform: ble,
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );

    expect(runtime.blePlatform, same(ble));
    expect(await runtime.blePlatform.getConnectedDevices(), hasLength(1));
    await ble.dispose();
  });

  testWidgets('runtime scope exposes the injected runtime', (tester) async {
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport({'status': 200, 'data': {}}),
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );
    MomCozyApiRuntime? resolved;

    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: Builder(
          builder: (context) {
            resolved = MomCozyRuntimeScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved, same(runtime));
  });
}
