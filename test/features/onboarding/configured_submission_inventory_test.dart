import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

// Fixed G11 gaps only. Run with --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=true.
void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> mount(
    WidgetTester tester,
    MomCozyRuntimeController runtime,
    GoRouter router,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeRouteIntentPlatform();
    addTearDown(platform.dispose);
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        routeIntentPlatform: platform,
        sessionStore: MemoryMomCozySessionStore(runtime.currentSession),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(
          'assets/images/me_baby_overview/postpartum_avatar.png',
        ),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    GoRouter router,
    String name,
    String trigger, {
    String? previous,
  }) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/ui_inventory/$name-390.png'),
    );
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/$name.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode({
          'source': 'test/goldens/ui_inventory/$name-390.png',
          'previous_source': previous,
          'route': router.state.uri.path,
          'trigger': trigger,
          'root_entry': 'Configured App entry; real createMomCozyRouter',
          'evidence':
              'Production pages, repositories and router; fixture HTTP and image picker; not an OS picker screenshot',
          'test':
              'test/features/onboarding/configured_submission_inventory_test.dart',
        }),
      );
    }
  }

  testWidgets('inventory configured invite submission pending', (tester) async {
    expect(const bool.fromEnvironment('MOMCOZY_INTERNAL_INVITE_LOGIN'), isTrue);
    final transport = _PendingInvite();
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        supportsSessionAutoRefresh: false,
      ),
    );
    final store = MemoryMomCozySessionStore();
    final router = createMomCozyRouter(
      initialLocation: '/login?from=/more',
      runtimeController: runtime,
      sessionStore: store,
    );
    addTearDown(() {
      router.dispose();
      runtime.dispose();
    });
    await mount(tester, runtime, router);
    await tester.enterText(
      find.byKey(const ValueKey('auth-invite-code-field')),
      'INVENTORY-CODE',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await capture(
      tester,
      router,
      'auth-invite-submit-pending',
      'Configured invitation login → enter code → submit; response pending',
    );
    transport.ready.complete();
    await tester.pumpAndSettle();
    expect(runtime.currentSession.isAuthenticated, isTrue);
    expect(router.state.uri.path, '/more');
    expect(transport.postedBodies, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory configured invitation failure outcomes', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'http_status': 403,
      'body': {
        'error': {
          'code': 'permission_denied',
          'message': 'Invite code is already bound to another device.',
        },
      },
    });
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        supportsSessionAutoRefresh: false,
      ),
    );
    final store = _RecoverableSessionStore();
    final router = createMomCozyRouter(
      initialLocation: '/login?from=/more',
      runtimeController: runtime,
      sessionStore: store,
    );
    addTearDown(() {
      router.dispose();
      runtime.dispose();
    });
    await mount(tester, runtime, router);
    await tester.enterText(
      find.byKey(const ValueKey('auth-invite-code-field')),
      'INVENTORY-CODE',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('auth-invite-login-button'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('邀请码已在其他设备使用过'), findsOneWidget);
    await capture(
      tester,
      router,
      'auth-invite-device-error',
      'Invite submit rejected → code retained and device message displayed',
    );
    transport.response
      ..clear()
      ..addAll(_PendingInvite().response);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('账号认证已通过，但无法保存本机登录状态。请重启 App 后重试。'), findsOneWidget);
    expect(runtime.currentSession.isAuthenticated, isFalse);
    await capture(
      tester,
      router,
      'auth-invite-storage-error',
      'Retry accepted by server → local session save fails; remains logged out',
      previous: 'test/goldens/ui_inventory/auth-invite-device-error-390.png',
    );
    store.failWrite = false;
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(runtime.currentSession.isAuthenticated, isTrue);
    expect(router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory configured avatar failure feedback', (tester) async {
    final portrait = (await rootBundle.load(
      'assets/images/me_baby_overview/postpartum_avatar.png',
    )).buffer.asUint8List();
    final oldPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _PortraitPicker(portrait);
    addTearDown(() => ImagePickerPlatform.instance = oldPicker);
    final errorResponse = <String, Object?>{
      'http_status': 503,
      'body': {
        'error': {
          'code': 'unavailable',
          'message': 'Could not apply your choice. Try again.',
        },
      },
    };
    final writes = <String, Map<String, Object?>>{
      '/v1/onboarding/me/complete': errorResponse,
    };
    final transport = FixtureApiJsonTransportByPath({
      '/v1/onboarding/me': _avatarState(false),
    }, writeResponsesByPath: writes);
    final upload = FixtureApiMultipartTransport(errorResponse);
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: upload,
        supportsSessionAutoRefresh: false,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'inventory-avatar',
          babyId: '',
          locale: 'en-US',
          accessToken: 'fixture-access',
        ),
      ),
    );
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    final router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: runtime,
      onboardingController: controller,
    );
    addTearDown(() {
      router.dispose();
      controller.dispose();
      runtime.dispose();
    });
    await mount(tester, runtime, router);
    await tester.tap(find.widgetWithText(FilledButton, 'Upload a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-library-source')));
    await tester.pumpAndSettle();
    expect(upload.lastPath, '/v1/onboarding/me/portrait');
    expect(controller.busy, isFalse);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not apply your choice. Try again.'),
      findsOneWidget,
    );
    await capture(
      tester,
      router,
      'onboarding-request-error',
      'Upload photo request fails → inline error and usable retry/default buttons',
    );
    await tester.tap(find.text('Use the MomCozy character for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(transport.mutationPaths, ['/v1/onboarding/me/complete']);
    expect(
      find.text('Could not apply your choice. Try again.'),
      findsOneWidget,
    );
    // Same visible state and message: reuse one golden for both real actions.
    await capture(
      tester,
      router,
      'onboarding-request-error',
      'Default-avatar confirmation also fails → same inline error and available retry/default buttons; shared with upload failure',
    );
    writes['/v1/onboarding/me/complete'] = {
      'status': 'completed',
      'profile_confirmed': true,
      'can_enter_app': true,
      'avatar_setup_completed': true,
    };
    await tester.tap(find.text('Use the MomCozy character for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory configured avatar upload and handoff', (tester) async {
    final portrait = (await rootBundle.load(
      'assets/images/me_baby_overview/postpartum_avatar.png',
    )).buffer.asUint8List();
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _PortraitPicker(portrait);
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);

    // Both real dialog actions, one shared screenshot. No width/error matrix.
    for (final enterApp in [false, true]) {
      final upload = _PendingPortrait();
      final transport = FixtureApiJsonTransportByPath(
        {'/v1/onboarding/me': _avatarState(false)},
        writeResponsesByPath: {
          '/v1/onboarding/me/avatar-generations': _avatarState(true),
        },
      );
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: upload,
          supportsSessionAutoRefresh: false,
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'inventory-avatar',
            babyId: '',
            locale: 'en-US',
            accessToken: 'fixture-access',
          ),
        ),
      );
      final controller = OnboardingController(runtimeController: runtime);
      await controller.load();
      final router = createMomCozyRouter(
        initialLocation: '/more',
        runtimeController: runtime,
        onboardingController: controller,
        avatarThumbnailLoader: (_) async => portrait,
      );
      await mount(tester, runtime, router);
      expect(router.state.uri.path, '/onboarding');
      final uploadButton = find.widgetWithText(FilledButton, 'Upload a photo');
      await tester.ensureVisible(uploadButton);
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-library-source')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.busy, isTrue);
      if (!enterApp) {
        await capture(
          tester,
          router,
          'onboarding-upload-pending',
          'Configured onboarding → Upload a photo → Choose from library → upload pending',
        );
      }
      upload.ready.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Your digital companion is being created'),
        findsOneWidget,
      );
      expect(upload.lastPath, '/v1/onboarding/me/portrait');
      expect(transport.lastBody, {'portrait_file_id': 'fixture-portrait'});
      if (!enterApp) {
        await capture(
          tester,
          router,
          'onboarding-generation-handoff',
          'Portrait accepted and generation queued → handoff dialog',
          previous:
              'test/goldens/ui_inventory/onboarding-upload-pending-390.png',
        );
      }
      await tester.tap(find.text(enterApp ? 'Enter the app' : 'Wait here'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.state.uri.path, enterApp ? '/more' : '/onboarding');
      expect(
        find.text('Your digital companion is being created'),
        findsNothing,
      );
      expect(controller.state?.canEnterApp, isTrue);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      controller.dispose();
      runtime.dispose();
    }
  });
}

Map<String, Object?> _avatarState(bool generating) => {
  'status': generating ? 'avatar_generating' : 'avatar_required',
  'current_step': 'avatar',
  'profile_confirmed': true,
  'can_enter_app': generating,
  'can_continue_with_default': true,
  if (generating)
    'avatar': {
      'id': 'fixture-generation',
      'stage': 'postpartum',
      'status': 'queued',
      'created_at': '2026-09-14T00:00:00Z',
      'candidates': <Object?>[],
    },
};

class _PendingInvite extends FixtureApiJsonTransport {
  _PendingInvite()
    : super({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {'id': 'inventory-invite', 'display_name': 'Inventory'},
      });
  final ready = Completer<void>();
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await ready.future;
    return super.postJson(path, body: body, headers: headers);
  }
}

class _RecoverableSessionStore extends MemoryMomCozySessionStore {
  bool failWrite = true;
  @override
  Future<void> writeSession(MomCozySession session) async {
    if (failWrite) throw StateError('fixture session storage unavailable');
    await super.writeSession(session);
  }
}

class _PendingPortrait extends FixtureApiMultipartTransport {
  _PendingPortrait() : super({'id': 'fixture-portrait'});
  final ready = Completer<void>();
  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    await ready.future;
    return super.uploadMultipart(
      path,
      query: query,
      fields: fields,
      headers: headers,
      file: file,
    );
  }
}

class _PortraitPicker extends ImagePickerPlatform {
  _PortraitPicker(this.bytes);
  final Uint8List bytes;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile.fromData(bytes, name: 'portrait.png', mimeType: 'image/png');
}
