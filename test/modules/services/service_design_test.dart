import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/expert_support_section.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_catalog_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_package_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_progress_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/appointment_detail_page.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_codec.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('home keeps booking disabled until appointment status is known', (
    tester,
  ) async {
    final pending = Completer<BookingContext>();
    final appointments = _HomeAppointments(pending: pending.future);
    final care = _Repository(active: true);
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: SingleChildScrollView(
            child: ExpertSupportSection(
              repository: care,
              appointmentRepository: appointments,
              now: () => DateTime.utc(2026, 9, 8, 15, 30),
              onCatalog: () async {},
              onProgress: (_) async {},
              onBook: (_) async {},
            ),
          ),
        ),
        1,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('正在读取预约…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '预约咨询'))
          .onPressed,
      isNull,
    );
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('预约暂时未载入，可在服务进度中查看'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '预约咨询'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'home displays and opens confirmed appointment at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          CareAppointment? opened;
          var booked = false;
          await tester.pumpWidget(
            _host(
              Scaffold(
                body: SingleChildScrollView(
                  child: ExpertSupportSection(
                    repository: _Repository(active: true),
                    appointmentRepository: _HomeAppointments(),
                    now: () => DateTime.utc(2026, 9, 8, 15, 30),
                    onCatalog: () async {},
                    onProgress: (_) async {},
                    onBook: (_) async {
                      booked = true;
                    },
                    onAppointment: (value) async {
                      opened = value;
                    },
                  ),
                ),
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          // Asset decoding runs outside fake time; settle it before the golden.
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(MomHomeAssets.experts),
              tester.element(find.byType(ExpertSupportSection)),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Test IBCLC'), findsOneWidget);
          expect(find.text('00:30:00'), findsOneWidget);
          expect(find.text('预约咨询'), findsNothing);
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/expert-appointment-${width.toInt()}.png',
              ),
            );
          }
          await tester.ensureVisible(find.text('查看预约'));
          await tester.tap(find.text('查看预约'));
          await tester.pumpAndSettle();
          expect(opened?.id, _Appointments().value.id);
          expect(booked, isFalse);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets('appointment detail at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Appointments();
        final appointment = repository.value;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => AppointmentDetailPage(
                repository: repository,
                appointmentId: appointment.id,
              ),
            ),
            GoRoute(
              path: '/services/appointments/:id/:page',
              builder: (_, state) => Scaffold(
                body: Text('Opened ${state.pathParameters['page']}'),
              ),
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
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/appointment-detail-${width.toInt()}.png',
            ),
          );
        }
        for (final entry in {
          (appointment.intakeVersion > 0 ? '查看信息采集表' : '填写信息采集表'): 'intake',
          '咨询前准备': 'room',
        }.entries) {
          await tester.scrollUntilVisible(find.text(entry.key), 240);
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.key));
          await tester.pumpAndSettle();
          expect(find.text('Opened ${entry.value}'), findsOneWidget);
          router.go('/');
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
      });
      for (final progressPage in [false, true]) {
        testWidgets(
          'service ${progressPage ? 'progress' : 'package'} at $width / $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final repository = _Repository(active: progressPage);
            var booked = false;
            await tester.pumpWidget(
              _host(
                progressPage
                    ? ServiceProgressPage(
                        repository: repository,
                        episodeId: 'episode',
                        onBack: () {},
                        onBook: (_) => booked = true,
                      )
                    : ServicePackagePage(
                        repository: repository,
                        packageId: 'feeding-confidence',
                        onBack: () {},
                        onBook: (_) {},
                        onProgress: (_) {},
                      ),
                scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  '../../goldens/design_system/service-${progressPage ? 'progress' : 'package'}-${width.toInt()}.png',
                ),
              );
            }
            if (progressPage) {
              await tester.scrollUntilVisible(find.text('预约咨询'), 240);
              await tester.pumpAndSettle();
              await tester.tap(find.text('预约咨询'));
              expect(booked, isTrue);
            } else {
              await tester.tap(find.text('购买'));
              await tester.pumpAndSettle();
              expect(find.text('购买前确认'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.tap(find.byTooltip('关闭购买'));
              await tester.pumpAndSettle();
              expect(find.text('购买前确认'), findsNothing);
            }
          },
        );
      }
      testWidgets('catalog owned and pending actions at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final pending in [false, true]) {
          final repo = _Repository(
            active: !pending,
            pending: pending,
            withProviders: true,
          );
          ServicePackage? selected;
          await tester.pumpWidget(
            _host(
              ServiceCatalogPage(
                key: ValueKey(pending),
                repository: repo,
                onSelect: (value) => selected = value,
                onBack: () {},
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          final action = find.text(pending ? '继续付款' : '查看我的服务');
          // Large text makes the service summary taller than one viewport.
          // Exercise the same scrolling path as a user before tapping it.
          for (
            var i = 0;
            i < 20 && action.hitTestable().evaluate().isEmpty;
            i++
          ) {
            await tester.drag(find.byType(ListView), const Offset(0, -240));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          await tester.tap(action);
          expect(selected?.id, 'feeding-confidence');
          if (!pending && scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/services-owned-${width.toInt()}.png',
              ),
            );
          }
          await tester.scrollUntilVisible(
            find.text('了解团队'),
            -250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('了解团队'));
          await tester.pumpAndSettle();
          expect(find.text('Test IBCLC'), findsOneWidget);
          expect(find.text('English · 中文'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (!pending && scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/service-team-populated-${width.toInt()}.png',
              ),
            );
          }
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
          expect(find.text('Test IBCLC'), findsNothing);
        }
      });
      testWidgets('service catalog at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        ServicePackage? selected;
        var back = false;
        await tester.pumpWidget(
          _host(
            ServiceCatalogPage(
              repository: repository,
              onSelect: (package) => selected = package,
              onBack: () => back = true,
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/services-${width.toInt()}.png',
            ),
          );
        }
        await tester.tap(find.text('了解团队'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('IBCLC 专家团队'), findsOneWidget);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/service-team-${width.toInt()}.png',
            ),
          );
        }

        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        final choose = find.text('查看方案 →').first;
        await tester.ensureVisible(choose);
        await tester.pumpAndSettle();
        await tester.tap(choose);
        expect(selected?.id, repository.data.packages.first.id);
        await tester.tap(find.text('返回'));
        expect(back, isTrue);
      });
      testWidgets('active expert support at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var booked = false;
        var progress = false;
        await tester.pumpWidget(
          _host(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: ExpertServiceCard(
                  episode: const CareEpisode(
                    id: 'episode',
                    orderId: 'order',
                    packageId: 'feeding-confidence',
                    status: CareEpisodeStatus.active,
                    stage: CareStage.preparation,
                    totalSessions: 2,
                    remainingSessions: 2,
                    version: 1,
                  ),
                  package: _Repository().data.packages.first,
                  onBook: () => booked = true,
                  onProgress: () => progress = true,
                ),
              ),
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/expert-support-${width.toInt()}.png',
            ),
          );
        }
        await tester.ensureVisible(find.text('服务进度 ›'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('服务进度 ›'));
        await tester.ensureVisible(find.text('预约咨询'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('预约咨询'));
        expect(progress && booked, isTrue);
      });
    }
  }
}

Widget _host(Widget child, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

class _Repository extends Fake implements CareRepository {
  _Repository({
    this.active = false,
    this.pending = false,
    this.withProviders = false,
  });
  final bool active, pending, withProviders;
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
  ServiceCatalog get data => ServiceCatalog(
    packages: _data.packages,
    providers: withProviders
        ? const [
            CareProvider(
              id: 'provider',
              displayName: 'Test IBCLC',
              timezone: 'America/Los_Angeles',
              regions: ['CA'],
              languages: ['English', '中文'],
              bio: '支持含乳调整与喂养节奏，结合连续记录提供跟进。',
              sandbox: true,
            ),
          ]
        : _data.providers,
    availableRegions: _data.availableRegions,
    paymentMode: _data.paymentMode,
  );
  @override
  Future<ServiceCatalog> catalog() async => data;
  @override
  Future<CareOverview> overview() async => active || pending
      ? CareOverview(
          orders: [
            CareOrder(
              id: 'order',
              packageId: 'feeding-confidence',
              status: pending ? CareOrderStatus.pending : CareOrderStatus.paid,
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
          episodes: pending
              ? const []
              : const [
                  CareEpisode(
                    id: 'episode',
                    orderId: 'order',
                    packageId: 'feeding-confidence',
                    status: CareEpisodeStatus.active,
                    stage: CareStage.preparation,
                    totalSessions: 2,
                    remainingSessions: 2,
                    version: 1,
                  ),
                ],
        )
      : const CareOverview(orders: [], episodes: []);
}

class _Appointments extends Fake implements AppointmentRepository {
  final value = readIntakeContext(
    Map<String, Object?>.from(
      jsonDecode(
            File(
              'test/fixtures/product_baseline/intake_context.json',
            ).readAsStringSync(),
          )
          as Map,
    ),
  ).appointment;
  @override
  Future<CareAppointment> read(String appointmentId) async => value;
}

class _HomeAppointments extends Fake implements AppointmentRepository {
  _HomeAppointments({this.pending});
  final Future<BookingContext>? pending;
  @override
  Future<BookingContext> context(String episodeId) async =>
      pending ??
      BookingContext(
        episode: (await _Repository(active: true).overview()).episodes.first,
        providers: const [],
        appointments: [_Appointments().value],
        serverTime: DateTime.utc(2026, 9, 8, 15, 30),
      );
}
