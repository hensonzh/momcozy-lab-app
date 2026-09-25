import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/services/consultations/consultation_media.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/room_outcome_scenarios.dart';
import 'room_test_support.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('unsuccessful room outcomes $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyRoomOutcomes(
          tester,
          fixture: roomFixture(),
          scale: scale,
          capture: (state) => expectLater(
            find.byType(ConsultationRoomPage),
            matchesGoldenFile(
              '../../goldens/product_baseline/room-$state-${width.toInt()}-${scale.toInt()}x.png',
            ),
          ),
        );
      });
    }
  }
  for (final (width, height, scale) in [
    (390.0, 844.0, 1.0),
    (320.0, 844.0, 2.0),
    (320.0, 568.0, 2.0),
  ]) {
    for (final outcome in [
      'completed',
      'safety_escalation',
      'cancelled',
      'pending-record',
      'technical_failure',
      'user_no_show',
    ]) {
      testWidgets('server outcome $outcome at $width x $height / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = TestRoomRepository()..ready();
        final media = TestConsultationMedia();
        final controller = testController(repository, media);
        await controller.load();
        await controller.enter();
        var summary = 0, rebook = 0, home = 0;
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
              onProgress: (appointment) {
                expect(appointment.id, repository.context.appointment.id);
                summary++;
              },
              onRebook: (appointment) {
                expect(appointment.id, repository.context.appointment.id);
                rebook++;
              },
              onHome: () => home++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        repository.room(status: 'note_pending', roomStatus: 'closed');
        (repository.json['consultation'] as Map)['end_reason'] =
            !['cancelled', 'pending-record'].contains(outcome) ? outcome : null;
        if (outcome == 'cancelled') {
          (repository.json['appointment'] as Map)['status'] = 'cancelled';
        }
        await controller.load();
        await tester.pumpAndSettle();
        expect(media.state, ConsultationMediaState.disconnected);
        final unsuccessful =
            outcome == 'technical_failure' || outcome == 'user_no_show';
        expect(
          find.text(
            outcome == 'technical_failure'
                ? 'Video connection could not continue'
                : outcome == 'user_no_show'
                ? 'This consultation could not start'
                : outcome == 'cancelled'
                ? 'Appointment canceled'
                : 'This consultation has ended',
          ),
          findsOneWidget,
        );
        expect(find.text('This appointment'), findsOneWidget);
        expect(
          find.text('Back to home'),
          unsuccessful ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('No consultation was used'),
          unsuccessful ? findsOneWidget : findsNothing,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/outcome-$outcome-${width.toInt()}-${height.toInt()}-${scale.toInt()}x.png',
          ),
        );
        Future<void> click(String label) async {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        if (unsuccessful) {
          expect(find.text('View consultation summary'), findsNothing);
          await click('Book another appointment');
          await click('Back to home');
          expect(rebook, 1);
          expect(summary, 0);
        } else {
          await click('View consultation summary');
          expect(summary, 1);
          if (outcome == 'completed') {
            expect(find.text('Book another appointment'), findsNothing);
          } else {
            await click('Book another appointment');
            expect(rebook, 1);
          }
        }
        await tester.ensureVisible(find.text('Test IBCLC'));
        await tester.pumpAndSettle();
        expect(find.text('Test IBCLC').hitTestable(), findsOneWidget);
        if (height == 568) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/outcome-$outcome-short-details.png',
            ),
          );
        }
        expect(home, unsuccessful ? 1 : 0);
        expect(repository.endCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
