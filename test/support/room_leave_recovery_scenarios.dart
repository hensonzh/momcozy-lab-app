import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/services/consultations/consultation_media.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../modules/consultation/room_test_support.dart';

const leaveFailureCopy =
    'Could not leave the consultation room. Tap Leave Room again to try.';

class RetryDisconnectMedia extends TestConsultationMedia {
  @override
  bool get sandbox => false;
  int attempts = 0;
  @override
  Future<void> disconnect() async {
    if (++attempts == 1) throw StateError('private-media-disconnect-error');
    await super.disconnect();
  }
}

Future<void> verifyRoomLeaveRecovery(
  WidgetTester tester, {
  required Map<String, Object?> fixture,
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final repository = TestRoomRepository(fixture: fixture)..ready();
  final media = RetryDisconnectMedia();
  final controller = testController(repository, media);
  await controller.load();
  await controller.enter();
  var returned = 0;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: ConsultationRoomPage(
        createController: () => controller,
        onBack: () => returned++,
        onIntake: () async {},
        onProgress: (_) {},
        onRebook: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  Future<void> click(String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  await click('Leave room');
  await click('Leave for now');
  expect(tester.takeException(), isNull);
  expect(returned, 0);
  expect(controller.inRoom, isTrue);
  expect(controller.busy, isFalse);
  expect(media.state, ConsultationMediaState.connected);
  expect(repository.sentPresence, isNot(contains(ParticipantPresence.left)));
  await controller.load();
  await tester.pumpAndSettle();
  expect(find.text(leaveFailureCopy), findsOneWidget);
  expect(find.textContaining('private-media'), findsNothing);
  expect(
    tester.getRect(find.text(leaveFailureCopy)).top,
    greaterThanOrEqualTo(0),
  );
  expect(find.text(leaveFailureCopy).hitTestable(), findsOneWidget);
  await tester.ensureVisible(find.text(leaveFailureCopy));
  await tester.pumpAndSettle();
  await capture('failure');
  await click('Leave room');
  await capture('retry-confirmation');
  await click('Leave for now');
  expect(returned, 1);
  expect(media.attempts, 2);
  expect(controller.inRoom, isFalse);
  expect(media.state, ConsultationMediaState.disconnected);
  expect(
    repository.sentPresence.where((p) => p == ParticipantPresence.left),
    hasLength(1),
  );
  expect(repository.endCalls, 0);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
