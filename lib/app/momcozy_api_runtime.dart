import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_conversation_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_content_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_file_cache.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/notifications/data/notifications_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_finalization_store.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_voice_signaling.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/modules/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_native_runtime_coordinator.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);
const _defaultAgentApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_AGENT_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8010',
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
const _defaultLocale = momCozyEnglishLocale;

Future<String> _deviceTimezone() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

class MomCozyApiRuntime {
  MomCozyApiRuntime({
    required this.jsonTransport,
    ApiJsonTransport? agentJsonTransport,
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
    ProductAssetRepository? productAssetRepository,
    MediaContentRepository? mediaContentRepository,
    VolumeUnitPreferenceStore? volumeUnitPreferenceStore,
    MomCozyObservability? observability,
    DateTime Function()? now,
    Future<String> Function()? timezoneProvider,
    this.supportsSessionAutoRefresh = false,
    this._currentSessionProvider,
    this.agentStreamUnauthorizedHandler,
  }) : agentJsonTransport = agentJsonTransport ?? jsonTransport,
       session =
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
       now = now ?? DateTime.now,
       timezoneProvider = timezoneProvider ?? _deviceTimezone {
    _clientEventClient = clientEventClient;
    _multipartTransport = multipartTransport;

    _productAssetRepository = productAssetRepository;
    _mediaContentRepository = mediaContentRepository;
    _hasInjectedProductAssetRepository = productAssetRepository != null;
    _volumeUnitPreferenceStore = volumeUnitPreferenceStore;
    _blePlatform = blePlatform;
    _pumpProtocolPlatform = pumpProtocolPlatform;
    _hasInjectedPumpProtocolPlatform = pumpProtocolPlatform != null;
  }

  factory MomCozyApiRuntime.fromEnvironment({
    ApiJsonTransport? jsonTransport,
    ApiJsonTransport? agentJsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    ProductAssetRepository? productAssetRepository,
    MediaContentRepository? mediaContentRepository,
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
      agentJsonTransport: agentJsonTransport,
      clientEventClient: clientEventClient,
      multipartTransport: multipartTransport,
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      observability: observability,
      productAssetRepository: productAssetRepository,
      mediaContentRepository: mediaContentRepository,
    );
  }

  factory MomCozyApiRuntime.fromSession(
    MomCozySession session, {
    ApiJsonTransport? jsonTransport,
    ApiJsonTransport? agentJsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    ProductAssetRepository? productAssetRepository,
    MediaContentRepository? mediaContentRepository,
    VolumeUnitPreferenceStore? volumeUnitPreferenceStore,
    MomCozySessionStore? sessionStore,
    MomCozySession Function()? sessionProvider,
    Future<void> Function(MomCozySession session)? onSessionChanged,
  }) {
    final baseUri = Uri.parse(_defaultApiBaseUrl);
    final agentBaseUri = Uri.parse(_defaultAgentApiBaseUrl);
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

    ApiJsonTransport agentJsonTransportForToken(String? token) {
      return ObservedApiJsonTransport(
        inner: IoApiJsonTransport(
          baseUri: agentBaseUri,
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
        agentJsonTransport == null &&
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
      agentJsonTransport:
          agentJsonTransport ??
          (canAutoRefresh
              ? AuthenticatedApiJsonTransport(
                  transportFactory: agentJsonTransportForToken,
                  sessionProvider: sessionProvider,
                  refreshCoordinator: refreshCoordinator!,
                  onSessionChanged: onSessionChanged,
                )
              : agentJsonTransportForToken(authToken)),
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
      observability: runtimeObservability,
      productAssetRepository: productAssetRepository,
      mediaContentRepository: mediaContentRepository,
      volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      currentSessionProvider: sessionProvider,
      supportsSessionAutoRefresh:
          jsonTransport == null &&
          agentJsonTransport == null &&
          multipartTransport == null,
      agentStreamUnauthorizedHandler: canAutoRefresh
          ? () async {
              final currentSession = sessionProvider();
              final refreshed = await refreshCoordinator!.refresh(
                currentSession,
                onSessionChanged: onSessionChanged,
              );
              return refreshed.isAuthenticated;
            }
          : null,
    );
  }

  static Future<MomCozyApiRuntime> bootstrap({
    MomCozyAuthApiRepository? authRepository,
    MomCozySessionStore store = const FlutterSecureMomCozySessionStore(),
    MomCozySession? environmentSession,
    ApiJsonTransport? jsonTransport,
    ApiJsonTransport? agentJsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    ProductAssetRepository? productAssetRepository,
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
    final runtime = MomCozyApiRuntime.fromSession(
      session,
      jsonTransport: jsonTransport,
      agentJsonTransport: agentJsonTransport,
      clientEventClient: clientEventClient,
      multipartTransport: multipartTransport,
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      observability: observability,
      productAssetRepository: productAssetRepository,
    );
    try {
      final restored = await MomCozySessionRestorer(
        authRepository: authRepository ?? runtime.authRepository,
        store: store,
      ).restore(session);
      if (!identical(restored, session)) {
        return MomCozyApiRuntime.fromSession(
          restored,
          jsonTransport: jsonTransport,
          agentJsonTransport: agentJsonTransport,
          clientEventClient: clientEventClient,
          multipartTransport: multipartTransport,
          blePlatform: blePlatform,
          pumpProtocolPlatform: pumpProtocolPlatform,
          observability: observability,
          productAssetRepository: productAssetRepository,
        );
      }
    } catch (_) {
      // Transient network/storage failure keeps the durable session for retry.
      // Every API still checks server-side account and session state.
    }
    return runtime;
  }

  final ApiJsonTransport jsonTransport;
  final ApiJsonTransport agentJsonTransport;
  final MomCozySession session;
  final MomCozyObservability observability;
  final DateTime Function() now;
  final Future<String> Function() timezoneProvider;
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

  AgentHubPlatformImagePicker? _agentHubPlatformImagePicker;
  AgentHubPlatformDocumentPicker? _agentHubPlatformDocumentPicker;
  ProductAssetRepository? _productAssetRepository;
  MediaContentRepository? _mediaContentRepository;
  ScheduleApiRepository? _scheduleRepository;
  MotionAssessmentApiRepository? _motionAssessmentRepository;
  String? _motionAssessmentRepositoryUserId;
  VolumeUnitPreferenceStore? _volumeUnitPreferenceStore;
  late final bool _hasInjectedProductAssetRepository;
  BlePlatform? _blePlatform;
  PumpProtocolPlatform? _pumpProtocolPlatform;
  PumpNativeRuntimeCoordinator? _pumpNativeRuntimeCoordinator;
  late final bool _hasInjectedPumpProtocolPlatform;

  String get userId => session.userId;

  String get babyId => session.babyId;

  String get locale => momCozyEnglishLocale;

  MomCozySession get currentSession =>
      _currentSessionProvider?.call() ?? session;

  Uri get apiBaseUri => Uri.parse(_defaultApiBaseUrl);

  Uri get agentApiBaseUri => Uri.parse(_defaultAgentApiBaseUrl);

  void handleAgentApplicationEvent(AgentStreamEvent event) {}

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

  AgentHubProfileRepository get agentHubProfileRepository {
    return AgentHubProfileRepository(transport: jsonTransport);
  }

  AgentConversationApiRepository get agentConversationRepository {
    return AgentConversationApiRepository(transport: agentJsonTransport);
  }

  ScheduleRepository get scheduleRepository =>
      _scheduleRepository ??= ScheduleApiRepository(transport: jsonTransport);

  RecordsApiRepository get recordsRepository {
    return RecordsApiRepository(transport: jsonTransport);
  }

  NotificationsApiRepository get notificationsRepository {
    return NotificationsApiRepository(transport: jsonTransport);
  }

  MotionAssessmentApiRepository get motionAssessmentRepository {
    final ownerUserId = currentSession.userId;
    if (_motionAssessmentRepository == null ||
        _motionAssessmentRepositoryUserId != ownerUserId) {
      _motionAssessmentRepositoryUserId = ownerUserId;
      _motionAssessmentRepository = MotionAssessmentApiRepository(
        transport: jsonTransport,
        finalizationStore: FlutterSecureMotionAssessmentFinalizationStore(
          userId: ownerUserId,
        ),
      );
    }
    return _motionAssessmentRepository!;
  }

  MotionVoiceSignaling get motionVoiceSignaling {
    return MotionVoiceSignaling(
      baseUri: apiBaseUri,
      tokenProvider: () => currentSession.accessToken,
      onUnauthorized: agentStreamUnauthorizedHandler,
    );
  }

  VolumeUnitPreferenceStore get volumeUnitPreferenceStore {
    return _volumeUnitPreferenceStore ??=
        FlutterSecureVolumeUnitPreferenceStore(userId: currentSession.userId);
  }

  MediaApiRepository get mediaRepository {
    final transport = jsonTransport;
    return MediaApiRepository(
      transport: multipartTransport,
      mutationTransport: transport is ApiJsonMutationTransport
          ? transport as ApiJsonMutationTransport
          : null,
    );
  }

  MediaContentRepository get mediaContentRepository {
    return _mediaContentRepository ??= MediaContentRepository(
      baseUri: Uri.parse(_defaultApiBaseUrl),
      tokenProvider: () => currentSession.accessToken,
      onUnauthorized: agentStreamUnauthorizedHandler,
    );
  }

  ProductAssetRepository get productAssetRepository {
    return _productAssetRepository ??= ProductAssetRepository(
      baseUri: Uri.parse(_defaultApiBaseUrl),
      tokenProvider: () => currentSession.accessToken,
      onUnauthorized: agentStreamUnauthorizedHandler,
      persistentCache: ProductAssetFileCache(),
    );
  }

  AgentHubImagePicker get agentHubImagePicker {
    return (_agentHubPlatformImagePicker ??= AgentHubPlatformImagePicker())
        .pick;
  }

  AgentHubDocumentPicker get agentHubDocumentPicker {
    return (_agentHubPlatformDocumentPicker ??=
            AgentHubPlatformDocumentPicker())
        .pick;
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
  MomCozyRuntimeController(MomCozyApiRuntime runtime)
    : _runtime = runtime,
      _currentSession = runtime.currentSession;

  MomCozyApiRuntime _runtime;
  MomCozySession _currentSession;
  MomCozySessionStore? _autoRefreshStore;
  int _sessionGeneration = 0;
  Future<void> _sessionWrites = Future<void>.value();

  Future<void> _serializeSessionWrite(Future<void> Function() write) {
    final next = _sessionWrites.then((_) => write());
    _sessionWrites = next.catchError((Object _) {});
    return next;
  }

  Future<void> saveAuthenticatedSession(
    MomCozySession session, {
    required MomCozySessionStore sessionStore,
  }) async {
    final englishSession = session.copyWith(locale: momCozyEnglishLocale);
    final generation = ++_sessionGeneration;
    await _serializeSessionWrite(() async {
      if (generation != _sessionGeneration) {
        throw StateError('Session changed.');
      }
      await sessionStore.writeSession(englishSession);
      if (generation != _sessionGeneration) {
        throw StateError('Session changed.');
      }
      replaceRuntime(_runtimeForSession(englishSession));
    });
  }

  MomCozyApiRuntime get runtime => _runtime;

  MomCozySession get currentSession => _currentSession;

  /// Changes on login/logout, not access-token rotation or baby selection.
  int get sessionGeneration => _sessionGeneration;

  void replaceRuntime(MomCozyApiRuntime runtime) {
    if (identical(_runtime, runtime)) return;
    _runtime = runtime;
    _currentSession = runtime.session;
    notifyListeners();
  }

  void replaceSession(MomCozySession session) {
    if (_currentSession.isAuthenticated != session.isAuthenticated ||
        _currentSession.userId != session.userId) {
      ++_sessionGeneration;
    }
    if (_canReplaceSessionInPlace(session)) {
      _currentSession = session;
      return;
    }
    replaceRuntime(_runtimeForSession(session));
  }

  bool _canReplaceSessionInPlace(MomCozySession next) {
    final current = _currentSession;
    return _autoRefreshStore != null &&
        current.isAuthenticated &&
        next.isAuthenticated &&
        current.userId == next.userId &&
        current.babyId == next.babyId &&
        current.locale == next.locale;
  }

  Future<void> logout({
    required MomCozySessionStore sessionStore,
    bool revokeRemote = true,
  }) async {
    final runtime = _runtime;
    final session = _currentSession;
    ++_sessionGeneration;
    replaceSession(session.loggedOut());
    final local = _serializeSessionWrite(() async {
      final manager = MomCozySessionManager(
        store: sessionStore,
        environmentSession: session.loggedOut(),
      );
      await manager.logout(session);
      if (runtime.supportsSessionAutoRefresh) {
        await Future.wait([ProductAssetFileCache().clear()]);
      }
    });
    // Possession of a refresh token can revoke its whole device session even
    // when the access token expired or a refresh rotated this token concurrently.
    final remote = revokeRemote && session.refreshToken != null
        ? runtime.authRepository
              .logoutSession(session.refreshToken!)
              .timeout(const Duration(seconds: 8))
        : Future<void>.value();
    await Future.wait([local, remote]);
  }

  void enableSessionAutoRefresh(MomCozySessionStore store) {
    if (!_runtime.supportsSessionAutoRefresh) return;
    _autoRefreshStore = store;
    replaceRuntime(_runtimeForSession(_currentSession));
  }

  Future<void> selectBaby(String babyId) async {
    final selectedBabyId = babyId.trim();
    if (selectedBabyId.isEmpty) {
      throw ArgumentError.value(babyId, 'babyId', 'Baby ID is required.');
    }
    if (selectedBabyId == _currentSession.babyId) return;
    final store = _autoRefreshStore;
    if (store == null) {
      throw StateError('Session persistence is not available.');
    }
    final generation = _sessionGeneration;
    await _serializeSessionWrite(() async {
      if (generation != _sessionGeneration ||
          !_currentSession.isAuthenticated) {
        return;
      }
      final next = _currentSession.copyWith(babyId: selectedBabyId);
      await store.writeSession(next);
      if (generation == _sessionGeneration) replaceSession(next);
    });
  }

  MomCozyApiRuntime _runtimeForSession(MomCozySession session) {
    final store = _autoRefreshStore;
    final currentSession = _currentSession;
    final sameAuthenticatedAccount =
        session.isAuthenticated &&
        currentSession.isAuthenticated &&
        session.userId == currentSession.userId;
    final volumeUnitPreferenceStore = sameAuthenticatedAccount
        ? _runtime.volumeUnitPreferenceStore
        : null;
    final mediaContentRepository = sameAuthenticatedAccount
        ? _runtime._mediaContentRepository
        : null;
    if (store == null) {
      return MomCozyApiRuntime.fromSession(
        session,
        observability: _runtime.observability,
        productAssetRepository: _runtime._hasInjectedProductAssetRepository
            ? _runtime._productAssetRepository
            : null,
        mediaContentRepository: mediaContentRepository,
        volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      );
    }
    final generation = _sessionGeneration;
    return MomCozyApiRuntime.fromSession(
      session,
      observability: _runtime.observability,
      productAssetRepository: _runtime._hasInjectedProductAssetRepository
          ? _runtime._productAssetRepository
          : null,
      mediaContentRepository: mediaContentRepository,
      volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      sessionStore: _GuardedSessionStore(
        store,
        isCurrent: () => generation == _sessionGeneration,
        serialize: _serializeSessionWrite,
      ),
      sessionProvider: () => _currentSession,
      onSessionChanged: (next) async {
        if (generation != _sessionGeneration) return;
        replaceSession(next);
      },
    );
  }
}

class _GuardedSessionStore implements MomCozySessionStore {
  _GuardedSessionStore(
    this.inner, {
    required this.isCurrent,
    required this.serialize,
  });
  final MomCozySessionStore inner;
  final bool Function() isCurrent;
  final Future<void> Function(Future<void> Function()) serialize;
  @override
  Future<MomCozySession?> readSession() => inner.readSession();
  @override
  Future<void> clearSession() => serialize(inner.clearSession);
  @override
  Future<void> writeSession(MomCozySession session) => serialize(() async {
    if (!isCurrent()) throw StateError('Session changed.');
    await inner.writeSession(session);
    if (!isCurrent()) throw StateError('Session changed.');
  });
}
