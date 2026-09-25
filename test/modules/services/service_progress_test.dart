import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_progress_page.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_codec.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

class _Repository extends Fake implements CareRepository {
  _Repository({
    this.active = false,
    this.status = CareEpisodeStatus.active,
    this.remaining = 2,
  });
  Completer<void>? pending;
  bool offline = false;
  bool longName = false;
  final bool active;
  final CareEpisodeStatus status;
  final int remaining;
  final _data = readServiceCatalog(
    Map<String, Object?>.from(
      jsonDecode(
            File(
              'test/fixtures/product_baseline/care_catalog.json',
            ).readAsStringSync(),
          )
          as Map,
    ),
  );
  @override
  Future<ServiceCatalog> catalog() async {
    await pending?.future;
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    if (longName) {
      final json =
          jsonDecode(
                File(
                  'test/fixtures/product_baseline/care_catalog.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      (json['packages'] as List).first['name'] =
          'Personalized Feeding and Lactation Support for Your Growing Family';
      return readServiceCatalog(json);
    }
    return _data;
  }

  @override
  Future<CareOverview> overview() async => active
      ? CareOverview(
          orders: [
            CareOrder(
              id: 'order',
              packageId: 'feeding-confidence',
              status: CareOrderStatus.paid,
              priceMinor: 21900,
              currency: 'USD',
              durationDays: 7,
              totalSessions: 2,
              paymentMode: PaymentMode.sandbox,
              region: 'CA',
              version: 1,
              createdAt: DateTime(2026, 9, 8, 10),
              updatedAt: DateTime(2026, 9, 8, 10),
            ),
          ],
          episodes: [
            CareEpisode(
              id: 'episode',
              orderId: 'order',
              packageId: 'feeding-confidence',
              status: status,
              stage: CareStage.preparation,
              totalSessions: 2,
              remainingSessions: remaining,
              version: 1,
            ),
          ],
        )
      : const CareOverview(orders: [], episodes: []);
}

class Appointments extends Fake implements AppointmentRepository {
  List<CareAppointment> values = [
    appt('completed', 10),
    appt('cancelled', 11),
    appt('confirmed', 15),
    appt('held', 16),
    appt('expired', 12),
  ];
  bool offline = false;
  int calls = 0;
  Completer<void>? pending;
  @override
  Future<BookingContext> context(String id) async {
    calls++;
    if (pending != null) await pending!.future;
    if (offline) throw StateError('offline');
    return BookingContext(
      episode: (await _Repository(active: true).overview()).episodes.first,
      providers: [],
      appointments: values,
      serverTime: DateTime.utc(2026, 9, 12),
    );
  }
}

CareAppointment appt(String status, int day) {
  final json =
      jsonDecode(
            File(
              'test/fixtures/product_baseline/intake_context.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final a = json['appointment'] as Map;
  a['id'] = 'appointment-$status';
  a['episode_id'] = 'episode';
  a['status'] = status;
  a['starts_at'] = DateTime.utc(2026, 9, day, 17).toIso8601String();
  a['ends_at'] = DateTime.utc(2026, 9, day, 17, 30).toIso8601String();
  return readIntakeContext(json).appointment;
}

Future<void> mount(
  WidgetTester tester,
  Appointments appointments, {
  double width = 390,
  double scale = 1,
  double height = 844,
  ValueChanged<CareAppointment>? onOpen,
  VoidCallback? onRenew,
  CareRepository? care,
  bool settle = true,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
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
      home: ServiceProgressPage(
        repository: care ?? _Repository(active: true),
        episodeId: 'episode',
        appointmentRepository: appointments,
        onBack: () {},
        onBook: (_) {},
        onOpenAppointment: onOpen ?? (_) {},
        onRenew: onRenew,
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

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/design_system/progress-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
    ),
  );
}

void main() {
  testWidgets(
    'long plan name on short large-text screen keeps records and actions reachable',
    (tester) async {
      final care = _Repository(active: true)..longName = true;
      await mount(
        tester,
        Appointments(),
        care: care,
        width: 320,
        height: 568,
        scale: 2,
      );
      await tester.tap(find.text('↑ Earlier records'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Personalized Feeding and Lactation Support for Your Growing Family',
        ),
        findsOneWidget,
      );
      await shot(tester, 'long-name', 320, 2);
      await tester.tap(find.text('↓ Back to latest records'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Book consultation'));
      await tester.pumpAndSettle();
      expect(find.text('Book consultation').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'initial and refresh errors recover without losing the service route',
    (tester) async {
      final care = _Repository(active: true)..pending = Completer<void>();
      final appointments = Appointments();
      await mount(
        tester,
        appointments,
        care: care,
        width: 320,
        scale: 2,
        settle: false,
      );
      expect(find.text('Loading service progress…'), findsOneWidget);
      await shot(tester, 'initial-loading', 320, 2);
      care.offline = true;
      care.pending!.complete();
      await tester.pumpAndSettle();
      expect(appointments.calls, 0);
      await shot(tester, 'initial-error', 320, 2);
      care.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(appointments.calls, 1);
      expect(find.text('Consultation booked'), findsOneWidget);
      care.offline = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(appointments.calls, 1);
      care.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(appointments.calls, 2);
      expect(find.text('Consultation booked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('full timeline navigation at $width / $scale', (
        tester,
      ) async {
        final repo = Appointments();
        CareAppointment? opened;
        await mount(
          tester,
          repo,
          width: width,
          scale: scale,
          onOpen: (a) => opened = a,
        );
        expect(repo.calls, 1);
        expect(find.text('2 used · 0/2 consultations left'), findsNothing);
        expect(find.text('0 used · 2/2 consultations left'), findsOneWidget);
        expect(find.text('Appointment time pending'), findsNothing);
        expect(find.text('Appointment expired'), findsOneWidget);
        await shot(tester, 'latest', width, scale);
        await tester.ensureVisible(find.text('View appointment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View appointment'));
        expect(opened?.id, 'appointment-confirmed');
        await tester.tap(find.text('↑ Earlier records'));
        await tester.pumpAndSettle();
        await shot(tester, 'earlier', width, scale);
        await tester.ensureVisible(find.text('View consultation summary'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View consultation summary'));
        expect(opened?.id, 'appointment-completed');
        await tester.tap(find.text('↑ Earlier records'));
        await tester.pumpAndSettle();
        if (find.text('↓ Back to latest records').evaluate().isNotEmpty) {
          await tester.tap(find.text('↓ Back to latest records'));
          await tester.pumpAndSettle();
          expect(find.text('↓ Back to latest records'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'failed appointment read preserves order and retry reads fresh appointments',
    (tester) async {
      final repo = Appointments()..offline = true;
      await mount(tester, repo);
      await shot(tester, 'offline', 390, 1);
      expect(find.text('Package purchased'), findsOneWidget);
      repo.offline = false;
      await tester.tap(find.text('Reload appointments'));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('Consultation booked'), findsOneWidget);
      repo.values = [appt('completed', 15)];
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(repo.calls, 3);
      expect(find.text('Consultation booked'), findsNothing);
      expect(find.text('Consultation ended'), findsOneWidget);
    },
  );
  for (final status in CareEpisodeStatus.values) {
    testWidgets('booking follows authoritative service status $status', (
      tester,
    ) async {
      final repo = Appointments()..values = [];
      await mount(
        tester,
        repo,
        care: _Repository(active: true, status: status, remaining: 1),
      );
      expect(find.text('1 used · 1/2 consultations left'), findsOneWidget);
      expect(
        find.text('Book consultation'),
        status == CareEpisodeStatus.active ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('ended service opens renewal without changing the service', (
    tester,
  ) async {
    var opened = false;
    await mount(
      tester,
      Appointments()..values = [],
      care: _Repository(
        active: true,
        status: CareEpisodeStatus.completed,
        remaining: 0,
      ),
      onRenew: () => opened = true,
    );
    expect(find.text('Book consultation'), findsNothing);
    await tester.ensureVisible(find.text('Continue care'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue care'));
    expect(opened, isTrue);
    await shot(tester, 'completed-renewal', 390, 1);
  });
  testWidgets('short display with enlarged text keeps timeline scrollable', (
    tester,
  ) async {
    await mount(tester, Appointments(), width: 320, height: 568, scale: 2);
    await tester.tap(find.text('↑ Earlier records'));
    await tester.pumpAndSettle();
    await shot(tester, 'short', 320, 2);
    await tester.ensureVisible(find.text('View appointment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('pending context and navigation away release safely', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repo = Appointments()..pending = pending;
    await mount(tester, repo, settle: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await shot(tester, 'loading', 390, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing service has recoverable empty state', (tester) async {
    final repo = Appointments();
    await mount(tester, repo, care: _Repository());
    expect(find.text('Could not find this package'), findsOneWidget);
    expect(repo.calls, 0);
    await shot(tester, 'empty', 390, 1);
  });
}
