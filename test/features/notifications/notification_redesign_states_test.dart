import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
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
  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    final suffix = '${size.$1.toInt()}-${size.$2.toInt()}x';
    Future<void> mount(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = Size(size.$1, 844);
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
            ).copyWith(textScaler: TextScaler.linear(size.$2)),
            child: child!,
          ),
          home: page,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> capture(WidgetTester tester, String name) async {
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/ui_refactor/notifications-$name-$suffix.png',
        ),
      );
    }

    Future<void> reveal(
      WidgetTester tester,
      Finder target, {
      double delta = 240,
    }) async {
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          delta,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
      }
      await tester.ensureVisible(target);
    }

    Future<void> tap(
      WidgetTester tester,
      Finder target, {
      bool pending = false,
      double delta = 240,
    }) async {
      await reveal(tester, target, delta: delta);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(target);
      if (pending) {
        await tester.pump(const Duration(milliseconds: 500));
      } else {
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    }

    testWidgets('notification initial loading retry and read-all $suffix', (
      tester,
    ) async {
      final repository = _Inbox()..readGate = Completer<void>();
      final controller = NotificationsController(repository: repository);
      addTearDown(controller.dispose);
      final opened = <String>[];
      await mount(
        tester,
        NotificationsPage(
          repository: repository,
          controller: controller,
          onBack: () {},
          onSettings: () {},
          onOpen: (id) async {
            opened.add(id);
            await controller.markRead(id);
          },
          now: () => DateTime.utc(2026, 9, 12, 2),
        ),
      );
      expect(find.text('All caught up'), findsNothing);
      await capture(tester, 'loading');
      repository.failRead = true;
      repository.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsNothing);
      await capture(tester, 'initial-error');
      repository.failRead = false;
      await tap(tester, find.text('Retry'));
      await capture(tester, 'long-inbox');
      await tap(tester, find.text(repository.item('one').title));
      expect(opened, ['one']);
      repository.allReadGate = Completer<void>();
      await tap(tester, find.text('Mark all read'), pending: true, delta: -240);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Mark all read'),
            )
            .onPressed,
        isNull,
      );
      await capture(tester, 'read-all-pending');
      repository.allReadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('All caught up'), findsOneWidget);
      await capture(tester, 'all-read');
    });

    testWidgets(
      'notification pagination and archive failures retain content $suffix',
      (tester) async {
        final repository = _Inbox();
        final controller = NotificationsController(repository: repository);
        addTearDown(controller.dispose);
        await mount(
          tester,
          NotificationsPage(
            repository: repository,
            controller: controller,
            onBack: () {},
            now: () => DateTime.utc(2026, 9, 12, 2),
          ),
        );
        await tester.pumpAndSettle();
        repository.readGate = Completer<void>();
        await tap(tester, find.text('Load more'), pending: true);
        expect(controller.state.loadingMore, isTrue);
        await capture(tester, 'pagination-pending');
        repository.failRead = true;
        repository.readGate!.complete();
        await tester.pumpAndSettle();
        expect(controller.state.notifications.map((n) => n.id), ['one']);
        await reveal(
          tester,
          find.text('Previously loaded updates remain visible.'),
          delta: -240,
        );
        await tester.pumpAndSettle();
        await capture(tester, 'pagination-error');
        repository.failRead = false;
        await tap(tester, find.text('Load more'));
        expect(controller.state.notifications.map((n) => n.id), ['one', 'two']);
        repository.archiveGate = Completer<void>();
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-one')),
          pending: true,
          delta: -240,
        );
        expect(controller.state.busyIds, {'one'});
        await capture(tester, 'archive-pending');
        repository.failArchive = true;
        repository.archiveGate!.complete();
        await tester.pumpAndSettle();
        expect(controller.state.notifications.map((n) => n.id), ['one', 'two']);
        await reveal(
          tester,
          find.text('Previously loaded updates remain visible.'),
          delta: -240,
        );
        await tester.pumpAndSettle();
        await capture(tester, 'archive-error');
        repository.failArchive = false;
        await tap(
          tester,
          find.byKey(const ValueKey('notification-archive-one')),
        );
        expect(controller.state.notifications.map((n) => n.id), ['two']);
      },
    );

    Future<NotificationCoordinator> coordinator(
      FakePlatform platform,
      _Preferences repository,
    ) async {
      final c = NotificationCoordinator(
        permission: NotificationPermissionController(platform),
        gateway: FakeGateway(),
        store: FakeStore(),
        platformName: 'ios',
        onNavigate: (_) {},
        onMessage: (_) {},
        onForeground: (_) {},
      );
      addTearDown(c.dispose);
      await c.setAccount(
        key: 'account',
        inboxRepository: repository,
        deliveryRepository: repository,
      );
      return c;
    }

    bool toggleValue(WidgetTester tester, String category) {
      final f = find.byKey(ValueKey('notification-preference-$category'));
      return size.$2 == 2
          ? tester.widget<Switch>(f).value
          : tester.widget<SwitchListTile>(f).value;
    }

    bool toggleEnabled(WidgetTester tester, String category) {
      final f = find.byKey(ValueKey('notification-preference-$category'));
      return size.$2 == 2
          ? tester.widget<Switch>(f).onChanged != null
          : tester.widget<SwitchListTile>(f).onChanged != null;
    }

    testWidgets('notification permission denial and restoration $suffix', (
      tester,
    ) async {
      final platform = FakePlatform()..value = NotificationPermission.denied;
      final repository = _Preferences();
      final c = await coordinator(platform, repository);
      await mount(tester, NotificationSettingsPage(coordinator: c));
      await tester.pumpAndSettle();
      await capture(tester, 'settings-denied');
      final toggle = find.byKey(
        const ValueKey('notification-preference-consultations'),
      );
      await tap(tester, toggle, pending: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Notifications are off'), findsOneWidget);
      await capture(tester, 'settings-offer');
      await tap(tester, find.text('Not now'));
      expect(platform.requests, 0);
      expect(repository.writes, isEmpty);
      platform.value = NotificationPermission.authorized;
      await tap(tester, find.text('Refresh status'));
      await tester.ensureVisible(find.text('Allowed'));
      await tester.pumpAndSettle();
      await capture(tester, 'settings-restored');
      await tap(tester, toggle);
      expect(repository.writes, ['consultations:true']);
      expect(toggleValue(tester, 'consultations'), isTrue);
      await tester.ensureVisible(find.text('Refresh status'));
      await tester.pumpAndSettle();
      await capture(tester, 'settings-bottom');
    });

    testWidgets(
      'notification preference loading error and unavailable device $suffix',
      (tester) async {
        final platform = FakePlatform()
          ..value = NotificationPermission.authorized;
        final repository = _Preferences();
        final c = await coordinator(platform, repository);
        repository.gate = Completer<void>();
        await mount(tester, NotificationSettingsPage(coordinator: c));
        expect(toggleEnabled(tester, 'appointments'), isFalse);
        await capture(tester, 'preferences-loading');
        repository.fail = true;
        repository.gate!.complete();
        await tester.pumpAndSettle();
        expect(
          find.text('Could not load your preferences. Please try again.'),
          findsOneWidget,
        );
        await capture(tester, 'preferences-error');
        repository.fail = false;
        await tap(tester, find.text('Refresh status'));
        expect(toggleEnabled(tester, 'appointments'), isTrue);
        platform.value = NotificationPermission.unavailable;
        await tap(tester, find.text('Refresh status'));
        await tester.ensureVisible(find.text('Unavailable on this device'));
        await tester.pumpAndSettle();
        await capture(tester, 'platform-unavailable');
        await mount(
          tester,
          const NotificationSettingsPage(
            coordinator: null,
            key: ValueKey('unavailable'),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'no-coordinator');
      },
    );
  }
}

class _Inbox extends FakeRepository {
  Completer<void>? readGate, archiveGate, allReadGate;
  bool failRead = false, failArchive = false, allRead = false;
  final read = <String>{}, archived = <String>{};
  MomCozyNotification item(String id) => MomCozyNotification(
    id: id,
    type: 'appointment_created',
    title: id == 'one'
        ? 'Your appointment has been confirmed'
        : 'Your expert has shared an update',
    body:
        'Your IBCLC expert is ready to meet with you. Review the appointment details and prepare any questions you would like to discuss.',
    status: allRead || read.contains(id) ? 'read' : 'unread',
    source: 'care',
    payload: const {},
    createdAt: DateTime.utc(2026, 9, 12, 1, 30),
  );
  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async {
    await readGate?.future;
    readGate = null;
    if (failRead) throw StateError('fixture read failure');
    return NotificationPageData(
      items: [
        for (final id in cursor == null ? ['one'] : ['one', 'two'])
          if (!archived.contains(id)) item(id),
      ],
      unreadCount: allRead ? 0 : 2 - {...read, ...archived}.length,
      nextCursor: cursor == null ? 'next' : null,
    );
  }

  @override
  Future<MomCozyNotification> setReadState({
    required String notificationId,
    required bool read,
  }) async {
    this.read.add(notificationId);
    return item(notificationId);
  }

  @override
  Future<void> markAllRead() async {
    await allReadGate?.future;
    allReadGate = null;
    allRead = true;
  }

  @override
  Future<void> archive({required String notificationId}) async {
    await archiveGate?.future;
    archiveGate = null;
    if (failArchive) throw StateError('fixture archive failure');
    archived.add(notificationId);
  }
}

class _Preferences extends FakeRepository {
  Completer<void>? gate;
  bool fail = false;
  final values = {
    'appointments': true,
    'consultations': false,
    'expert_feedback': false,
    'service_updates': false,
  };
  final writes = <String>[];
  @override
  Future<Map<String, bool>> preferences() async {
    await gate?.future;
    gate = null;
    if (fail) throw StateError('fixture preferences failure');
    return Map.of(values);
  }

  @override
  Future<Map<String, bool>> setPreference(
    String category, {
    required bool enabled,
    String? installationId,
  }) async {
    writes.add('$category:$enabled');
    values[category] = enabled;
    return Map.of(values);
  }
}
