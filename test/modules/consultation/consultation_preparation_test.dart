import 'dart:async';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/consultation_preparation.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

class _RefreshRooms extends TestRoomRepository {
  bool offline = false;
  @override
  Future<ConsultationRoomContext> load(String id) async {
    if (offline) throw const ProductFailure(ProductFailureKind.offline);
    return context;
  }
}

Future<void> mount(
  WidgetTester tester,
  TestRoomRepository repository, {
  double width = 390,
  double scale = 1,
  double height = 844,
  Future<void> Function()? onCancel,
  VoidCallback? onIntake,
  VoidCallback? onRebook,
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
      home: ConsultationRoomPage(
        createController: () =>
            testController(repository, TestConsultationMedia()),
        createDeviceCheck: TestReadyDeviceCheck.new,
        onBack: () {},
        onIntake: () async => onIntake?.call(),
        onRebook: (_) => onRebook?.call(),
        onProgress: (_) {},
        onCancel: (_) async => onCancel?.call(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'countdown opens entry at the authoritative window without entering automatically',
    (tester) async {
      final repository = TestRoomRepository();
      final data = repository.context;
      var now = data.opensAt.subtract(const Duration(seconds: 1));
      var enters = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: Scaffold(
            body: ConsultationPreparation(
              data: data,
              now: () => now,
              busy: false,
              onStart: () {
                enters++;
              },
              onIntake: () {},
              onRebook: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('00:10:01'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start consultation'),
            )
            .onPressed,
        isNull,
      );
      now = data.opensAt;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:10:00'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start consultation'),
            )
            .onPressed,
        isNotNull,
      );
      expect(enters, 0);
      now = data.closesAt;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Join window has closed'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start consultation'),
            )
            .onPressed,
        isNull,
      );
      expect(enters, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('preparation time and requirements $width / $scale', (
        tester,
      ) async {
        for (final state in [
          'ready',
          'early',
          'expired',
          'intake',
          'case-consent',
          'disabled',
          'demo',
        ]) {
          final repository = TestRoomRepository();
          repository.json['video_provider'] = 'livekit';
          if (state == 'early' || state == 'demo') {
            repository.json['server_time'] = '2026-09-06T15:55:00Z';
          }
          if (state == 'demo') repository.json['demo_early_join'] = true;
          if (state == 'expired') {
            repository.json['server_time'] = '2026-09-08T17:16:00Z';
          }
          if (state == 'intake') repository.json['intake_ready'] = false;
          if (state == 'case-consent') repository.json['case_consent'] = false;
          if (state == 'disabled') {
            repository.json['video_provider'] = 'disabled';
          }
          var intake = 0, rebook = 0, cancel = 0;
          await mount(
            tester,
            repository,
            width: width,
            scale: scale,
            onCancel: () async {
              cancel++;
            },
            onIntake: () {
              intake++;
            },
            onRebook: () {
              rebook++;
            },
          );
          expect(find.text('Appointment details'), findsOneWidget);
          expect(find.text('Test IBCLC'), findsOneWidget);
          expect(
            tester
                    .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Start consultation'),
                    )
                    .onPressed !=
                null,
            state == 'ready' || state == 'demo',
          );
          if (state == 'early') {
            expect(find.text('2 days 00:05'), findsOneWidget);
          }
          if (state == 'ready') expect(find.text('00:05:00'), findsOneWidget);
          if (state == 'demo') {
            expect(find.text('You can join early'), findsOneWidget);
          }
          await tester.pump(const Duration(milliseconds: 300));
          if (scale == 1 || width == 320) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/preparation-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
              ),
            );
          }
          if (scale == 2 && width == 320) {
            await tester.ensureVisible(find.text('Cancel appointment'));
            await tester.pumpAndSettle();
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/preparation-$state-actions-320-2x.png',
              ),
            );
          }
          if (state == 'intake' || state == 'case-consent') {
            await click(tester, 'View intake form');
            expect(intake, 1);
          }
          if (state == 'expired') {
            await click(tester, 'Book another appointment');
            expect(rebook, 1);
          }
          await click(tester, 'Cancel appointment');
          expect(cancel, 1);
          expect(repository.keys, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }

  testWidgets(
    'preparation refresh error preserves context and recovers without joining',
    (tester) async {
      final repository = _RefreshRooms();
      await mount(tester, repository, width: 320, scale: 2);
      repository.offline = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Refresh consultation status'), findsOneWidget);
      expect(find.text('Test IBCLC'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/preparation-refresh-error-320-2x.png',
        ),
      );
      repository.offline = false;
      await click(tester, 'Refresh consultation status');
      expect(find.text('Refresh consultation status'), findsNothing);
      expect(repository.keys, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'active consultation preparation offers reentry without cancellation or automatic join',
    (tester) async {
      final repository = TestRoomRepository()..room(status: 'in_progress');
      await mount(tester, repository);
      expect(find.text('Rejoin consultation room'), findsOneWidget);
      expect(find.text('Cancel appointment'), findsNothing);
      expect(repository.keys, isEmpty);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/preparation-rejoin-390.png',
        ),
      );
      await click(tester, 'Rejoin consultation room');
      expect(find.text('Camera and microphone are ready'), findsOneWidget);
      expect(repository.keys, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cancel in flight locks other actions and reloads afterwards', (
    tester,
  ) async {
    final repository = TestRoomRepository();
    final pending = Completer<void>();
    var calls = 0;
    await mount(
      tester,
      repository,
      width: 320,
      height: 568,
      scale: 2,
      onCancel: () {
        calls++;
        return pending.future;
      },
    );
    await click(tester, 'Cancel appointment');
    expect(calls, 1);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Cancel appointment'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Please wait…'),
          )
          .onPressed,
      isNull,
    );
    repository.json['intake_ready'] = false;
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('View intake form'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start consultation'),
          )
          .onPressed,
      isNull,
    );
    expect(repository.keys, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
