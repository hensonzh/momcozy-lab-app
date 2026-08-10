import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/update/app_release_lifecycle.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';
import 'package:momcozy_flutter_app/core/routing/external_url_launcher.dart';
import 'package:momcozy_flutter_app/core/routing/safe_link_target.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
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
    this.apiRuntime,
    this.runtimeController,
    this.sessionStore = const FlutterSecureMomCozySessionStore(),
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
    this.lastInviteCodeStore = const FlutterSecureMomCozyLastInviteCodeStore(),
    this.onboardingReleasePolicy = const NoopOnboardingReleasePolicy(),
    this.agentHubBuilder,
    this.externalUrlLauncher = const PlatformExternalUrlLauncher(),
  }) : assert(
         apiRuntime == null || runtimeController == null,
         'Pass either apiRuntime or runtimeController, not both.',
       );

  final GoRouter? router;
  final RouteIntentPlatform? routeIntentPlatform;
  final MomCozyApiRuntime? apiRuntime;
  final MomCozyRuntimeController? runtimeController;
  final MomCozySessionStore sessionStore;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;
  final MomCozyLastInviteCodeStore lastInviteCodeStore;
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
      widget.router == null &&
          _runtimeController.runtime.supportsSessionAutoRefresh
      ? OnboardingController(
          runtimeController: _runtimeController,
          onPrimaryInfantSelected: _runtimeController.selectBaby,
          onAvatarActivated: () => _runtimeController
              .runtime
              .profileOverviewCache
              .invalidateOverview(),
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
        agentHubBuilder: widget.agentHubBuilder,
        externalUrlLauncher: widget.externalUrlLauncher,
      );
  late final bool _ownsRouter = widget.router == null;
  late final RouteIntentPlatform _routeIntentPlatform =
      widget.routeIntentPlatform ?? AndroidRouteIntentPlatform();
  late final bool _ownsRouteIntentPlatform = widget.routeIntentPlatform == null;
  StreamSubscription<PendingNativeRoute>? _activeRouteSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtimeController.enableSessionAutoRefresh(widget.sessionStore);
    _activeRouteSub = _routeIntentPlatform.activeRoutes.listen(
      _handlePendingNativeRoute,
    );
    unawaited(_consumePendingNativeRoute());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_activeRouteSub?.cancel());
    if (_ownsRouteIntentPlatform) {
      final platform = _routeIntentPlatform;
      if (platform is AndroidRouteIntentPlatform) unawaited(platform.dispose());
    }
    _avatarTaskController?.dispose();
    _onboardingController?.dispose();
    if (_ownsRuntimeController) _runtimeController.dispose();
    if (_ownsRouter) _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _avatarTaskController?.setForeground(state == AppLifecycleState.resumed);
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
          child: child!,
        );
      },
      child: MaterialApp.router(
        title: 'Momcozy Lab',
        theme: momCozyTheme(),
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

ThemeData momCozyTheme() {
  final colorScheme = const ColorScheme.light(
    primary: MomCozyColors.primary,
    onPrimary: MomCozyColors.background,
    primaryContainer: MomCozyColors.roseSoft,
    onPrimaryContainer: MomCozyColors.foreground,
    secondary: MomCozyColors.secondary,
    onSecondary: MomCozyColors.foreground,
    secondaryContainer: MomCozyColors.secondary,
    onSecondaryContainer: MomCozyColors.foreground,
    tertiary: MomCozyColors.warm,
    onTertiary: MomCozyColors.foreground,
    surface: MomCozyColors.background,
    onSurface: MomCozyColors.foreground,
    surfaceContainerLowest: MomCozyColors.background,
    surfaceContainerLow: MomCozyColors.card,
    surfaceContainer: MomCozyColors.muted,
    surfaceContainerHigh: MomCozyColors.secondary,
    surfaceContainerHighest: MomCozyColors.roseSoft,
    onSurfaceVariant: MomCozyColors.mutedForeground,
    outline: MomCozyColors.border,
    outlineVariant: MomCozyColors.border,
    error: Color(0xffdc2626),
    errorContainer: Color(0xffffe4e6),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MomCozyColors.background,
    fontFamily: MomCozyTypography.fontFamily,
    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
    textTheme: Typography.blackCupertino.apply(
      bodyColor: MomCozyColors.foreground,
      displayColor: MomCozyColors.foreground,
      fontFamily: MomCozyTypography.fontFamily,
      fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
    ),
    dividerTheme: const DividerThemeData(
      color: MomCozyColors.border,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: MomCozyColors.foreground),
    cardTheme: CardThemeData(
      color: MomCozyColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
        side: const BorderSide(color: MomCozyColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MomCozyColors.primary,
        foregroundColor: MomCozyColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MomCozyColors.primary,
        side: const BorderSide(color: MomCozyColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MomCozyColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: MomCozyColors.mutedForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MomCozyColors.raised;
        }
        return MomCozyColors.mutedForeground.withValues(alpha: 0.82);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MomCozyColors.primary;
        }
        return MomCozyColors.border.withValues(alpha: 0.72);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MomCozyColors.care;
        }
        return MomCozyColors.raised;
      }),
      checkColor: WidgetStateProperty.all(MomCozyColors.raised),
      side: const BorderSide(color: MomCozyColors.care, width: 1.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: MomCozyColors.primary,
      inactiveTrackColor: MomCozyColors.border.withValues(alpha: 0.7),
      overlayColor: MomCozyColors.primary.withValues(alpha: 0.12),
      thumbColor: MomCozyColors.primary,
      valueIndicatorColor: MomCozyColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        color: MomCozyColors.background,
        fontFamily: MomCozyTypography.fontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        fontWeight: FontWeight.w800,
      ),
      trackHeight: 5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: MomCozyColors.primary,
      linearTrackColor: MomCozyColors.roseSoft,
      circularTrackColor: MomCozyColors.roseSoft,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? MomCozyColors.roseSoft
              : MomCozyColors.card;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? MomCozyColors.primary
              : MomCozyColors.mutedForeground;
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: MomCozyColors.border),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MomCozyRadii.control),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: MomCozyTypography.fontFamily,
            fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MomCozyColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.primary, width: 1.4),
      ),
    ),
  );
}

GoRouter createMomCozyRouter({
  String initialLocation = '/',
  MomCozyRuntimeController? runtimeController,
  OnboardingController? onboardingController,
  AvatarTaskController? avatarTaskController,
  OnboardingAvatarImageLoader? avatarThumbnailLoader,
  MomCozySessionStore sessionStore = const FlutterSecureMomCozySessionStore(),
  MomCozyAuthDeviceIdStore authDeviceIdStore =
      const FlutterSecureMomCozyAuthDeviceIdStore(),
  MomCozyLastInviteCodeStore lastInviteCodeStore =
      const FlutterSecureMomCozyLastInviteCodeStore(),
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
          );
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: runtimeController == null
        ? onboardingController
        : onboardingController == null
        ? runtimeController
        : Listenable.merge([runtimeController, onboardingController]),
    redirect: (context, state) {
      if (state.uri.path == '/status') return '/me';
      if (state.uri.path == '/schedule') {
        return state.uri.replace(path: '/plan').toString();
      }
      if (runtimeController == null) return null;
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
                _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/',
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
                _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/',
            avatarThumbnailLoader: avatarThumbnailLoader,
            onAvatarTaskCompleted: avatarTaskController?.showCompleted,
          ),
        ),
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
              builder: (context, state) => MomCozyRoutePage(
                route: route,
                uri: state.uri,
                extra: state.extra,
                onLogout: runtimeController == null
                    ? null
                    : () =>
                          runtimeController.logout(sessionStore: sessionStore),
                onBabySelected: runtimeController?.selectBaby,
              ),
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return const MomCozyRouteShell(
        location: '/404',
        child: MomCozyRoutePage(route: notFoundRoute),
      );
    },
  );
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
      queryParameters: from == '/' ? null : {'from': from},
    ).toString();
  }
  if (isOnboarding) {
    if (onboardingController.state?.canEnterApp == true &&
        onboardingController.state?.isCompleted == false) {
      return null;
    }
    return _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/';
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
      queryParameters: from == '/' ? null : {'from': from},
    ).toString();
  }
  if (isAuthenticated && isLogin) {
    return _safeAuthRedirect(state.uri.queryParameters['from']) ?? '/';
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
  MomCozyApiRuntime? _warmedPlanRuntime;
  bool _openingAvatarTask = false;

  @override
  void initState() {
    super.initState();
    if (widget.location == '/motion-assessment') {
      _voicePlaybackCoordinator.suspend();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (identical(_warmedPlanRuntime, runtime)) return;
    _warmedPlanRuntime = runtime;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_warmedPlanRuntime, runtime)) return;
      unawaited(_warmPlanDashboard(runtime));
    });
  }

  Future<void> _warmPlanDashboard(MomCozyApiRuntime runtime) async {
    try {
      await runtime.planRepository.fetchDashboard(weekOf: runtime.now());
    } catch (_) {
      // Warm-up is optional; PlanPage performs the user-visible retry.
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
      _voicePlaybackCoordinator.suspend();
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
    final hideNavigation = _routesWithoutBottomNavigation.contains(location);
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
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MomCozyLayout.maxAppWidth,
                  ),
                  child: content,
                ),
              ),
            ),
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

class MomCozyBottomNavigation extends StatelessWidget {
  const MomCozyBottomNavigation({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return _buildNavigation(context);
  }

  Widget _buildNavigation(BuildContext context) {
    final selectedIndex = _selectedTabIndex(location);
    final matchesPlanDesign = location == '/plan';

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xfffcf7f5)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MomCozyLayout.bottomNavHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MomCozyLayout.bottomNavChromeHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: MomCozyColors.border.withValues(alpha: 0.52),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MomCozyLayout.bottomNavChromeHeight,
                child: Material(
                  type: MaterialType.transparency,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MomCozyLayout.maxAppWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MomCozyNavTab(
                                navKey: const ValueKey('bottom-nav-me'),
                                label: 'Me',
                                selected: selectedIndex == 0,
                                asset: MomCozyAssets.bottomNavMe,
                                iconSize: const Size.square(20),
                                matchesPlanDesign: matchesPlanDesign,
                                onTap: () => context.go(_tabPaths[0]),
                              ),
                            ),
                            Expanded(
                              child: _MomCozyNavTab(
                                navKey: const ValueKey('bottom-nav-baby'),
                                label: 'Baby',
                                selected: selectedIndex == 1,
                                asset: MomCozyAssets.bottomNavBaby,
                                iconSize: const Size.square(22),
                                matchesPlanDesign: matchesPlanDesign,
                                onTap: () => context.go(_tabPaths[1]),
                              ),
                            ),
                            Expanded(
                              child: _CozymateNavSlot(
                                selected: selectedIndex == 2,
                                usePlanAvatar: location == '/plan',
                                onTap: () => context.go(_tabPaths[2]),
                              ),
                            ),
                            Expanded(
                              child: _MomCozyNavTab(
                                navKey: const ValueKey('bottom-nav-plan'),
                                label: 'Plan',
                                selected: selectedIndex == 3,
                                asset: MomCozyAssets.bottomNavPlan,
                                iconSize: const Size.square(22),
                                matchesPlanDesign: matchesPlanDesign,
                                onTap: () {
                                  context.go(_tabPaths[3]);
                                },
                              ),
                            ),
                            Expanded(
                              child: _MomCozyNavTab(
                                navKey: const ValueKey('bottom-nav-more'),
                                label: 'More',
                                selected: selectedIndex == 4,
                                asset: MomCozyAssets.bottomNavMore,
                                iconSize: const Size.square(16),
                                matchesPlanDesign: matchesPlanDesign,
                                onTap: null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomCozyNavTab extends StatelessWidget {
  const _MomCozyNavTab({
    required this.navKey,
    required this.label,
    required this.selected,
    required this.asset,
    required this.iconSize,
    required this.matchesPlanDesign,
    required this.onTap,
  });

  final Key navKey;
  final String label;
  final bool selected;
  final String asset;
  final Size iconSize;
  final bool matchesPlanDesign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = onTap == null
        ? const Color(0xff9e8880).withValues(alpha: 0.56)
        : selected
        ? MomCozyV3Colors.brand
        : const Color(0xff9e8880);

    return SizedBox.expand(
      child: Semantics(
        key: navKey,
        selected: selected,
        button: true,
        enabled: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(MomCozyRadii.control),
            onTap: onTap,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: matchesPlanDesign
                        ? MomCozyTypography.interfaceFontFamily
                        : MomCozyTypography.fontFamily,
                    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                    color: foreground,
                    fontSize: 11,
                    height: 1.05,
                    fontWeight: matchesPlanDesign
                        ? selected
                              ? FontWeight.w600
                              : FontWeight.w500
                        : selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: SvgPicture.asset(
                            asset,
                            width: iconSize.width,
                            height: iconSize.height,
                            colorFilter: ColorFilter.mode(
                              foreground,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
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
}

class _CozymateNavSlot extends StatelessWidget {
  const _CozymateNavSlot({
    required this.selected,
    required this.usePlanAvatar,
    required this.onTap,
  });

  final bool selected;
  final bool usePlanAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MomCozyAgentNavTab(
      selected: selected,
      usePlanAvatar: usePlanAvatar,
      onTap: onTap,
    );
  }
}

const _agentNavWakeDuration = Duration(milliseconds: 1640);

class _MomCozyAgentNavTab extends StatefulWidget {
  const _MomCozyAgentNavTab({
    required this.selected,
    required this.usePlanAvatar,
    required this.onTap,
  });

  final bool selected;
  final bool usePlanAvatar;
  final VoidCallback onTap;

  @override
  State<_MomCozyAgentNavTab> createState() => _MomCozyAgentNavTabState();
}

class _MomCozyAgentNavTabState extends State<_MomCozyAgentNavTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wakeController = AnimationController(
    vsync: this,
    duration: _agentNavWakeDuration,
  );
  late final Animation<double> _presenceScale = _wakeTween(
    const [0.9, 0.86, 1.2, 1.08, 1.12, 1],
    const [18, 28, 22, 16, 16],
  );
  late final Animation<double> _presenceOffsetY = _wakeTween(
    const [3, 5, -7, -2, -4, 0],
    const [18, 28, 22, 16, 16],
  );
  late final Animation<double> _presenceRotation = _wakeTween(
    const [-3.5, -5, 4, -1.6, 1, 0],
    const [18, 28, 22, 16, 16],
  );
  late final Animation<double> _haloOpacity = _wakeTween(
    const [0, 0.34, 0.72, 0.42, 0],
    const [26, 26, 26, 22],
  );
  late final Animation<double> _haloScale = _wakeTween(
    const [0.7, 0.92, 1.1, 1.2, 1.28],
    const [26, 26, 26, 22],
  );
  late final Animation<double> _ringOpacity = _wakeTween(
    const [0, 0.46, 0.96, 0.5, 0],
    const [28, 27, 27, 18],
  );
  late final Animation<double> _ringScale = _wakeTween(
    const [0.72, 0.98, 1.16, 1.22, 1.32],
    const [28, 27, 27, 18],
  );
  late final Animation<double> _ringRotation = _wakeTween(
    const [-38, -8, 42, 86, 118],
    const [28, 27, 27, 18],
  );
  int _wakeReplayCount = 0;
  Uint8List? _wakeGifBytes;
  late final Future<Uint8List> _wakeGifSourceBytes =
      _loadAgentWakeGifSourceBytes();

  @override
  void initState() {
    super.initState();
    unawaited(_wakeGifSourceBytes);
  }

  Animation<double> _wakeTween(List<double> values, List<double> weights) {
    assert(values.length == weights.length + 1);
    return TweenSequence<double>([
      for (var index = 0; index < weights.length; index += 1)
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: values[index],
            end: values[index + 1],
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: weights[index],
        ),
    ]).animate(_wakeController);
  }

  @override
  void didUpdateWidget(covariant _MomCozyAgentNavTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      unawaited(_playWakeAnimation());
    }
  }

  @override
  void dispose() {
    _wakeController.dispose();
    super.dispose();
  }

  Future<void> _playWakeAnimation() async {
    final sourceBytes = await _wakeGifSourceBytes;
    if (!mounted) return;
    setState(() {
      _wakeReplayCount += 1;
      _wakeGifBytes = Uint8List.fromList(sourceBytes);
    });
    _wakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Semantics(
            label: 'Cozymate',
            selected: widget.selected,
            button: true,
            child: Transform.translate(
              offset: const Offset(0, -7),
              child: Material(
                key: const ValueKey('bottom-nav-agent'),
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: MomCozyLayout.bottomNavCenterSize,
                    height: MomCozyLayout.bottomNavCenterSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: MomCozyV3Colors.ink, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x263a2731),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (widget.selected)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          ),
                        AnimatedBuilder(
                          animation: _wakeController,
                          builder: (context, child) {
                            final waking =
                                _wakeController.value > 0 &&
                                _wakeController.value < 1;
                            final haloOpacity = waking
                                ? _haloOpacity.value
                                : 0.0;
                            final haloScale = waking ? _haloScale.value : 1.0;
                            final ringOpacity = waking
                                ? _ringOpacity.value
                                : 0.0;
                            final ringScale = waking ? _ringScale.value : 1.0;
                            final ringRotation = waking
                                ? _ringRotation.value
                                : 0.0;
                            final presenceScale = waking
                                ? _presenceScale.value
                                : 1.0;
                            final presenceOffsetY = waking
                                ? _presenceOffsetY.value
                                : 0.0;
                            final presenceRotation = waking
                                ? _presenceRotation.value
                                : 0.0;
                            return Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  key: const ValueKey(
                                    'bottom-nav-agent-avatar-wake-halo',
                                  ),
                                  opacity: haloOpacity,
                                  child: Transform.scale(
                                    scale: haloScale,
                                    child: Container(
                                      width: 74,
                                      height: 74,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0xbdfff6fa),
                                            Color(0x5cf49dbd),
                                            Color(0x387ccac0),
                                            Color(0x00ffffff),
                                          ],
                                          stops: [0, 0.42, 0.6, 0.72],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Opacity(
                                  key: const ValueKey(
                                    'bottom-nav-agent-avatar-wake-ring-opacity',
                                  ),
                                  opacity: ringOpacity,
                                  child: Transform.rotate(
                                    angle: _degreesToRadians(ringRotation),
                                    child: Transform.scale(
                                      key: const ValueKey(
                                        'bottom-nav-agent-avatar-wake-ring',
                                      ),
                                      scale: ringScale,
                                      child: Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xb87ccac0),
                                            width: 2.5,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x3ddb799a),
                                              blurRadius: 12,
                                            ),
                                            BoxShadow(
                                              color: Color(0x267ccac0),
                                              blurRadius: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(0, presenceOffsetY),
                                  child: Transform.rotate(
                                    angle: _degreesToRadians(presenceRotation),
                                    child: Transform.scale(
                                      key: const ValueKey(
                                        'bottom-nav-agent-avatar-presence-scale',
                                      ),
                                      scale: presenceScale,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            key: const ValueKey(
                                              'bottom-nav-agent-avatar',
                                            ),
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: DecorationImage(
                                                image: AssetImage(
                                                  widget.usePlanAvatar
                                                      ? MomCozyAssets
                                                            .planCozymateAvatar
                                                      : MomCozyAssets
                                                            .agentAvatar,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x243a2731),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (waking && _wakeGifBytes != null)
                                            ClipOval(
                                              child: Image.memory(
                                                _wakeGifBytes!,
                                                key: ValueKey(
                                                  'bottom-nav-agent-avatar-wake-media-$_wakeReplayCount',
                                                ),
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                gaplessPlayback: false,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<Uint8List> _loadAgentWakeGifSourceBytes() async {
  final data = await rootBundle.load(MomCozyAssets.agentAwakenAvatar);
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

double _degreesToRadians(double degrees) => degrees * 3.141592653589793 / 180;

class MomCozyRoutePage extends StatelessWidget {
  const MomCozyRoutePage({
    super.key,
    required this.route,
    this.uri,
    this.extra,
    this.onLogout,
    this.onBabySelected,
  });

  final MomCozyRouteConfig route;
  final Uri? uri;
  final Object? extra;
  final Future<void> Function()? onLogout;
  final Future<void> Function(String babyId)? onBabySelected;

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

Widget _buildDefaultAgentHubPage(
  BuildContext context,
  Uri? uri,
  Object? extra,
  AgentVoicePlaybackCoordinator voicePlaybackCoordinator, {
  ExternalUrlLauncher externalUrlLauncher = const PlatformExternalUrlLauncher(),
}) {
  final runtime = MomCozyRuntimeScope.of(context);
  String? currentAccessToken() {
    return runtime.currentSession.accessToken ??
        MomCozyRuntimeScope.read(context)?.currentSession.accessToken ??
        runtime.session.accessToken;
  }

  return AgentHubPage(
    key: ValueKey('agent-hub-${runtime.currentSession.userId}'),
    stateCacheKey: runtime,
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
    ),
    actionClient: createSessionAgentHubActionClient(
      runtime.session,
      accessTokenProvider: currentAccessToken,
    ),
    clientEventClient: createSessionAgentHubClientEventClient(
      runtime.session,
      accessTokenProvider: currentAccessToken,
    ),
    conversationRepository: runtime.agentConversationRepository,
    greetingProfileLoader:
        runtime.agentHubProfileRepository.fetchGreetingProfile,
    requestBuilder: (message) => buildSessionAgentHubRequest(
      message,
      session: runtime.session,
      clientContext: runtime.hospitalBagCartStore.agentClientContext,
    ),
    voicePlaybackCoordinator: voicePlaybackCoordinator,
    voicePlaybackPlayer: runtime.agentVoicePlaybackPlayer,
    pickImage: runtime.agentHubImagePicker,
    pickDocument: runtime.agentHubDocumentPicker,
    mediaRepository: runtime.mediaRepository,
    loadImageThumbnail: runtime.mediaContentRepository.loadImageThumbnail,
    loadImageContent: runtime.mediaContentRepository.loadImage,
    productAssetRepository: runtime.productAssetRepository,
    ibclcConsultStore: runtime.ibclcConsultStore,
    supportTicketSubmitter: runtime.supportTicketRepository.submit,
    onApplicationEvent: runtime.handleAgentApplicationEvent,
    onHospitalBagCartUpdate: (seed) {
      runtime.hospitalBagCartStore.ingestArtifact(seed);
    },
    onHospitalBagCartContextRequired: () {
      final store = runtime.hospitalBagCartStore;
      store.activate(store.activeCartId);
    },
    onNewSession: runtime.hospitalBagCartStore.clearForNewSession,
    onArtifactAction: (action) => unawaited(
      dispatchAgentArtifactAction(
        context,
        action,
        externalUrlLauncher: externalUrlLauncher,
      ),
    ),
    initialComposerText: _agentPrefillFromRoute(uri, extra),
    initialAutoSend: _agentAutoSendFromRoute(uri, extra),
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
  summary: '该入口不在当前 Flutter route map 中。',
  icon: Icons.search_off_rounded,
  accent: Color(0xff7f6a75),
  priority: 'P2',
);

const momCozyRoutes = [
  MomCozyRouteConfig(
    path: '/',
    title: 'Cozymate',
    summary: '母婴健康咨询、日程管理与泌乳计划状态服务入口。',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xff9f6378),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/me',
    title: 'Me',
    summary: 'Postpartum recovery and lactation overview.',
    icon: Icons.person_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/baby',
    title: 'Baby',
    summary: 'Infant care, feeding and growth overview.',
    icon: Icons.child_care_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/baby/development',
    title: 'Baby Development',
    summary: 'Confirmed pregnancy week and prenatal education.',
    icon: Icons.pregnant_woman_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/notifications',
    title: 'Notifications',
    summary: 'Confirmed reminders and account updates.',
    icon: Icons.notifications_rounded,
    accent: Color(0xff862644),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/calibration',
    title: '舒适负压调节',
    summary: '每一步确认一个动作，找到你的舒适档位。',
    icon: Icons.tune_rounded,
    accent: Color(0xff9b6b2f),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/pump',
    title: '泵奶',
    summary: '泵奶 session、前台服务、通知恢复和上传状态的核心页面。',
    icon: Icons.water_drop_rounded,
    accent: Color(0xff43827b),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/plan',
    title: 'Plan',
    summary: 'Personalized recovery plans and guided sessions.',
    icon: Icons.event_note_rounded,
    accent: Color(0xffb2773b),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/more',
    title: 'Body Profile',
    summary: 'Postpartum recovery profile and confirmed health records.',
    icon: Icons.health_and_safety_outlined,
    accent: Color(0xffa21849),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/more/body-profile',
    title: 'Body Profile',
    summary: 'Private recovery profile availability and data state.',
    icon: Icons.health_and_safety_outlined,
    accent: Color(0xffa21849),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/more/body-profile/edit',
    title: 'Edit Body Profile',
    summary: 'Body profile editor availability.',
    icon: Icons.edit_note_rounded,
    accent: Color(0xffa21849),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/community',
    title: '社区',
    summary: '社区内容与妈妈支持网络入口。',
    icon: Icons.groups_2_rounded,
    accent: Color(0xff6b6da8),
    priority: 'TBD',
  ),
  MomCozyRouteConfig(
    path: '/device',
    title: '设备',
    summary: 'BLE 设备连接、左右侧状态和设备管理入口。',
    icon: Icons.bluetooth_connected_rounded,
    accent: Color(0xff43827b),
    priority: 'P0',
  ),
  MomCozyRouteConfig(
    path: '/device/manage',
    title: '设备提醒',
    summary: '任务提醒和奶量分析动作入口。',
    icon: Icons.notifications_active_rounded,
    accent: Color(0xffb2773b),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/device/user',
    title: '用户参数',
    summary: '内部调试参数配置入口。',
    icon: Icons.manage_accounts_rounded,
    accent: Color(0xff7f6a75),
    priority: 'TBD',
  ),
  MomCozyRouteConfig(
    path: '/w1',
    title: 'W1',
    summary: 'W1 产品内容入口。',
    icon: Icons.workspace_premium_rounded,
    accent: Color(0xffb2773b),
    priority: 'TBD',
  ),
  MomCozyRouteConfig(
    path: '/hospital-bag-cart',
    title: '待产包',
    summary: '待产包清单和购物车状态入口。',
    icon: Icons.shopping_bag_rounded,
    accent: Color(0xff9b6b2f),
    priority: 'TBD',
  ),
  MomCozyRouteConfig(
    path: '/ibclc-chat.html',
    title: 'IBCLC',
    summary: '哺乳顾问咨询和返回状态恢复入口。',
    icon: Icons.health_and_safety_rounded,
    accent: Color(0xff43827b),
    priority: 'TBD',
  ),
  MomCozyRouteConfig(
    path: '/media-viewer',
    title: '资料预览',
    summary: 'PDF、图片和视频资料的独立预览入口。',
    icon: Icons.perm_media_rounded,
    accent: Color(0xff6b6da8),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/motion-assessment',
    title: '动态姿态评估',
    summary: '端侧人体关键点识别与独立实时语音动作指导。',
    icon: Icons.accessibility_new_rounded,
    accent: Color(0xff8c4768),
    priority: 'P0',
  ),
];

const _routesWithoutBottomNavigation = {
  '/calibration',
  '/pump',
  '/hospital-bag-cart',
  '/ibclc-chat.html',
  '/media-viewer',
  '/motion-assessment',
  '/more',
  '/more/body-profile',
  '/more/body-profile/edit',
};

const _tabPaths = ['/me', '/baby', '/', '/plan', '/more'];

int _selectedTabIndex(String location) {
  if (location == '/me') return 0;
  if (location == '/baby' || location.startsWith('/baby/')) return 1;
  if (location == '/') return 2;
  if (location == '/plan') return 3;
  if (location == '/more' ||
      location == '/community' ||
      location == '/device' ||
      location == '/device/manage' ||
      location == '/device/user' ||
      location == '/w1') {
    return 4;
  }
  return -1;
}

Future<void> dispatchAgentArtifactAction(
  BuildContext context,
  AgentArtifactActionView action, {
  ExternalUrlLauncher externalUrlLauncher = const PlatformExternalUrlLauncher(),
}) async {
  final path = action.routePath;
  if (path != null && _knownFlutterRoutePaths.contains(path)) {
    Object? routeExtra = action.routeExtra;
    if (path == '/hospital-bag-cart') {
      final store = MomCozyRuntimeScope.of(context).hospitalBagCartStore;
      final seed = action.hospitalBagCartSeed;
      final cartId = seed == null
          ? store.activate(store.activeCartId)
          : store.ingestArtifact(seed);
      routeExtra = HospitalBagCartRouteState(cartId: cartId);
    }
    if (path == '/ibclc-chat.html' && routeExtra is IbclcConsultRouteState) {
      MomCozyRuntimeScope.of(
        context,
      ).ibclcConsultStore.beginConsult(routeExtra);
    }
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
    .toSet();
