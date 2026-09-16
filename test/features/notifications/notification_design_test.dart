import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_settings_page.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/notification_fakes.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      Future<void> mount(WidgetTester tester, Widget page) async {
        tester.view.physicalSize = Size(width, 844);
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
            home: page,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(WidgetTester tester, String name) async {
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/notifications-$name-${width.toInt()}.png',
            ),
          );
        }
      }

      Future<void> tap(WidgetTester tester, Finder target) async {
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }

      testWidgets('inbox and retained-content error at $width / $scale', (
        tester,
      ) async {
        final repository = _Inbox();
        final controller = NotificationsController(repository: repository);
        addTearDown(controller.dispose);
        var back = 0, settings = 0;
        await mount(
          tester,
          NotificationsPage(
            repository: repository,
            controller: controller,
            onBack: () => back++,
            onSettings: () => settings++,
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
        await capture(tester, 'inbox');
        repository.fail = true;
        await controller.load();
        await tester.pumpAndSettle();
        await capture(tester, 'error');
        repository.fail = false;
        await tap(tester, find.text('Retry'));
        await tap(tester, find.text('Your appointment has been confirmed'));
        expect(controller.state.unreadCount, 0);
        await capture(tester, 'read');
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-one')),
        );
        expect(repository.archived, isTrue);
        await capture(tester, 'empty');
        await tap(tester, find.byTooltip('Notification settings'));
        expect(settings, 1);
        await tap(tester, find.byKey(const ValueKey('notifications-back')));
        expect(back, 1);
      });
      testWidgets('notification settings and consent at $width / $scale', (
        tester,
      ) async {
        final repository = FakeRepository();
        final platform = FakePlatform();
        final coordinator = NotificationCoordinator(
          permission: NotificationPermissionController(platform),
          gateway: FakeGateway(),
          store: FakeStore(),
          platformName: 'ios',
          onNavigate: (_) {},
          onMessage: (_) {},
          onForeground: (_) {},
        );
        addTearDown(coordinator.dispose);
        await coordinator.setAccount(
          key: 'account',
          inboxRepository: repository,
          deliveryRepository: repository,
        );
        await mount(tester, NotificationSettingsPage(coordinator: coordinator));
        await capture(tester, 'settings');
        final consultations = find.widgetWithText(
          SwitchListTile,
          'Consultations',
        );
        await tester.scrollUntilVisible(consultations, 200);
        await tap(
          tester,
          find.descendant(of: consultations, matching: find.byType(Switch)),
        );
        expect(platform.requests, 0);
        await capture(tester, 'consent');
        await tap(tester, find.text('Not now'));
        expect(platform.requests, 0);
        await tester.scrollUntilVisible(find.text('Refresh status'), 250);
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
        await tap(tester, find.text('Refresh status'));
        expect(platform.requests, 0);
      });
    }
  }
}

class _Inbox extends FakeRepository {
  bool fail = false, archived = false, read = false;
  MomCozyNotification get item => MomCozyNotification(
    id: 'one',
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
  }) async {
    if (fail) throw StateError('offline');
    return NotificationPageData(
      items: archived ? [] : [item],
      unreadCount: read || archived ? 0 : 1,
    );
  }

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
