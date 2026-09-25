import 'dart:io';
import '../features/notifications/data/firebase_push_messaging.dart';
import '../features/notifications/data/native_notification_platform.dart';
import '../features/notifications/data/notification_installation_store.dart';
import '../features/notifications/presentation/notification_coordinator.dart';
import '../features/notifications/presentation/notification_permission_controller.dart';
import '../features/notifications/presentation/notification_scope.dart';
import 'mom_module_routes.dart';
import 'baby_module_routes.dart';
import 'mom_bottom_navigation.dart';
import '../shared/widgets/momcozy_components.dart';
import '../shared/design_system/mom_home_tokens.dart';
import '../shared/design_system/mom_settings_theme.dart';
import '../shared/widgets/mom_settings_widgets.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/config/momcozy_app_capabilities.dart';
import 'package:momcozy_flutter_app/core/update/app_release_lifecycle.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/more_page.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_banner.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

typedef MomCozyAgentHubBuilder =
    Widget Function(BuildContext context, Uri? uri, Object? extra);

class MomCozyFlutterApp extends StatefulWidget {
  const MomCozyFlutterApp({
    super.key,
    this.router,
    this.routeIntentPlatform,
    this.notificationCoordinator,
    this.apiRuntime,
    this.runtimeController,
    this.sessionStore = const FlutterSecureMomCozySessionStore(),
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
    this.lastInviteCodeStore = const FlutterSecureMomCozyLastInviteCodeStore(),
    this.capabilities = const MomCozyAppCapabilities.fromEnvironment(),
    this.onboardingReleasePolicy = const NoopOnboardingReleasePolicy(),
    this.agentHubBuilder,
  }) : assert(
         apiRuntime == null || runtimeController == null,
         'Pass either apiRuntime or runtimeController, not both.',
       );

  final GoRouter? router;
  final RouteIntentPlatform? routeIntentPlatform;
  final NotificationCoordinator? notificationCoordinator;
  final MomCozyApiRuntime? apiRuntime;
  final MomCozyRuntimeController? runtimeController;
  final MomCozySessionStore sessionStore;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;
  final MomCozyLastInviteCodeStore lastInviteCodeStore;
  final MomCozyAppCapabilities capabilities;
  final OnboardingReleasePolicy onboardingReleasePolicy;
  final MomCozyAgentHubBuilder? agentHubBuilder;

  @override
  State<MomCozyFlutterApp> createState() => _MomCozyFlutterAppState();
}

class _MomCozyFlutterAppState extends State<MomCozyFlutterApp>
    with WidgetsBindingObserver {
  late final MomCozyRuntimeController _runtimeController =
      widget.runtimeController ??
      MomCozyRuntimeController(
        widget.apiRuntime ?? MomCozyApiRuntime.fromEnvironment(),
      );
  late final bool _ownsRuntimeController = widget.runtimeController == null;
  late final OnboardingController? _onboardingController =
      widget.capabilities.onboardingGateEnabled &&
          widget.router == null &&
          _runtimeController.runtime.supportsSessionAutoRefresh
      ? OnboardingController(
          runtimeController: _runtimeController,
          onPrimaryInfantSelected: _runtimeController.selectBaby,
          releasePolicy: widget.onboardingReleasePolicy,
        )
      : null;
  late final AvatarTaskController? _avatarTaskController =
      _onboardingController == null
      ? null
      : AvatarTaskController(onboardingController: _onboardingController);
  late final GoRouter _router =
      widget.router ??
      createMomCozyRouter(
        runtimeController: _runtimeController,
        onboardingController: _onboardingController,
        avatarTaskController: _avatarTaskController,
        sessionStore: widget.sessionStore,
        authDeviceIdStore: widget.authDeviceIdStore,
        lastInviteCodeStore: widget.lastInviteCodeStore,
        capabilities: widget.capabilities,
        agentHubBuilder: widget.agentHubBuilder,
      );
  late final bool _ownsRouter = widget.router == null;
  late final RouteIntentPlatform _routeIntentPlatform =
      widget.routeIntentPlatform ?? AndroidRouteIntentPlatform();
  late final bool _ownsRouteIntentPlatform = widget.routeIntentPlatform == null;
  StreamSubscription<PendingNativeRoute>? _activeRouteSub;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final NotificationCoordinator? _notifications =
      widget.notificationCoordinator ??
      (_runtimeController.runtime.supportsSessionAutoRefresh
          ? NotificationCoordinator(
              permission: NotificationPermissionController(
                const NativeNotificationPlatform(),
              ),
              gateway: FirebasePushMessaging(),
              store: SecureNotificationInstallationStore(),
              platformName: Platform.isIOS ? 'ios' : 'android',
              onNavigate: (route) {
                if (mounted) _router.go(route);
              },
              onMessage: (message) {
                if (mounted) {
                  _messengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
              onForeground: (intent) {
                if (mounted) {
                  _messengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: const Text('You have a new Momcozy update.'),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () =>
                            unawaited(_notifications?.openPush(intent)),
                      ),
                    ),
                  );
                }
              },
            )
          : null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtimeController.enableSessionAutoRefresh(widget.sessionStore);
    _runtimeController.addListener(_handleRuntimeChanged);
    _activeRouteSub = _routeIntentPlatform.activeRoutes.listen(
      _handlePendingNativeRoute,
    );
    unawaited(_consumePendingNativeRoute());
    _handleRuntimeChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runtimeController.removeListener(_handleRuntimeChanged);
    unawaited(_activeRouteSub?.cancel());
    if (_ownsRouteIntentPlatform) {
      final platform = _routeIntentPlatform;
      if (platform is AndroidRouteIntentPlatform) unawaited(platform.dispose());
    }
    if (widget.notificationCoordinator == null) _notifications?.dispose();
    _avatarTaskController?.dispose();
    _onboardingController?.dispose();
    if (_ownsRuntimeController) _runtimeController.dispose();
    if (_ownsRouter) _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _avatarTaskController?.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      unawaited(_notifications?.refresh());
    }
  }

  void _handleRuntimeChanged() {
    final session = _runtimeController.currentSession;
    final repository = _runtimeController.runtime.notificationsRepository;
    unawaited(
      _notifications?.setAccount(
        key: session.isAuthenticated
            ? '${session.userId}:${_runtimeController.sessionGeneration}'
            : null,
        inboxRepository: repository,
        deliveryRepository: repository,
        locale: momCozyEnglishLocale,
      ),
    );
  }

  Future<void> _consumePendingNativeRoute() async {
    try {
      final route = await _routeIntentPlatform.consumePendingRoute();
      if (route != null) _handlePendingNativeRoute(route);
    } catch (_) {
      // The MethodChannel is Android-only; non-Android test/dev targets can skip it.
    }
  }

  void _handlePendingNativeRoute(PendingNativeRoute route) {
    final intent = routeIntentFromNativeNotification(
      _nativeRoutePayload(route),
    );
    if (intent == null || intent.type == 'RejectUnsafeRoute') return;
    final path = intent.path;
    if (path == null || path.isEmpty) return;
    _router.go(path, extra: intent.payload.isEmpty ? null : intent.payload);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtimeController,
      builder: (context, child) {
        return MomCozyRuntimeScope(
          apiRuntime: _runtimeController.runtime,
          child: _notifications == null
              ? child!
              : NotificationScope(coordinator: _notifications, child: child!),
        );
      },
      child: MaterialApp.router(
        title: 'Momcozy AI',
        scaffoldMessengerKey: _messengerKey,
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: momCozyTheme().copyWith(
          pageTransitionsTheme: momCozyPageTransitionsTheme,
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

Map<String, Object?> _nativeRoutePayload(PendingNativeRoute route) {
  return {
    'path': route.path,
    'autoEndTeardown': route.autoEndTeardown,
    if (route.notifyJson != null) 'notifyJson': jsonEncode(route.notifyJson),
  };
}

GoRouter createMomCozyRouter({
  String initialLocation = '/me',
  MomCozyRuntimeController? runtimeController,
  OnboardingController? onboardingController,
  AvatarTaskController? avatarTaskController,
  OnboardingAvatarImageLoader? avatarThumbnailLoader,
  MomCozySessionStore sessionStore = const FlutterSecureMomCozySessionStore(),
  MomCozyAuthDeviceIdStore authDeviceIdStore =
      const FlutterSecureMomCozyAuthDeviceIdStore(),
  MomCozyLastInviteCodeStore lastInviteCodeStore =
      const FlutterSecureMomCozyLastInviteCodeStore(),
  MomCozyAppCapabilities capabilities = const MomCozyAppCapabilities(),
  MomCozyAgentHubBuilder? agentHubBuilder,
}) {
  final resolvedAgentHubBuilder =
      agentHubBuilder ??
      (context, uri, extra) => _buildDefaultAgentHubPage(context, uri, extra);
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: runtimeController == null
        ? onboardingController
        : onboardingController == null
        ? runtimeController
        : Listenable.merge([runtimeController, onboardingController]),
    redirect: (context, state) {
      if (runtimeController == null) return null;
      if (onboardingController == null &&
          _isOnboardingFlowPath(state.uri.path)) {
        return '/';
      }
      final authRedirect = _authRedirect(runtimeController, state);
      if (authRedirect != null) return authRedirect;
      if (onboardingController == null ||
          !runtimeController.currentSession.isAuthenticated) {
        return null;
      }
      return _onboardingRedirect(
        runtimeController,
        onboardingController,
        state,
      );
    },
    routes: [
      if (runtimeController != null)
        GoRoute(
          path: '/account',
          builder: (context, state) => MomCozyAccountPage(
            runtimeController: runtimeController,
            sessionStore: sessionStore,
          ),
        ),
      if (runtimeController != null)
        GoRoute(
          path: '/login',
          builder: (context, state) => MomCozyAuthPage(
            runtimeController: runtimeController,
            sessionStore: sessionStore,
            authDeviceIdStore: authDeviceIdStore,
            lastInviteCodeStore: lastInviteCodeStore,
          ),
        ),
      if (runtimeController != null && onboardingController != null)
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => OnboardingPage(
            controller: onboardingController,
            entryPath:
                _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/me',
            avatarThumbnailLoader: avatarThumbnailLoader,
          ),
        ),
      if (runtimeController != null && onboardingController != null)
        GoRoute(
          path: '/avatar/review',
          builder: (context, state) => OnboardingPage(
            controller: onboardingController,
            avatarTaskMode: true,
            entryPath:
                _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/me',
            avatarThumbnailLoader: avatarThumbnailLoader,
            onAvatarTaskCompleted: avatarTaskController?.showCompleted,
          ),
        ),
      if (runtimeController != null && onboardingController != null)
        GoRoute(
          path: '/avatar/create',
          builder: (context, state) => OnboardingPage(
            controller: onboardingController,
            avatarTaskMode: true,
            entryPath:
                _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/me',
            avatarThumbnailLoader: avatarThumbnailLoader,
            onAvatarTaskCompleted: avatarTaskController?.showCompleted,
          ),
        ),
      ...momModuleRoutes,
      ...babyModuleRoutes,
      ShellRoute(
        builder: (context, state, child) {
          final runtime = MomCozyRuntimeScope.of(context);
          return MomCozyRouteTelemetry(
            location: state.uri.path,
            observability: runtime.observability,
            child: MomCozyRouteShell(
              location: state.uri.path,
              uri: state.uri,
              extra: state.extra,
              agentHubBuilder: resolvedAgentHubBuilder,
              avatarTaskController: avatarTaskController,
              child: child,
            ),
          );
        },
        routes: [
          for (final route in momCozyRoutes)
            GoRoute(
              path: route.path,
              builder: (context, state) =>
                  runtimeController != null &&
                      !capabilities.isRouteEnabled(route.path)
                  ? _BackendCapabilityUnavailablePage(route: route)
                  // The shell keeps one Agent Hub alive across tab changes.
                  // Keep its nested Navigator mounted without creating a
                  // second chat page for this route.
                  : route.path == '/'
                  ? const SizedBox.shrink()
                  : MomCozyRoutePage(
                      route: route,
                      uri: state.uri,
                      extra: state.extra,
                      extendedProductResourcesEnabled:
                          capabilities.extendedProductApiEnabled,
                      onLogout: runtimeController == null
                          ? null
                          : () => runtimeController.logout(
                              sessionStore: sessionStore,
                            ),
                      onBabySelected: runtimeController?.selectBaby,
                    ),
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return const MomCozyRouteShell(
        location: '/404',
        child: MomCozyNotFoundPage(),
      );
    },
  );
}

bool _isOnboardingFlowPath(String path) {
  return path == '/onboarding' || path.startsWith('/avatar/');
}

class _BackendCapabilityUnavailablePage extends StatelessWidget {
  const _BackendCapabilityUnavailablePage({required this.route});

  final MomCozyRouteConfig route;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MomCozyColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              key: ValueKey('backend-capability-unavailable-${route.path}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(route.icon, color: route.accent, size: 42),
                const SizedBox(height: 16),
                Text(
                  '${route.title} is not available yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'This feature is not available in the current environment. You can continue using the rest of the app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _onboardingRedirect(
  MomCozyRuntimeController runtimeController,
  OnboardingController onboardingController,
  GoRouterState state,
) {
  final userId = runtimeController.currentSession.userId;
  final isOnboarding = state.uri.path == '/onboarding';
  if (!onboardingController.isResolvedFor(userId)) {
    return isOnboarding ? null : '/onboarding';
  }
  if (onboardingController.requiresOnboardingFor(userId)) {
    if (isOnboarding) return null;
    final from = state.uri.toString();
    return Uri(
      path: '/onboarding',
      queryParameters: from == '/me' ? null : {'from': from},
    ).toString();
  }
  if (isOnboarding) {
    if (onboardingController.state?.canEnterApp == true &&
        onboardingController.state?.isCompleted == false) {
      return null;
    }
    return _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/me';
  }
  return null;
}

String? _authRedirect(
  MomCozyRuntimeController runtimeController,
  GoRouterState state,
) {
  final path = state.uri.path;
  final isLogin = path == '/login';
  final isAuthenticated = runtimeController.currentSession.isAuthenticated;
  if (!isAuthenticated && !isLogin) {
    final from = state.uri.toString();
    return Uri(
      path: '/login',
      queryParameters: from == '/me' ? null : {'from': from},
    ).toString();
  }
  if (isAuthenticated && isLogin) {
    return _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/me';
  }
  return null;
}

String? _safeAuthRedirect(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path;
  if (path.isEmpty || !path.startsWith('/') || path == '/login') return null;
  return uri.toString();
}

class MomCozyRouteShell extends StatefulWidget {
  const MomCozyRouteShell({
    super.key,
    required this.location,
    required this.child,
    this.uri,
    this.extra,
    this.agentHubBuilder,
    this.avatarTaskController,
  });

  final String location;
  final Widget child;
  final Uri? uri;
  final Object? extra;
  final MomCozyAgentHubBuilder? agentHubBuilder;
  final AvatarTaskController? avatarTaskController;

  @override
  State<MomCozyRouteShell> createState() => _MomCozyRouteShellState();
}

class _MomCozyRouteShellState extends State<MomCozyRouteShell> {
  late bool _hasBuiltAgentHub = widget.location == '/';
  bool _openingAvatarTask = false;

  @override
  void didUpdateWidget(covariant MomCozyRouteShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location == '/' && widget.location != '/') {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (widget.location == '/') {
      _hasBuiltAgentHub = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final hideNavigation = !_primaryNavigationRoutes.contains(location);
    final content = _buildContent(context);

    return Scaffold(
      // Let Schedule scroll beneath the navigation's transparent avatar inset.
      extendBody: location == '/schedule',
      backgroundColor: location == '/me'
          ? MomHomeTokens.background
          : MomCozyColors.background,
      body: SafeArea(
        bottom: hideNavigation,
        child: Column(
          children: [
            if (widget.avatarTaskController case final controller?)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MomCozyLayout.maxAppWidth,
                ),
                child: AvatarTaskBanner(
                  controller: controller,
                  onOpen: () => unawaited(_openAvatarTask(context)),
                ),
              ),
            Expanded(child: MomCozyPageBody(safeArea: false, child: content)),
          ],
        ),
      ),
      bottomNavigationBar: hideNavigation
          ? null
          : MomCozyBottomNavigation(location: location),
    );
  }

  Future<void> _openAvatarTask(BuildContext context) async {
    if (_openingAvatarTask) return;
    _openingAvatarTask = true;
    final origin = widget.uri?.toString() ?? widget.location;
    try {
      await context.push(
        Uri(
          path: '/avatar/review',
          queryParameters: origin == '/' ? null : {'from': origin},
        ).toString(),
      );
    } finally {
      _openingAvatarTask = false;
    }
  }

  Widget _buildContent(BuildContext context) {
    final agentHubBuilder = widget.agentHubBuilder;
    if (agentHubBuilder == null) return widget.child;

    final location = widget.location;
    final isAgentRoute = location == '/';
    if (!_hasBuiltAgentHub) return widget.child;

    final runtime = MomCozyRuntimeScope.of(context);
    final agentHub = KeyedSubtree(
      key: ValueKey<String>(
        'agent-hub-session:${runtime.session.status.name}:${runtime.session.userId}',
      ),
      child: agentHubBuilder(
        context,
        isAgentRoute ? widget.uri : null,
        isAgentRoute ? widget.extra : null,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !isAgentRoute,
          child: ExcludeFocus(
            excluding: !isAgentRoute,
            child: TickerMode(enabled: isAgentRoute, child: agentHub),
          ),
        ),
        Positioned.fill(
          child: Offstage(
            offstage: isAgentRoute,
            child: ExcludeFocus(
              excluding: isAgentRoute,
              child: TickerMode(enabled: !isAgentRoute, child: widget.child),
            ),
          ),
        ),
      ],
    );
  }
}

class MomCozyRoutePage extends StatelessWidget {
  const MomCozyRoutePage({
    super.key,
    required this.route,
    this.uri,
    this.extra,
    this.onLogout,
    this.onBabySelected,
    this.extendedProductResourcesEnabled = false,
  });

  final MomCozyRouteConfig route;
  final Uri? uri;
  final Object? extra;
  final Future<void> Function()? onLogout;
  final Future<void> Function(String babyId)? onBabySelected;
  final bool extendedProductResourcesEnabled;

  @override
  Widget build(BuildContext context) {
    if (route.path == '/me') return buildMotherHome(context);
    if (route.path == '/baby') {
      return buildBabyHome(context, onBabySelected: onBabySelected);
    }
    if (route.path == '/more') {
      return MorePage(onLogout: onLogout);
    }

    if (route.path == '/') {
      return _buildDefaultAgentHubPage(context, uri, extra);
    }

    return MomCozyFeaturePage(
      path: route.path,
      title: route.title,
      summary: route.summary,
      icon: route.icon,
      accent: route.accent,
      priority: route.priority,
      routeUri: uri,
      routeExtra: extra,
      onLogout: onLogout,
      onBabySelected: onBabySelected,
      extendedProductResourcesEnabled: extendedProductResourcesEnabled,
    );
  }
}

final _agentSessionInteractionKeys = Expando<Map<String, Object>>(
  'agent-user-session-keys',
);
Object _agentSessionInteractionKey(MomCozyApiRuntime runtime) =>
    (_agentSessionInteractionKeys[runtime] ??= {}).putIfAbsent(
      runtime.currentSession.userId,
      Object.new,
    );

Widget _buildDefaultAgentHubPage(
  BuildContext context,
  Uri? uri,
  Object? extra,
) {
  final runtime = MomCozyRuntimeScope.of(context);
  String? currentAccessToken() {
    return runtime.currentSession.accessToken ??
        MomCozyRuntimeScope.read(context)?.currentSession.accessToken ??
        runtime.session.accessToken;
  }

  final targetConversationId = uri?.queryParameters['conversationId'];
  return AgentHubPage(
    key: ObjectKey(_agentSessionInteractionKey(runtime)),
    isVisible: uri != null,
    now: runtime.now,
    initialConversationId: targetConversationId,
    stateCacheKey: _agentSessionInteractionKey(runtime),
    interactionStateStore: createSessionAgentHubInteractionStateStore(
      runtime.currentSession,
    ),
    runner: createSessionAgentHubRunner(
      runtime.session,
      accessTokenProvider: currentAccessToken,
      onUnauthorized: runtime.agentStreamUnauthorizedHandler,
    ),
    cancelClient: createSessionAgentHubCancelClient(
      runtime.session,
      accessTokenProvider: currentAccessToken,
      onUnauthorized: runtime.agentStreamUnauthorizedHandler,
    ),
    conversationRepository: runtime.agentConversationRepository,
    greetingProfileLoader:
        runtime.agentHubProfileRepository.fetchGreetingProfile,
    requestBuilder: (message) =>
        buildSessionAgentHubRequest(message, session: runtime.session),
    pickImage: runtime.agentHubImagePicker,
    pickDocument: runtime.agentHubDocumentPicker,
    mediaRepository: runtime.mediaRepository,
    loadImageThumbnail: runtime.mediaContentRepository.loadImageThumbnail,
    loadImageContent: runtime.mediaContentRepository.loadImage,
    onApplicationEvent: runtime.handleAgentApplicationEvent,
    initialComposerText: _agentPrefillFromRoute(uri, extra),
    initialAutoSend: _agentAutoSendFromRoute(uri, extra),
    initialAutoRunRequest: _agentAutoRunFromRoute(extra),
    externalConversationRefreshKey: _motionAssessmentFeedbackRefreshKey(extra),
    externalConversationRefreshUntilFound:
        _motionAssessmentFeedbackRefreshKey(extra) != null,
  );
}

String? _motionAssessmentFeedbackRefreshKey(Object? extra) {
  final extraMap = extra is Map ? extra : null;
  final assessmentId = extraMap?['motionAssessmentFeedbackRefreshKey']
      ?.toString()
      .trim();
  if (assessmentId == null || assessmentId.isEmpty) return null;
  return 'motion:$assessmentId';
}

AgentHubAutoRunRequest? _agentAutoRunFromRoute(Object? extra) {
  final extraMap = extra is Map ? extra : null;
  final rawRequest = extraMap?['agentAutoRun'];
  if (rawRequest is! Map) return null;
  final requestMessage = rawRequest['requestMessage']?.toString().trim() ?? '';
  final idempotencyKey = rawRequest['idempotencyKey']?.toString().trim() ?? '';
  if (requestMessage.isEmpty || idempotencyKey.isEmpty) return null;
  final rawMetadata = rawRequest['metadata'];
  return AgentHubAutoRunRequest(
    requestMessage: requestMessage,
    idempotencyKey: idempotencyKey,
    metadata: rawMetadata is Map
        ? Map<String, Object?>.from(rawMetadata)
        : const <String, Object?>{},
  );
}

String? _agentPrefillFromRoute(Uri? uri, Object? extra) {
  final extraMap = extra is Map ? extra : null;
  final extraPrefill = extraMap?['agentPrefill'];
  if (extraPrefill is String && extraPrefill.trim().isNotEmpty) {
    return extraPrefill.trim();
  }
  final queryPrefill = uri?.queryParameters['agentPrefill'];
  if (queryPrefill != null && queryPrefill.trim().isNotEmpty) {
    return queryPrefill.trim();
  }
  return null;
}

bool _agentAutoSendFromRoute(Uri? uri, Object? extra) {
  final extraMap = extra is Map ? extra : null;
  final extraAutoSend = extraMap?['autoSend'] ?? extraMap?['agentAutoSend'];
  if (extraAutoSend == true) return true;
  final queryAutoSend =
      uri?.queryParameters['autoSend'] ?? uri?.queryParameters['agentAutoSend'];
  return queryAutoSend == 'true' || queryAutoSend == '1';
}

class MomCozyNotFoundPage extends StatelessWidget {
  const MomCozyNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: MomSettingsCard(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: MomHomeTokens.mint,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.search_off_outlined,
                          size: 32,
                          color: MomHomeTokens.teal,
                        ),
                      ),
                    ),
                    Text(
                      'Page not found',
                      textAlign: TextAlign.center,
                      style: MomHomeTokens.text(22, weight: FontWeight.w700),
                    ),
                    Text(
                      'This page may have moved, or the link may have expired.',
                      textAlign: TextAlign.center,
                      style: MomHomeTokens.text(
                        14,
                        color: MomHomeTokens.secondary,
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/me'),
                      child: const Text('Back to home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class MomCozyRouteConfig {
  const MomCozyRouteConfig({
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.priority,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final String priority;
}

const notFoundRoute = MomCozyRouteConfig(
  path: '/404',
  title: 'Page not found',
  summary: 'This page may have moved, or the link may have expired.',
  icon: Icons.search_off_rounded,
  accent: Color(0xff7f6a75),
  priority: 'P2',
);

const momCozyRoutes = [
  MomCozyRouteConfig(
    path: '/',
    title: 'Momcozy AI',
    summary: 'AI support, connected records, and expert services.',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xff9f6378),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/me',
    title: 'Me',
    summary: 'Your profile, lactation records, and expert support.',
    icon: Icons.person_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/baby',
    title: 'Baby',
    summary: 'Baby profiles, care records, and growth trends.',
    icon: Icons.child_care_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/schedule',
    title: 'Schedule',
    summary: 'Appointments, care tasks, and your schedule.',
    icon: Icons.event_note_rounded,
    accent: Color(0xffb2773b),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/more',
    title: 'More',
    summary: 'Account, services, notifications, and privacy settings.',
    icon: Icons.more_horiz_rounded,
    accent: Color(0xffa21849),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/notifications',
    title: 'Notifications',
    summary: 'Appointment, task, and service reminders.',
    icon: Icons.notifications_rounded,
    accent: Color(0xff862644),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/media-viewer',
    title: 'Resource preview',
    summary: 'A secure preview opened from a Momcozy AI resource card.',
    icon: Icons.perm_media_rounded,
    accent: Color(0xff6b6da8),
    priority: 'P1',
  ),
];

const _primaryNavigationRoutes = {'/me', '/baby', '/', '/schedule', '/more'};
