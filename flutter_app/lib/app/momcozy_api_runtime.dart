import 'package:flutter/widgets.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_executor.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_native_runtime_coordinator.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);
const _defaultApiToken = String.fromEnvironment('MOMCOZY_API_TOKEN');
const _defaultRefreshToken = String.fromEnvironment('MOMCOZY_REFRESH_TOKEN');
const _defaultUserId = String.fromEnvironment(
  'MOMCOZY_DEFAULT_USER_ID',
  defaultValue: 'demo-user',
);
const _defaultBabyId = String.fromEnvironment(
  'MOMCOZY_DEFAULT_BABY_ID',
  defaultValue: 'demo-baby',
);
const _defaultLocale = String.fromEnvironment(
  'MOMCOZY_LOCALE',
  defaultValue: 'zh-CN',
);

class MomCozyApiRuntime {
  MomCozyApiRuntime({
    required this.jsonTransport,
    MomCozySession? session,
    String? userId,
    String? babyId,
    String? locale,
    AgentStreamClientEventClient? clientEventClient,
    AgentStreamClientEventClient Function()? clientEventClientFactory,
    ApiMultipartTransport? multipartTransport,
    ApiMultipartTransport Function()? multipartTransportFactory,
    BlePlatform? blePlatform,
    BlePlatform Function()? blePlatformFactory,
    PumpProtocolPlatform? pumpProtocolPlatform,
    PumpNativeRuntimeCoordinator Function(BlePlatform ble)?
    pumpNativeRuntimeCoordinatorFactory,
    MomCozyObservability? observability,
    this.storageMigrationResult,
    DateTime Function()? now,
  }) : session =
           session ??
           MomCozySession.fromEnvironment(
             accessToken: '',
             refreshToken: '',
             userId: userId ?? _defaultUserId,
             babyId: babyId ?? _defaultBabyId,
             locale: locale ?? _defaultLocale,
           ),
       _clientEventClientFactory =
           clientEventClientFactory ??
           (() => throw StateError('Client event client is not configured.')),
       _multipartTransportFactory =
           multipartTransportFactory ??
           (() => throw StateError('Multipart transport is not configured.')),
       _blePlatformFactory = blePlatformFactory ?? AndroidBlePlatform.new,
       _pumpNativeRuntimeCoordinatorFactory =
           pumpNativeRuntimeCoordinatorFactory ??
           ((ble) => PumpNativeRuntimeCoordinator(
             ble: ble,
             upload: AndroidPumpAgentUploadPlatform(),
           )),
       observability = observability ?? MomCozyObservability(),
       now = now ?? DateTime.now {
    _clientEventClient = clientEventClient;
    _multipartTransport = multipartTransport;
    _blePlatform = blePlatform;
    _pumpProtocolPlatform = pumpProtocolPlatform;
    _hasInjectedPumpProtocolPlatform = pumpProtocolPlatform != null;
  }

  factory MomCozyApiRuntime.fromEnvironment({
    ApiJsonTransport? jsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    String? userId,
    String? babyId,
    String? locale,
  }) {
    final session = MomCozySession.fromEnvironment(
      accessToken: _defaultApiToken,
      refreshToken: _defaultRefreshToken,
      userId: userId ?? _defaultUserId,
      babyId: babyId ?? _defaultBabyId,
      locale: locale ?? _defaultLocale,
    );
    return MomCozyApiRuntime.fromSession(
      session,
      jsonTransport: jsonTransport,
      clientEventClient: clientEventClient,
      multipartTransport: multipartTransport,
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      observability: observability,
    );
  }

  factory MomCozyApiRuntime.fromSession(
    MomCozySession session, {
    ApiJsonTransport? jsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    StorageMigrationApplyResult? storageMigrationResult,
    MomCozyObservability? observability,
  }) {
    final baseUri = Uri.parse(_defaultApiBaseUrl);
    final authToken = session.accessToken;
    const defaultHeaders = {'X-Momcozy-Client': 'flutter'};
    final runtimeObservability = observability ?? MomCozyObservability();
    return MomCozyApiRuntime(
      jsonTransport:
          jsonTransport ??
          ObservedApiJsonTransport(
            inner: IoApiJsonTransport(
              baseUri: baseUri,
              token: authToken,
              headers: defaultHeaders,
            ),
            observability: runtimeObservability,
          ),
      multipartTransport:
          multipartTransport ??
          ObservedApiMultipartTransport(
            inner: IoApiMultipartTransport(
              baseUri: baseUri,
              token: authToken,
              headers: defaultHeaders,
            ),
            observability: runtimeObservability,
          ),
      clientEventClient:
          clientEventClient ??
          AgentStreamClientEventClient(
            endpoint: AgentStreamEndpoint(
              uri: baseUri.replace(path: '/api/client-event'),
              token: authToken,
              headers: defaultHeaders,
            ),
          ),
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      session: session,
      storageMigrationResult: storageMigrationResult,
      observability: runtimeObservability,
    );
  }

  static Future<MomCozyApiRuntime> bootstrap({
    MomCozySessionStore store = const FlutterSecureMomCozySessionStore(),
    MomCozySession? environmentSession,
    ApiJsonTransport? jsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    Map<String, Object?>? legacyStorageSnapshot,
    StorageMigrationTargetStore? storageMigrationTargetStore,
  }) async {
    final manager = MomCozySessionManager(
      store: store,
      environmentSession:
          environmentSession ??
          MomCozySession.fromEnvironment(
            accessToken: _defaultApiToken,
            refreshToken: _defaultRefreshToken,
            userId: _defaultUserId,
            babyId: _defaultBabyId,
            locale: _defaultLocale,
          ),
    );
    final session = await manager.bootstrap();
    final storageMigrationResult = legacyStorageSnapshot == null
        ? null
        : await StorageMigrationExecutor(
            storageMigrationTargetStore ??
                const FlutterSecureStorageMigrationTargetStore(),
          ).applyInputIfNeeded(
            legacyStorageSnapshot,
            context: {'envDefaultUserId': session.userId},
          );
    return MomCozyApiRuntime.fromSession(
      session,
      jsonTransport: jsonTransport,
      clientEventClient: clientEventClient,
      multipartTransport: multipartTransport,
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      storageMigrationResult: storageMigrationResult,
      observability: observability,
    );
  }

  final ApiJsonTransport jsonTransport;
  final MomCozySession session;
  final StorageMigrationApplyResult? storageMigrationResult;
  final MomCozyObservability observability;
  final DateTime Function() now;
  final AgentStreamClientEventClient Function() _clientEventClientFactory;
  final ApiMultipartTransport Function() _multipartTransportFactory;
  final BlePlatform Function() _blePlatformFactory;
  final PumpNativeRuntimeCoordinator Function(BlePlatform ble)
  _pumpNativeRuntimeCoordinatorFactory;
  AgentStreamClientEventClient? _clientEventClient;
  ApiMultipartTransport? _multipartTransport;
  BlePlatform? _blePlatform;
  PumpProtocolPlatform? _pumpProtocolPlatform;
  PumpNativeRuntimeCoordinator? _pumpNativeRuntimeCoordinator;
  late final bool _hasInjectedPumpProtocolPlatform;

  String get userId => session.userId;

  String get babyId => session.babyId;

  String get locale => session.locale;

  BlePlatform get blePlatform {
    return _blePlatform ??= _blePlatformFactory();
  }

  AgentStreamClientEventClient get clientEventClient {
    return _clientEventClient ??= _clientEventClientFactory();
  }

  ApiMultipartTransport get multipartTransport {
    return _multipartTransport ??= _multipartTransportFactory();
  }

  PumpNativeRuntimeCoordinator get pumpNativeRuntimeCoordinator {
    return _pumpNativeRuntimeCoordinator ??=
        _pumpNativeRuntimeCoordinatorFactory(blePlatform);
  }

  PumpProtocolPlatform get pumpProtocolPlatform {
    return _pumpProtocolPlatform ??= pumpNativeRuntimeCoordinator.protocol;
  }

  Future<void> startPumpNativeRuntime({
    bool subscribeConnectedDevices = true,
  }) async {
    await pumpNativeRuntimeCoordinator.start(
      subscribeConnectedDevices: subscribeConnectedDevices,
    );
  }

  Future<void> ensurePumpProtocolReady({
    bool subscribeConnectedDevices = true,
  }) async {
    if (_hasInjectedPumpProtocolPlatform) return;
    await startPumpNativeRuntime(
      subscribeConnectedDevices: subscribeConnectedDevices,
    );
  }

  StatusApiRepository get statusRepository {
    return StatusApiRepository(transport: jsonTransport);
  }

  ScheduleApiRepository get scheduleRepository {
    return ScheduleApiRepository(transport: jsonTransport);
  }

  RecordsApiRepository get recordsRepository {
    return RecordsApiRepository(transport: jsonTransport);
  }

  MediaApiRepository get mediaRepository {
    return MediaApiRepository(transport: multipartTransport);
  }

  AgentVoiceApiRepository get agentVoiceRepository {
    return AgentVoiceApiRepository(
      multipartTransport: multipartTransport,
      baseUri: Uri.parse(_defaultApiBaseUrl),
      token: session.accessToken,
      headers: const {'X-Momcozy-Client': 'flutter'},
    );
  }

  HospitalBagCartApiRepository get hospitalBagCartRepository {
    return HospitalBagCartApiRepository(transport: jsonTransport);
  }

  PumpWorkstateApiRepository get pumpWorkstateRepository {
    return PumpWorkstateApiRepository(transport: jsonTransport);
  }
}

class MomCozyRuntimeScope extends InheritedWidget {
  const MomCozyRuntimeScope({
    super.key,
    required this.apiRuntime,
    required super.child,
  });

  final MomCozyApiRuntime apiRuntime;

  static MomCozyApiRuntime of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MomCozyRuntimeScope>();
    assert(
      scope != null,
      'MomCozyRuntimeScope is missing from the widget tree.',
    );
    return scope!.apiRuntime;
  }

  static MomCozyApiRuntime? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MomCozyRuntimeScope>()
        ?.apiRuntime;
  }

  @override
  bool updateShouldNotify(MomCozyRuntimeScope oldWidget) {
    return apiRuntime != oldWidget.apiRuntime;
  }
}
