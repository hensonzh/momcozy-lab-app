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
import '../test/support/fixture_api_transport.dart';
import '../test/support/fake_agent_voice.dart';

// Actual device probe through the production More → Mom → appointment flow.
// The host captures and operates real Android dialogs; no room is joined.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets('native consultation camera microphone deny retry allow', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final directory = await getApplicationDocumentsDirectory();
    const prefix = 'native-device';
    final responses = (jsonDecode(_responses) as Map).map(
      (k, v) => MapEntry(k.toString(), Map<String, Object?>.from(v as Map)),
    );
    final transport = FixtureApiJsonTransportByPath(responses);
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'isolated-device-session',
      refreshToken: 'isolated-device-refresh',
    );
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),
        agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
        session: session,
        supportsSessionAutoRefresh: false,
        now: () => DateTime.utc(2026, 9, 13, 8),
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
    addTearDown(() async {
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
            'More → Me → View appointment → Start consultation → actual native device permission',
        'test': 'integration_test/consultation_native_device_test.dart',
      });
      previous = name;
      await File(
        '${directory.path}/$prefix-journeys.json',
      ).writeAsString(jsonEncode(rows));
    }

    Future<void> tap(Finder target) async {
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          300,
          scrollable: find.byType(Scrollable).last,
        );
      } else {
        await tester.ensureVisible(target);
      }
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> permissions(String action) async {
      final ack = File('${directory.path}/native-device-$action.ack');
      if (await ack.exists()) await ack.delete();
      await File('${directory.path}/native-device-phase.json').writeAsString(
        jsonEncode({
          'phase': action,
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
        reason: 'Host did not finish actual camera and microphone dialogs',
      );
      previous = (await ack.readAsString()).trim();
      for (
        var i = 0;
        i < 100 && find.text('正在请求设备权限…').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    await capture('more', 'Authenticated More entry');
    await tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    await capture('mom', 'Bottom Me → home with isolated active appointment');
    await tap(find.text('查看预约'));
    await tester.pumpAndSettle();
    await capture(
      'appointment',
      'View appointment → actual preparation dialog',
      overlay: true,
    );
    await tap(find.text('开始咨询'));
    await capture(
      'checking',
      'Start consultation → device checking before native permission response',
      overlay: true,
    );
    await permissions('deny');
    expect(find.text('检查未通过，请重试'), findsOneWidget);
    expect(find.textContaining('未能使用摄像头'), findsOneWidget);
    expect(find.textContaining('未能使用麦克风'), findsOneWidget);
    await capture(
      'denied',
      'Deny camera and microphone → actual device errors',
      overlay: true,
    );
    await tap(find.text('开始检测'));
    await capture(
      'retry-checking',
      'Retry device check → requesting permissions again',
      overlay: true,
    );
    await permissions('allow');
    expect(find.text('摄像头和麦克风均可用'), findsOneWidget);
    await capture(
      'ready',
      'Allow camera and microphone → actual local tracks created and released',
      overlay: true,
    );
    await tap(find.text('重新检查'));
    await tester.pumpAndSettle();
    expect(find.text('摄像头和麦克风均可用'), findsOneWidget);
    await capture(
      'rechecked',
      'Recheck with granted permissions → ready without system prompt',
      overlay: true,
    );
    await tap(find.text('继续确认'));
    await tester.pumpAndSettle();
    await capture(
      'start-confirm',
      'Device check continue → actual consultation confirmation, no room join',
      overlay: true,
    );
    await tap(find.byTooltip('关闭咨询确认'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    await capture('mom-return', 'Close consultation confirmation → home');
    await tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/more');
    await capture('more-return', 'Bottom More → original tab');
    expect(
      transport.mutationPaths.where((p) => p.contains('/room/join')),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await File('${directory.path}/$prefix-result.json').writeAsString(
      jsonEncode({
        'status': 'PASS',
        'states': rows.length,
        'mutations': transport.mutationPaths,
        'data':
            'isolated HTTP/session; actual LiveKit local device tracks and Android permissions; no room joined',
      }),
    );
  });
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

const _responses =
    r'''{"/v1/auth/me": {"id": "inventory-user", "email": "inventory@example.test", "email_verified": true, "account_status": "active", "auth_providers": ["email"]}, "/v1/profile/me": {"preferred_name": "Mia", "age": 30}, "/v1/profile/lactation": {"actual_delivery_date": "2026-08-24", "current_delivery_method": "vaginal"}, "/v1/care/catalog": {"packages": [{"id": "feeding-confidence", "name": "喂养安心", "subtitle": "Feeding Confidence", "description": "判断宝宝当前是否吃够，明确是否需要调整喂养，并形成 Feeding Plan。", "duration_days": 7, "sessions": 2, "price_minor": 21900, "currency": "USD", "highlights": ["判断宝宝是否吃够", "形成 Feeding Plan", "7 天持续跟进"], "expert_services": ["1 次首次视频咨询（60 分钟）", "1 次 IBCLC 跟进（20–30 分钟）"], "continuous_services": ["跟踪 feeding、pumping、奶量及宝宝关键记录", "按 Care Plan 提醒执行与记录", "收集喂养反馈", "生成阶段总结供 IBCLC 复核"]}, {"id": "better-breastfeeding", "name": "亲喂改善", "subtitle": "Better Breastfeeding", "description": "找到影响亲喂的主要问题，改善含乳、吸吮和喂养体验。", "duration_days": 14, "sessions": 2, "price_minor": 23900, "currency": "USD", "highlights": ["定位亲喂问题", "改善含乳与吸吮", "14 天持续跟进"], "expert_services": ["1 次首次视频咨询（60 分钟）", "1 次 IBCLC 跟进（20–30 分钟）"], "continuous_services": ["跟踪亲喂频次及主观反馈", "按 Care Plan 提醒练习与调整", "收集亲喂体验和问题变化", "生成阶段总结供 IBCLC 复核"]}, {"id": "milk-supply-care", "name": "奶量管理", "subtitle": "Milk Supply Care", "description": "判断奶量问题，建立并持续调整个性化奶量管理方案。", "duration_days": 14, "sessions": 3, "price_minor": 29900, "currency": "USD", "highlights": ["判断奶量问题", "建立个性化方案", "14 天持续调整"], "expert_services": ["1 次首次视频咨询（60 分钟）", "2 次 IBCLC 跟进（20–30 分钟）"], "continuous_services": ["跟踪 pumping、奶量及供需趋势", "按 Care Plan 提醒执行与记录", "汇总奶量及计划执行变化", "生成阶段总结供 IBCLC 复核"]}, {"id": "comfortable-feeding", "name": "舒适哺乳支持", "subtitle": "Comfortable Feeding", "description": "找到影响舒适度的主要因素，改善不适并及时识别医疗转介需求。", "duration_days": 3, "sessions": 2, "price_minor": 21900, "currency": "USD", "highlights": ["定位不适因素", "改善哺乳舒适度", "识别转介需求"], "expert_services": ["1 次首次视频咨询（60 分钟）", "1 次 IBCLC 跟进（20–30 分钟）"], "continuous_services": ["定期发起症状回访", "按 Care Plan 提醒执行与观察", "收集疼痛、胀奶、堵奶等反馈", "生成阶段总结供 IBCLC 复核"]}], "providers": [{"user_id": "inventory-ibclc", "display_name": "Test IBCLC", "timezone": "America/Los_Angeles", "regions": ["CA"], "languages": ["English"], "bio": "本地测试专家资料，用于验证预约流程。", "sandbox": true}], "available_regions": ["CA"], "payment_mode": "sandbox"}, "/v1/care/overview": {"orders": [{"id": "service-order", "package_id": "feeding-confidence", "status": "paid", "price_minor": 21900, "currency": "USD", "duration_days": 7, "total_sessions": 2, "payment_mode": "sandbox", "region": "CA", "version": 1, "created_at": "2026-09-13T08:00:00.000Z", "updated_at": "2026-09-13T08:00:00.000Z"}], "episodes": [{"id": "service-episode", "order_id": "service-order", "package_id": "feeding-confidence", "assigned_ibclc_id": "inventory-ibclc", "status": "active", "stage": "preparation", "total_sessions": 2, "remaining_sessions": 2, "version": 1, "starts_at": "2026-09-13T08:00:00.000Z", "ends_at": "2026-09-20T08:00:00.000Z"}]}, "/v1/mother/diary": {"items": []}, "/v1/lactation/records": {"items": []}, "/v1/care/appointments/service-appointment": {"id": "service-appointment", "episode_id": "service-episode", "provider_id": "inventory-ibclc", "provider_name": "Test IBCLC", "starts_at": "2026-09-13T08:05:00.000Z", "ends_at": "2026-09-13T09:05:00.000Z", "timezone": "America/Los_Angeles", "region": "CA", "status": "confirmed", "version": 2, "intake_version": 1, "confirmed_at": "2026-09-13T08:00:00.000Z", "hold_expires_at": "2026-09-13T08:00:00.000Z", "cancelled_at": null}, "/v1/care/appointments/service-appointment/room": {"appointment": {"id": "service-appointment", "episode_id": "service-episode", "provider_id": "inventory-ibclc", "provider_name": "Test IBCLC", "starts_at": "2026-09-13T08:05:00.000Z", "ends_at": "2026-09-13T09:05:00.000Z", "timezone": "America/Los_Angeles", "region": "CA", "status": "confirmed", "version": 2, "intake_version": 1, "confirmed_at": "2026-09-13T08:00:00.000Z", "hold_expires_at": "2026-09-13T08:00:00.000Z", "cancelled_at": null}, "viewer_role": "mom", "consultation": null, "participants": [], "intake_ready": true, "case_consent": true, "video_consent": false, "location": null, "opens_at": "2026-09-13T07:55:00.000Z", "closes_at": "2026-09-13T09:20:00.000Z", "server_time": "2026-09-13T08:00:00.000Z", "demo_early_join": false, "video_provider": "sandbox", "consent_policy_version": "2026-09-08"}, "/v1/care/appointments/service-appointment/intake": {"appointment": {"id": "service-appointment", "episode_id": "service-episode", "provider_id": "inventory-ibclc", "provider_name": "Test IBCLC", "starts_at": "2026-09-13T08:05:00.000Z", "ends_at": "2026-09-13T09:05:00.000Z", "timezone": "America/Los_Angeles", "region": "CA", "status": "confirmed", "version": 2, "intake_version": 1, "confirmed_at": "2026-09-13T08:00:00.000Z", "hold_expires_at": "2026-09-13T08:00:00.000Z", "cancelled_at": null}, "intake": {"id": "service-intake", "appointment_id": "service-appointment", "episode_id": "service-episode", "version": 1, "submitted_at": "2026-09-13T08:00:00.000Z", "symptoms": ["pumping_schedule"], "feeding_goal": "Isolated inventory consultation", "support_needed": "", "profile": {"baby_id": "inventory-baby", "baby_name": "Test baby", "baby_birth_date": "2026-08-18", "baby_sex": "female", "feeding_mode": "mixed_feeding", "delivery_date": "2026-08-18", "region": "CA"}}, "previous_intake": null, "consents": [{"id": "service-case-consent", "episode_id": "service-episode", "scope": "ibclc_case", "active": true, "version": 1, "policy_version": "2026-09-08", "recorded_at": "2026-09-13T08:00:00.000Z"}], "babies": [{"name": "宝宝", "birth_date": "2026-08-18", "sex": "female", "feeding_mode": "unknown", "id": "3df630e7-513a-481f-b1f8-e2577200e219", "version": 1, "created_at": "2026-09-09T12:00:00Z", "updated_at": "2026-09-09T12:00:00Z"}], "delivery_date": "2026-08-18", "consent_policy_version": "2026-09-08"}, "/v1/care/episodes/service-episode/consents": {"items": [{"id": "service-case-consent", "episode_id": "service-episode", "scope": "ibclc_case", "active": true, "version": 1, "policy_version": "2026-09-08", "recorded_at": "2026-09-13T08:00:00.000Z"}]}, "/v1/notifications": {"items": [], "unread_count": 0, "next_cursor": null}, "/v1/notifications/preferences": {"appointments": false, "consultations": false, "expert_feedback": false, "service_updates": false}, "/v1/care/episodes/service-episode/booking": {"episode": {"id": "service-episode", "order_id": "service-order", "package_id": "feeding-confidence", "assigned_ibclc_id": "inventory-ibclc", "status": "active", "stage": "preparation", "total_sessions": 2, "remaining_sessions": 2, "version": 1, "starts_at": "2026-09-13T08:00:00.000Z", "ends_at": "2026-09-20T08:00:00.000Z"}, "providers": [{"user_id": "inventory-ibclc", "display_name": "Test IBCLC", "timezone": "America/Los_Angeles", "regions": ["CA"], "languages": ["English"], "bio": "本地测试专家资料，用于验证预约流程。", "sandbox": true}], "appointments": [{"id": "service-appointment", "episode_id": "service-episode", "provider_id": "inventory-ibclc", "provider_name": "Test IBCLC", "starts_at": "2026-09-13T08:05:00.000Z", "ends_at": "2026-09-13T09:05:00.000Z", "timezone": "America/Los_Angeles", "region": "CA", "status": "confirmed", "version": 2, "intake_version": 1, "confirmed_at": "2026-09-13T08:00:00.000Z", "hold_expires_at": "2026-09-13T08:00:00.000Z", "cancelled_at": null}], "eligibility": null, "server_time": "2026-09-13T08:00:00.000Z"}}''';
