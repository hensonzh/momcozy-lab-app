import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/me_home_route.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';

import '../support/baby_inventory_transport.dart';

class _FirstFeedingTransport extends BabyInventoryTransport {
  _FirstFeedingTransport(this.deliveryDate) {
    profiles.clear();
  }

  final String? deliveryDate;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/profile/me-experience') {
      return {
        'profile': {
          'preferred_name': 'Mia',
          'actual_delivery_date': deliveryDate,
        },
      };
    }
    if (path == '/v1/profile/me') return {'preferred_name': 'Mia'};
    if (path == '/v1/profile/lactation') {
      return {
        'actual_delivery_date': deliveryDate,
        'current_delivery_method': 'unknown',
      };
    }
    if (path == '/v1/lactation/records') return {'items': []};
    return super.getJson(path, query: query);
  }
}

void main() {
  Future<void> openFirstFeeding(
    WidgetTester tester,
    _FirstFeedingTransport transport,
  ) async {
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'me-first-feeding',
      babyId: 'missing-baby',
      timezoneProvider: () async => 'Asia/Shanghai',
      now: () => DateTime.utc(2026, 9, 13, 8),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MeHomeRoute(runtime: runtime)),
      ),
    );
    await tester.pumpAndSettle();
    final feeding = find.byWidgetPredicate(
      (widget) => widget is MeHomeMetric && widget.kind == MeMetric.feed,
    );
    await tester.ensureVisible(feeding);
    await tester.tap(feeding);
    await tester.pumpAndSettle();
    expect(find.text('Add a baby'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'babe wang');
    await tester.tap(find.text('Girl'));
    await tester.pumpAndSettle();
  }

  testWidgets('Me feeding uses the delivery date and continues after save', (
    tester,
  ) async {
    final transport = _FirstFeedingTransport('2026-08-24');
    await openFirstFeeding(tester, transport);
    expect(find.text('2026-08-24'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNotNull);
    await tester.tap(find.text('Save baby profile'));
    await tester.pumpAndSettle();
    expect(transport.profiles.single['birth_date'], '2026-08-24');
    expect(find.text('Log a feeding'), findsOneWidget);
  });

  testWidgets('Me feeding can add a baby when delivery date is missing', (
    tester,
  ) async {
    final transport = _FirstFeedingTransport(null);
    await openFirstFeeding(tester, transport);
    expect(find.text('Choose date of birth'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Choose date of birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '2026-09-13'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Save baby profile'));
    await tester.pumpAndSettle();
    expect(transport.profiles.single['birth_date'], '2026-09-13');
    expect(find.text('Log a feeding'), findsOneWidget);
  });
}
