import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/baby_module_routes.dart';
import '../app/me_home_route.dart';
import '../app/momcozy_api_runtime.dart';
import '../app/momcozy_app.dart';
import '../app/primary_tab_activity.dart';
import '../core/agent_stream/agent_stream_client.dart';
import '../core/agent_stream/agent_stream_runner.dart';
import '../core/auth/momcozy_session.dart';
import '../core/network/api_json_transport.dart';
import '../core/preferences/volume_unit_preference.dart';
import '../features/agent_hub/agent_hub_page.dart';
import '../features/agent_hub/domain/agent_hub_greeting.dart';
import '../features/media/data/media_content_repository.dart';
import '../features/media/data/product_asset_repository.dart';
import '../modules/schedule/presentation/schedule_page.dart';
import '../native/p0_platform_interfaces.dart';
import '../shared/design_system/momcozy_theme.dart';
import 'demo_agent_client.dart';
import 'demo_memory_transport.dart';

/// This entrypoint does not initialize authentication, native channels or any
/// production client. Recreating the whole instance drops every demo change.
class WebDemoApp extends StatefulWidget {
  const WebDemoApp({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  State<WebDemoApp> createState() => _WebDemoAppState();
}

class _WebDemoAppState extends State<WebDemoApp> {
  int _instance = 0;

  @override
  Widget build(BuildContext context) => _DemoInstance(
    key: ValueKey(_instance),
    now: widget.now,
    reset: () => setState(() => _instance++),
  );
}

class _DemoInstance extends StatefulWidget {
  const _DemoInstance({super.key, required this.now, required this.reset});
  final DateTime Function() now;
  final VoidCallback reset;

  @override
  State<_DemoInstance> createState() => _DemoInstanceState();
}

class _DemoInstanceState extends State<_DemoInstance> {
  late final DemoMemoryTransport _store = DemoMemoryTransport(now: widget.now);
  late final MomCozyApiRuntime _runtime = MomCozyApiRuntime(
    jsonTransport: _store,
    agentJsonTransport: _store,
    multipartTransport: const _NoDemoUploads(),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.denied),
    pumpProtocolPlatform: FakePumpProtocolPlatform(),
    productAssetRepository: ProductAssetRepository(
      baseUri: Uri.parse('http://127.0.0.1'),
      connector: const _NoDemoAssets(),
    ),
    mediaContentRepository: MediaContentRepository(
      baseUri: Uri.parse('http://127.0.0.1'),
      connector: const _NoDemoAssets(),
    ),
    volumeUnitPreferenceStore: _MemoryVolumePreference(),
    timezoneProvider: () async => 'UTC',
    now: widget.now,
    session: const MomCozySession(
      status: MomCozySessionStatus.anonymous,
      userId: 'fictional-mia',
      babyId: 'demo-baby',
      locale: momCozyEnglishLocale,
    ),
  );
  late final DemoAgentClient _agent = DemoAgentClient();
  late final AgentStreamRunner _agentRunner = AgentStreamRunner(_agent);
  final Object _conversationKey = Object();
  late final GoRouter _router = GoRouter(
    initialLocation: '/me',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MomCozyRouteShell(
          location: state.uri.path,
          onSelectTab: (index) => shell.goBranch(index),
          appBar: _DemoHeader(reset: widget.reset),
          child: shell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => MeHomeRoute(runtime: _runtime),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/baby',
                builder: (context, state) => buildBabyHome(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => AgentHubPage(
                  stateCacheKey: _conversationKey,
                  now: widget.now,
                  isVisible:
                      PrimaryTabActivity.maybeOf(context)?.selectedIndex == 2,
                  runner: _agentRunner,
                  greetingProfileLoader: () async =>
                      const AgentHubGreetingProfile(
                        displayName: 'Mia',
                        age: 30,
                      ),
                  requestBuilder: (message) => AgentStreamRequest(
                    message: message,
                    threadId: 'demo-thread',
                  ),
                  initialComposerText: state.extra is Map
                      ? (state.extra as Map)['agentPrefill'] as String?
                      : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => SchedulePage(
                  repository: _runtime.scheduleRepository,
                  timezoneProvider: _runtime.timezoneProvider,
                  now: widget.now,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const _DemoAbout(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _DemoUnavailable(),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MomCozyRuntimeScope(
    apiRuntime: _runtime,
    child: MaterialApp.router(
      title: 'Momcozy AI · Demo',
      theme: momCozyTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

class _DemoHeader extends StatelessWidget implements PreferredSizeWidget {
  const _DemoHeader({required this.reset});
  final VoidCallback reset;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Container(
      color: const Color(0xfffff1e8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'WEB DEMO · Fictional data',
                  child: const Text(
                    'WEB DEMO · Fictional data',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('web-demo-reset'),
                onPressed: reset,
                child: const Text('Reset demo'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DemoAbout extends StatelessWidget {
  const _DemoAbout();

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('web-demo-about'),
    padding: const EdgeInsets.all(24),
    children: [
      Text('Momcozy AI demo', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      const Text(
        'Explore a fictional mom, baby and schedule. No account is needed. Nothing you enter is saved or sent to a real service.',
      ),
      const SizedBox(height: 12),
      const Text(
        'The AI chat is scripted. This demo is not a medical consultation.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Bluetooth pumps, camera assessments, file uploads and notifications are not available in this Web demo.',
      ),
    ],
  );
}

class _DemoUnavailable extends StatelessWidget {
  const _DemoUnavailable();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Not available in this demo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'You can continue exploring the Me, Baby, AI and Schedule tabs.',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/me'),
              child: const Text('Back to demo'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NoDemoUploads implements ApiMultipartTransport {
  const _NoDemoUploads();

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) => Future.error(
    UnsupportedError('File uploads are not available in the demo.'),
  );
}

class _NoDemoAssets implements ProductAssetHttpConnector {
  const _NoDemoAssets();

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) => Future.error(
    UnsupportedError('Remote assets are not available in the demo.'),
  );
}

class _MemoryVolumePreference implements VolumeUnitPreferenceStore {
  MomCozyVolumeUnit? _unit;

  @override
  Future<MomCozyVolumeUnit?> read() async => _unit;

  @override
  Future<void> write(MomCozyVolumeUnit unit) async => _unit = unit;
}
