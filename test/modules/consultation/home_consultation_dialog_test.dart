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
            child: const Text('View appointment'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('View appointment'));
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
    expect(find.text('Appointment details'), findsOneWidget);
    await tester.tap(find.byTooltip('Close appointment details'));
    await tester.pumpAndSettle();
    expect(returned, 1);
    rooms.pending!.complete(rooms.context);
    await tester.pumpAndSettle();
    expect(find.text('Appointment details'), findsNothing);
    expect(rooms.keys, isEmpty);
    final reads = rooms.loads;
    await tester.pump(const Duration(seconds: 10));
    expect(rooms.loads, reads);
    rooms.pending = null;
    rooms.offline = true;
    await tester.tap(find.text('View appointment'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    rooms.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ConsultationPreparation),
        matching: find.text('00:05:00'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close appointment details'));
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
      await tester.tap(find.text('Start consultation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      rooms.json['intake_ready'] = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View intake form').last);
      await tester.pumpAndSettle();
      expect(destination, HomeConsultationDestination.intake);
      expect(find.text('Appointment details'), findsNothing);
      expect(find.text('Start video consultation'), findsNothing);
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
      expect(find.text('Loading consultation details'), findsOneWidget);
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
      expect(find.text('Try again'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/home-preparation-error-short-320-2x.png',
        ),
      );
      rooms.pending = null;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start consultation'));
      await tester.pumpAndSettle();
      expect(rooms.keys, isEmpty);
      await tester.tap(find.byTooltip('Close appointment details'));
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

          await click('View appointment');
          expect(
            find.descendant(
              of: find.byType(ConsultationPreparation),
              matching: find.text('00:05:00'),
            ),
            findsOneWidget,
          );
          expect(find.text('Appointment details'), findsOneWidget);
          expect(find.text('Prepare for your consultation'), findsNothing);
          expect(rooms.keys, isEmpty);
          expect(media.single.connectCalls, 0);
          await shot('ready');
          await tester.tap(find.byTooltip('Close appointment details'));
          await tester.pumpAndSettle();
          expect(returned, 1);
          expect(find.text('Appointment details'), findsNothing);
          await click('View appointment');
          await click('Cancel appointment');
          await shot('cancel');
          expect(appointments.cancels, 0);
          // Keeping the appointment returns home, matching the design modal flow.
          await click('Keep appointment');
          expect(returned, 2);
          await click('View appointment');
          await click('Start consultation');
          expect(find.text('Camera and microphone are ready'), findsOneWidget);
          await click('Continue');
          expect(find.text('Start video consultation'), findsOneWidget);
          expect(rooms.keys, isEmpty);
          await click('Confirm and join');
          expect(rooms.keys, hasLength(1));
          expect(media.last.connectCalls, 1);
          expect(find.text('Waiting room'), findsWidgets);
          await shot('room');
          await click('Leave room');
          await click('Stay in room');
          expect(returned, 2);
          await click('Leave room');
          await click('Leave for now');
          expect(returned, 3);
          expect(media.last.disconnectCalls, greaterThan(0));
          await click('View appointment');
          await click('Cancel appointment');
          await click('Confirm cancellation');
          expect(appointments.cancels, 1);
          expect(returned, 4);
          expect(find.text('Appointment details'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
