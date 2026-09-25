import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/room_leave_recovery_scenarios.dart';
import 'room_test_support.dart';

class _PendingDisconnectMedia extends TestConsultationMedia {
  final pending = Completer<void>();
  @override
  Future<void> disconnect() => pending.future;
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('inventory leave pending then returns', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = TestRoomRepository()..ready();
    final media = _PendingDisconnectMedia();
    final controller = testController(repository, media);
    await controller.load();
    await controller.enter();
    var returned = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
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
    await tester.ensureVisible(find.text('Leave room'));
    await tester.tap(find.text('Leave room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave for now'));
    await tester.pumpAndSettle();
    expect(controller.busy, isTrue);
    expect(returned, 0);
    expect(find.text('Leave the consultation room for now?'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/room-leave-pending-390.png',
      ),
    );
    media.pending.complete();
    await tester.pumpAndSettle();
    expect(returned, 1);
    expect(controller.busy, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'late disconnect failure cannot restore a disposed connection',
    () async {
      final repository = TestRoomRepository()..ready();
      final media = _PendingDisconnectMedia();
      final controller = testController(repository, media);
      await controller.load();
      await controller.enter();
      final leave = controller.leave();
      final result = expectLater(leave, throwsStateError);
      controller.dispose();
      media.pending.completeError(
        StateError('disconnect failed after disposal'),
      );
      await result;
      expect(controller.inRoom, isFalse);
      expect(repository.endCalls, 0);
    },
  );
  test(
    'disconnect failure preserves connection for retry and leave report',
    () async {
      final repository = TestRoomRepository()..ready();
      final controller = testController(repository, RetryDisconnectMedia());
      addTearDown(controller.dispose);
      await controller.load();
      await controller.enter();
      await expectLater(controller.leave(), throwsStateError);
      expect(controller.inRoom, isTrue);
      expect(controller.busy, isFalse);
      await controller.leave();
      expect(controller.inRoom, isFalse);
      expect(repository.endCalls, 0);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('leave recovery $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyRoomLeaveRecovery(
          tester,
          fixture: roomFixture(),
          scale: scale,
          capture: (state) => expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/product_baseline/room-leave-$state-${width.toInt()}-${scale.toInt()}x.png',
            ),
          ),
        );
      });
    }
  }
}
