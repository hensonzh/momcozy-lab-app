import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_executor.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_native_runtime_coordinator.dart';

import '../support/fixture_api_transport.dart';

void main() {
  test('default runtime builds JSON transport from dart-define defaults', () {
    final runtime = MomCozyApiRuntime.fromEnvironment();
    final observed = runtime.jsonTransport as ObservedApiJsonTransport;
    final transport = observed.inner as IoApiJsonTransport;

    expect(runtime.userId, 'demo-user');
    expect(runtime.babyId, 'demo-baby');
    expect(runtime.locale, 'zh-CN');
    expect(runtime.session.status, MomCozySessionStatus.anonymous);
    expect(transport.baseUri, Uri.parse('http://127.0.0.1:8769'));
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

    final runtime = await MomCozyApiRuntime.bootstrap(store: store);
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

  test('runtime bootstrap can apply a legacy storage snapshot', () async {
    final migrationStore = _RuntimeMigrationStore();

    final runtime = await MomCozyApiRuntime.bootstrap(
      store: MemoryMomCozySessionStore(),
      legacyStorageSnapshot: {
        'localStorage': {
          'mai_debug_user_id': 'legacy-user',
          'mai_agent_conversation_id': 'legacy-conv',
        },
      },
      storageMigrationTargetStore: migrationStore,
    );

    expect(runtime.storageMigrationResult?.applied, isTrue);
    expect(migrationStore.version, currentStorageMigrationVersion);
    expect(
      migrationStore.values[storageMigrationScopedKey(
        'legacy-user',
        'agent.conversationId',
      )],
      'legacy-conv',
    );
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
      'delivery_date': '2026-06-11',
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      multipartTransport: FixtureApiMultipartTransport({
        'status': 200,
        'data': {},
      }),
      userId: 'user-fixture',
      babyId: 'baby-fixture',
      locale: 'zh-CN',
    );

    expect(runtime.statusRepository, isA<StatusApiRepository>());
    expect(runtime.agentHubProfileRepository, isA<AgentHubProfileRepository>());
    expect(runtime.authRepository, isA<MomCozyAuthApiRepository>());
    expect(runtime.scheduleRepository.transport, same(transport));
    expect(runtime.recordsRepository.transport, same(transport));
    expect(runtime.pumpWorkstateRepository.transport, same(transport));
    expect(runtime.mediaRepository, isA<MediaApiRepository>());
    expect(runtime.productAssetRepository, isA<ProductAssetRepository>());
    expect(runtime.agentVoiceRepository, isA<AgentVoiceApiRepository>());
    expect(
      runtime.agentVoicePlaybackPlayer,
      isA<AgentVoiceApiPlaybackPlayer>(),
    );
    expect(
      runtime.hospitalBagCartRepository,
      isA<HospitalBagCartApiRepository>(),
    );
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

  test(
    'runtime exposes voice repository over the session multipart transport',
    () async {
      final multipart = FixtureApiMultipartTransport(const {
        'transcript': 'runtime voice text',
      });
      final runtime = MomCozyApiRuntime.fromSession(
        const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'voice-user',
          babyId: 'voice-baby',
          locale: 'zh-CN',
          accessToken: 'voice-access',
        ),
        multipartTransport: multipart,
      );

      final voiceText = await runtime.agentVoiceRepository
          .transcribeSpeechChunk(
            file: const ApiUploadFile(
              name: 'voice.wav',
              mimeType: 'audio/wav',
              sizeBytes: 4,
            ),
          );
      final repository = runtime.agentVoiceRepository;

      expect(repository.token, 'voice-access');
      expect(repository.multipartTransport, same(multipart));
      expect(voiceText, 'runtime voice text');
      expect(multipart.lastPath, speechTranscribeChunkEndpoint);
      expect(multipart.lastFields, isEmpty);
      expect(
        multipart.lastHeaders,
        containsPair('Authorization', 'Bearer voice-access'),
      );
    },
  );

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
    final previousCartStore = runtime.hospitalBagCartStore;
    final previousConsultStore = runtime.ibclcConsultStore;
    previousCartStore.ingestArtifact(_cartSeed('previous-user-cart'));
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
      controller.runtime.hospitalBagCartStore,
      isNot(same(previousCartStore)),
    );
    expect(controller.runtime.hospitalBagCartStore.agentClientContext, isNull);
    expect(
      controller.runtime.ibclcConsultStore,
      isNot(same(previousConsultStore)),
    );
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
    final cartStore = controller.runtime.hospitalBagCartStore;
    final consultStore = controller.runtime.ibclcConsultStore;
    cartStore.ingestArtifact(_cartSeed('same-user-cart'));
    var notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    controller.enableSessionAutoRefresh(store);

    expect(notifyCount, 1);
    expect(controller.runtime.hospitalBagCartStore, same(cartStore));
    expect(controller.runtime.ibclcConsultStore, same(consultStore));
    expect(
      controller.runtime.hospitalBagCartStore.agentClientContext,
      isNotNull,
    );
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

    expect(notifyCount, 2);
    expect(controller.runtime.currentSession.accessToken, 'fresh-access');
    expect(controller.runtime.hospitalBagCartStore, same(cartStore));
    expect(controller.runtime.ibclcConsultStore, same(consultStore));
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
}

HospitalBagCartArtifactSeed _cartSeed(String artifactId) {
  return HospitalBagCartArtifactSeed.tryFromCartUpdate(
    artifactId: artifactId,
    cartUpdate: {
      'groups': [
        {
          'title': '我的清单',
          'tone': 'sky',
          'items': [
            {'id': 'custom', 'name': '个性化用品', 'qty': 1, 'price': 10},
          ],
        },
      ],
    },
  )!;
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

class _RuntimeMigrationStore implements StorageMigrationTargetStore {
  int? version;
  final values = <String, Object?>{};

  @override
  Future<int?> readMigrationVersion() async => version;

  @override
  Future<void> writeMigrationValue(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> writeMigrationVersion(int version) async {
    this.version = version;
  }

  @override
  Future<void> removeLegacyKey(String bucket, String key) async {}
}
