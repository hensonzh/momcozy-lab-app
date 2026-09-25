import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_page.dart';

import '../../support/momcozy_test_fonts.dart';
import '../../support/notification_fakes.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  MomCozyNotification notification({
    String type = 'appointment_created',
    String title = '预约已确认',
    String body = 'Cozymate 提醒您查看预约。',
  }) => MomCozyNotification(
    id: 'legacy-1',
    type: type,
    title: title,
    body: body,
    status: 'unread',
    source: 'care',
    payload: const {'appointment_id': 'appointment-1'},
  );

  test(
    'known legacy notification uses English template without rewriting stored data',
    () {
      final item = notification();
      expect(item.displayTitle, 'Appointment confirmed');
      expect(
        item.displayBody,
        'Your appointment is confirmed. Open the details to prepare.',
      );
      expect(item.title, '预约已确认');
      expect(item.body, 'Cozymate 提醒您查看预约。');
      expect(item.payload['appointment_id'], 'appointment-1');
    },
  );

  test(
    'clean English content is preserved; unknown legacy type gets a neutral fallback',
    () {
      final english = notification(
        title: 'A personal update',
        body: 'Review your appointment details.',
      );
      expect(english.displayTitle, english.title);
      expect(english.displayBody, english.body);

      final unknown = notification(
        type: 'future_event',
        title: '新消息',
        body: '查看 Cozy Mate 的最新内容',
      );
      expect(unknown.displayTitle, 'Momcozy AI update');
      expect(unknown.displayBody, 'Open the app to view the latest details.');
    },
  );

  test(
    'notification templates cover old non-English payloads without rewriting them',
    () {
      final item = notification(
        type: 'consultation_started',
        title: '상담이 시작되었습니다',
        body: 'Пожалуйста, присоединитесь к звонку.',
      );
      expect(item.displayTitle, 'Your consultation has started');
      expect(item.displayBody, 'Open your consultation to join.');
      expect(item.title, '상담이 시작되었습니다');
      expect(item.body, 'Пожалуйста, присоединитесь к звонку.');
      expect(item.id, 'legacy-1');
    },
  );

  testWidgets('unknown legacy update stays legible at 320 px with 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _LegacyInbox(
      notification(
        type: 'future_event',
        title: 'CozyMate 通知',
        body: '请查看新的服务信息',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: NotificationsPage(repository: repository, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Momcozy AI update');
    final body = find.text('Open the app to view the latest details.');
    expect(title, findsOneWidget);
    expect(body, findsOneWidget);
    await tester.ensureVisible(body);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(title).right, lessThanOrEqualTo(320));
    expect(tester.getRect(body).right, lessThanOrEqualTo(320));
    expect(find.textContaining('CozyMate'), findsNothing);
    expect(find.textContaining('请查看'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/notification-legacy-320-2x.png',
      ),
    );
  });

  testWidgets(
    'legacy server copy stays off the inbox but opening uses the original id',
    (tester) async {
      final repository = _LegacyInbox(notification());
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsPage(
            repository: repository,
            onBack: () {},
            onOpen: (id) async => opened.add(id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('预约已确认'), findsNothing);
      expect(find.textContaining('Cozymate'), findsNothing);
      expect(find.text('Appointment confirmed'), findsOneWidget);
      expect(
        find.text(
          'Your appointment is confirmed. Open the details to prepare.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('notification-item-legacy-1')),
      );
      await tester.pumpAndSettle();
      expect(opened, ['legacy-1']);
    },
  );
}

class _LegacyInbox extends FakeRepository {
  _LegacyInbox(this.item);
  final MomCozyNotification item;

  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async => NotificationPageData(items: [item], unreadCount: 1);
}
