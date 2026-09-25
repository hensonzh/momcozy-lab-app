import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_scope.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_concerns.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import '../../support/notification_fakes.dart';
import 'me_experience_test.dart' show TestMeRepository, controller;

class PendingPermission extends FakePlatform {
  final gate = Completer<NotificationPermission>();
  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    return value = await gate.future;
  }
}

void main() {
  for (final outcome in [
    NotificationPermission.authorized,
    NotificationPermission.denied,
  ]) {
    testWidgets(
      'confirmation stays until native permission resolves $outcome',
      (tester) async {
        final platform = PendingPermission();
        final repo = TestMeRepository();
        final c = controller(repo);
        final coordinator = NotificationCoordinator(
          permission: NotificationPermissionController(platform),
          gateway: FakeGateway(),
          store: FakeStore(),
          platformName: 'android',
          onNavigate: (_) {},
          onMessage: (_) {},
          onForeground: (_) {},
        );
        addTearDown(coordinator.dispose);
        addTearDown(c.dispose);
        tester.view.physicalSize = const Size(393, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          NotificationScope(
            coordinator: coordinator,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showMeConcernFlow(
                      context,
                      c,
                      initial: const MeConcern(
                        id: 'test',
                        issues: [MeIssue.comfort],
                      ),
                    ),
                    child: const Text('首页'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('首页'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(repo.saves, 1);
        expect(platform.requests, 1);
        expect(find.text('Choose what you\'d like to work on'), findsOneWidget);
        expect(find.text('开启通知提醒'), findsNothing);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(repo.saves, 1);
        platform.gate.complete(outcome);
        await tester.pumpAndSettle();
        expect(find.text('首页'), findsOneWidget);
        expect(find.text('Choose what you\'d like to work on'), findsNothing);
        expect(c.state!.concerns.length, 1);
      },
    );
  }
  testWidgets('already denied uses bottom settings sheet, skip returns home', (
    tester,
  ) async {
    final platform = FakePlatform()..value = NotificationPermission.denied;
    final c = controller(TestMeRepository());
    final coordinator = NotificationCoordinator(
      permission: NotificationPermissionController(platform),
      gateway: FakeGateway(),
      store: FakeStore(),
      platformName: 'android',
      onNavigate: (_) {},
      onMessage: (_) {},
      onForeground: (_) {},
    );
    addTearDown(coordinator.dispose);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      NotificationScope(
        coordinator: coordinator,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMeConcernFlow(
                  context,
                  c,
                  initial: const MeConcern(
                    id: 'test',
                    issues: [MeIssue.comfort],
                  ),
                ),
                child: const Text('首页'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(platform.requests, 0);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(platform.settings, 0);
  });
}
