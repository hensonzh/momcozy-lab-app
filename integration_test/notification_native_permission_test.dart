import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/features/notifications/data/native_notification_platform.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import '../test/support/fixture_api_transport.dart';
import '../test/support/notification_fakes.dart';

// Run with scripts/capture-native-notification-permissions.py. The host only
// responds to actual Android dialogs; business writes remain in this transport.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  const allow = bool.fromEnvironment('NATIVE_PERMISSION_ALLOW');
  final branch = allow ? 'allow' : 'deny';
  testWidgets(
    'native notification $branch and system settings return',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      const native = NativeNotificationPlatform();
      expect(
        await native.currentPermission(),
        NotificationPermission.notDetermined,
      );
      final directory = await getApplicationDocumentsDirectory();
      final prefix = 'native-permission-$branch';
      final transport = _Transport();
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'permission-inventory',
        babyId: 'permission-baby',
        locale: 'zh-CN',
        accessToken: 'isolated-native-session',
        refreshToken: 'isolated-native-refresh',
      );
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: FixtureApiMultipartTransport({}),

          session: session,
          supportsSessionAutoRefresh: false,
          now: () => DateTime.utc(2026, 9, 14, 8),
          timezoneProvider: () async => 'Asia/Shanghai',
        ),
      );
      final store = MemoryMomCozySessionStore(session);
      final platform = FakeRouteIntentPlatform();
      final router = createMomCozyRouter(
        initialLocation: '/more',
        runtimeController: runtime,
        sessionStore: store,
      );
      final coordinator = NotificationCoordinator(
        permission: NotificationPermissionController(native),
        gateway: FakeGateway(),
        store: FakeStore(),
        platformName: 'android',
        onNavigate: (route) => router.go(route),
        onMessage: (message) => ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold).last),
        ).showSnackBar(SnackBar(content: Text(message))),
        onForeground: (_) {},
      );
      addTearDown(() async {
        coordinator.dispose();
        router.dispose();
        runtime.dispose();
        await platform.dispose();
      });
      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          runtimeController: runtime,
          sessionStore: store,
          routeIntentPlatform: platform,
          notificationCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      final rows = <Map<String, Object?>>[];
      String? previous;
      Future<void> capture(
        String state,
        String trigger, {
        bool overlay = false,
      }) async {
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 300));
        final name = '$prefix-$state';
        final bytes = await binding.takeScreenshot(name);
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        String? full;
        final scroll = find.byType(Scrollable);
        if (!overlay &&
            scroll.evaluate().isNotEmpty &&
            await _captureLongScroll(
              tester,
              binding,
              scroll.first,
              '$name-long',
            )) {
          full = '$name-long';
        }
        rows.add({
          'state': state,
          'file': '$name.png',
          'previous': previous,
          'route': router.state.uri.path,
          'trigger': trigger,
          'overlay': overlay,
          if (full != null) 'full_document': '$full.png',
          if (full != null) 'scroll_metadata': '$full.json',
          'root_entry':
              'More → notifications → notification settings → category switch → actual native permission',
          'test': 'integration_test/notification_native_permission_test.dart',
        });
        previous = name;
        await File(
          '${directory.path}/$prefix-journeys.json',
        ).writeAsString(jsonEncode(rows));
      }

      Future<void> gate(String phase, String action) async {
        final ack = File('${directory.path}/$prefix-$phase.ack');
        if (await ack.exists()) await ack.delete();
        await File(
          '${directory.path}/native-permission-phase.json',
        ).writeAsString(
          jsonEncode({
            'branch': branch,
            'phase': phase,
            'action': action,
            'previous': previous,
            'route': router.state.uri.path,
            'ack': ack.path,
          }),
        );
        for (var i = 0; i < 1800 && !await ack.exists(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          await ack.exists(),
          isTrue,
          reason: 'Host did not operate the actual native permission UI',
        );
        previous = (await ack.readAsString()).trim();
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 400));
      }

      final updates = find.widgetWithText(SwitchListTile, 'Momcozy AI updates');
      await capture('more', 'Authenticated More entry');
      router.go('/notifications');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/notifications');
      await capture('inbox', 'Tap notifications → actual empty inbox');
      await tap(find.byTooltip('Notification settings'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/notifications/settings');
      expect(find.text('Not requested'), findsOneWidget);
      await capture(
        'not-requested',
        'Inbox toolbar → not requested, category off',
      );
      await tap(updates);
      expect(find.text('Receive reminders?'), findsOneWidget);
      await capture(
        'education',
        'Enable category → App permission explanation',
        overlay: true,
      );
      // Do not wait for the pending category request while its dialog is open.
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 400));
      await gate('system-request', allow ? 'allow' : 'deny');
      expect(
        await native.currentPermission(),
        allow
            ? NotificationPermission.authorized
            : NotificationPermission.denied,
      );
      expect(transport.preferences['agent_updates'], allow);
      await capture(
        allow ? 'allowed' : 'denied',
        'Android $branch → permission refreshed and category result',
      );
      if (!allow) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tap(updates);
        expect(find.text('Notifications are off'), findsOneWidget);
        await capture(
          'settings-offer',
          'Enable after denial → offer Android settings',
          overlay: true,
        );
        await tester.tap(find.text('Open settings'));
        await tester.pump(const Duration(milliseconds: 400));
        await gate('system-settings-off', 'enable-settings');
        expect(
          await native.currentPermission(),
          NotificationPermission.authorized,
        );
        await tap(find.text('Refresh status'));
        await tester.pumpAndSettle();
        expect(find.text('Allowed'), findsOneWidget);
        await capture(
          'settings-allowed',
          'Allow in Android settings and return → App refresh',
        );
        await tap(updates);
        await tester.pumpAndSettle();
        expect(transport.preferences['agent_updates'], isTrue);
        await capture(
          'category-enabled',
          'Enable category after system permission → isolated preference saved',
        );
      }
      await tap(updates);
      await tester.pumpAndSettle();
      expect(transport.preferences['agent_updates'], isFalse);
      await capture(
        'category-disabled',
        'Disable conversation updates; Android permission remains allowed',
      );
      expect(
        await native.currentPermission(),
        NotificationPermission.authorized,
      );
      await tester.tap(
        find.byTooltip(
          MaterialLocalizations.of(
            tester.element(find.byType(AppBar)),
          ).backButtonTooltip,
        ),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/notifications');
      await capture('inbox-return', 'App back → inbox');
      await tester.tap(find.byKey(const ValueKey('notifications-back')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/more');
      await capture('more-return', 'Inbox back → original More');
      await File('${directory.path}/$prefix-result.json').writeAsString(
        jsonEncode({
          'status': 'PASS',
          'branch': branch,
          'states': rows.length,
          'preference_writes': transport.preferenceWrites,
          'permission': (await native.currentPermission()).wire,
          'data':
              'isolated HTTP, gateway and installation store; actual native permission platform',
        }),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _Transport extends FixtureApiJsonTransportByPath {
  _Transport()
    : super(
        {
          '/v1/notifications': {'items': [], 'unread_count': 0},
        },
        writeResponsesByPath: {
          '/v1/notifications/installations': {
            'binding_id': 'isolated-binding',
            'token_registered': true,
            'push_available': true,
          },
        },
      );
  final preferences = <String, bool>{'agent_updates': false};
  final preferenceWrites = <String>[];
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/notifications/preferences') {
      return Map<String, Object?>.from(preferences);
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.startsWith('/v1/notifications/preferences/')) {
      final category = path.split('/').last;
      preferences[category] = body['enabled']! as bool;
      preferenceWrites.add('$category:${body['enabled']}');
      return Map<String, Object?>.from(preferences);
    }
    return super.patchJson(path, body: body, headers: headers);
  }
}

Future<bool> _captureLongScroll(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  Finder finder,
  String name,
) async {
  final state = tester.state<ScrollableState>(finder);
  final p = state.position;
  if (p.maxScrollExtent <= 1) return false;
  final original = p.pixels;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final frames = <ui.Image>[];
  final offsets = <double>[];
  final logicalWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final viewport = tester.getRect(finder);
  Rect? bounds;
  var written = 0.0;
  var ratio = 1.0;
  try {
    for (var i = 0; i < 100; i++) {
      final target = (i * viewport.height * .45).floorToDouble().clamp(
        0.0,
        p.maxScrollExtent,
      );
      for (var retry = 0; retry < 4; retry++) {
        p.jumpTo(target);
        await tester.pumpAndSettle();
        if ((p.pixels - target).abs() < .5) break;
      }
      expect((p.pixels - target).abs(), lessThan(.5));
      final bytes = await binding.takeScreenshot('$name-frame-$i');
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      frames.add(image);
      ratio = image.width / logicalWidth;
      bounds ??= Rect.fromLTRB(
        viewport.left * ratio,
        viewport.top * ratio,
        viewport.right * ratio,
        viewport.bottom * ratio,
      );
      if (i == 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Paint(),
        );
      }
      final offset = p.pixels * ratio;
      offsets.add(offset);
      var usable = bounds.height;
      final atEnd = p.pixels >= p.maxScrollExtent - .5;
      if (!atEnd) {
        usable -= 32 * ratio;
        final latest = find.byKey(const ValueKey('agent-scroll-latest-button'));
        if (latest.evaluate().isNotEmpty) {
          usable = usable.clamp(
            0.0,
            (tester.getRect(latest).top - viewport.top - 8) * ratio,
          );
        }
      }
      final start = (written - offset).clamp(0.0, usable);
      final count = usable - start;
      if (count > 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, bounds.top + start, image.width.toDouble(), count),
          Rect.fromLTWH(0, bounds.top + written, image.width.toDouble(), count),
          Paint(),
        );
        written += count;
      }
      if (atEnd) break;
    }
    expect(p.pixels, greaterThanOrEqualTo(p.maxScrollExtent - .5));
    expect(
      written,
      greaterThanOrEqualTo((p.maxScrollExtent + viewport.height) * ratio - 2),
    );
    final last = frames.last;
    final bottom = last.height - bounds!.bottom;
    canvas.drawImageRect(
      last,
      Rect.fromLTWH(0, bounds.bottom, last.width.toDouble(), bottom),
      Rect.fromLTWH(0, bounds.top + written, last.width.toDouble(), bottom),
      Paint(),
    );
    final picture = recorder.endRecording();
    final output = await picture.toImage(
      last.width,
      (bounds.top + written + bottom).ceil(),
    );
    picture.dispose();
    final png = await output.toByteData(format: ui.ImageByteFormat.png);
    output.dispose();
    final directory = await getApplicationDocumentsDirectory();
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    await File('${directory.path}/$name.json').writeAsString(
      jsonEncode({
        'kind': 'actual-native-ScrollPosition-measured-stitch',
        'first_visible_top': offsets.first,
        'last_visible_bottom': p.pixels + viewport.height,
        'document_height': p.maxScrollExtent + viewport.height,
        'pixel_ratio': ratio,
        'pixel_offsets': offsets,
        'viewport_bounds': [
          bounds.left,
          bounds.top,
          bounds.width,
          bounds.height,
        ],
        'stitched_content_height': written,
        'header_footer': 'each retained once',
        'scroll_latest_overlay': 'excluded from middle strips',
      }),
    );
    return true;
  } finally {
    for (final f in frames) {
      f.dispose();
    }
    p.jumpTo(original);
    await tester.pumpAndSettle();
  }
}
