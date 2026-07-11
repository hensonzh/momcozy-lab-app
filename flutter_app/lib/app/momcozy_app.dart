import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
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
    this.agentHubBuilder,
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
  final MomCozyAgentHubBuilder? agentHubBuilder;

  @override
  State<MomCozyFlutterApp> createState() => _MomCozyFlutterAppState();
}

class _MomCozyFlutterAppState extends State<MomCozyFlutterApp> {
  late final MomCozyRuntimeController _runtimeController =
      widget.runtimeController ??
      MomCozyRuntimeController(
        widget.apiRuntime ?? MomCozyApiRuntime.fromEnvironment(),
      );
  late final bool _ownsRuntimeController = widget.runtimeController == null;
  late final GoRouter _router =
      widget.router ??
      createMomCozyRouter(
        runtimeController: _runtimeController,
        sessionStore: widget.sessionStore,
        authDeviceIdStore: widget.authDeviceIdStore,
        agentHubBuilder: widget.agentHubBuilder,
      );
  late final bool _ownsRouter = widget.router == null;
  late final RouteIntentPlatform _routeIntentPlatform =
      widget.routeIntentPlatform ?? AndroidRouteIntentPlatform();
  late final bool _ownsRouteIntentPlatform = widget.routeIntentPlatform == null;
  StreamSubscription<PendingNativeRoute>? _activeRouteSub;

  @override
  void initState() {
    super.initState();
    _runtimeController.enableSessionAutoRefresh(widget.sessionStore);
    _activeRouteSub = _routeIntentPlatform.activeRoutes.listen(
      _handlePendingNativeRoute,
    );
    unawaited(_consumePendingNativeRoute());
  }

  @override
  void dispose() {
    unawaited(_activeRouteSub?.cancel());
    if (_ownsRouteIntentPlatform) {
      final platform = _routeIntentPlatform;
      if (platform is AndroidRouteIntentPlatform) unawaited(platform.dispose());
    }
    if (_ownsRuntimeController) _runtimeController.dispose();
    if (_ownsRouter) _router.dispose();
    super.dispose();
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
    _router.go(path);
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
  MomCozySessionStore sessionStore = const FlutterSecureMomCozySessionStore(),
  MomCozyAuthDeviceIdStore authDeviceIdStore =
      const FlutterSecureMomCozyAuthDeviceIdStore(),
  MomCozyAgentHubBuilder? agentHubBuilder,
}) {
  final resolvedAgentHubBuilder = agentHubBuilder ?? _buildDefaultAgentHubPage;
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: runtimeController,
    redirect: runtimeController == null
        ? null
        : (context, state) => _authRedirect(runtimeController, state),
    routes: [
      if (runtimeController != null)
        GoRoute(
          path: '/login',
          builder: (context, state) => MomCozyAuthPage(
            runtimeController: runtimeController,
            sessionStore: sessionStore,
            redirectTo: state.uri.queryParameters['from'],
            authDeviceIdStore: authDeviceIdStore,
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

String? _authRedirect(
  MomCozyRuntimeController runtimeController,
  GoRouterState state,
) {
  final path = state.uri.path;
  final isLogin = path == '/login';
  final isAuthenticated = runtimeController.runtime.session.isAuthenticated;
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
  });

  final String location;
  final Widget child;
  final Uri? uri;
  final Object? extra;
  final MomCozyAgentHubBuilder? agentHubBuilder;

  @override
  State<MomCozyRouteShell> createState() => _MomCozyRouteShellState();
}

class _MomCozyRouteShellState extends State<MomCozyRouteShell> {
  final AgentVoicePlaybackCoordinator _voicePlaybackCoordinator =
      AgentVoicePlaybackCoordinator();
  late bool _hasBuiltAgentHub = widget.location == '/';

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
    final hideNavigation = _routesWithoutBottomNavigation.contains(location);
    final content = _buildContent(context);

    return Scaffold(
      backgroundColor: MomCozyColors.background,
      body: SafeArea(
        bottom: hideNavigation,
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
      bottomNavigationBar: hideNavigation
          ? null
          : MomCozyBottomNavigation(location: location),
    );
  }

  Widget _buildContent(BuildContext context) {
    final agentHubBuilder = widget.agentHubBuilder;
    if (agentHubBuilder == null) return widget.child;

    final location = widget.location;
    final isAgentRoute = location == '/';
    if (!_hasBuiltAgentHub) return widget.child;

    final agentHub = agentHubBuilder(
      context,
      isAgentRoute ? widget.uri : null,
      isAgentRoute ? widget.extra : null,
      _voicePlaybackCoordinator,
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
    final selectedIndex = _selectedTabIndex(location);

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
                      child: Transform.translate(
                        offset: const Offset(0, -2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _MomCozyNavTab(
                                  navKey: const ValueKey('bottom-nav-status'),
                                  label: '宝宝和我',
                                  selected: selectedIndex == 0,
                                  icon: const _MomBabyNavIcon(),
                                  selectedIcon: const _MomBabyNavIcon(
                                    filled: true,
                                  ),
                                  onTap: () => context.go(_tabPaths[0]),
                                ),
                              ),
                              Expanded(
                                child: _MomCozyNavTab(
                                  navKey: const ValueKey('bottom-nav-schedule'),
                                  label: '计划',
                                  selected: selectedIndex == 1,
                                  icon: const Icon(Icons.event_note_outlined),
                                  selectedIcon: const Icon(
                                    Icons.event_note_rounded,
                                  ),
                                  onTap: () => context.go(_tabPaths[1]),
                                ),
                              ),
                              Expanded(
                                child: _MomCozyAgentNavTab(
                                  selected: selectedIndex == 2,
                                  onTap: () => context.go(_tabPaths[2]),
                                ),
                              ),
                              Expanded(
                                child: _MomCozyNavTab(
                                  navKey: const ValueKey(
                                    'bottom-nav-community',
                                  ),
                                  label: '社区',
                                  selected: selectedIndex == 3,
                                  icon: const Icon(Icons.groups_2_outlined),
                                  selectedIcon: const Icon(
                                    Icons.groups_2_rounded,
                                  ),
                                  onTap: () => context.go(_tabPaths[3]),
                                ),
                              ),
                              Expanded(
                                child: _MomCozyNavTab(
                                  navKey: const ValueKey('bottom-nav-device'),
                                  label: '设备',
                                  selected: selectedIndex == 4,
                                  icon: const Icon(
                                    Icons.bluetooth_connected_outlined,
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.bluetooth_connected_rounded,
                                  ),
                                  onTap: () => context.go(_tabPaths[4]),
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
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
  });

  final Key navKey;
  final String label;
  final bool selected;
  final Widget icon;
  final Widget selectedIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? MomCozyColors.primary
        : MomCozyColors.mutedForeground;

    return Center(
      child: Semantics(
        key: navKey,
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? MomCozyColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(MomCozyRadii.control),
            ),
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 21),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: MomCozyTypography.fontFamily,
                  fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                  color: foreground,
                  fontSize: 10,
                  height: 1.05,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 22,
                      child: Center(child: selected ? selectedIcon : icon),
                    ),
                    const SizedBox(height: 5),
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
    );
  }
}

const _agentNavWakeDuration = Duration(milliseconds: 1640);

class _MomCozyAgentNavTab extends StatefulWidget {
  const _MomCozyAgentNavTab({required this.selected, required this.onTap});

  final bool selected;
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
    return Center(
      child: Semantics(
        label: '智能体',
        selected: widget.selected,
        button: true,
        child: Transform.translate(
          offset: const Offset(0, -10),
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
                  gradient: widget.selected ? MomCozyGradients.primary : null,
                  color: widget.selected ? null : MomCozyColors.card,
                  border: Border.all(color: MomCozyColors.background, width: 5),
                  boxShadow: widget.selected
                      ? const [
                          BoxShadow(
                            color: Color(0x42754b5e),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x1a3a2731),
                            blurRadius: 22,
                            offset: Offset(0, 8),
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
                        final haloOpacity = waking ? _haloOpacity.value : 0.0;
                        final haloScale = waking ? _haloScale.value : 1.0;
                        final ringOpacity = waking ? _ringOpacity.value : 0.0;
                        final ringScale = waking ? _ringScale.value : 1.0;
                        final ringRotation = waking ? _ringRotation.value : 0.0;
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
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              MomCozyAssets.agentAvatar,
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

class _MomBabyNavIcon extends StatelessWidget {
  const _MomBabyNavIcon({this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _MomBabyNavIconPainter(
        color: IconTheme.of(context).color ?? MomCozyColors.primary,
        strokeWidth: filled ? 2.5 : 1.8,
        fill: filled,
      ),
    );
  }
}

class _MomBabyNavIconPainter extends CustomPainter {
  const _MomBabyNavIconPainter({
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24;
    final scaleY = size.height / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final wash = Paint()
      ..color = color.withValues(alpha: fill ? 0.18 : 0)
      ..style = PaintingStyle.fill;

    Offset p(double x, double y) => Offset(x * scaleX, y * scaleY);
    if (fill) canvas.drawCircle(p(8.2, 7.1), 2.8 * scaleX, wash);
    canvas.drawCircle(p(8.2, 7.1), 2.8 * scaleX, stroke);
    final momPath = Path()
      ..moveTo(3.8 * scaleX, 19.2 * scaleY)
      ..lineTo(3.8 * scaleX, 17.8 * scaleY)
      ..cubicTo(
        3.8 * scaleX,
        14.7 * scaleY,
        5.7 * scaleX,
        12.4 * scaleY,
        8.2 * scaleX,
        12.4 * scaleY,
      )
      ..cubicTo(
        10.7 * scaleX,
        12.4 * scaleY,
        12.6 * scaleX,
        14.7 * scaleY,
        12.6 * scaleX,
        17.8 * scaleY,
      )
      ..lineTo(12.6 * scaleX, 19.2 * scaleY);
    canvas.drawPath(momPath, stroke);
    final momSmile = Path()
      ..moveTo(5.7 * scaleX, 18.8 * scaleY)
      ..cubicTo(
        6.4 * scaleX,
        19.2 * scaleY,
        7.2 * scaleX,
        19.4 * scaleY,
        8.2 * scaleX,
        19.4 * scaleY,
      )
      ..cubicTo(
        9.2 * scaleX,
        19.4 * scaleY,
        10 * scaleX,
        19.2 * scaleY,
        10.7 * scaleX,
        18.8 * scaleY,
      );
    canvas.drawPath(momSmile, stroke);

    if (fill) canvas.drawCircle(p(16.4, 9.7), 2.1 * scaleX, wash);
    canvas.drawCircle(p(16.4, 9.7), 2.1 * scaleX, stroke);
    final babyPath = Path()
      ..moveTo(12.9 * scaleX, 19.2 * scaleY)
      ..lineTo(12.9 * scaleX, 18.3 * scaleY)
      ..cubicTo(
        12.9 * scaleX,
        15.9 * scaleY,
        14.3 * scaleX,
        14.2 * scaleY,
        16.4 * scaleX,
        14.2 * scaleY,
      )
      ..cubicTo(
        18.5 * scaleX,
        14.2 * scaleY,
        19.9 * scaleX,
        15.9 * scaleY,
        19.9 * scaleX,
        18.3 * scaleY,
      )
      ..lineTo(19.9 * scaleX, 19.2 * scaleY);
    canvas.drawPath(babyPath, stroke);
    final babySmile = Path()
      ..moveTo(14.5 * scaleX, 18.7 * scaleY)
      ..cubicTo(
        15 * scaleX,
        19 * scaleY,
        15.6 * scaleX,
        19.1 * scaleY,
        16.4 * scaleX,
        19.1 * scaleY,
      )
      ..cubicTo(
        17.2 * scaleX,
        19.1 * scaleY,
        17.8 * scaleX,
        19 * scaleY,
        18.3 * scaleX,
        18.7 * scaleY,
      );
    canvas.drawPath(babySmile, stroke);
  }

  @override
  bool shouldRepaint(covariant _MomBabyNavIconPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fill != fill;
  }
}

class MomCozyRoutePage extends StatelessWidget {
  const MomCozyRoutePage({
    super.key,
    required this.route,
    this.uri,
    this.extra,
  });

  final MomCozyRouteConfig route;
  final Uri? uri;
  final Object? extra;

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
    );
  }
}

Widget _buildDefaultAgentHubPage(
  BuildContext context,
  Uri? uri,
  Object? extra,
  AgentVoicePlaybackCoordinator voicePlaybackCoordinator,
) {
  final runtime = MomCozyRuntimeScope.of(context);
  String? currentAccessToken() {
    return runtime.currentSession.accessToken ??
        MomCozyRuntimeScope.read(context)?.currentSession.accessToken ??
        runtime.session.accessToken;
  }

  return AgentHubPage(
    stateCacheKey: runtime,
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
    greetingProfileLoader:
        runtime.agentHubProfileRepository.fetchGreetingProfile,
    requestBuilder: (message) =>
        buildSessionAgentHubRequest(message, session: runtime.session),
    voicePlaybackCoordinator: voicePlaybackCoordinator,
    voicePlaybackPlayer: runtime.agentVoicePlaybackPlayer,
    productAssetRepository: runtime.productAssetRepository,
    onArtifactAction: (action) => _handleAgentArtifactAction(context, action),
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
    title: '智能体',
    summary: 'Momcozy Agent 主入口，承载对话、分析卡片、资料和跨功能跳转。',
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xff9f6378),
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
    path: '/schedule',
    title: '计划',
    summary: '日程、任务、提醒和计划状态的管理入口。',
    icon: Icons.event_note_rounded,
    accent: Color(0xffb2773b),
    priority: 'P1',
  ),
  MomCozyRouteConfig(
    path: '/status',
    title: '宝宝和我',
    summary: '妈妈、宝宝、孕期和哺乳状态的总览入口。',
    icon: Icons.favorite_rounded,
    accent: Color(0xff9f6378),
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
];

const _routesWithoutBottomNavigation = {
  '/calibration',
  '/pump',
  '/hospital-bag-cart',
  '/ibclc-chat.html',
  '/media-viewer',
};

const _tabPaths = ['/status', '/schedule', '/', '/community', '/device'];

int _selectedTabIndex(String location) {
  if (location == '/status') return 0;
  if (location == '/schedule') return 1;
  if (location == '/') return 2;
  if (location == '/community') return 3;
  if (location.startsWith('/device') || location == '/w1') return 4;
  return -1;
}

void _handleAgentArtifactAction(
  BuildContext context,
  AgentArtifactActionView action,
) {
  final path = action.routePath;
  if (path == null || !_knownFlutterRoutePaths.contains(path)) return;
  context.go(path, extra: action.routeExtra);
}

final _knownFlutterRoutePaths = momCozyRoutes
    .map((route) => route.path)
    .toSet();
