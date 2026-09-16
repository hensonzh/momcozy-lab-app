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
import '../shared/widgets/product_feedback.dart';
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
import 'package:momcozy_flutter_app/core/routing/external_url_launcher.dart';
import 'package:momcozy_flutter_app/core/routing/safe_link_target.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
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
    Widget Function(
      BuildContext context,
      Uri? uri,
      Object? extra,
      AgentVoicePlaybackCoordinator voicePlaybackCoordinator,
    );

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
    this.externalUrlLauncher = const PlatformExternalUrlLauncher(),
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
  final ExternalUrlLauncher externalUrlLauncher;

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
        externalUrlLauncher: widget.externalUrlLauncher,
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
        locale: session.locale,
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
        title: 'Momcozy Lab',
        scaffoldMessengerKey: _messengerKey,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
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
  ExternalUrlLauncher externalUrlLauncher = const PlatformExternalUrlLauncher(),
}) {
  final resolvedAgentHubBuilder =
      agentHubBuilder ??
      (context, uri, extra, voicePlaybackCoordinator) =>
          _buildDefaultAgentHubPage(
            context,
            uri,
            extra,
            voicePlaybackCoordinator,
            externalUrlLauncher: externalUrlLauncher,
            conversationHistoryEnabled:
                capabilities.agentConversationHistoryEnabled,
          );
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
                  '${route.title} 暂未开放',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前环境尚未启用对应后端契约。其他功能可继续使用。',
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
  final AgentVoicePlaybackCoordinator _voicePlaybackCoordinator =
      AgentVoicePlaybackCoordinator();
  late bool _hasBuiltAgentHub = widget.location == '/';
  bool _openingAvatarTask = false;

  @override
  void initState() {
    super.initState();
    if (widget.location == '/motion-assessment') {
      unawaited(_voicePlaybackCoordinator.suspendAndDrain());
    }
  }

  @override
  void didUpdateWidget(covariant MomCozyRouteShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location == '/' && widget.location != '/') {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final wasMotionAssessment = oldWidget.location == '/motion-assessment';
    final isMotionAssessment = widget.location == '/motion-assessment';
    if (!wasMotionAssessment && isMotionAssessment) {
      // The assessment owns its own full-duplex Realtime voice session. The
      // Agent Hub remains mounted offstage, so suspend both current and future
      // normal Agent playback until this focused flow has ended.
      unawaited(_voicePlaybackCoordinator.suspendAndDrain());
    } else if (wasMotionAssessment && !isMotionAssessment) {
      _voicePlaybackCoordinator.resume();
    }
    if (widget.location == '/') {
      _hasBuiltAgentHub = true;
    }
  }

  @override
  void dispose() {
    _voicePlaybackCoordinator.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final hideNavigation = !_primaryNavigationRoutes.contains(location);
    final content = _buildContent(context);

    return Scaffold(
      backgroundColor: MomCozyColors.background,
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
        _voicePlaybackCoordinator,
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
        if (!isAgentRoute) Positioned.fill(child: widget.child),
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
      return _buildDefaultAgentHubPage(
        context,
        uri,
        extra,
        AgentVoicePlaybackCoordinator(),
      );
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

// AgentHubPage caches by object identity. Keep conversation keys stable across
// route rebuilds, while allowing all keys to be collected with their runtime.
final _conversationInteractionKeys = Expando<Map<String, Object>>(
  'momcozy-conversation-interaction-keys',
);

Object _conversationInteractionKey(
  MomCozyApiRuntime runtime,
  String conversationId,
) {
  final keys = _conversationInteractionKeys[runtime] ??= <String, Object>{};
  return keys.putIfAbsent(
    '${runtime.currentSession.userId}:$conversationId',
    Object.new,
  );
}

Widget _buildDefaultAgentHubPage(
  BuildContext context,
  Uri? uri,
  Object? extra,
  AgentVoicePlaybackCoordinator voicePlaybackCoordinator, {
  ExternalUrlLauncher externalUrlLauncher = const PlatformExternalUrlLauncher(),
  bool conversationHistoryEnabled = false,
}) {
  final runtime = MomCozyRuntimeScope.of(context);
  String? currentAccessToken() {
    return runtime.currentSession.accessToken ??
        MomCozyRuntimeScope.read(context)?.currentSession.accessToken ??
        runtime.session.accessToken;
  }

  final targetConversationId = uri?.queryParameters['conversationId'];
  return AgentHubPage(
    key: ValueKey(
      'agent-hub-${runtime.currentSession.userId}${targetConversationId == null ? '' : '-$targetConversationId'}',
    ),
    initialConversationId: targetConversationId,
    stateCacheKey: targetConversationId == null
        ? runtime
        : _conversationInteractionKey(runtime, targetConversationId),
    interactionStateStore: targetConversationId != null
        ? null
        : createSessionAgentHubInteractionStateStore(runtime.currentSession),
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
    actionClient: createSessionAgentHubActionClient(
      runtime.session,
      accessTokenProvider: currentAccessToken,
      onUnauthorized: runtime.agentStreamUnauthorizedHandler,
    ),
    clientEventClient: createSessionAgentHubClientEventClient(
      runtime.session,
      accessTokenProvider: currentAccessToken,
      onUnauthorized: runtime.agentStreamUnauthorizedHandler,
    ),
    conversationRepository:
        conversationHistoryEnabled || targetConversationId != null
        ? runtime.agentConversationRepository
        : null,
    greetingProfileLoader:
        runtime.agentHubProfileRepository.fetchGreetingProfile,
    requestBuilder: (message) =>
        buildSessionAgentHubRequest(message, session: runtime.session),
    voicePlaybackCoordinator: voicePlaybackCoordinator,
    voicePlaybackPlayer: runtime.agentVoicePlaybackPlayer,
    pickImage: runtime.agentHubImagePicker,
    pickDocument: runtime.agentHubDocumentPicker,
    mediaRepository: runtime.mediaRepository,
    loadImageThumbnail: runtime.mediaContentRepository.loadImageThumbnail,
    loadImageContent: runtime.mediaContentRepository.loadImage,
    productAssetRepository: runtime.productAssetRepository,
    supportTicketSubmitter: runtime.supportTicketRepository.submit,
    onApplicationEvent: runtime.handleAgentApplicationEvent,
    onArtifactAction: (action) => unawaited(
      dispatchAgentArtifactAction(
        context,
        action,
        externalUrlLauncher: externalUrlLauncher,
      ),
    ),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: ProductEmptyView(
            icon: Icons.search_off_outlined,
            title: '页面未找到',
            description: '这个页面可能已移动，或链接已失效。',
            action: FilledButton(
              onPressed: () => context.go('/me'),
              child: const Text('返回首页'),
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
  title: '页面未找到',
  summary: '这个页面可能已移动，或链接已失效。',
  icon: Icons.search_off_rounded,
  accent: Color(0xff7f6a75),
  priority: 'P2',
);

const momCozyRoutes = [
  MomCozyRouteConfig(
    path: '/',
    title: 'Cozymate',
    summary: '智能体陪伴、记录衔接与服务入口。',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xff9f6378),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/me',
    title: 'Me',
    summary: '妈妈状态、日记、泌乳和专家支持。',
    icon: Icons.person_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/baby',
    title: 'Baby',
    summary: '宝宝档案、照护记录和成长趋势。',
    icon: Icons.child_care_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/schedule',
    title: 'Schedule',
    summary: '预约、专业任务和个人日程。',
    icon: Icons.event_note_rounded,
    accent: Color(0xffb2773b),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/more',
    title: 'More',
    summary: '账号、服务资产、通知与隐私授权。',
    icon: Icons.more_horiz_rounded,
    accent: Color(0xffa21849),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/notifications',
    title: 'Notifications',
    summary: '预约、任务和服务提醒。',
    icon: Icons.notifications_rounded,
    accent: Color(0xff862644),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/media-viewer',
    title: '资料预览',
    summary: '从 Cozymate 资料卡片打开的安全预览。',
    icon: Icons.perm_media_rounded,
    accent: Color(0xff6b6da8),
    priority: 'P1',
  ),
];

const _primaryNavigationRoutes = {'/me', '/baby', '/', '/schedule', '/more'};

Future<void> dispatchAgentArtifactAction(
  BuildContext context,
  AgentArtifactActionView action, {
  ExternalUrlLauncher externalUrlLauncher = const PlatformExternalUrlLauncher(),
}) async {
  final path = action.routePath;
  if (path != null && _knownFlutterRoutePaths.contains(path)) {
    Object? routeExtra = action.routeExtra;
    final target = SafeLinkTarget.tryParse(action.value);
    final location = routeExtra == null && target?.internalPath == path
        ? target!.internalLocation!
        : path;
    context.go(location, extra: routeExtra);
    return;
  }

  final externalUri = SafeLinkTarget.tryParse(
    action.externalUri?.toString(),
  )?.externalUri;
  if (externalUri == null) return;
  var opened = false;
  try {
    opened = await externalUrlLauncher.open(externalUri);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(const SnackBar(content: Text('无法打开链接，请稍后重试')));
}

final _knownFlutterRoutePaths = momCozyRoutes
    .map((route) => route.path)
    .followedBy(momModuleRoutes.map((route) => route.path))
    .followedBy(babyModuleRoutes.map((route) => route.path))
    .toSet();
