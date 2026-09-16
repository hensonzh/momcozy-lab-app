import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/expert_support_section.dart';
import '../services/expert_home_states_test.dart' show episode;
import '../services/service_catalog_states_test.dart' show CatalogFixture;
import 'package:momcozy_flutter_app/modules/consultation/presentation/home_consultation_dialog.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/consultation_preparation.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

class Appointments extends Fake implements AppointmentRepository {
  Appointments(this.rooms);
  final TestRoomRepository rooms;
  int cancels = 0;
  @override
  Future<CareAppointment> read(String id) async => rooms.context.appointment;
  @override
  Future<CareAppointment> cancel(
    String id, {
    required int expectedVersion,
  }) async {
    expect(id, rooms.context.appointment.id);
    expect(expectedVersion, rooms.context.appointment.version);
    cancels++;
    rooms.json['appointment'] = {
      ...Map<String, Object?>.from(rooms.json['appointment'] as Map),
      'status': 'cancelled',
      'version': expectedVersion + 1,
    };
    return rooms.context.appointment;
  }
}

class DeferredRooms extends TestRoomRepository {
  Completer<ConsultationRoomContext>? pending;
  bool offline = false;
  int loads = 0;
  @override
  Future<ConsultationRoomContext> load(String id) async {
    loads++;
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    return pending?.future ?? context;
  }
}

Future<void> mountHost(
  WidgetTester tester,
  TestRoomRepository rooms,
  void Function(HomeConsultationDestination?) done, {
  double scale = 1,
}) async {
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
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => done(
              await showHomeConsultationDialog(
                context,
                createController: () =>
                    testController(rooms, TestConsultationMedia()),
                appointments: Appointments(rooms),
                createDeviceCheck: TestReadyDeviceCheck.new,
              ),
            ),
            child: const Text('查看预约'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('查看预约'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('loading can close safely and errors retry in the same overlay', (
    tester,
  ) async {
    final rooms = DeferredRooms()
      ..pending = Completer<ConsultationRoomContext>();
    var returned = 0;
    await mountHost(tester, rooms, (_) => returned++);
    expect(find.text('预约详情'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭预约详情'));
    await tester.pumpAndSettle();
    expect(returned, 1);
    rooms.pending!.complete(rooms.context);
    await tester.pumpAndSettle();
    expect(find.text('预约详情'), findsNothing);
    expect(rooms.keys, isEmpty);
    final reads = rooms.loads;
    await tester.pump(const Duration(seconds: 10));
    expect(rooms.loads, reads);
    rooms.pending = null;
    rooms.offline = true;
    await tester.tap(find.text('查看预约'));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    rooms.offline = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ConsultationPreparation),
        matching: find.text('00:05:00'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('关闭预约详情'));
    await tester.pumpAndSettle();
    expect(returned, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'intake navigation dismisses nested preflight and home overlay together',
    (tester) async {
      final rooms = DeferredRooms()..ready();
      HomeConsultationDestination? destination;
      await mountHost(tester, rooms, (value) => destination = value);
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始咨询'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续确认'));
      await tester.pumpAndSettle();
      rooms.json['intake_ready'] = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看信息采集表').last);
      await tester.pumpAndSettle();
      expect(destination, HomeConsultationDestination.intake);
      expect(find.text('预约详情'), findsNothing);
      expect(find.text('开始视频咨询'), findsNothing);
      expect(rooms.keys, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'short enlarged home preparation can retry loading failure and close',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rooms = DeferredRooms()
        ..pending = Completer<ConsultationRoomContext>();
      var returned = false;
      await mountHost(tester, rooms, (_) => returned = true, scale: 2);
      expect(find.text('正在读取咨询信息'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/home-preparation-loading-short-320-2x.png',
        ),
      );
      rooms.pending!.completeError(
        const ProductFailure(ProductFailureKind.offline),
      );
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/home-preparation-error-short-320-2x.png',
        ),
      );
      rooms.pending = null;
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('开始咨询'));
      await tester.pumpAndSettle();
      expect(rooms.keys, isEmpty);
      await tester.tap(find.byTooltip('关闭预约详情'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'home preparation closes, cancels and enters through existing checks $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final rooms = TestRoomRepository()..ready();
          final appointments = Appointments(rooms);
          final media = <TestConsultationMedia>[];
          var returned = 0;
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
              home: Scaffold(
                body: Builder(
                  builder: (context) => SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ExpertServiceCard(
                      episode: episode,
                      package: CatalogFixture().data.packages.first,
                      appointment: rooms.context.appointment,
                      now: rooms.context.serverTime,
                      onBook: () {},
                      onProgress: () {},
                      onAppointment: () async {
                        final current = TestConsultationMedia();
                        media.add(current);
                        await showHomeConsultationDialog(
                          context,
                          createController: () =>
                              testController(rooms, current),
                          appointments: appointments,
                          createDeviceCheck: TestReadyDeviceCheck.new,
                        );
                        returned++;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          Future<void> click(String label) async {
            await tester.ensureVisible(find.text(label).last);
            await tester.pumpAndSettle();
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
          }

          Future<void> shot(String state) async {
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/home-preparation-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
              ),
            );
          }

          await click('查看预约');
          expect(
            find.descendant(
              of: find.byType(ConsultationPreparation),
              matching: find.text('00:05:00'),
            ),
            findsOneWidget,
          );
          expect(find.text('预约详情'), findsOneWidget);
          expect(find.text('咨询前准备'), findsNothing);
          expect(rooms.keys, isEmpty);
          expect(media.single.connectCalls, 0);
          await shot('ready');
          await tester.tap(find.byTooltip('关闭预约详情'));
          await tester.pumpAndSettle();
          expect(returned, 1);
          expect(find.text('预约详情'), findsNothing);
          await click('查看预约');
          await click('取消预约');
          await shot('cancel');
          expect(appointments.cancels, 0);
          // Keeping the appointment returns home, matching the design modal flow.
          await click('保留预约');
          expect(returned, 2);
          await click('查看预约');
          await click('开始咨询');
          expect(find.text('摄像头和麦克风均可用'), findsOneWidget);
          await click('继续确认');
          expect(find.text('开始视频咨询'), findsOneWidget);
          expect(rooms.keys, isEmpty);
          await click('确认并进入咨询室');
          expect(rooms.keys, hasLength(1));
          expect(media.last.connectCalls, 1);
          expect(find.text('等待室'), findsWidgets);
          await shot('room');
          await click('离开房间');
          await click('留在房间');
          expect(returned, 2);
          await click('离开房间');
          await click('暂时离开');
          expect(returned, 3);
          expect(media.last.disconnectCalls, greaterThan(0));
          await click('查看预约');
          await click('取消预约');
          await click('确认取消');
          expect(appointments.cancels, 1);
          expect(returned, 4);
          expect(find.text('预约详情'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
