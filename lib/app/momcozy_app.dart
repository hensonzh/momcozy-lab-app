import 'dart:io';
import '../features/notifications/data/firebase_push_messaging.dart';
import '../features/notifications/data/native_notification_platform.dart';
import '../features/notifications/data/notification_installation_store.dart';
import '../features/notifications/presentation/notification_coordinator.dart';
import '../features/notifications/presentation/notification_permission_controller.dart';
import '../features/notifications/presentation/notification_scope.dart';
import 'mom_module_routes.dart';
import 'baby_module_routes.dart';
import 'chat_first_navigation.dart';
import 'mom_bottom_navigation.dart';
import 'primary_tab_activity.dart';
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
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/more_page.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/chat_first_onboarding_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_workspace.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_avatar.dart';
import 'package:momcozy_flutter_app/features/app_pages/devices_page.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_mother_page.dart';
import 'package:momcozy_flutter_app/features/records/presentation/chat_first_record_sheet.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_welcome_coordinator.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_welcome_gate.dart';
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
          chatFirstMode: true,
        )
      : null;
  late final GoRouter _router =
      widget.router ??
      createMomCozyRouter(
        runtimeController: _runtimeController,
        onboardingController: _onboardingController,
        chatFirstExperience: true,
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
    _onboardingController?.dispose();
    if (_ownsRuntimeController) _runtimeController.dispose();
    if (_ownsRouter) _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
  String? initialLocation,
  bool chatFirstExperience = false,
  MomCozyRuntimeController? runtimeController,
  OnboardingController? onboardingController,
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
      (context, uri, extra) => _buildDefaultAgentHubPage(
        context,
        uri,
        extra,
        chatFirstExperience: chatFirstExperience,
        familyRole: onboardingController?.state?.role,
      );
  final routesByPath = {for (final route in momCozyRoutes) route.path: route};
  GoRoute routeFor(String path, {List<RouteBase> childRoutes = const []}) {
    final route = routesByPath[path]!;
    return GoRoute(
      path: path,
      routes: childRoutes,
      builder: (context, state) {
        if (runtimeController != null && !capabilities.isRouteEnabled(path)) {
          return _BackendCapabilityUnavailablePage(route: route);
        }
        if (path == '/') {
          final runtime = MomCozyRuntimeScope.of(context);
          return KeyedSubtree(
            key: ValueKey((
              runtime,
              runtime.session.status,
              runtime.session.userId,
            )),
            child: chatFirstExperience
                ? ChatFirstVoiceHost(
                    runtimeBaseUri: runtime.apiBaseUri,
                    tokenProvider: () => runtime.currentSession.accessToken,
                    child: Column(
                      children: [
                        ChatFirstWorkspace(
                          runtime: runtime,
                          role: onboardingController?.state?.role,
                          onOpenDrawer: () => Scaffold.of(context).openDrawer(),
                        ),
                        Expanded(
                          child: resolvedAgentHubBuilder(
                            context,
                            state.uri,
                            state.extra,
                          ),
                        ),
                      ],
                    ),
                  )
                : resolvedAgentHubBuilder(context, state.uri, state.extra),
          );
        }
        final role = onboardingController?.state?.role;
        final page =
            chatFirstExperience &&
                path == '/me' &&
                onboardingController?.state?.profileScope == 'chat_first' &&
                role != null
            ? ChatFirstMotherPage(
                key: ValueKey(MomCozyRuntimeScope.of(context)),
                runtime: MomCozyRuntimeScope.of(context),
                role: role,
              )
            : MomCozyRoutePage(
                route: route,
                chatFirstExperience: chatFirstExperience,
                uri: state.uri,
                extra: state.extra,
                extendedProductResourcesEnabled:
                    capabilities.extendedProductApiEnabled,
                onLogout: runtimeController == null
                    ? null
                    : () =>
                          runtimeController.logout(sessionStore: sessionStore),
                onDeleteAccount: runtimeController == null
                    ? null
                    : () async {
                        await runtimeController.runtime.authRepository
                            .deleteAccount();
                        await runtimeController.logout(
                          sessionStore: sessionStore,
                          revokeRemote: false,
                        );
                      },
                onBabySelected: runtimeController?.selectBaby,
              );
        return chatFirstExperience && _chatFirstSectionRoutes.contains(path)
            ? Column(
                children: [
                  ChatFirstSectionHeader(location: path),
                  Expanded(child: page),
                ],
              )
            : page;
      },
    );
  }

  return GoRouter(
    initialLocation: initialLocation ?? (chatFirstExperience ? '/' : '/me'),
    refreshListenable: runtimeController == null
        ? onboardingController
        : onboardingController == null
        ? runtimeController
        : Listenable.merge([runtimeController, onboardingController]),
    redirect: (context, state) {
      if (runtimeController == null) return null;
      if (state.uri.path.startsWith('/avatar/')) {
        return chatFirstExperience ? '/' : '/me';
      }
      if (onboardingController == null && state.uri.path == '/onboarding') {
        return chatFirstExperience ? '/' : '/me';
      }
      final authRedirect = _authRedirect(
        runtimeController,
        state,
        home: chatFirstExperience ? '/' : '/me',
      );
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
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(chatFirstExperience ? '/more' : '/me'),
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
          builder: (context, state) => onboardingController.chatFirstMode
              ? ChatFirstOnboardingPage(
                  controller: onboardingController,
                  entryPath:
                      _safeAuthRedirect(state.uri.queryParameters['from']) ??
                      '/',
                )
              : OnboardingPage(
                  controller: onboardingController,
                  entryPath:
                      _safeAuthRedirect(state.uri.queryParameters['from']) ??
                      '/me',
                ),
        ),
      ...createMomModuleRoutes(chatFirstExperience: chatFirstExperience),
      ...babyModuleRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final runtime = MomCozyRuntimeScope.of(context);
          return MomCozyRouteTelemetry(
            location: state.uri.path,
            observability: runtime.observability,
            child: MomCozyRouteShell(
              location: state.uri.path,
              chatFirstExperience: chatFirstExperience,
              familyRole: onboardingController?.state?.role,
              child: navigationShell,
              onSelectTab: (index) {
                if (index != navigationShell.currentIndex) {
                  navigationShell.goBranch(index);
                }
              },
            ),
          );
        },
        branches: [
          for (final path in [
            '/me',
            '/baby',
            '/',
            '/schedule',
            '/more',
            '/devices',
          ])
            StatefulShellBranch(
              routes: [
                routeFor(
                  path,
                  childRoutes: path == '/baby' && chatFirstExperience
                      ? [
                          GoRoute(
                            path: 'details',
                            builder: (context, state) => Column(
                              children: [
                                const ChatFirstSectionHeader(
                                  location: '/baby',
                                  backPath: '/baby',
                                ),
                                Expanded(
                                  child: buildBabyHome(
                                    context,
                                    chatFirstExperience: true,
                                    fullDetails: true,
                                    onBabySelected:
                                        runtimeController?.selectBaby,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : const [],
                ),
              ],
            ),
          StatefulShellBranch(
            routes: [routeFor('/notifications'), routeFor('/media-viewer')],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return MomCozyRouteShell(
        location: '/404',
        chatFirstExperience: chatFirstExperience,
        child: MomCozyNotFoundPage(chatFirstExperience: chatFirstExperience),
      );
    },
  );
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
  final home = onboardingController.chatFirstMode ? '/' : '/me';
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
      queryParameters: from == home ? null : {'from': from},
    ).toString();
  }
  if (isOnboarding) {
    return _safeAuthRedirect(state.uri.queryParameters['from']) ?? home;
  }
  return null;
}

String? _authRedirect(
  MomCozyRuntimeController runtimeController,
  GoRouterState state, {
  required String home,
}) {
  final path = state.uri.path;
  final isLogin = path == '/login';
  final isAuthenticated = runtimeController.currentSession.isAuthenticated;
  if (!isAuthenticated && !isLogin) {
    final from = state.uri.toString();
    return Uri(
      path: '/login',
      queryParameters: from == home ? null : {'from': from},
    ).toString();
  }
  if (isAuthenticated && isLogin) {
    return _safeAuthRedirect(state.uri.queryParameters['from']) ?? home;
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
    this.familyRole,
    this.chatFirstExperience = false,
    this.onSelectTab,
    this.appBar,
  });

  final String location;
  final Widget child;
  final FamilyRole? familyRole;
  final bool chatFirstExperience;
  final ValueChanged<int>? onSelectTab;
  final PreferredSizeWidget? appBar;

  @override
  State<MomCozyRouteShell> createState() => _MomCozyRouteShellState();
}

class _MomCozyRouteShellState extends State<MomCozyRouteShell> {
  int _activation = 0;
  MomCozyApiRuntime? _tabRuntime;
  final _avatarController = ChatFirstAvatarController();

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  String? get _selectedTab => switch (widget.location) {
    '/me' => 'me',
    '/baby' => 'baby',
    '/schedule' => 'schedule',
    _ => null,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabRuntime = MomCozyRuntimeScope.maybeOf(context);
    _tabRuntime?.selectPrimaryTab(_selectedTab);
  }

  @override
  void didUpdateWidget(covariant MomCozyRouteShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _tabRuntime?.selectPrimaryTab(_selectedTab);
    }
    if (oldWidget.location != widget.location &&
        _primaryNavigationRoutes.contains(widget.location)) {
      _activation++;
    }
    if (oldWidget.location == '/' && widget.location != '/') {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final isHome = widget.chatFirstExperience && location == '/';
    final hideLegacyNavigation = !_primaryNavigationRoutes.contains(location);
    return Scaffold(
      appBar: widget.appBar,
      extendBody: !widget.chatFirstExperience && location == '/schedule',
      drawer: isHome ? const ChatFirstDrawer() : null,
      backgroundColor: location == '/me'
          ? MomHomeTokens.background
          : MomCozyColors.background,
      body: ChatFirstAvatarScope(
        controller: _avatarController,
        child: SafeArea(
          bottom: widget.chatFirstExperience || hideLegacyNavigation,
          child: Column(
            children: [
              Expanded(
                child: MomCozyPageBody(
                  safeArea: false,
                  child: PrimaryTabActivity(
                    selectedIndex: switch (location) {
                      '/me' => 0,
                      '/baby' => 1,
                      '/' => 2,
                      '/schedule' => 3,
                      '/more' => 4,
                      _ => -1,
                    },
                    activation: _activation,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.chatFirstExperience || hideLegacyNavigation
          ? null
          : _tabRuntime == null
          ? MomCozyBottomNavigation(
              location: location,
              onSelectTab: widget.onSelectTab,
            )
          : ValueListenableBuilder<Set<String>>(
              valueListenable: _tabRuntime!.updatedPrimaryTabs,
              builder: (context, updatedTabs, child) => MomCozyBottomNavigation(
                location: location,
                onSelectTab: widget.onSelectTab,
                updatedTabs: updatedTabs,
              ),
            ),
    );
  }
}

class MomCozyRoutePage extends StatelessWidget {
  const MomCozyRoutePage({
    super.key,
    required this.route,
    this.chatFirstExperience = false,
    this.uri,
    this.extra,
    this.onLogout,
    this.onDeleteAccount,
    this.onBabySelected,
    this.extendedProductResourcesEnabled = false,
  });

  final MomCozyRouteConfig route;
  final bool chatFirstExperience;
  final Uri? uri;
  final Object? extra;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onDeleteAccount;
  final Future<void> Function(String babyId)? onBabySelected;
  final bool extendedProductResourcesEnabled;

  @override
  Widget build(BuildContext context) {
    if (route.path == '/me') return buildMotherHome(context);
    if (route.path == '/baby') {
      return buildBabyHome(
        context,
        chatFirstExperience: chatFirstExperience,
        onBabySelected: onBabySelected,
      );
    }
    if (route.path == '/more') {
      return MorePage(
        key: ValueKey(MomCozyRuntimeScope.of(context)),
        onLogout: onLogout,
        onDeleteAccount: onDeleteAccount,
        showChatFirstLinks: chatFirstExperience,
      );
    }
    if (route.path == '/devices') {
      final runtime = MomCozyRuntimeScope.of(context);
      return DevicesPage(key: ValueKey(runtime), runtime: runtime);
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
      onDeleteAccount: onDeleteAccount,
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
  Object? extra, {
  bool chatFirstExperience = false,
  FamilyRole? familyRole,
}) {
  final runtime = MomCozyRuntimeScope.of(context);
  final tabActivity = PrimaryTabActivity.maybeOf(context);
  String? currentAccessToken() {
    return runtime.currentSession.accessToken ??
        MomCozyRuntimeScope.read(context)?.currentSession.accessToken ??
        runtime.session.accessToken;
  }

  final targetConversationId = uri?.queryParameters['conversationId'];
  final isVisible = tabActivity == null
      ? uri != null
      : tabActivity.selectedIndex == 2;
  Widget buildHub(
    AgentHubAutoRunRequest? welcomeRequest,
    String? currentWelcomeKey,
    ValueChanged<String>? onWelcomeAccepted,
    VoidCallback? onWelcomeRejected,
    int retryToken,
  ) => AgentHubPage(
    chatFirstExperience: chatFirstExperience,
    currentWelcomeKey: currentWelcomeKey,
    onInitialAutoRunAccepted: onWelcomeAccepted,
    onInitialAutoRunRejected: onWelcomeRejected,
    initialAutoRunRetryToken: retryToken,
    onChatFirstRecord: chatFirstExperience
        ? (context, kind) async {
            await showChatFirstRecordSheet(
              context,
              runtime: runtime,
              kind: kind,
            );
          }
        : null,
    key: ObjectKey(_agentSessionInteractionKey(runtime)),
    isVisible: isVisible,
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
    conversationRepository: runtime.createAgentConversationRepository(
      identifyWelcomeBoundary:
          chatFirstExperience && familyRole == FamilyRole.mother,
    ),
    greetingProfileLoader:
        runtime.agentHubProfileRepository.fetchGreetingProfile,
    requestBuilder: (message) => buildSessionAgentHubRequest(
      message,
      session: runtime.session,
      locale: chatFirstExperience ? 'zh-CN' : null,
    ),
    pickImage: runtime.agentHubImagePicker,
    pickStoolPhoto: runtime.stoolPhotoOriginalPicker,
    stoolPhotoReviewRepository: runtime.stoolPhotoReviewRepository,
    stoolAnalysisRepository: runtime.stoolAnalysisRepository,
    stoolBabyId: runtime.currentSession.babyId,
    pickDocument: runtime.agentHubDocumentPicker,
    mediaRepository: runtime.mediaRepository,
    loadImageThumbnail: runtime.mediaContentRepository.loadImageThumbnail,
    loadImageContent: runtime.mediaContentRepository.loadImage,
    onApplicationEvent: runtime.handleAgentApplicationEvent,
    initialComposerText: _agentPrefillFromRoute(uri, extra),
    initialComposerRequestKey: extra,
    initialAutoSend: _agentAutoSendFromRoute(uri, extra),
    initialAutoRunRequest: _agentAutoRunFromRoute(extra) ?? welcomeRequest,
    externalConversationRefreshKey: _motionAssessmentFeedbackRefreshKey(extra),
    externalConversationRefreshUntilFound:
        _motionAssessmentFeedbackRefreshKey(extra) != null,
  );
  if (!chatFirstExperience || familyRole != FamilyRole.mother) {
    return buildHub(null, null, null, null, 0);
  }
  return ChatFirstWelcomeGate(
    activationKey: runtime.currentSession.userId,
    visible: isVisible,
    coordinator: ChatFirstWelcomeCoordinator(
      product: runtime.jsonTransport,
      agent: runtime.agentJsonTransport,
      store: const SecureChatFirstWelcomeStore(),
      ownerUserId: runtime.currentSession.userId,
      role: familyRole,
      now: runtime.now,
    ),
    builder:
        (context, request, currentKey, onAccepted, onRejected, retryToken) =>
            buildHub(request, currentKey, onAccepted, onRejected, retryToken),
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
  const MomCozyNotFoundPage({super.key, this.chatFirstExperience = false});

  final bool chatFirstExperience;

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
                      chatFirstExperience
                          ? chatFirstNotFoundTitle
                          : 'Page not found',
                      textAlign: TextAlign.center,
                      style: MomHomeTokens.text(22, weight: FontWeight.w700),
                    ),
                    Text(
                      chatFirstExperience
                          ? chatFirstNotFoundSummary
                          : 'This page may have moved, or the link may have expired.',
                      textAlign: TextAlign.center,
                      style: MomHomeTokens.text(
                        14,
                        color: MomHomeTokens.secondary,
                      ),
                    ),
                    FilledButton(
                      onPressed: () =>
                          context.go(chatFirstExperience ? '/' : '/me'),
                      child: Text(
                        chatFirstExperience
                            ? chatFirstBackToConversation
                            : 'Back to home',
                      ),
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
    summary: 'AI support and connected records.',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xff9f6378),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/me',
    title: 'Me',
    summary: 'Your profile and lactation records.',
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
    summary: 'Your personal schedule.',
    icon: Icons.event_note_rounded,
    accent: Color(0xffb2773b),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/more',
    title: 'More',
    summary: 'Account and privacy settings.',
    icon: Icons.more_horiz_rounded,
    accent: Color(0xffa21849),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/devices',
    title: 'Devices',
    summary: 'Registered devices for this account.',
    icon: Icons.devices_other_rounded,
    accent: Color(0xff9f6378),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/notifications',
    title: 'Notifications',
    summary: 'Conversation and account updates.',
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
const _chatFirstSectionRoutes = {
  '/me',
  '/baby',
  '/devices',
  '/schedule',
  '/more',
};
