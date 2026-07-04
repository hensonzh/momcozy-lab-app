import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../../support/fixture_api_transport.dart';
import '../../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  group('Records component parity goldens', () {
    testWidgets('dashboard card matches compact baseline', (tester) async {
      await _pumpRecordsComponentApp(tester);

      final dashboard = find.byKey(const ValueKey('records-dashboard-card'));
      expect(dashboard, findsOneWidget);
      expect(find.text('今日吸奶器使用'), findsOneWidget);
      expect(find.text('过去1周日补录奶量趋势'), findsOneWidget);

      await expectLater(
        dashboard,
        matchesGoldenFile(
          '../../../goldens/component_parity/records_dashboard_card.png',
        ),
      );
    });

    testWidgets('pump milk row matches compact baseline', (tester) async {
      await _pumpRecordsComponentApp(tester);

      final row = find.byKey(const ValueKey('records-pump-row-pump-legacy-1'));
      expect(row, findsOneWidget);
      expect(find.text('175 mL'), findsOneWidget);
      expect(find.text('20分钟'), findsOneWidget);

      await expectLater(
        row,
        matchesGoldenFile(
          '../../../goldens/component_parity/records_pump_milk_row.png',
        ),
      );
    });

    testWidgets('list toolbar matches compact baseline', (tester) async {
      await _pumpRecordsComponentApp(tester);

      final toolbar = find.byKey(const ValueKey('records-list-toolbar'));
      expect(toolbar, findsOneWidget);
      expect(find.text('今日记录'), findsOneWidget);
      expect(find.text('手动记录'), findsOneWidget);

      await expectLater(
        toolbar,
        matchesGoldenFile(
          '../../../goldens/component_parity/records_list_toolbar.png',
        ),
      );
    });
  });
}

Future<void> _pumpRecordsComponentApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      child: MomCozyFlutterApp(
        router: createMomCozyRouter(initialLocation: '/records'),
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: _recordsRuntime(),
      ),
    ),
  );
  await tester.pump();

  final appContext = tester.element(find.byType(MomCozyFlutterApp));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(MomCozyAssets.momcozyLogo),
      appContext,
    ).timeout(const Duration(seconds: 5));
  });
  await tester.pumpAndSettle();
}

MomCozyApiRuntime _recordsRuntime() {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      pumpMilkRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': [
            {
              'id': 'pump-legacy-1',
              'title': '20分钟',
              'amountMl': 175,
              'pumpSource': 1,
              'occurredAt': '2026-03-08T06:30:00',
            },
            {
              'id': 'pump-legacy-2',
              'title': '15分钟',
              'amountMl': 135,
              'pumpSource': 1,
              'occurredAt': '2026-03-08T10:00:00',
            },
            {
              'id': 'pump-legacy-3',
              'title': '一分钟',
              'amountMl': 155,
              'pumpSource': 9,
              'occurredAt': '2026-03-08T14:00:00',
            },
          ],
        },
      },
      feedingRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': [
            {
              'id': 'feed-legacy-1',
              'type': 'bottle',
              'amountMl': 70,
              'occurredAt': '2026-03-08T15:10:00',
            },
          ],
        },
      },
      growthRecordsEndpoint: const <String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'records': [
            {
              'id': 'growth-legacy-1',
              'weightGram': 5600,
              'heightCm': 58.2,
              'measuredAt': '2026-03-08',
            },
          ],
        },
      },
    }),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-records-component-parity',
    babyId: 'demo-baby-records-component-parity',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 3, 8),
  );
}
