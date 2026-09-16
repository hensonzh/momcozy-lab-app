import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/application/appointment_cancellation_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/appointment_detail_page.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

CareAppointment appointment({String status = 'confirmed', int version = 2}) {
  final json =
      jsonDecode(
            File(
              'test/fixtures/product_baseline/intake_context.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  (json['appointment'] as Map)['status'] = status;
  (json['appointment'] as Map)['version'] = version;
  return readIntakeContext(json).appointment;
}

class Repository extends Fake implements AppointmentRepository {
  CareAppointment value = appointment();
  bool failRead = false;
  Completer<CareAppointment>? readGate;
  int reads = 0;
  Completer<CareAppointment>? pending;
  final versions = <int>[];
  @override
  Future<CareAppointment> read(String id) async {
    reads++;
    if (readGate != null) return readGate!.future;
    if (failRead) throw const ProductFailure(ProductFailureKind.offline);
    return value;
  }

  @override
  Future<CareAppointment> cancel(
    String id, {
    required int expectedVersion,
  }) async {
    expect(id, value.id);
    versions.add(expectedVersion);
    if (pending != null) return pending!.future;
    return value = appointment(
      status: 'cancelled',
      version: expectedVersion + 1,
    );
  }
}

Future<void> mount(
  WidgetTester tester,
  Repository repository, {
  double width = 390,
  double scale = 1,
  bool settle = true,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => AppointmentDetailPage(
          repository: repository,
          appointmentId: repository.value.id,
        ),
      ),
      GoRoute(
        path: '/me',
        builder: (_, _) =>
            const Scaffold(body: Text('Home after cancellation')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('Notifications')),
      ),
      GoRoute(
        path: '/services/appointments/:id/:page',
        builder: (_, s) =>
            Scaffold(body: Text('Opened ${s.pathParameters['page']}')),
      ),
      GoRoute(
        path: '/services/episodes/:id/booking',
        builder: (_, _) => const Scaffold(body: Text('Booking')),
      ),
      GoRoute(
        path: '/services/episodes/:id',
        builder: (_, _) => const Scaffold(body: Text('Service')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
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

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/appointment-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
      ),
    );
  }
}

void main() {
  testWidgets(
    'initial load and refresh failure remove stale appointment actions',
    (tester) async {
      final gate = Completer<CareAppointment>();
      final repo = Repository()..readGate = gate;
      await mount(tester, repo, width: 320, scale: 2, settle: false);
      expect(find.text('正在加载预约…'), findsOneWidget);
      expect(find.text('取消预约'), findsNothing);
      await shot(tester, 'loading', 320, 2);
      gate.complete(repo.value);
      repo.readGate = null;
      await tester.pumpAndSettle();
      expect(find.text('取消预约'), findsOneWidget);
      repo.failRead = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('取消预约'), findsNothing);
      await shot(tester, 'refresh-error', 320, 2);
      repo.failRead = false;
      repo.value = appointment(status: 'completed');
      await click(tester, find.text('重试'));
      expect(find.text('查看咨询总结'), findsOneWidget);
      expect(find.text('填写信息采集表'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'held appointment booking return rereads status and root back opens notifications',
    (tester) async {
      final repo = Repository()..value = appointment(status: 'held');
      await mount(tester, repo, width: 320, scale: 2);
      await shot(tester, 'held', 320, 2);
      await click(tester, find.text('继续确认预约'));
      expect(find.text('Booking'), findsOneWidget);
      repo.value = appointment(status: 'confirmed');
      GoRouter.of(tester.element(find.text('Booking'))).pop();
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(find.text('取消预约'), findsOneWidget);
      expect(find.text('继续确认预约'), findsNothing);
      await click(tester, find.text('返回'));
      expect(find.text('Notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short screen and safe areas keep cancellation actions reachable',
    (tester) async {
      final repo = Repository();
      await mount(tester, repo, width: 320, scale: 2);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      await click(tester, find.widgetWithText(OutlinedButton, '取消预约'));
      await click(tester, find.text('确认取消'));
      expect(repo.versions, [2]);
      expect(find.text('Home after cancellation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('appointment keep and cancel at $width / $scale', (
        tester,
      ) async {
        final repo = Repository();
        await mount(tester, repo, width: width, scale: scale);
        await shot(tester, 'detail', width, scale);
        await click(tester, find.widgetWithText(OutlinedButton, '取消预约'));
        await shot(tester, 'cancel', width, scale);
        await click(tester, find.text('保留预约'));
        expect(repo.versions, isEmpty);
        await click(tester, find.widgetWithText(OutlinedButton, '取消预约'));
        await click(tester, find.text('确认取消'));
        expect(repo.versions, [2]);
        expect(find.text('Home after cancellation'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'cancel pending locks return and retry uses original appointment version',
    (tester) async {
      final repo = Repository()..pending = Completer<CareAppointment>();
      await mount(tester, repo);
      await click(tester, find.widgetWithText(OutlinedButton, '取消预约'));
      await tester.tap(find.text('确认取消'));
      await tester.pump();
      expect(repo.versions, [2]);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is IconButton && (w.tooltip?.startsWith('关闭') ?? false),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('正在处理…'), findsOneWidget);
      repo.pending!.completeError(
        const ProductFailure(ProductFailureKind.offline),
      );
      await tester.pumpAndSettle();
      await shot(tester, 'cancel-uncertain', 390, 1);
      expect(find.text('返回预约'), findsOneWidget);
      repo.pending = null;
      await click(tester, find.text('重试取消'));
      expect(repo.versions, [2, 2]);
      expect(find.text('Home after cancellation'), findsOneWidget);
    },
  );
  testWidgets(
    'query resolves lost cancellation response without another mutation',
    (tester) async {
      final repo = Repository()..pending = Completer<CareAppointment>();
      await mount(tester, repo);
      await click(tester, find.widgetWithText(OutlinedButton, '取消预约'));
      await tester.tap(find.text('确认取消'));
      await tester.pump();
      repo.value = appointment(status: 'cancelled', version: 3);
      repo.pending!.completeError(
        const ProductFailure(ProductFailureKind.offline),
      );
      await tester.pumpAndSettle();
      await click(tester, find.text('核对预约状态'));
      expect(repo.versions, [2]);
      expect(find.text('Home after cancellation'), findsOneWidget);
    },
  );
  testWidgets(
    'appointment read failure retries instead of showing stale actions',
    (tester) async {
      final repo = Repository()..failRead = true;
      await mount(tester, repo);
      expect(find.text('暂时无法打开预约'), findsOneWidget);
      expect(find.text('取消预约'), findsNothing);
      await shot(tester, 'unavailable', 390, 1);
      repo.failRead = false;
      await click(tester, find.text('重试'));
      expect(find.text('取消预约'), findsOneWidget);
      expect(repo.reads, 2);
    },
  );
  for (final status in [
    'in_progress',
    'completed',
    'cancelled',
    'expired',
    'held',
  ]) {
    testWidgets('appointment actions follow $status state', (tester) async {
      final repo = Repository()..value = appointment(status: status);
      await mount(tester, repo);
      expect(find.text('取消预约'), findsNothing);
      await shot(tester, status, 390, 1);
      if (status == 'completed') {
        await click(tester, find.text('查看咨询总结'));
        expect(find.text('Opened summary'), findsOneWidget);
      } else if (status == 'in_progress') {
        await click(tester, find.text('返回咨询室'));
        expect(find.text('Opened room'), findsOneWidget);
      } else {
        expect(find.text('咨询前准备'), findsNothing);
      }
    });
  }
  test(
    'cancel controller rejects duplicate submits and stops after appointment starts',
    () async {
      final repo = Repository()..pending = Completer<CareAppointment>();
      final controller = AppointmentCancellationController(
        repository: repo,
        appointment: repo.value,
      );
      addTearDown(controller.dispose);
      final task = controller.cancel();
      await controller.cancel();
      expect(repo.versions, [2]);
      repo.pending!.completeError(
        const ProductFailure(ProductFailureKind.conflict),
      );
      await task;
      repo.value = appointment(status: 'in_progress', version: 3);
      await controller.refresh();
      expect(controller.canCancel, isFalse);
      await controller.cancel();
      expect(repo.versions, [2]);
    },
  );
}
