import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Device subpage state goldens', () {
    for (final viewport in _goldenViewports) {
      testWidgets('reminder loading matches ${viewport.label} baseline', (
        tester,
      ) async {
        await _setViewport(tester, viewport.size);
        final client = _PendingClientEventClient();
        addTearDown(client.complete);

        await _pumpDeviceStateApp(
          tester,
          initialLocation: '/device/manage',
          clientEventClient: client,
        );
        await tester.tap(find.text('任务提醒'));
        await tester.pump();

        expect(find.text('处理中...'), findsOneWidget);
        await expectLater(
          find.byKey(_goldenSurfaceKey),
          matchesGoldenFile(
            viewport.filePath('device_manage_loading_mobile.png'),
          ),
        );
      });

      testWidgets('reminder offline sync matches ${viewport.label} baseline', (
        tester,
      ) async {
        await _setViewport(tester, viewport.size);

        await _pumpDeviceStateApp(
          tester,
          initialLocation: '/device/manage',
          clientEventClient: const AgentStreamClientEventClient(sent: false),
        );
        await tester.tap(find.text('任务提醒'));
        await tester.pumpAndSettle();

        expect(find.text('任务提醒已记录，等待提醒服务同步。'), findsOneWidget);
        await expectLater(
          find.byKey(_goldenSurfaceKey),
          matchesGoldenFile(
            viewport.filePath('device_manage_offline_mobile.png'),
          ),
        );
      });

      testWidgets('user list expanded matches ${viewport.label} baseline', (
        tester,
      ) async {
        await _setViewport(tester, viewport.size);
        await _pumpDeviceStateApp(tester, initialLocation: '/device/user');

        await tester.tap(find.byKey(const ValueKey('device-user-list-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('device-user-list-panel')),
          findsOneWidget,
        );
        await expectLater(
          find.byKey(_goldenSurfaceKey),
          matchesGoldenFile(
            viewport.filePath('device_user_list_open_mobile.png'),
          ),
        );
      });

      testWidgets('user save failure matches ${viewport.label} baseline', (
        tester,
      ) async {
        await _setViewport(tester, viewport.size);
        await _pumpDeviceStateApp(tester, initialLocation: '/device/user');

        await tester.enterText(find.byType(TextField), '');
        await tester.tap(find.text('切换用户'));
        await tester.pumpAndSettle();

        expect(find.text('保存失败：请输入用户名'), findsOneWidget);
        await expectLater(
          find.byKey(_goldenSurfaceKey),
          matchesGoldenFile(
            viewport.filePath('device_user_save_failed_mobile.png'),
          ),
        );
      });
    }
  });
}

const _goldenSurfaceKey = ValueKey('device-subpage-state-golden-surface');

const _goldenViewports = [
  _GoldenViewport(
    label: 'narrow mobile 360x800',
    size: Size(360, 800),
    directory: 'narrow_360x800',
  ),
  _GoldenViewport(label: 'compact mobile', size: Size(390, 844)),
  _GoldenViewport(
    label: 'large mobile 430x932',
    size: Size(430, 932),
    directory: 'large_430x932',
  ),
];

class _GoldenViewport {
  const _GoldenViewport({
    required this.label,
    required this.size,
    this.directory,
  });

  final String label;
  final Size size;
  final String? directory;

  String filePath(String fileName) {
    final viewportDirectory = directory;
    if (viewportDirectory == null) {
      return '../../goldens/device_subpages/$fileName';
    }
    return '../../goldens/device_subpages/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDeviceStateApp(
  WidgetTester tester, {
  required String initialLocation,
  AgentStreamClientEventClient clientEventClient =
      const AgentStreamClientEventClient(),
}) async {
  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenSurfaceKey,
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: initialLocation),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: _deviceRuntime(clientEventClient),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _deviceRuntime(
  AgentStreamClientEventClient clientEventClient,
) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath(const {
      '/v1/mom-baby/today/query': {
        'status': 200,
        'data': {
          'mom': {'stage': '哺乳期', 'postpartum_day': 21},
          'baby': {'nickname': 'Mia', 'age_days': 88},
        },
      },
    }),
    clientEventClient: clientEventClient,
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-golden',
    babyId: 'demo-baby-golden',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7, 3, 8),
  );
}

class _PendingClientEventClient extends AgentStreamClientEventClient {
  _PendingClientEventClient();

  final Completer<AgentStreamClientEventResult> _completer = Completer();

  @override
  Future<AgentStreamClientEventResult> post(
    AgentStreamClientEventRequest event,
  ) {
    return _completer.future;
  }

  void complete() {
    if (_completer.isCompleted) return;
    _completer.complete(
      const AgentStreamClientEventResult(sent: true, body: {}),
    );
  }
}
