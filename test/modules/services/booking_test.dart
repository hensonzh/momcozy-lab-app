import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/application/booking_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/booking_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/booking_flow_dialogs.dart';
import 'package:momcozy_flutter_app/services/appointments/appointment_api_repository.dart';
import 'package:momcozy_flutter_app/services/appointments/appointment_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

final _now = DateTime.utc(2026, 9, 8, 15);

Future<void> _mountBooking(
  WidgetTester tester,
  _Repository repository, {
  double width = 390,
  double scale = 1,
  bool settle = true,
  DateTime Function()? now,
  Future<void> Function(CareAppointment)? onIntake,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('booking-capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: BookingPage(
          repository: repository,
          episodeId: 'episode',
          now: now ?? () => _now,
          onBack: () {},
          onIntake: onIntake ?? (_) async {},
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _clickBooking(WidgetTester tester, String text) async {
  if (text == 'Close') {
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is IconButton && (w.tooltip?.startsWith('Close') ?? false),
      ),
    );
    await tester.pumpAndSettle();
    return;
  }
  await tester.pumpAndSettle();
  final target = find.text(text);
  final scrollable = find.descendant(
    of: find.byType(BookingPage),
    matching: find.byType(Scrollable),
  );
  if (target.evaluate().isEmpty && scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(target, 200, scrollable: scrollable.first);
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _selectRegion(WidgetTester tester, String name) async {
  final field = find.descendant(
    of: find.byType(BookingPrecheckDialog),
    matching: find.byType(DropdownButtonFormField<String>),
  );
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _bookingShot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  final appBar = tester.widget<AppBar>(find.byType(AppBar));
  final title = (appBar.title! as Text).data!;
  final titleFinder = find.descendant(
    of: find.byType(AppBar),
    matching: find.text(title),
  );
  expect(
    tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
    isFalse,
    reason: 'The booking title must not ellipsize at $width/$scale',
  );
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byKey(const ValueKey('booking-capture')),
      matchesGoldenFile(
        '../../goldens/design_system/booking-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
      ),
    );
  }
}

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
  bio: 'Support with latching, pumping plans, and feeding routines.',
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
  Future<BookingContext>? nextContext;
  bool offline = false;
  BookingEligibility? eligibility;
  CareAppointment? appointment;
  Future<CareAppointment>? nextHold;
  Future<CareAppointment>? nextConfirm;
  Future<CareAppointment>? nextCancel;
  Future<AppointmentAvailability>? nextAvailability;
  final holdKeys = <String>[];
  final confirmVersions = <int>[];
  final cancelVersions = <int>[];
  int prechecks = 0;
  @override
  Future<BookingContext> context(String episodeId) async {
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    return nextContext ??
        BookingContext(
          episode: _episode,
          providers: [_provider],
          appointments: [?appointment],
          serverTime: _now,
          eligibility: eligibility,
        );
  }

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
    return nextCancel ??
        (appointment = readAppointment(
          _appointmentJson(status: 'cancelled', version: expectedVersion + 1),
        ));
  }
}

void main() {
  for (final config in [(393.0, 1.0), (320.0, 2.0)]) {
    final (width, scale) = config;
    testWidgets(
      'booking loading retry empty slots and unavailable slots $width/$scale',
      (tester) async {
        final gate = Completer<BookingContext>();
        final repo = _Repository()
          ..eligibility = _eligible()
          ..nextContext = gate.future;
        await _mountBooking(
          tester,
          repo,
          width: width,
          scale: scale,
          settle: false,
        );
        expect(find.text('Loading appointments…'), findsOneWidget);
        await _bookingShot(tester, 'initial-loading', width, scale);
        gate.completeError(const ProductFailure(ProductFailureKind.offline));
        await tester.pumpAndSettle();
        await _bookingShot(tester, 'initial-error', width, scale);
        repo.nextContext = null;
        repo.nextAvailability = Future.value(
          AppointmentAvailability(
            providerId: _provider.id,
            date: LocalDate(2026, 9, 8),
            timezone: _provider.timezone,
            slots: [],
            serverTime: _now,
          ),
        );
        await _clickBooking(tester, 'Try again');
        await tester.scrollUntilVisible(
          find.text('No times available'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(BookingPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await _bookingShot(tester, 'empty-slots', width, scale);
        repo.nextAvailability = null;
        await tester.tap(find.byTooltip('Refresh appointment'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('10:00 – 11:00 PDT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10:00 – 11:00 PDT'));
        expect(repo.holdKeys, isEmpty);
        expect(find.byType(BookingSelectionDialog), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'confirmed booking groups preparation and reminder $width/$scale',
      (tester) async {
        final repo = _Repository()
          ..eligibility = _eligible()
          ..appointment = readAppointment(
            _appointmentJson(status: 'confirmed', version: 2),
          );
        await _mountBooking(tester, repo, width: width, scale: scale);
        expect(find.text('Confirmed · IBCLC'), findsOneWidget);
        await _bookingShot(tester, 'confirmed-top', width, scale);
        await tester.ensureVisible(find.text('Complete intake form'));
        await tester.pumpAndSettle();
        await _bookingShot(tester, 'confirmed-preparation', width, scale);
        expect(find.text('Complete intake form').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'booking date picker preserves invalid input and original date on cancel',
    (tester) async {
      final repo = _Repository()..eligibility = _eligible();
      await _mountBooking(tester, repo, width: 320, scale: 2);
      await _clickBooking(tester, '2026-09-08');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final labels = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.tap(find.text(labels.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await _bookingShot(tester, 'date-invalid', 320, 2);
      await tester.tap(find.text(labels.cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-08'), findsOneWidget);
      expect(repo.holdKeys, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'precheck waits for availability without allowing a second submit or back',
    (tester) async {
      final repository = _Repository();
      final availability = Completer<AppointmentAvailability>();
      repository.nextAvailability = availability.future;
      await _mountBooking(tester, repository);
      await _selectRegion(tester, 'California (CA)');
      await _clickBooking(
        tester,
        'I need IBCLC support with lactation or feeding.',
      );
      await _clickBooking(tester, 'None of these apply right now');
      // Pump one frame: the asynchronous availability request is intentionally pending.
      await tester.ensureVisible(find.text('Continue to time selection'));
      await tester.tap(find.text('Continue to time selection'));
      await tester.pump();
      expect(repository.prechecks, 1);
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is IconButton &&
                    (w.tooltip?.startsWith('Close') ?? false),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BookingPrecheckDialog), findsOneWidget);
      availability.complete(
        AppointmentAvailability(
          providerId: _provider.id,
          date: LocalDate(2026, 9, 8),
          timezone: _provider.timezone,
          slots: [_slot],
          serverTime: _now,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingPrecheckDialog), findsNothing);
      expect(repository.prechecks, 1);
      expect(find.byType(BookingPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'resumed confirmed state offers intake rather than an expired hold',
    (tester) async {
      final repository = _Repository()
        ..eligibility = _eligible()
        ..appointment = readAppointment(_appointmentJson());
      await _mountBooking(tester, repository);
      repository.appointment = readAppointment(
        _appointmentJson(status: 'confirmed', version: 2),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Appointment confirmed'), findsOneWidget);
      expect(
        find.text(
          'Your selected time is no longer on hold. Choose another time.',
        ),
        findsNothing,
      );
      await _clickBooking(tester, 'Continue intake form');
      expect(find.byType(BookingSelectionDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('booking precheck and held dialog flow at $width / $scale', (
        tester,
      ) async {
        final repository = _Repository();
        CareAppointment? intake;
        await _mountBooking(
          tester,
          repository,
          width: width,
          scale: scale,
          onIntake: (a) async => intake = a,
        );
        expect(find.byType(BookingPrecheckDialog), findsOneWidget);
        await _selectRegion(tester, 'California (CA)');
        await _bookingShot(tester, 'precheck', width, scale);
        await _selectRegion(tester, 'New York (NY)');
        await _clickBooking(
          tester,
          'I need IBCLC support with lactation or feeding.',
        );
        await _clickBooking(tester, 'None of these apply right now');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue to time selection'),
              )
              .onPressed,
          isNull,
        );
        expect(repository.prechecks, 0);
        await _bookingShot(tester, 'unavailable', width, scale);
        await _selectRegion(tester, 'California (CA)');
        await _clickBooking(tester, 'Yes, or I am not sure');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue to time selection'),
              )
              .onPressed,
          isNull,
        );
        await _bookingShot(tester, 'emergency', width, scale);
        await _clickBooking(tester, 'Close');
        expect(find.byType(BookingPrecheckDialog), findsNothing);
        await _clickBooking(tester, 'Start check');
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        await _clickBooking(tester, 'None of these apply right now');
        await _clickBooking(tester, 'Continue to time selection');
        expect(repository.prechecks, 1);
        expect(find.byType(BookingPrecheckDialog), findsNothing);
        await _clickBooking(tester, '09:00 – 10:00 PDT');
        expect(find.byType(BookingSelectionDialog), findsOneWidget);
        await _bookingShot(tester, 'held', width, scale);
        await _clickBooking(tester, 'Close');
        expect(repository.cancelVersions, isEmpty);
        await _clickBooking(tester, 'View selected time');
        await _clickBooking(tester, 'Confirm appointment');
        expect(intake?.status, AppointmentStatus.confirmed);
        expect(repository.holdKeys, hasLength(1));
        expect(repository.confirmVersions, [1]);
        expect(find.byType(BookingSelectionDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'held confirmation blocks back, retries original version then opens intake once',
    (tester) async {
      final repository = _Repository()
        ..eligibility = _eligible()
        ..appointment = readAppointment(_appointmentJson());
      var opened = 0;
      await _mountBooking(
        tester,
        repository,
        onIntake: (_) async {
          opened++;
        },
      );
      final wait = Completer<CareAppointment>();
      repository.nextConfirm = wait.future;
      await _clickBooking(tester, 'Confirm appointment');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BookingSelectionDialog), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is IconButton &&
                    (w.tooltip?.startsWith('Close') ?? false),
              ),
            )
            .onPressed,
        isNull,
      );
      wait.completeError(const ProductFailure(ProductFailureKind.offline));
      await tester.pumpAndSettle();
      final retry = find.descendant(
        of: find.byType(BookingSelectionDialog),
        matching: find.text('Retry last submission'),
      );
      await tester.ensureVisible(retry);
      await _bookingShot(tester, 'confirm-uncertain', 390, 1);
      repository.nextConfirm = null;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.confirmVersions, [1, 1]);
      expect(opened, 1);
      expect(find.byType(BookingSelectionDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'expired hold removes confirm and reselect does not cancel expired data',
    (tester) async {
      var clock = _now;
      final repository = _Repository()
        ..eligibility = _eligible()
        ..appointment = readAppointment(_appointmentJson());
      await _mountBooking(tester, repository, now: () => clock);
      clock = _now.add(const Duration(minutes: 11));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Confirm appointment'), findsNothing);
      expect(
        find.text(
          'Your selected time is no longer on hold. Choose another time.',
        ),
        findsOneWidget,
      );
      await _bookingShot(tester, 'hold-expired', 390, 1);
      await _clickBooking(tester, 'Choose another time');
      expect(repository.cancelVersions, isEmpty);
      expect(find.byType(BookingSelectionDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'release retry closes held dialog after the original cancellation succeeds',
    (tester) async {
      final repository = _Repository()
        ..eligibility = _eligible()
        ..appointment = readAppointment(_appointmentJson());
      await _mountBooking(tester, repository);
      final wait = Completer<CareAppointment>();
      repository.nextCancel = wait.future;
      await _clickBooking(tester, 'Choose another time');
      wait.completeError(const ProductFailure(ProductFailureKind.offline));
      await tester.pumpAndSettle();
      repository.nextCancel = null;
      await tester.tap(
        find.descendant(
          of: find.byType(BookingSelectionDialog),
          matching: find.text('Retry last submission'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.cancelVersions, [1, 1]);
      expect(find.byType(BookingSelectionDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: BookingPage(
            repository: repository,
            episodeId: 'episode',
            now: () => _now,
            onBack: () => closed = true,
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
      expect(find.text('Your selected time is on hold'), findsOneWidget);
      await tester.tap(find.text('Confirm appointment'));
      await tester.pumpAndSettle();
      expect(intake!.id, 'appointment');
      expect(find.text('Confirmed · IBCLC'), findsOneWidget);
      await tester.tap(find.text('Cancel appointment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm cancellation'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
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
