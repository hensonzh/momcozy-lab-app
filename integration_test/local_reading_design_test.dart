import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_page.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_settings_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../test/support/fixture_api_transport.dart';
import '../test/support/notification_fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'Android account and inbox reading at both text scales',
    (tester) async {
      var converted = false;
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pump();
        }
        final bytes = await binding.takeScreenshot(name);
        final directory = await getApplicationDocumentsDirectory();
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
      }

      for (final scale in [1.0, 2.0]) {
        Future<void> mount(Widget page) async {
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
              home: page,
            ),
          );
          await tester.pumpAndSettle();
        }

        final repository = _ReadingInbox();
        var backs = 0;
        await mount(
          NotificationsPage(
            repository: repository,
            onBack: () => backs++,
            now: () => DateTime.utc(2026, 9, 12, 2),
          ),
        );
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(repository.item.body))
              .text
              .style!
              .height,
          1.55,
        );
        await capture('native-reading-inbox-${scale.toInt()}x');
        await tester.tap(find.text(repository.item.title));
        await tester.pumpAndSettle();
        expect(repository.read, isTrue);
        await tester.ensureVisible(
          find.byKey(const ValueKey('notification-archive-reading')),
        );
        await tester.tap(
          find.byKey(const ValueKey('notification-archive-reading')),
        );
        await tester.pumpAndSettle();
        expect(repository.archived, isTrue);
        await tester.tap(find.byKey(const ValueKey('notifications-back')));
        expect(backs, 1);

        final platform = FakePlatform();
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
        await coordinator.setAccount(
          key: 'reading',
          inboxRepository: repository,
          deliveryRepository: repository,
        );
        await mount(NotificationSettingsPage(coordinator: coordinator));
        await tester.scrollUntilVisible(find.text('Refresh status'), 250);
        await tester.pumpAndSettle();
        for (final copy in [
          'Not enabled. Service preferences do not opt you into marketing.',
          'Only future reminders you previously enabled can resume when permission is restored. Past reminders are not sent later.',
        ]) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(copy))
                .text
                .style!
                .height,
            1.55,
          );
        }
        await capture('native-reading-settings-${scale.toInt()}x');
        await tester.tap(find.text('Refresh status'));
        await tester.pumpAndSettle();
        expect(platform.requests, 0);

        final transport = FixtureApiJsonTransport({
          'email': 'mia.long-account@example.com',
          'email_verified': true,
          'account_status': 'active',
          'auth_providers': ['email'],
        });
        final runtime = MomCozyRuntimeController(
          MomCozyApiRuntime(jsonTransport: transport),
        );
        addTearDown(runtime.dispose);
        await mount(
          MomCozyAccountPage(
            runtimeController: runtime,
            sessionStore: MemoryMomCozySessionStore(),
          ),
        );
        await capture('native-reading-account-${scale.toInt()}x');
        final deletion = find.byKey(const ValueKey('account-delete'));
        await tester.scrollUntilVisible(deletion, 250);
        await tester.pumpAndSettle();
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.textContaining('Your access will end immediately.'),
              )
              .text
              .style!
              .height,
          1.55,
        );
        await capture('native-reading-account-explanation-${scale.toInt()}x');
        await tester.tap(deletion);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(transport.mutationPaths, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _ReadingInbox extends FakeRepository {
  bool read = false, archived = false;
  MomCozyNotification get item => MomCozyNotification(
    id: 'reading',
    createdAt: DateTime.utc(2026, 9, 12, 1, 30),
    type: 'appointment_created',
    title: 'Your appointment has been confirmed',
    body:
        'Your IBCLC expert is ready to meet with you. Review the appointment details and prepare any questions you would like to discuss.',
    status: read ? 'read' : 'unread',
    source: 'care',
    payload: const {},
  );
  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async => NotificationPageData(
    items: archived ? [] : [item],
    unreadCount: read || archived ? 0 : 1,
  );
  @override
  Future<MomCozyNotification> setReadState({
    required String notificationId,
    required bool read,
  }) async {
    this.read = read;
    return item;
  }

  @override
  Future<void> archive({required String notificationId}) async {
    archived = true;
  }
}
