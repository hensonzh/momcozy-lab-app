import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/services/consultations/consultation_media.dart';
import 'package:momcozy_flutter_app/services/consultations/room_api_repository.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

void main() {
  test(
    'room API uses scoped route, stable join key and own connection for leave',
    () async {
      final transport = FixtureApiJsonTransport(roomFixture());
      final repository = ConsultationRoomApiRepository(transport: transport);
      final context = await repository.load('appointment');
      expect(context.videoConsent, isFalse);
      await repository.presence(
        'appointment',
        connectionId: 'current-connection',
        presence: ParticipantPresence.left,
      );
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastBody, {
        'connection_id': 'current-connection',
        'presence': 'left',
      });
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final joined in [false, true]) {
        testWidgets(
          '${joined ? 'waiting room' : 'consultation preparation'} at $width / $scale',
          (tester) async {
            await loadMomCozyTestFonts();
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final repository = TestRoomRepository();
            final media = TestConsultationMedia();
            final controller = testController(repository, media);
            if (joined) {
              repository.ready();
              await controller.load();
              await controller.enter();
            }
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
                  onBack: () {},
                  onIntake: () async {},
                  onProgress: (_) {},
                  onRebook: (_) {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await expectLater(
                find.byType(ConsultationRoomPage),
                matchesGoldenFile(
                  '../../goldens/product_baseline/${joined ? 'room-waiting' : 'room-preparation'}-${width.toInt()}.png',
                ),
              );
            }
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -650),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  testWidgets(
    'leaving a room asks for confirmation and keeps the consultation open',
    (tester) async {
      final repository = TestRoomRepository()..ready();
      final media = TestConsultationMedia();
      final controller = testController(repository, media);
      await controller.load();
      await controller.enter();
      var exited = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: ConsultationRoomPage(
            createController: () => controller,
            onBack: () => exited = true,
            onIntake: () async {},
            onProgress: (_) {},
            onRebook: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leave room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave room'));
      await tester.pumpAndSettle();
      expect(find.text('Leave the consultation room for now?'), findsOneWidget);
      expect(media.state, ConsultationMediaState.connected);
      await tester.tap(find.text('Leave for now'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
      expect(media.state, ConsultationMediaState.disconnected);
      expect(repository.endCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'room survives parent rebuild and supports text at 2x on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = TestRoomRepository()..ready();
      final media = TestConsultationMedia();
      final controller = testController(repository, media);
      await controller.load();
      await controller.enter();
      var created = 0;
      Widget app() => MaterialApp(
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ConsultationRoomPage(
          key: const ValueKey('room'),
          createController: () {
            created++;
            return controller;
          },
          onBack: () {},
          onIntake: () async {},
          onProgress: (_) {},
          onRebook: (_) {},
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leave room'));
      expect(created, 1);
      expect(media.connectCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
