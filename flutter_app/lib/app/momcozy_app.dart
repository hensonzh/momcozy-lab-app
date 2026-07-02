import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/routing/route_intent.dart';
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
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff9f6378),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme.copyWith(
      surface: const Color(0xfffffbfc),
      surfaceContainer: const Color(0xfffff2f5),
      surfaceContainerHighest: const Color(0xfff4e3e8),
    ),
    scaffoldBackgroundColor: const Color(0xfffffbfc),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: const Color(0xfffffbfc),
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
  );
}

GoRouter createMomCozyRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MomCozyRouteShell(location: state.uri.path, child: child);
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
      body: SafeArea(
        bottom: hideNavigation,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
    return NavigationBar(
      selectedIndex: _selectedTabIndex(location),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.favorite_border_rounded),
          selectedIcon: Icon(Icons.favorite_rounded),
          label: '宝宝和我',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note_rounded),
          label: '计划',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome_rounded),
          label: '智能体',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_2_outlined),
          selectedIcon: Icon(Icons.groups_2_rounded),
          label: '社区',
        ),
        NavigationDestination(
          icon: Icon(Icons.bluetooth_connected_outlined),
          selectedIcon: Icon(Icons.bluetooth_connected_rounded),
          label: '设备',
        ),
      ],
      onDestinationSelected: (index) => context.go(_tabPaths[index]),
    );
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
    title: '舒适校准',
    summary: '泵奶前的左右侧舒适档位校准流程。',
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
    title: '记录',
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
    title: '设备管理',
    summary: '设备操作、解绑和管理动作入口。',
    icon: Icons.settings_remote_rounded,
    accent: Color(0xff43827b),
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
