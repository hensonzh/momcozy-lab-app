import 'dart:async';

import 'package:flutter/widgets.dart';
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
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_voice_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/support_ticket_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_playback.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/media_content_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_file_cache.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_store.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_change_persistence.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_change_persistence.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/android_schedule_reminder_gateway.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_image_recognition_gateway.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/milk_plan_change_persistence.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_reminder_preference_store.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_image_recognition.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_plan.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/schedule_reminder.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_preference_store.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_selection.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_cache.dart';
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
    ProductAssetRepository? productAssetRepository,
    HospitalBagCartStore? hospitalBagCartStore,
    IbclcConsultStore? ibclcConsultStore,
    PregnancyDiaryChangeStore? pregnancyDiaryChangeStore,
    PregnancyPlanChangeStore? pregnancyPlanChangeStore,
    StatusDashboardCache? statusDashboardCache,
    MilkPlanChangeStore? milkPlanChangeStore,
    StatusPreferenceStore? statusPreferenceStore,
    ScheduleReminderPreferenceStore? scheduleReminderPreferenceStore,
    ScheduleReminderGateway? scheduleReminderGateway,
    VolumeUnitPreferenceStore? volumeUnitPreferenceStore,
    MomCozyObservability? observability,
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
       hospitalBagCartStore =
           hospitalBagCartStore ??
           HospitalBagCartStore(
             persistence: FlutterSecureHospitalBagCartPersistence(
               userId: session?.userId ?? userId ?? _defaultUserId,
             ),
           ),
       now = now ?? DateTime.now {
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
    this.pregnancyDiaryChangeStore =
        pregnancyDiaryChangeStore ??
        PregnancyDiaryChangeStore(
          persistence: FlutterSecurePregnancyDiaryChangePersistence(
            userId: this.session.userId,
          ),
        );
    unawaited(this.pregnancyDiaryChangeStore.restore());
    this.pregnancyPlanChangeStore =
        pregnancyPlanChangeStore ??
        PregnancyPlanChangeStore(
          persistence: FlutterSecurePregnancyPlanChangePersistence(
            userId: this.session.status == MomCozySessionStatus.authenticated
                ? this.session.userId
                : '',
          ),
        );
    unawaited(this.pregnancyPlanChangeStore.restore());
    this.statusDashboardCache =
        statusDashboardCache?.matches(
              ownerUserId: this.session.userId,
              babyId: this.session.babyId,
            ) ==
            true
        ? statusDashboardCache!
        : StatusDashboardCache(
            ownerUserId: this.session.userId,
            babyId: this.session.babyId,
          );
    this.milkPlanChangeStore =
        milkPlanChangeStore ??
        MilkPlanChangeStore(
          persistence: FlutterSecureMilkPlanChangePersistence(
            userId: this.session.status == MomCozySessionStatus.authenticated
                ? this.session.userId
                : '',
          ),
        );
    unawaited(this.milkPlanChangeStore.restore());
    _clientEventClient = clientEventClient;
    _multipartTransport = multipartTransport;
    _agentVoicePlaybackPlayer = agentVoicePlaybackPlayer;
    _hasInjectedAgentVoicePlaybackPlayer = agentVoicePlaybackPlayer != null;
    _productAssetRepository = productAssetRepository;
    _hasInjectedProductAssetRepository = productAssetRepository != null;
    _statusPreferenceStore = statusPreferenceStore;
    _scheduleReminderPreferenceStore = scheduleReminderPreferenceStore;
    _scheduleReminderGateway = scheduleReminderGateway;
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
    PregnancyPlanChangeStore? pregnancyPlanChangeStore,
    StatusDashboardCache? statusDashboardCache,
    MilkPlanChangeStore? milkPlanChangeStore,
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
      pregnancyPlanChangeStore: pregnancyPlanChangeStore,
      statusDashboardCache: statusDashboardCache,
      milkPlanChangeStore: milkPlanChangeStore,
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
    PregnancyDiaryChangeStore? pregnancyDiaryChangeStore,
    PregnancyPlanChangeStore? pregnancyPlanChangeStore,
    StatusDashboardCache? statusDashboardCache,
    MilkPlanChangeStore? milkPlanChangeStore,
    ScheduleReminderPreferenceStore? scheduleReminderPreferenceStore,
    ScheduleReminderGateway? scheduleReminderGateway,
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
      pregnancyDiaryChangeStore: pregnancyDiaryChangeStore,
      pregnancyPlanChangeStore: pregnancyPlanChangeStore,
      statusDashboardCache: statusDashboardCache,
      milkPlanChangeStore: milkPlanChangeStore,
      scheduleReminderPreferenceStore: scheduleReminderPreferenceStore,
      scheduleReminderGateway: scheduleReminderGateway,
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
  late final PregnancyDiaryChangeStore pregnancyDiaryChangeStore;
  late final PregnancyPlanChangeStore pregnancyPlanChangeStore;
  late final StatusDashboardCache statusDashboardCache;
  late final MilkPlanChangeStore milkPlanChangeStore;
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
  late final bool _hasInjectedAgentVoicePlaybackPlayer;
  AgentVoiceInputController? _agentVoiceInputController;
  AgentHubPlatformImagePicker? _agentHubPlatformImagePicker;
  AgentHubPlatformDocumentPicker? _agentHubPlatformDocumentPicker;
  ProductAssetRepository? _productAssetRepository;
  MediaContentRepository? _mediaContentRepository;
  StatusPreferenceStore? _statusPreferenceStore;
  ScheduleReminderPreferenceStore? _scheduleReminderPreferenceStore;
  ScheduleReminderGateway? _scheduleReminderGateway;
  ScheduleImageRecognitionGateway? _scheduleImageRecognitionGateway;
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
    return StatusApiRepository(transport: jsonTransport, now: now);
  }

  Future<DateTime?> loadSchedulePostpartumAnchorDate() async {
    final overview = await statusRepository.fetchOverview();
    return overview.mom?.deliveryDate ?? overview.baby?.birthDate;
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

  ScheduleApiRepository get scheduleRepository {
    return ScheduleApiRepository(transport: jsonTransport);
  }

  RecordsApiRepository get recordsRepository {
    return RecordsApiRepository(transport: jsonTransport);
  }

  PregnancyDiaryApiRepository get pregnancyDiaryRepository {
    return PregnancyDiaryApiRepository(transport: jsonTransport);
  }

  PregnancyPlanApiRepository get pregnancyPlanRepository {
    return PregnancyPlanApiRepository(transport: jsonTransport);
  }

  StatusPreferenceStore get statusPreferenceStore {
    return _statusPreferenceStore ??= FlutterSecureStatusPreferenceStore(
      userId: currentSession.userId,
    );
  }

  ScheduleReminderPreferenceStore get scheduleReminderPreferenceStore {
    return _scheduleReminderPreferenceStore ??=
        FlutterSecureScheduleReminderPreferenceStore(
          userId: currentSession.userId,
        );
  }

  ScheduleReminderGateway get scheduleReminderGateway {
    final configured = _scheduleReminderGateway;
    if (configured != null) return configured;
    if (!currentSession.isAuthenticated) {
      return const UnsupportedScheduleReminderGateway();
    }
    return _scheduleReminderGateway = AndroidScheduleReminderGateway(
      ownerScope: currentSession.userId,
      now: now,
    );
  }

  VolumeUnitPreferenceStore get volumeUnitPreferenceStore {
    return _volumeUnitPreferenceStore ??=
        FlutterSecureVolumeUnitPreferenceStore(userId: currentSession.userId);
  }

  StatusDashboardController createStatusDashboardController({
    StatusCareStage initialCareStage = StatusCareStage.postpartum,
    StatusIdentity initialIdentity = StatusIdentity.mom,
  }) {
    final records = recordsRepository;
    return StatusDashboardController(
      statusRepository: statusRepository,
      feedingRepository: records,
      milkTrendRepository: records,
      growthRepository: records,
      pregnancyDiaryRepository: pregnancyDiaryRepository,
      pregnancyPlanRepository: pregnancyPlanRepository,
      preferenceStore: statusPreferenceStore,
      volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      cache: statusDashboardCache,
      babyId: currentSession.babyId,
      initialCareStage: initialCareStage,
      initialIdentity: initialIdentity,
      now: now,
    );
  }

  bool recordPregnancyDiaryChange(PregnancyDiaryChange change) {
    final recorded = pregnancyDiaryChangeStore.record(change);
    if (recorded) statusDashboardCache.invalidatePregnancyDiary();
    return recorded;
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

  ScheduleImageRecognitionGateway? get scheduleImageRecognitionGateway {
    if (!currentSession.isAuthenticated) return null;
    return _scheduleImageRecognitionGateway ??=
        ApiScheduleImageRecognitionGateway(
          imagePicker: agentHubImagePicker,
          mediaRepository: mediaRepository,
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
      multipartTransport: multipartTransport,
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

  AgentVoiceInputController get agentVoiceInputController {
    return _agentVoiceInputController ??= AgentVoiceInputController(
      recorder: AgentHubPlatformVoiceRecorder(),
      transcriber: AgentVoiceApiInputTranscriber(
        repository: agentVoiceRepository,
        language: locale,
      ),
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
    final previous = _runtime;
    final sameAuthenticatedAccount =
        previous.session.isAuthenticated &&
        runtime.session.isAuthenticated &&
        previous.session.userId == runtime.session.userId;
    final previousReminderGateway = previous._scheduleReminderGateway;
    if (previous.session.isAuthenticated &&
        !sameAuthenticatedAccount &&
        previousReminderGateway != null) {
      unawaited(
        previousReminderGateway.setEnabled(
          enabled: false,
          tasks: const <ScheduleTask>[],
        ),
      );
    }
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

  MomCozyApiRuntime _runtimeForSession(MomCozySession session) {
    final store = _autoRefreshStore;
    final currentSession = _currentSession;
    final hospitalBagCartStore = session.userId == currentSession.userId
        ? _runtime.hospitalBagCartStore
        : null;
    final ibclcConsultStore = session.userId == currentSession.userId
        ? _runtime.ibclcConsultStore
        : null;
    final pregnancyDiaryChangeStore = session.userId == currentSession.userId
        ? _runtime.pregnancyDiaryChangeStore
        : null;
    final sameAuthenticatedPlanAccount =
        session.isAuthenticated &&
        currentSession.isAuthenticated &&
        session.userId == currentSession.userId;
    final pregnancyPlanChangeStore = sameAuthenticatedPlanAccount
        ? _runtime.pregnancyPlanChangeStore
        : null;
    final statusDashboardCache =
        sameAuthenticatedPlanAccount && session.babyId == currentSession.babyId
        ? _runtime.statusDashboardCache
        : null;
    final milkPlanChangeStore =
        session.status == MomCozySessionStatus.authenticated &&
            currentSession.status == MomCozySessionStatus.authenticated &&
            session.userId == currentSession.userId
        ? _runtime.milkPlanChangeStore
        : null;
    final scheduleReminderGateway = sameAuthenticatedPlanAccount
        ? _runtime.scheduleReminderGateway
        : null;
    final scheduleReminderPreferenceStore = sameAuthenticatedPlanAccount
        ? _runtime.scheduleReminderPreferenceStore
        : null;
    final volumeUnitPreferenceStore = sameAuthenticatedPlanAccount
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
        pregnancyDiaryChangeStore: pregnancyDiaryChangeStore,
        pregnancyPlanChangeStore: pregnancyPlanChangeStore,
        statusDashboardCache: statusDashboardCache,
        milkPlanChangeStore: milkPlanChangeStore,
        scheduleReminderGateway: scheduleReminderGateway,
        scheduleReminderPreferenceStore: scheduleReminderPreferenceStore,
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
      pregnancyDiaryChangeStore: pregnancyDiaryChangeStore,
      pregnancyPlanChangeStore: pregnancyPlanChangeStore,
      statusDashboardCache: statusDashboardCache,
      milkPlanChangeStore: milkPlanChangeStore,
      scheduleReminderGateway: scheduleReminderGateway,
      scheduleReminderPreferenceStore: scheduleReminderPreferenceStore,
      volumeUnitPreferenceStore: volumeUnitPreferenceStore,
      sessionStore: store,
      sessionProvider: () => _currentSession,
      onSessionChanged: (next) async {
        replaceSession(next);
      },
    );
  }
}
