import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/domain/care/intake.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/consultation/application/room_controller.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/consultation_start_dialog.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

class Rooms extends TestRoomRepository {
  final regions = <String>[];
  Completer<void>? locationPending;
  bool preparing = false, locationOffline = false;
  @override
  Future<ConsultationLocation> checkLocation(String id, String region) async {
    regions.add(region);
    if (locationPending != null) await locationPending!.future;
    if (locationOffline) throw const ProductFailure(ProductFailureKind.offline);
    final now = context.serverTime;
    json['location'] = {
      'id': 'location',
      'region': region,
      'decision': region == 'NY' ? 'blocked' : 'passed',
      'created_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(minutes: 30)).toIso8601String(),
    };
    return context.location!;
  }

  @override
  Future<ConsultationRoomContext> prepare(String id) async {
    if (!preparing) return super.prepare(id);
    prepareCalls++;
    room(roomStatus: 'creating');
    return context;
  }
}

class Consents extends Fake implements IntakeRepository {
  Consents(this.rooms);
  final Rooms rooms;
  final writes = <({CareConsentScope scope, int version, bool active})>[];
  int version = 4;
  Completer<void>? pending;
  CareConsent record() => CareConsent(
    id: 'video',
    episodeId: rooms.context.appointment.episodeId,
    scope: CareConsentScope.video,
    active: rooms.context.videoConsent,
    version: version,
    policyVersion: rooms.context.consentPolicyVersion,
    recordedAt: rooms.context.serverTime,
  );
  @override
  Future<List<CareConsent>> consents(String episodeId) async => [record()];
  @override
  Future<CareConsent> setConsent(
    String episodeId, {
    required CareConsentScope scope,
    required bool active,
    required int expectedVersion,
    required String policyVersion,
  }) async {
    expect(episodeId, rooms.context.appointment.episodeId);
    expect(policyVersion, rooms.context.consentPolicyVersion);
    writes.add((scope: scope, version: expectedVersion, active: active));
    if (pending != null) await pending!.future;
    rooms.json['video_consent'] = active;
    version++;
    return record();
  }
}

Future<ConsultationRoomController> mount(
  WidgetTester tester,
  Rooms rooms,
  Consents consents, {
  double width = 390,
  double height = 844,
  double scale = 1,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ConsultationRoomController(
    repository: rooms,
    consents: consents,
    appointmentId: rooms.context.appointment.id,
    media: TestConsultationMedia(),
    now: () => rooms.context.serverTime,
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ConsultationRoomPage(
        createController: () => controller,
        createDeviceCheck: TestReadyDeviceCheck.new,
        onBack: () {},
        onIntake: () async {},
        onProgress: (_) {},
        onRebook: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('开始咨询'), 200);
  await click(tester, '开始咨询');
  expect(find.text('摄像头和麦克风均可用'), findsOneWidget);
  expect(rooms.regions, isEmpty);
  expect(rooms.keys, isEmpty);
  await click(tester, '继续确认');
  return controller;
}

Future<void> click(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> region(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byKey(const ValueKey('consult-location')));
  await tester.tap(find.byKey(const ValueKey('consult-location')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/preflight-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
      ),
    );
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('device consent region and enter $width / $scale', (
        tester,
      ) async {
        final rooms = Rooms();
        final actualConsents = Consents(rooms);
        await mount(tester, rooms, actualConsents, width: width, scale: scale);
        await shot(tester, 'consent-required', width, scale);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '确认并进入咨询室'),
              )
              .onPressed,
          isNull,
        );
        await click(tester, '去授权');
        await shot(tester, 'consent', width, scale);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确认视频授权'))
              .onPressed,
          isNull,
        );
        await click(tester, '我同意开启本次服务的视频咨询');
        await click(tester, '确认视频授权');
        expect(actualConsents.writes, [
          (scope: CareConsentScope.video, version: 4, active: true),
        ]);
        await shot(tester, 'ready', width, scale);
        await region(tester, 'New York (NY)');
        await click(tester, '确认并进入咨询室');
        expect(rooms.regions, ['NY']);
        expect(rooms.keys, isEmpty);
        await shot(tester, 'region-blocked', width, scale);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '确认并进入咨询室'),
              )
              .onPressed,
          isNull,
        );
        await region(tester, 'California (CA)');
        await click(tester, '确认并进入咨询室');
        expect(rooms.regions, ['NY', 'CA']);
        expect(rooms.keys, hasLength(1));
        expect(find.byType(ConsultationStartDialog), findsNothing);
        expect(find.textContaining('等待 Test IBCLC 进入'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'open preflight reflects changed prerequisites and restores entry without submitting',
    (tester) async {
      for (final state in ['intake', 'disabled', 'early', 'expired']) {
        final rooms = Rooms()..ready();
        final controller = await mount(
          tester,
          rooms,
          Consents(rooms),
          width: 320,
          scale: 2,
        );
        if (state == 'intake') rooms.json['intake_ready'] = false;
        if (state == 'disabled') rooms.json['video_provider'] = 'disabled';
        if (state == 'early') {
          rooms.json['server_time'] = '2026-09-08T15:40:00Z';
        }
        if (state == 'expired') {
          rooms.json['server_time'] = '2026-09-08T17:16:00Z';
        }
        await controller.load();
        await tester.pumpAndSettle();
        final enter = find.widgetWithText(FilledButton, '确认并进入咨询室');
        expect(tester.widget<FilledButton>(enter).onPressed, isNull);
        await tester.ensureVisible(enter);
        await shot(tester, 'changed-$state', 320, 2);
        rooms.json['intake_ready'] = true;
        rooms.json['video_provider'] = 'sandbox';
        rooms.json['server_time'] = '2026-09-08T15:55:00Z';
        await controller.load();
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(enter).onPressed, isNotNull);
        expect(rooms.keys, isEmpty);
        expect(rooms.regions, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('location request blocks edits duplicate entry and back', (
    tester,
  ) async {
    final rooms = Rooms()
      ..ready()
      ..locationPending = Completer<void>();
    await mount(tester, rooms, Consents(rooms));
    await tester.tap(find.text('确认并进入咨询室'));
    await tester.pump();
    expect(rooms.regions, ['CA']);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('consult-location')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byType(ConsultationStartDialog),
              matching: find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '关闭咨询确认',
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ConsultationStartDialog), findsOneWidget);
    rooms.locationPending!.complete();
    await tester.pumpAndSettle();
    expect(rooms.keys, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('short screen enlarged text keeps consent and region reachable', (
    tester,
  ) async {
    final rooms = Rooms();
    await mount(
      tester,
      rooms,
      Consents(rooms),
      width: 320,
      height: 568,
      scale: 2,
    );
    await click(tester, '去授权');
    await click(tester, '我同意开启本次服务的视频咨询');
    await click(tester, '确认视频授权');
    await region(tester, 'New York (NY)');
    await click(tester, '确认并进入咨询室');
    await tester.ensureVisible(find.text('确认并进入咨询室'));
    await tester.pumpAndSettle();
    await shot(tester, 'short-blocked-footer', 320, 2);
    expect(rooms.keys, isEmpty);
    await region(tester, 'California (CA)');
    await click(tester, '确认并进入咨询室');
    expect(rooms.keys, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('revoked consent during location lookup prevents room entry', (
    tester,
  ) async {
    final rooms = Rooms()
      ..ready()
      ..locationPending = Completer<void>();
    await mount(tester, rooms, Consents(rooms));
    await tester.tap(find.text('确认并进入咨询室'));
    await tester.pump();
    rooms.json['video_consent'] = false;
    rooms.locationPending!.complete();
    await tester.pumpAndSettle();
    expect(rooms.keys, isEmpty);
    expect(find.text('去授权'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('closing a preparing room cancels pending automatic join', (
    tester,
  ) async {
    final rooms = Rooms()
      ..ready()
      ..preparing = true;
    final controller = await mount(tester, rooms, Consents(rooms));
    await tester.tap(find.text('确认并进入咨询室'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.wantsToJoin, isTrue);
    await shot(tester, 'preparing', 390, 1);
    await tester.tap(
      find.descendant(
        of: find.byType(ConsultationStartDialog),
        matching: find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == '关闭咨询确认',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.wantsToJoin, isFalse);
    rooms.room();
    await controller.load();
    await tester.pumpAndSettle();
    expect(rooms.keys, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('location network failure retries without joining prematurely', (
    tester,
  ) async {
    final rooms = Rooms()
      ..ready()
      ..locationOffline = true;
    await mount(tester, rooms, Consents(rooms));
    await click(tester, '确认并进入咨询室');
    expect(rooms.keys, isEmpty);
    expect(
      find.descendant(
        of: find.byType(ConsultationStartDialog),
        matching: find.textContaining('连接暂时中断'),
      ),
      findsOneWidget,
    );
    await shot(tester, 'offline', 390, 1);
    rooms.locationOffline = false;
    await click(tester, '确认并进入咨询室');
    expect(rooms.regions, ['CA', 'CA']);
    expect(rooms.keys, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('consent retry preserves video scope and original version', (
    tester,
  ) async {
    final rooms = Rooms();
    final actual = Consents(rooms)..pending = Completer<void>();
    await mount(tester, rooms, actual);
    await click(tester, '去授权');
    await click(tester, '我同意开启本次服务的视频咨询');
    await tester.tap(find.text('确认视频授权'));
    await tester.pump();
    expect(actual.writes, hasLength(1));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ConsultationVideoConsentDialog), findsOneWidget);
    actual.pending!.completeError(
      const ProductFailure(ProductFailureKind.offline),
    );
    await tester.pumpAndSettle();
    await shot(tester, 'consent-offline', 390, 1);
    actual.pending = null;
    await click(tester, '确认视频授权');
    expect(actual.writes.map((e) => e.version).toList(), [4, 4]);
    expect(
      actual.writes.every((e) => e.scope == CareConsentScope.video && e.active),
      isTrue,
    );
    expect(rooms.keys, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('a server approved region outside the design demo can enter', (
    tester,
  ) async {
    final rooms = Rooms()..ready();
    (rooms.json['appointment'] as Map)['region'] = 'WA';
    rooms.json['location'] = null;
    await mount(tester, rooms, Consents(rooms));
    expect(find.text('WA'), findsOneWidget);
    await click(tester, '确认并进入咨询室');
    expect(rooms.regions, ['WA']);
    expect(rooms.keys, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
