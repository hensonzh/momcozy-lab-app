import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_content_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_native_runtime_coordinator.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('default runtime builds JSON transport from dart-define defaults', () {
    final runtime = MomCozyApiRuntime.fromEnvironment();
    final observed = runtime.jsonTransport as ObservedApiJsonTransport;
    final transport = observed.inner as IoApiJsonTransport;
    final observedAgent =
        runtime.agentJsonTransport as ObservedApiJsonTransport;
    final agentTransport = observedAgent.inner as IoApiJsonTransport;

    expect(runtime.userId, 'demo-user');
    expect(runtime.babyId, 'demo-baby');
    expect(runtime.locale, 'en-US');
    expect(runtime.session.status, MomCozySessionStatus.anonymous);
    expect(transport.baseUri, Uri.parse('http://127.0.0.1:8769'));
    expect(agentTransport.baseUri, Uri.parse('http://127.0.0.1:8010'));
    expect(agentTransport, isNot(same(transport)));
    expect(transport.token, isNull);
    expect(transport.headers, containsPair('X-Momcozy-Client', 'flutter'));
    expect(runtime.observability, same(observed.observability));
  });

  test('runtime can be bootstrapped from secure session store', () async {
    final store = MemoryMomCozySessionStore(
      const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'secure-user',
        babyId: 'secure-baby',
        locale: 'en-US',
        accessToken: 'secure-access',
        refreshToken: 'secure-refresh',
      ),
    );

    final runtime = await MomCozyApiRuntime.bootstrap(
      store: store,
      authRepository: MomCozyAuthApiRepository(
        transport: FixtureApiJsonTransport({
          'id': 'secure-user',
          'account_status': 'active',
        }),
      ),
    );
    final observed = runtime.jsonTransport as ObservedApiJsonTransport;
    final transport = observed.inner as IoApiJsonTransport;
    final eventResult = await runtime.clientEventClient.post(
      const AgentStreamClientEventRequest(
        eventType: 'runtime_bootstrap_test',
        occurredAt: '2026-07-01T00:00:00Z',
      ),
    );

    expect(runtime.userId, 'secure-user');
    expect(runtime.babyId, 'secure-baby');
    expect(runtime.locale, 'en-US');
    expect(runtime.session.refreshToken, 'secure-refresh');
    expect(transport.token, 'secure-access');
    expect(eventResult.sent, isTrue);
    expect(eventResult.body?['event_type'], 'runtime_bootstrap_test');
    expect(runtime.observability, same(observed.observability));
  });

  test('runtime can be created directly from session', () {
    final runtime = MomCozyApiRuntime.fromSession(
      const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'session-user',
        babyId: 'session-baby',
        locale: 'en-US',
        accessToken: 'session-access',
      ),
    );
    final observed = runtime.jsonTransport as ObservedApiJsonTransport;
    final transport = observed.inner as IoApiJsonTransport;

    expect(runtime.userId, 'session-user');
    expect(runtime.session.isAuthenticated, isTrue);
    expect(transport.token, 'session-access');
    expect(runtime.observability, same(observed.observability));
  });

  test('runtime creates typed repositories over the injected transport', () {
    final transport = FixtureApiJsonTransport({
      'user_id': 'user-fixture',
      'current_care_stage': 'postpartum',
      'actual_delivery_date': '2026-06-11',
    });
    final agentTransport = FixtureApiJsonTransport({'items': <Object?>[]});
    final volumePreferences = _MemoryVolumeUnitPreferenceStore();
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      agentJsonTransport: agentTransport,
      multipartTransport: FixtureApiMultipartTransport({
        'status': 200,
        'data': {},
      }),
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
      volumeUnitPreferenceStore: volumePreferences,
    );

    expect(runtime.agentHubProfileRepository, isA<AgentHubProfileRepository>());
    expect(runtime.agentConversationRepository.transport, same(agentTransport));
    expect(runtime.authRepository, isA<MomCozyAuthApiRepository>());
    expect(runtime.scheduleRepository, isNotNull);
    expect(runtime.recordsRepository.transport, same(transport));
    expect(runtime.volumeUnitPreferenceStore, same(volumePreferences));
    expect(runtime.pumpWorkstateRepository.transport, same(transport));
    expect(runtime.mediaRepository, isA<MediaApiRepository>());
    expect(runtime.mediaContentRepository, isA<MediaContentRepository>());
    expect(runtime.productAssetRepository, isA<ProductAssetRepository>());
  });

  test('runtime exposes an injected multipart transport lazily', () async {
    final multipart = FixtureApiMultipartTransport({
      'id': 'file-runtime',
      'owner_user_id': 'user-fixture',
      'original_filename': 'runtime-fixture.png',
      'content_type': 'image/png',
      'size_bytes': 9,
      'status': 'ready',
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport({'status': 200, 'data': {}}),
      multipartTransport: multipart,
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );

    final uploaded = await runtime.mediaRepository.uploadFile(
      file: const ApiUploadFile(
        name: 'runtime-fixture.png',
        mimeType: 'image/png',
        sizeBytes: 9,
      ),
    );

    expect(runtime.multipartTransport, same(multipart));
    expect(multipart.lastFields, isEmpty);
    expect(uploaded.id, 'file-runtime');
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

  test('runtime exposes an injected pump protocol platform', () async {
    final protocol = FakePumpProtocolPlatform();
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport({'status': 200, 'data': {}}),
      pumpProtocolPlatform: protocol,
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );

    expect(runtime.pumpProtocolPlatform, same(protocol));
    await runtime.pumpProtocolPlatform.adjustGearForSide(PumpSide.left, 5);
    expect(protocol.recordedCommands.single.name, 'adjustGearForSide');
    expect(protocol.recordedCommands.single.payload, containsPair('gear', 5));
    await protocol.dispose();
  });

  test('runtime creates the pump native coordinator lazily', () async {
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
    final upload = FakePumpAgentUploadPlatform();
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport({'status': 200, 'data': {}}),
      blePlatform: ble,
      pumpNativeRuntimeCoordinatorFactory: (ble) =>
          PumpNativeRuntimeCoordinator(ble: ble, upload: upload),
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );

    await runtime.startPumpNativeRuntime();
    final commandFuture = expectLater(
      runtime.pumpProtocolPlatform.commands,
      emits(
        isA<PumpProtocolCommand>().having(
          (command) => command.name,
          'name',
          'queryDeviceStatus',
        ),
      ),
    );
    await runtime.pumpProtocolPlatform.queryDeviceStatus(PumpSide.left);

    expect(ble.writes.single['deviceId'], 'ble-left-fixture');
    await commandFuture;

    await runtime.pumpNativeRuntimeCoordinator.dispose();
    await upload.dispose();
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

  test('runtime controller replaces runtime and preserves observability', () {
    final observability = MomCozyObservability();
    final productAssetRepository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: const _NeverProductAssetConnector(),
    );
    final runtime = MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransport({'status': 200, 'data': {}}),
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
      observability: observability,
      productAssetRepository: productAssetRepository,
    );
    final controller = MomCozyRuntimeController(runtime);
    var notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    controller.replaceSession(
      const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'session-user',
        babyId: 'session-baby',
        locale: 'en-US',
        accessToken: 'session-access',
        refreshToken: 'session-refresh',
      ),
    );

    expect(notifyCount, 1);
    expect(controller.runtime.userId, 'session-user');
    expect(controller.runtime.session.accessToken, 'session-access');
    expect(controller.runtime.observability, same(observability));
    expect(
      controller.runtime.productAssetRepository,
      same(productAssetRepository),
    );
    controller.dispose();
  });

  test('runtime controller keeps auto-refresh transports across sessions', () {
    final observability = MomCozyObservability();
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'session-user',
      babyId: 'session-baby',
      locale: 'zh-CN',
      accessToken: 'stale-access',
      refreshToken: 'refresh-token',
    );
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime.fromSession(session, observability: observability),
    );
    final store = MemoryMomCozySessionStore(session);
    var notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    controller.enableSessionAutoRefresh(store);

    expect(notifyCount, 1);
    final autoRefreshRuntime = controller.runtime;
    expect(
      controller.runtime.jsonTransport,
      isA<AuthenticatedApiJsonTransport>(),
    );
    expect(
      controller.runtime.multipartTransport,
      isA<AuthenticatedApiMultipartTransport>(),
    );

    controller.replaceSession(
      session.copyWith(
        accessToken: 'fresh-access',
        refreshToken: 'fresh-refresh',
      ),
    );

    expect(notifyCount, 1);
    expect(controller.runtime, same(autoRefreshRuntime));
    expect(controller.runtime.currentSession.accessToken, 'fresh-access');
    expect(
      controller.runtime.jsonTransport,
      isA<AuthenticatedApiJsonTransport>(),
    );
    expect(
      controller.runtime.multipartTransport,
      isA<AuthenticatedApiMultipartTransport>(),
    );
    expect(controller.runtime.observability, same(observability));
    controller.dispose();
  });

  test(
    'runtime controller persists and publishes the selected infant',
    () async {
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'session-user',
        babyId: 'baby-one',
        locale: 'en-US',
        accessToken: 'session-access',
        refreshToken: 'session-refresh',
      );
      final store = MemoryMomCozySessionStore(session);
      final mediaContentRepository = MediaContentRepository(
        baseUri: Uri.parse('http://127.0.0.1:8769'),
      );
      final controller = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(
          session,
          mediaContentRepository: mediaContentRepository,
        ),
      );
      controller.enableSessionAutoRefresh(store);

      await controller.selectBaby(' baby-two ');

      expect(controller.currentSession.babyId, 'baby-two');
      expect(controller.runtime.currentSession.babyId, 'baby-two');
      expect((await store.readSession())?.babyId, 'baby-two');
      expect(
        controller.runtime.mediaContentRepository,
        same(mediaContentRepository),
      );
      controller.dispose();
    },
  );

  test(
    'runtime controller publishes a login session to auto-refresh transports',
    () {
      const anonymous = MomCozySession(
        status: MomCozySessionStatus.anonymous,
        userId: 'demo-user',
        babyId: 'demo-baby',
        locale: 'zh-CN',
      );
      const authenticated = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'invite-user',
        babyId: 'demo-baby',
        locale: 'zh-CN',
        accessToken: 'login-access',
        refreshToken: 'login-refresh',
      );
      final controller = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(anonymous),
      );
      controller.enableSessionAutoRefresh(MemoryMomCozySessionStore(anonymous));

      controller.replaceSession(authenticated);

      expect(controller.currentSession, same(authenticated));
      expect(controller.runtime.session, same(authenticated));
      expect(controller.runtime.currentSession, same(authenticated));
      controller.dispose();
    },
  );
}

class _MemoryVolumeUnitPreferenceStore implements VolumeUnitPreferenceStore {
  MomCozyVolumeUnit? value;

  @override
  Future<MomCozyVolumeUnit?> read() async => value;

  @override
  Future<void> write(MomCozyVolumeUnit unit) async {
    value = unit;
  }
}

class _NeverProductAssetConnector implements ProductAssetHttpConnector {
  const _NeverProductAssetConnector();

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) {
    throw UnsupportedError('No product asset request expected.');
  }
}
