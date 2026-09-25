import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/expert_support_section.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_codec.dart';
import '../../support/momcozy_test_fonts.dart';
import 'service_catalog_states_test.dart' show CatalogFixture, host;

const episode = CareEpisode(
  id: 'episode',
  orderId: 'order',
  packageId: 'feeding-confidence',
  status: CareEpisodeStatus.active,
  stage: CareStage.preparation,
  totalSessions: 2,
  remainingSessions: 2,
  version: 1,
);

class HomeCare extends CatalogFixture {
  @override
  Future<CareOverview> overview() async =>
      const CareOverview(orders: [], episodes: [episode]);
}

class HomeAppointments extends Fake implements AppointmentRepository {
  int intakeVersion = 0;
  bool booked = false;
  AppointmentStatus status = AppointmentStatus.confirmed;
  CareAppointment get value {
    final raw = Map<String, Object?>.from(
      jsonDecode(
            File(
              'test/fixtures/product_baseline/intake_context.json',
            ).readAsStringSync(),
          )
          as Map,
    );
    raw['appointment'] = {
      ...Map<String, Object?>.from(raw['appointment'] as Map),
      'episode_id': 'episode',
      'intake_version': intakeVersion,
      'status': status == AppointmentStatus.inProgress
          ? 'in_progress'
          : 'confirmed',
    };
    return readIntakeContext(raw).appointment;
  }

  @override
  Future<BookingContext> context(String id) async => BookingContext(
    episode: episode,
    providers: [],
    appointments: [if (booked) value],
    serverTime: DateTime.utc(2026, 9, 8, 15, 30),
  );
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'home purchased, intake and preparation actions $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final care = HomeCare();
          final appointments = HomeAppointments();
          final destinations = <String>[];
          var now = DateTime.utc(2026, 9, 8, 15, 30);
          await tester.pumpWidget(
            host(
              Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ExpertSupportSection(
                    repository: care,
                    appointmentRepository: appointments,
                    now: () => now,
                    onCatalog: () async {
                      destinations.add('catalog');
                    },
                    onProgress: (e) async {
                      destinations.add('progress:${e.id}');
                    },
                    onBook: (e) async {
                      destinations.add('book:${e.id}');
                      appointments.booked = true;
                    },
                    onIntake: (a) async {
                      destinations.add('intake:${a.id}');
                      appointments.intakeVersion = 1;
                    },
                    onAppointment: (a) async {
                      destinations.add('detail:${a.id}');
                    },
                    onJoin: (a) async {
                      destinations.add('room:${a.id}');
                    },
                  ),
                ),
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          Future<void> shot(String state) async {
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/home-service-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
              ),
            );
          }

          Future<void> click(String text) async {
            await tester.ensureVisible(find.text(text));
            await tester.pumpAndSettle();
            expect(find.text(text).hitTestable(), findsOneWidget);
            await tester.tap(find.text(text));
            await tester.pumpAndSettle();
          }

          await shot('paid');
          await click('Book a consultation');
          expect(destinations, ['book:episode']);
          expect(find.text('Complete intake'), findsOneWidget);
          expect(find.textContaining('09:00 – 10:00 PDT'), findsOneWidget);
          expect(find.text('00:30:00'), findsOneWidget);
          await shot('intake');
          await click('Complete intake');
          expect(destinations.last, 'intake:${appointments.value.id}');
          expect(find.text('View appointment'), findsOneWidget);
          expect(find.text('Complete intake'), findsNothing);
          await shot('ready');
          if (width == 320) {
            expect(
              tester
                  .getSize(
                    find.widgetWithText(FilledButton, 'View appointment'),
                  )
                  .width,
              greaterThan(200),
              reason:
                  'Keep the full English action readable on a narrow screen.',
            );
          }
          now = now.add(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('00:29:59'), findsOneWidget);
          await click('View appointment');
          expect(destinations.last, 'detail:${appointments.value.id}');
          appointments.status = AppointmentStatus.inProgress;
          await click('Service progress ›');
          expect(find.text('In consultation'), findsOneWidget);
          await click('Join consultation');
          expect(destinations.last, 'room:${appointments.value.id}');
          expect([care.createCalls, care.paymentCalls], [0, 0]);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
