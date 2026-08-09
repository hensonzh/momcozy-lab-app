import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_conversation_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/ibclc_consult_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/support_ticket_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/body_profile/data/body_profile_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_content_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_file_cache.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_store.dart';
import 'package:momcozy_flutter_app/features/notifications/data/notifications_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_voice_signaling.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/maternal_care_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/profile_identity.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_controller.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';
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

Future<String> _deviceTimezone() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

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
    ProductAssetRepository? productAssetRepository,
    HospitalBagCartStore? hospitalBagCartStore,
    IbclcConsultStore? ibclcConsultStore,
    ProfileOverviewCache? profileOverviewCache,
    VolumeUnitPreferenceStore? volumeUnitPreferenceStore,
    MomCozyObservability? observability,
    DateTime Function()? now,
    Future<String> Function()? timezoneProvider,
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
       hospitalBagCartStore =
           hospitalBagCartStore ??
           HospitalBagCartStore(
             persistence: FlutterSecureHospitalBagCartPersistence(
               userId: session?.userId ?? userId ?? _defaultUserId,
             ),
           ),
       now = now ?? DateTime.now,
       timezoneProvider = timezoneProvider ?? _deviceTimezone {
    unawaited(this.hospitalBagCartStore.restore().then<void>((_) {}));
    this.ibclcConsultStore =
        ibclcConsultStore ??
        IbclcConsultStore(
          persistence: FlutterSecureIbclcConsultPersistence(
            userId: this.session.userId,
          ),
          now: this.now,
        );
    unawaited(this.ibclcConsultStore.restore());
    this.profileOverviewCache =
        profileOverviewCache?.matches(
              ownerUserId: this.session.userId,
              babyId: this.session.babyId,
            ) ==
            true
        ? profileOverviewCache!
        : ProfileOverviewCache(
            ownerUserId: this.session.userId,
            babyId: this.session.babyId,
          );
    _clientEventClient = clientEventClient;
    _multipartTransport = multipartTransport;
    _agentVoicePlaybackPlayer = agentVoicePlaybackPlayer;
    _hasInjectedAgentVoicePlaybackPlayer = agentVoicePlaybackPlayer != null;
    _productAssetRepository = productAssetRepository;
    _hasInjectedProductAssetRepository = productAssetRepository != null;
    _volumeUnitPreferenceStore = volumeUnitPreferenceStore;
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
    ProductAssetRepository? productAssetRepository,
    HospitalBagCartStore? hospitalBagCartStore,
    IbclcConsultStore? ibclcConsultStore,
    ProfileOverviewCache? profileOverviewCache,
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
      productAssetRepository: productAssetRepository,
      hospitalBagCartStore: hospitalBagCartStore,
      ibclcConsultStore: ibclcConsultStore,
      profileOverviewCache: profileOverviewCache,
    );
  }

  factory MomCozyApiRuntime.fromSession(
    MomCozySession session, {
    ApiJsonTransport? jsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    AgentVoicePlaybackPlayer? agentVoicePlaybackPlayer,
    ProductAssetRepository? productAssetRepository,
    HospitalBagCartStore? hospitalBagCartStore,
    IbclcConsultStore? ibclcConsultStore,
    ProfileOverviewCache? profileOverviewCache,
    VolumeUnitPreferenceStore? volumeUnitPreferenceStore,
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
      observability: runtimeObservability,
      agentVoicePlaybackPlayer: agentVoicePlaybackPlayer,
      productAssetRepository: productAssetRepository,
      hospitalBagCartStore: hospitalBagCartStore,
      ibclcConsultStore: ibclcConsultStore,
      profileOverviewCache: profileOverviewCache,
      volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      currentSessionProvider: sessionProvider,
      supportsSessionAutoRefresh:
          jsonTransport == null && multipartTransport == null,
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
    MomCozySessionStore store = const FlutterSecureMomCozySessionStore(),
    MomCozySession? environmentSession,
    ApiJsonTransport? jsonTransport,
    AgentStreamClientEventClient? clientEventClient,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    MomCozyObservability? observability,
    AgentVoicePlaybackPlayer? agentVoicePlaybackPlayer,
    ProductAssetRepository? productAssetRepository,
    HospitalBagCartStore? hospitalBagCartStore,
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
      clientEventClient: clientEventClient,
      multipartTransport: multipartTransport,
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      observability: observability,
      agentVoicePlaybackPlayer: agentVoicePlaybackPlayer,
      productAssetRepository: productAssetRepository,
      hospitalBagCartStore: hospitalBagCartStore,
    );
    var cartRestored = await runtime.hospitalBagCartStore.restore();
    if (!cartRestored) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cartRestored = await runtime.hospitalBagCartStore.restore();
    }
    if (!cartRestored) {
      throw StateError('Hospital bag cart recovery is unavailable.');
    }
    return runtime;
  }

  final ApiJsonTransport jsonTransport;
  final MomCozySession session;
  final MomCozyObservability observability;
  final HospitalBagCartStore hospitalBagCartStore;
  late final IbclcConsultStore ibclcConsultStore;
  late final ProfileOverviewCache profileOverviewCache;
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
  AgentVoicePlaybackPlayer? _agentVoicePlaybackPlayer;
  late final bool _hasInjectedAgentVoicePlaybackPlayer;
  AgentHubPlatformImagePicker? _agentHubPlatformImagePicker;
  AgentHubPlatformDocumentPicker? _agentHubPlatformDocumentPicker;
  ProductAssetRepository? _productAssetRepository;
  MediaContentRepository? _mediaContentRepository;
  PlanApiRepository? _planRepository;
  VolumeUnitPreferenceStore? _volumeUnitPreferenceStore;
  late final bool _hasInjectedProductAssetRepository;
  BlePlatform? _blePlatform;
  PumpProtocolPlatform? _pumpProtocolPlatform;
  PumpNativeRuntimeCoordinator? _pumpNativeRuntimeCoordinator;
  late final bool _hasInjectedPumpProtocolPlatform;

  String get userId => session.userId;

  String get babyId => session.babyId;

  String get locale => session.locale;

  MomCozySession get currentSession =>
      _currentSessionProvider?.call() ?? session;

  Uri get apiBaseUri => Uri.parse(_defaultApiBaseUrl);

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

  ProfileOverviewApiRepository get profileOverviewRepository {
    return ProfileOverviewApiRepository(
      transport: jsonTransport,
      babyId: currentSession.babyId,
      now: now,
    );
  }

  MaternalCareOverviewApiRepository get maternalCareOverviewRepository {
    return MaternalCareOverviewApiRepository(transport: jsonTransport);
  }

  AgentHubProfileRepository get agentHubProfileRepository {
    return AgentHubProfileRepository(transport: jsonTransport);
  }

  AgentConversationApiRepository get agentConversationRepository {
    return AgentConversationApiRepository(transport: jsonTransport);
  }

  SupportTicketApiRepository get supportTicketRepository {
    return SupportTicketApiRepository(transport: jsonTransport);
  }

  PlanApiRepository get planRepository {
    return _planRepository ??= PlanApiRepository(transport: jsonTransport);
  }

  RecordsApiRepository get recordsRepository {
    return RecordsApiRepository(transport: jsonTransport);
  }

  NotificationsApiRepository get notificationsRepository {
    return NotificationsApiRepository(transport: jsonTransport);
  }

  MotionAssessmentApiRepository get motionAssessmentRepository {
    return MotionAssessmentApiRepository(transport: jsonTransport);
  }

  MotionVoiceSignaling get motionVoiceSignaling {
    return MotionVoiceSignaling(
      baseUri: apiBaseUri,
      tokenProvider: () => currentSession.accessToken,
      onUnauthorized: agentStreamUnauthorizedHandler,
    );
  }

  BodyProfileApiRepository get bodyProfileRepository {
    return BodyProfileApiRepository(transport: jsonTransport);
  }

  VolumeUnitPreferenceStore get volumeUnitPreferenceStore {
    return _volumeUnitPreferenceStore ??=
        FlutterSecureVolumeUnitPreferenceStore(userId: currentSession.userId);
  }

  ProfileOverviewController createProfileOverviewController({
    ProfileIdentity initialIdentity = ProfileIdentity.mom,
    String? babyId,
  }) {
    final requestedBabyId = babyId?.trim();
    final selectedBabyId = requestedBabyId?.isNotEmpty == true
        ? requestedBabyId!
        : currentSession.babyId;
    final records = recordsRepository;
    return ProfileOverviewController(
      profileOverviewRepository: ProfileOverviewApiRepository(
        transport: jsonTransport,
        babyId: selectedBabyId,
        now: now,
      ),
      feedingRepository: records,
      pumpMilkRepository: records,
      milkTrendRepository: records,
      growthRepository: records,
      waterRepository: records,
      waterTrendRepository: records,
      vitalRepository: records,
      sleepRepository: records,
      diaperRepository: records,
      maternalCareOverviewRepository: maternalCareOverviewRepository,
      planRepository: planRepository,
      cache:
          profileOverviewCache.matches(
            ownerUserId: currentSession.userId,
            babyId: selectedBabyId,
          )
          ? profileOverviewCache
          : ProfileOverviewCache(
              ownerUserId: currentSession.userId,
              babyId: selectedBabyId,
            ),
      babyId: selectedBabyId,
      identity: initialIdentity,
      timezoneProvider: timezoneProvider,
      now: now,
    );
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

  AgentVoiceApiRepository get agentVoiceRepository {
    return AgentVoiceApiRepository(
      baseUri: Uri.parse(_defaultApiBaseUrl),
      token: session.accessToken,
      tokenProvider: () => currentSession.accessToken,
      onUnauthorized: agentStreamUnauthorizedHandler,
      headers: const {'X-Momcozy-Client': 'flutter'},
    );
  }

  AgentVoicePlaybackPlayer get agentVoicePlaybackPlayer {
    return _agentVoicePlaybackPlayer ??= AgentVoiceApiPlaybackPlayer(
      repository: agentVoiceRepository,
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
  MomCozyRuntimeController(MomCozyApiRuntime runtime)
    : _runtime = runtime,
      _currentSession = runtime.currentSession;

  MomCozyApiRuntime _runtime;
  MomCozySession _currentSession;
  MomCozySessionStore? _autoRefreshStore;

  MomCozyApiRuntime get runtime => _runtime;

  MomCozySession get currentSession => _currentSession;

  void replaceRuntime(MomCozyApiRuntime runtime) {
    if (identical(_runtime, runtime)) return;
    _runtime = runtime;
    _currentSession = runtime.session;
    notifyListeners();
  }

  void replaceSession(MomCozySession session) {
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

  Future<void> logout({required MomCozySessionStore sessionStore}) async {
    final runtime = _runtime;
    final currentSession = runtime.currentSession;
    unawaited(_revokeRemoteSession(runtime));

    final sessionManager = MomCozySessionManager(
      store: sessionStore,
      environmentSession: currentSession.loggedOut(),
    );
    final anonymousSession = await sessionManager.logout(currentSession);
    replaceSession(anonymousSession);
  }

  Future<void> _revokeRemoteSession(MomCozyApiRuntime runtime) async {
    try {
      await runtime.authRepository.logout().timeout(const Duration(seconds: 5));
    } catch (error, stackTrace) {
      runtime.observability.recordNonFatal(
        error,
        stackTrace: stackTrace,
        context: const {
          'feature': 'auth',
          'operation': 'remote_logout',
          'localLogoutContinued': true,
        },
      );
    }
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
    final next = _currentSession.copyWith(babyId: selectedBabyId);
    await store.writeSession(next);
    replaceSession(next);
  }

  MomCozyApiRuntime _runtimeForSession(MomCozySession session) {
    final store = _autoRefreshStore;
    final currentSession = _currentSession;
    final hospitalBagCartStore = session.userId == currentSession.userId
        ? _runtime.hospitalBagCartStore
        : null;
    final ibclcConsultStore = session.userId == currentSession.userId
        ? _runtime.ibclcConsultStore
        : null;
    final sameAuthenticatedAccount =
        session.isAuthenticated &&
        currentSession.isAuthenticated &&
        session.userId == currentSession.userId;
    final profileOverviewCache =
        sameAuthenticatedAccount && session.babyId == currentSession.babyId
        ? _runtime.profileOverviewCache
        : null;
    final volumeUnitPreferenceStore = sameAuthenticatedAccount
        ? _runtime.volumeUnitPreferenceStore
        : null;
    if (store == null) {
      return MomCozyApiRuntime.fromSession(
        session,
        observability: _runtime.observability,
        agentVoicePlaybackPlayer: _runtime._hasInjectedAgentVoicePlaybackPlayer
            ? _runtime._agentVoicePlaybackPlayer
            : null,
        productAssetRepository: _runtime._hasInjectedProductAssetRepository
            ? _runtime._productAssetRepository
            : null,
        hospitalBagCartStore: hospitalBagCartStore,
        ibclcConsultStore: ibclcConsultStore,
        profileOverviewCache: profileOverviewCache,
        volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      );
    }
    return MomCozyApiRuntime.fromSession(
      session,
      observability: _runtime.observability,
      agentVoicePlaybackPlayer: _runtime._hasInjectedAgentVoicePlaybackPlayer
          ? _runtime._agentVoicePlaybackPlayer
          : null,
      productAssetRepository: _runtime._hasInjectedProductAssetRepository
          ? _runtime._productAssetRepository
          : null,
      hospitalBagCartStore: hospitalBagCartStore,
      ibclcConsultStore: ibclcConsultStore,
      profileOverviewCache: profileOverviewCache,
      volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      sessionStore: store,
      sessionProvider: () => _currentSession,
      onSessionChanged: (next) async {
        replaceSession(next);
      },
    );
  }
}
