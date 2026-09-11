import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/application/booking_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/booking_page.dart';
import 'package:momcozy_flutter_app/services/appointments/appointment_api_repository.dart';
import 'package:momcozy_flutter_app/services/appointments/appointment_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

final _now = DateTime.utc(2026, 9, 8, 15);
final _slot = AppointmentSlot(
  startsAt: DateTime.utc(2026, 9, 8, 16),
  endsAt: DateTime.utc(2026, 9, 8, 17),
  available: true,
);
const _episode = CareEpisode(
  id: 'episode',
  orderId: 'order',
  packageId: 'feeding-confidence',
  status: CareEpisodeStatus.active,
  stage: CareStage.preparation,
  totalSessions: 2,
  remainingSessions: 2,
  version: 1,
);
const _provider = CareProvider(
  id: 'ibclc',
  displayName: 'Test IBCLC',
  timezone: 'America/Los_Angeles',
  regions: ['CA'],
  languages: ['en'],
  bio: '支持含乳、泵奶安排与喂养节奏。',
  sandbox: true,
);
BookingEligibility _eligible() => BookingEligibility(
  id: 'eligibility',
  episodeId: 'episode',
  region: 'CA',
  serviceSuitable: true,
  emergencyStatus: EmergencyStatus.clear,
  eligible: true,
  reason: '',
  expiresAt: _now.add(const Duration(minutes: 30)),
);
Map<String, Object?> _appointmentJson({
  String status = 'held',
  int version = 1,
}) => {
  'id': 'appointment',
  'intake_version': 0,
  'episode_id': 'episode',
  'provider_id': 'ibclc',
  'provider_name': 'Test IBCLC',
  'starts_at': _slot.startsAt.toIso8601String(),
  'ends_at': _slot.endsAt.toIso8601String(),
  'timezone': 'America/Los_Angeles',
  'region': 'CA',
  'status': status,
  'hold_expires_at': _now.add(const Duration(minutes: 10)).toIso8601String(),
  'version': version,
  'confirmed_at': status == 'confirmed' ? _now.toIso8601String() : null,
  'cancelled_at': status == 'cancelled' ? _now.toIso8601String() : null,
};

class _Repository implements AppointmentRepository {
  BookingEligibility? eligibility;
  CareAppointment? appointment;
  Future<CareAppointment>? nextHold;
  Future<CareAppointment>? nextConfirm;
  Future<AppointmentAvailability>? nextAvailability;
  final holdKeys = <String>[];
  final confirmVersions = <int>[];
  final cancelVersions = <int>[];
  int prechecks = 0;
  @override
  Future<BookingContext> context(String episodeId) async => BookingContext(
    episode: _episode,
    providers: [_provider],
    appointments: [?appointment],
    serverTime: _now,
    eligibility: eligibility,
  );
  @override
  Future<BookingEligibility> precheck(
    String episodeId, {
    required String region,
    required bool serviceSuitable,
    required EmergencyStatus emergencyStatus,
  }) async {
    prechecks++;
    return eligibility = _eligible();
  }

  @override
  Future<AppointmentAvailability> availability(
    String episodeId, {
    required String eligibilityId,
    required String providerId,
    required LocalDate date,
  }) async =>
      nextAvailability ??
      AppointmentAvailability(
        providerId: providerId,
        date: date,
        timezone: _provider.timezone,
        slots: [
          _slot,
          AppointmentSlot(
            startsAt: _slot.endsAt,
            endsAt: _slot.endsAt.add(const Duration(hours: 1)),
            available: false,
          ),
        ],
        serverTime: _now,
      );
  @override
  Future<CareAppointment> hold(
    String episodeId, {
    required String eligibilityId,
    required String providerId,
    required DateTime startsAt,
    required String idempotencyKey,
  }) async {
    holdKeys.add(idempotencyKey);
    return nextHold ?? (appointment = readAppointment(_appointmentJson()));
  }

  @override
  Future<CareAppointment> read(String appointmentId) async => appointment!;
  @override
  Future<CareAppointment> confirm(
    String appointmentId, {
    required int expectedVersion,
  }) async {
    confirmVersions.add(expectedVersion);
    return nextConfirm ??
        (appointment = readAppointment(
          _appointmentJson(status: 'confirmed', version: 2),
        ));
  }

  @override
  Future<CareAppointment> cancel(
    String appointmentId, {
    required int expectedVersion,
  }) async {
    cancelVersions.add(expectedVersion);
    return appointment = readAppointment(
      _appointmentJson(status: 'cancelled', version: expectedVersion + 1),
    );
  }
}

void main() {
  test(
    'appointment transport sends the selected instant and identity, never owner or client duration',
    () async {
      final transport = FixtureApiJsonTransport(_appointmentJson());
      final repository = AppointmentApiRepository(transport: transport);
      await repository.hold(
        'episode',
        eligibilityId: 'eligible',
        providerId: 'ibclc',
        startsAt: _slot.startsAt,
        idempotencyKey: 'key',
      );
      expect(transport.lastPath, '/v1/care/episodes/episode/holds');
      expect(transport.lastBody, {
        'eligibility_id': 'eligible',
        'provider_id': 'ibclc',
        'starts_at': _slot.startsAt.toIso8601String(),
      });
      expect(transport.lastHeaders, {'Idempotency-Key': 'key'});
      await repository.confirm('appointment', expectedVersion: 1);
      expect(transport.lastBody, {'expected_version': 1});
      expect(transport.lastPath, '/v1/care/appointments/appointment/confirm');
    },
  );
  test(
    'time labels show provider date and distinguish repeated fall-back hours',
    () {
      expect(
        dateInTimezone(DateTime.utc(2026, 9, 9, 3), _provider.timezone),
        LocalDate(2026, 9, 8),
      );
      expect(
        zonedRange(
          DateTime.utc(2026, 11, 1, 8),
          DateTime.utc(2026, 11, 1, 9),
          _provider.timezone,
        ),
        '01:00 PDT – 01:00 PST',
      );
    },
  );
  test(
    'risk acknowledgement gates eligibility and uncertain holds preserve the original key',
    () async {
      final repository = _Repository();
      final controller = BookingController(
        repository: repository,
        episodeId: 'episode',
        now: () => _now,
        mutationKey: () => 'hold-key',
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.setRegion('CA');
      controller.setSuitable(true);
      controller.setEmergency(EmergencyStatus.needsHelp);
      await controller.precheck();
      expect(repository.prechecks, 0);
      controller.setEmergency(EmergencyStatus.clear);
      await controller.precheck();
      expect(controller.availability!.slots, hasLength(2));
      final pending = Completer<CareAppointment>();
      repository.nextHold = pending.future;
      final first = controller.hold(_slot);
      await controller.hold(_slot);
      expect(repository.holdKeys, ['hold-key']);
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await first;
      expect(controller.unresolvedMutation, isTrue);
      controller.setRegion('TX');
      expect(controller.region, 'CA');
      repository.nextHold = null;
      await controller.retry();
      expect(repository.holdKeys, ['hold-key', 'hold-key']);
      expect(controller.activeAppointment!.status, AppointmentStatus.held);
    },
  );
  test(
    'confirmation retry uses the original version and reloading restores an owned appointment',
    () async {
      final repository = _Repository()
        ..eligibility = _eligible()
        ..appointment = readAppointment(_appointmentJson());
      final controller = BookingController(
        repository: repository,
        episodeId: 'episode',
        now: () => _now.add(const Duration(days: 2)),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.activeAppointment!.status, AppointmentStatus.held);
      final pending = Completer<CareAppointment>();
      repository.nextConfirm = pending.future;
      final first = controller.confirm();
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await first;
      repository.nextConfirm = null;
      await controller.retry();
      expect(repository.confirmVersions, [1, 1]);
      expect(controller.activeAppointment!.status, AppointmentStatus.confirmed);
      await controller.cancel();
      expect(repository.cancelVersions, [2]);
      expect(controller.activeAppointment, isNull);
      expect(controller.availability, isNotNull);
    },
  );
  testWidgets(
    'select time, confirm, resume and cancel a persisted appointment',
    (tester) async {
      await loadMomCozyTestFonts();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository()..eligibility = _eligible();
      CareAppointment? intake;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: BookingPage(
            repository: repository,
            episodeId: 'episode',
            now: () => _now,
            onBack: () {},
            onIntake: (value) async {
              intake = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('09:00 – 10:00 PDT'), findsOneWidget);
      await tester.tap(find.text('09:00 – 10:00 PDT'));
      await tester.pumpAndSettle();
      expect(find.text('所选时间已暂时保留'), findsOneWidget);
      await tester.tap(find.text('确认预约'));
      await tester.pumpAndSettle();
      expect(intake!.id, 'appointment');
      expect(find.text('已确认的咨询'), findsOneWidget);
      await tester.tap(find.text('取消预约'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认取消'));
      await tester.pumpAndSettle();
      expect(find.text('可选时间'), findsOneWidget);
      expect(repository.cancelVersions, [2]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('booking date and expert selection at $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
            home: BookingPage(
              repository: _Repository()..eligibility = _eligible(),
              episodeId: 'episode',
              now: () => _now,
              onBack: () {},
              onIntake: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(BookingPage),
            matchesGoldenFile(
              '../../goldens/product_baseline/booking-${width.toInt()}.png',
            ),
          );
        }
        if (scale == 2) {
          for (var step = 0; step < 8; step++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -400),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
