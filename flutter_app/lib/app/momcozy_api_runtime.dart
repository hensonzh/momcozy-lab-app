import 'package:flutter/widgets.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_executor.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
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
    AgentVoicePlaybackPlayer? agentVoicePlaybackPlayer,
    MomCozyObservability? observability,
    this.storageMigrationResult,
    DateTime Function()? now,
    this.supportsSessionAutoRefresh = false,
    this._currentSessionProvider,
    this.agentStreamUnauthorizedHandler,
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
    _agentVoicePlaybackPlayer = agentVoicePlaybackPlayer;
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
    AgentVoicePlaybackPlayer? agentVoicePlaybackPlayer,
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
      agentVoicePlaybackPlayer: agentVoicePlaybackPlayer,
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
    AgentVoicePlaybackPlayer? agentVoicePlaybackPlayer,
    MomCozySessionStore? sessionStore,
    MomCozySession Function()? sessionProvider,
    Future<void> Function(MomCozySession session)? onSessionChanged,
  }) {
    final baseUri = Uri.parse(_defaultApiBaseUrl);
    final authToken = session.accessToken;
    const defaultHeaders = {'X-Momcozy-Client': 'flutter'};
    final runtimeObservability = observability ?? MomCozyObservability();
    ApiJsonTransport jsonTransportForToken(String? token) {
      return ObservedApiJsonTransport(
        inner: IoApiJsonTransport(
          baseUri: baseUri,
          token: token,
          headers: defaultHeaders,
        ),
        observability: runtimeObservability,
      );
    }

    ApiMultipartTransport multipartTransportForToken(String? token) {
      return ObservedApiMultipartTransport(
        inner: IoApiMultipartTransport(
          baseUri: baseUri,
          token: token,
          headers: defaultHeaders,
        ),
        observability: runtimeObservability,
      );
    }

    final canAutoRefresh =
        jsonTransport == null &&
        sessionStore != null &&
        sessionProvider != null &&
        onSessionChanged != null;
    final refreshCoordinator = canAutoRefresh
        ? MomCozySessionRefreshCoordinator(
            authRepository: MomCozyAuthApiRepository(
              transport: jsonTransportForToken(null),
            ),
            store: sessionStore,
          )
        : null;
    return MomCozyApiRuntime(
      jsonTransport:
          jsonTransport ??
          (canAutoRefresh
              ? AuthenticatedApiJsonTransport(
                  transportFactory: jsonTransportForToken,
                  sessionProvider: sessionProvider,
                  refreshCoordinator: refreshCoordinator!,
                  onSessionChanged: onSessionChanged,
                )
              : jsonTransportForToken(authToken)),
      multipartTransport:
          multipartTransport ??
          (canAutoRefresh
              ? AuthenticatedApiMultipartTransport(
                  transportFactory: multipartTransportForToken,
                  sessionProvider: sessionProvider,
                  refreshCoordinator: refreshCoordinator!,
                  onSessionChanged: onSessionChanged,
                )
              : multipartTransportForToken(authToken)),
      clientEventClient:
          clientEventClient ??
          AgentStreamClientEventClient(
            recorder: (event) => runtimeObservability.recordFeatureEvent(
              'client_event',
              event['event_type'] is String
                  ? event['event_type'] as String
                  : 'unknown',
              attributes: event,
            ),
          ),
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      session: session,
      storageMigrationResult: storageMigrationResult,
      observability: runtimeObservability,
      agentVoicePlaybackPlayer: agentVoicePlaybackPlayer,
      currentSessionProvider: sessionProvider,
      supportsSessionAutoRefresh:
          jsonTransport == null && multipartTransport == null,
      agentStreamUnauthorizedHandler: canAutoRefresh
          ? () async {
              final initialSession = sessionProvider();
              final refreshed = await refreshCoordinator!.refresh(
                initialSession,
              );
              await onSessionChanged(refreshed);
              return refreshed.isAuthenticated;
            }
          : null,
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
    AgentVoicePlaybackPlayer? agentVoicePlaybackPlayer,
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
      agentVoicePlaybackPlayer: agentVoicePlaybackPlayer,
    );
  }

  final ApiJsonTransport jsonTransport;
  final MomCozySession session;
  final StorageMigrationApplyResult? storageMigrationResult;
  final MomCozyObservability observability;
  final DateTime Function() now;
  final bool supportsSessionAutoRefresh;
  final Future<bool> Function()? agentStreamUnauthorizedHandler;
  final MomCozySession Function()? _currentSessionProvider;
  final AgentStreamClientEventClient Function() _clientEventClientFactory;
  final ApiMultipartTransport Function() _multipartTransportFactory;
  final BlePlatform Function() _blePlatformFactory;
  final PumpNativeRuntimeCoordinator Function(BlePlatform ble)
  _pumpNativeRuntimeCoordinatorFactory;
  AgentStreamClientEventClient? _clientEventClient;
  ApiMultipartTransport? _multipartTransport;
  AgentVoicePlaybackPlayer? _agentVoicePlaybackPlayer;
  BlePlatform? _blePlatform;
  PumpProtocolPlatform? _pumpProtocolPlatform;
  PumpNativeRuntimeCoordinator? _pumpNativeRuntimeCoordinator;
  late final bool _hasInjectedPumpProtocolPlatform;

  String get userId => session.userId;

  String get babyId => session.babyId;

  String get locale => session.locale;

  MomCozySession get currentSession =>
      _currentSessionProvider?.call() ?? session;

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

  MomCozyAuthApiRepository get authRepository {
    return MomCozyAuthApiRepository(transport: jsonTransport);
  }

  Future<void> startPumpNativeRuntime({
    bool subscribeConnectedDevices = true,
  }) async {
    await pumpNativeRuntimeCoordinator.snapshotSync.upload.setConfig(
      apiBaseUrl: _defaultApiBaseUrl,
      bearerToken: currentSession.accessToken ?? '',
    );
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
      tokenProvider: () => currentSession.accessToken,
      onUnauthorized: agentStreamUnauthorizedHandler,
      headers: const {'X-Momcozy-Client': 'flutter'},
    );
  }

  AgentVoicePlaybackPlayer get agentVoicePlaybackPlayer {
    return _agentVoicePlaybackPlayer ??
        AgentVoiceApiPlaybackPlayer(repository: agentVoiceRepository);
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

  static MomCozyApiRuntime? read(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<MomCozyRuntimeScope>()
        ?.widget;
    return widget is MomCozyRuntimeScope ? widget.apiRuntime : null;
  }

  @override
  bool updateShouldNotify(MomCozyRuntimeScope oldWidget) {
    return apiRuntime != oldWidget.apiRuntime;
  }
}

class MomCozyRuntimeController extends ChangeNotifier {
  MomCozyRuntimeController(this._runtime);

  MomCozyApiRuntime _runtime;
  MomCozySessionStore? _autoRefreshStore;

  MomCozyApiRuntime get runtime => _runtime;

  void replaceRuntime(MomCozyApiRuntime runtime) {
    if (identical(_runtime, runtime)) return;
    _runtime = runtime;
    notifyListeners();
  }

  void replaceSession(MomCozySession session) {
    replaceRuntime(_runtimeForSession(session));
  }

  void enableSessionAutoRefresh(MomCozySessionStore store) {
    if (!_runtime.supportsSessionAutoRefresh) return;
    _autoRefreshStore = store;
    replaceRuntime(_runtimeForSession(_runtime.session));
  }

  MomCozyApiRuntime _runtimeForSession(MomCozySession session) {
    final store = _autoRefreshStore;
    if (store == null) {
      return MomCozyApiRuntime.fromSession(
        session,
        observability: _runtime.observability,
        agentVoicePlaybackPlayer: _runtime._agentVoicePlaybackPlayer,
      );
    }
    return MomCozyApiRuntime.fromSession(
      session,
      observability: _runtime.observability,
      agentVoicePlaybackPlayer: _runtime._agentVoicePlaybackPlayer,
      sessionStore: store,
      sessionProvider: () => _runtime.session,
      onSessionChanged: (next) async {
        replaceSession(next);
      },
    );
  }
}
