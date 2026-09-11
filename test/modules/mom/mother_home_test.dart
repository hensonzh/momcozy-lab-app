import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

final _now = DateTime(2026, 9, 8, 10);
Map<String, Object?> _diary(
  Map<String, Object?> value, {
  String date = '2026-09-08',
  int version = 1,
}) => {
  'id': 'diary-$date',
  'owner_user_id': 'demo-user',
  'entry_date': date,
  'version': version,
  'updated_at': DateTime(2026, 9, 8, 9).toUtc().toIso8601String(),
  'diary': value,
};
Map<String, Object?> _catalog() => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/product_baseline/care_catalog.json',
        ).readAsStringSync(),
      )
      as Map,
);

_HomeTransport _transport() => _HomeTransport({
  '/v1/profile/me': {'preferred_name': 'Mia', 'age': 30},
  '/v1/profile/lactation': {
    'actual_delivery_date': '2026-08-18',
    'current_delivery_method': 'vaginal',
  },
  '/v1/mother/diary': {
    'items': [
      _diary({
        'rest': {'total': '4-5h'},
        'body': {'energy': 'managing'},
        'mood': {'tone': 'steady'},
      }),
      {
        ..._diary({
          'mood': {'tone': 'low'},
        }, date: '2026-09-07'),
        'updated_at': DateTime(2026, 9, 7, 22).toUtc().toIso8601String(),
      },
    ],
  },
  '/v1/lactation/records': {
    'items': [
      {
        'id': 'milk',
        'owner_user_id': 'demo-user',
        'version': 1,
        'observation': {
          'method': 'pump',
          'side': 'right',
          'occurred_at': DateTime(2026, 9, 8, 9).toUtc().toIso8601String(),
          'volume_ml': 55,
          'note': '',
        },
      },
    ],
  },
  '/v1/care/catalog': _catalog(),
  '/v1/care/overview': {'orders': [], 'episodes': []},
});

void main() {
  testWidgets(
    'default home opens grouped diary, saves and refreshes only current API data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = _transport();
      final router = createMomCozyRouter();
      addTearDown(router.dispose);
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        now: () => _now,
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MomCozyRuntimeScope(
          apiRuntime: runtime,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('早上好，Mia'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(
        transport.getPaths.any(
          (path) =>
              path.startsWith('/v1/plans') || path.startsWith('/v1/records'),
        ),
        isFalse,
      );
      await tester.tap(find.text('昨夜休息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5–6 小时'));
      await tester.pump();
      await tester.tap(find.text('保存今天的记录'));
      await tester.pumpAndSettle();
      expect(transport.lastBody?['expected_version'], 1);
      expect(
        (transport.lastBody?['diary'] as Map)['rest'],
        containsPair('total', '5-6h'),
      );
      await tester.tap(find.byTooltip('关闭记录'));
      await tester.pumpAndSettle();
      expect(find.text('5–6 小时'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/me');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('mother home matches the product baseline at $width', (
      tester,
    ) async {
      await loadMomCozyTestFonts();
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = createMomCozyRouter();
      addTearDown(router.dispose);
      final runtime = MomCozyApiRuntime(
        jsonTransport: _transport(),
        now: () => _now,
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MomCozyRuntimeScope(
          apiRuntime: runtime,
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: momCozyTheme(),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/momcozy-agent.png'),
          tester.element(find.byType(MaterialApp)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile(
          '../../goldens/product_baseline/mother-home-${width.toInt()}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'failed state is distinct from an empty diary and retries safely',
    (tester) async {
      final transport = _transport();
      transport.responsesByPath['/v1/mother/diary'] = {
        'http_status': 503,
        'status_text': 'Unavailable',
        'body': {
          'error': {'code': 'unavailable'},
        },
      };
      final router = createMomCozyRouter();
      addTearDown(router.dispose);
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        now: () => _now,
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MomCozyRuntimeScope(
          apiRuntime: runtime,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂未载入'), findsNWidgets(3));
      expect(find.text('未记录'), findsNothing);
      transport.responsesByPath['/v1/mother/diary'] = {'items': []};
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('暂未载入'), findsNothing);
      expect(find.text('未记录'), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _HomeTransport extends FixtureApiJsonTransportByPath {
  _HomeTransport(super.responsesByPath);
  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/mother/diary/2026-09-08') {
      lastBody = body;
      lastPath = path;
      lastMethod = 'PUT';
      mutationPaths.add(path);
      final result = _diary(
        Map<String, Object?>.from(body['diary'] as Map),
        version: 2,
      );
      responsesByPath['/v1/mother/diary'] = {
        'items': [result],
      };
      return result;
    }
    return super.putJson(path, body: body, headers: headers);
  }
}
