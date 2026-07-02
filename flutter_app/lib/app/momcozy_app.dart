import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/app_pages/momcozy_feature_pages.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

class MomCozyFlutterApp extends StatefulWidget {
  const MomCozyFlutterApp({
    super.key,
    this.router,
    this.routeIntentPlatform,
    this.apiRuntime,
  });

  final GoRouter? router;
  final RouteIntentPlatform? routeIntentPlatform;
  final MomCozyApiRuntime? apiRuntime;

  @override
  State<MomCozyFlutterApp> createState() => _MomCozyFlutterAppState();
}

class _MomCozyFlutterAppState extends State<MomCozyFlutterApp> {
  late final MomCozyApiRuntime _apiRuntime =
      widget.apiRuntime ?? MomCozyApiRuntime.fromEnvironment();
  late final GoRouter _router = widget.router ?? createMomCozyRouter();
  late final bool _ownsRouter = widget.router == null;
  late final RouteIntentPlatform _routeIntentPlatform =
      widget.routeIntentPlatform ?? AndroidRouteIntentPlatform();
  late final bool _ownsRouteIntentPlatform = widget.routeIntentPlatform == null;
  StreamSubscription<PendingNativeRoute>? _activeRouteSub;

  @override
  void initState() {
    super.initState();
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
    return MomCozyRuntimeScope(
      apiRuntime: _apiRuntime,
      child: MaterialApp.router(
        title: 'Momcozy',
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

GoRouter createMomCozyRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final runtime = MomCozyRuntimeScope.of(context);
          return MomCozyRouteTelemetry(
            location: state.uri.path,
            observability: runtime.observability,
            child: MomCozyRouteShell(location: state.uri.path, child: child),
          );
        },
        routes: [
          for (final route in momCozyRoutes)
            GoRoute(
              path: route.path,
              builder: (context, state) => MomCozyRoutePage(route: route),
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

class MomCozyRouteShell extends StatelessWidget {
  const MomCozyRouteShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hideNavigation = _routesWithoutBottomNavigation.contains(location);

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
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: hideNavigation
          ? null
          : MomCozyBottomNavigation(location: location),
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
      decoration: BoxDecoration(
        color: MomCozyColors.card.withValues(alpha: 0.92),
      ),
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
                      child: Row(
                        children: [
                          _MomCozyNavTab(
                            label: '宝宝和我',
                            selected: selectedIndex == 0,
                            icon: const _MomBabyNavIcon(),
                            selectedIcon: const _MomBabyNavIcon(filled: true),
                            onTap: () => context.go(_tabPaths[0]),
                          ),
                          _MomCozyNavTab(
                            label: '计划',
                            selected: selectedIndex == 1,
                            icon: const Icon(Icons.event_note_outlined),
                            selectedIcon: const Icon(Icons.event_note_rounded),
                            onTap: () => context.go(_tabPaths[1]),
                          ),
                          _MomCozyAgentNavTab(
                            selected: selectedIndex == 2,
                            onTap: () => context.go(_tabPaths[2]),
                          ),
                          _MomCozyNavTab(
                            label: '社区',
                            selected: selectedIndex == 3,
                            icon: const Icon(Icons.groups_2_outlined),
                            selectedIcon: const Icon(Icons.groups_2_rounded),
                            onTap: () => context.go(_tabPaths[3]),
                          ),
                          _MomCozyNavTab(
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
                        ],
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
    required this.label,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
  });

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

    return Expanded(
      child: Center(
        child: Semantics(
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
                      Text(label, maxLines: 1, overflow: TextOverflow.visible),
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

class _MomCozyAgentNavTab extends StatelessWidget {
  const _MomCozyAgentNavTab({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -12),
          child: Semantics(
            label: '智能体',
            selected: selected,
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: MomCozyLayout.bottomNavCenterSize,
                height: MomCozyLayout.bottomNavCenterSize,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? MomCozyGradients.primary : null,
                  color: selected ? null : MomCozyColors.card,
                  border: Border.all(color: MomCozyColors.background, width: 5),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x42754b5e),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ]
                      : MomCozyShadows.soft,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: selected ? 0.1 : 0),
                    image: const DecorationImage(
                      image: AssetImage(MomCozyAssets.agentAvatar),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const SizedBox.square(
                    dimension: MomCozyLayout.bottomNavCenterSize - 10,
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
  const MomCozyRoutePage({super.key, required this.route});

  final MomCozyRouteConfig route;

  @override
  Widget build(BuildContext context) {
    if (route.path == '/') {
      final runtime = MomCozyRuntimeScope.of(context);
      return AgentHubPage(
        runner: createSessionAgentHubRunner(runtime.session),
        cancelClient: createSessionAgentHubCancelClient(runtime.session),
        requestBuilder: (message) =>
            buildSessionAgentHubRequest(message, session: runtime.session),
        onArtifactAction: (action) =>
            _handleAgentArtifactAction(context, action),
      );
    }

    return MomCozyFeaturePage(
      path: route.path,
      title: route.title,
      summary: route.summary,
      icon: route.icon,
      accent: route.accent,
      priority: route.priority,
    );
  }
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
    path: '/records',
    title: '妈妈点滴',
    summary: '泵奶、喂养和成长记录的列表与图表入口。',
    icon: Icons.insights_rounded,
    accent: Color(0xff6b6da8),
    priority: 'P1',
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
    summary: '任务提醒、奶量总结和健康通知动作入口。',
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
  '/media-viewer',
};

const _tabPaths = ['/status', '/schedule', '/', '/community', '/device'];

int _selectedTabIndex(String location) {
  if (location == '/status') return 0;
  if (location == '/schedule') return 1;
  if (location == '/') return 2;
  if (location == '/community') return 3;
  if (location.startsWith('/device') || location == '/w1') return 4;
  return 2;
}

void _handleAgentArtifactAction(
  BuildContext context,
  AgentArtifactActionView action,
) {
  final path = action.routePath;
  if (path == null || !_knownFlutterRoutePaths.contains(path)) return;
  context.go(path);
}

final _knownFlutterRoutePaths = momCozyRoutes
    .map((route) => route.path)
    .toSet();
