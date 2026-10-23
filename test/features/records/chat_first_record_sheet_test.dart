@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_actions.dart';
import 'package:momcozy_flutter_app/features/records/presentation/chat_first_record_sheet.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets(
    'record form preserves the demo full-height card layout at 390',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showChatFirstRecordSheet(
                  context,
                  runtime: _runtime(_FlakyRecordTransport()),
                  kind: ChatFirstRecordKind.formula,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final form = find.byKey(const ValueKey('chat-first-record-sheet'));
      expect(tester.getSize(form).height, greaterThan(750));
      await expectLater(
        form,
        matchesGoldenFile('../../goldens/chat_first/record-form-390.png'),
      );
    },
    tags: 'golden',
  );

  testWidgets('a stale selected baby is not treated as a real profile', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(const {
      '/v1/babies': {'items': <Object>[]},
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner-1',
        babyId: 'demo-baby',
        locale: 'zh-CN',
        accessToken: 'access',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: runtime,
                kind: ChatFirstRecordKind.diaper,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(transport.getPaths, contains('/v1/babies'));
    expect(find.byKey(const ValueKey('record-save')), findsNothing);
    expect(find.byKey(const ValueKey('record-create-baby')), findsOneWidget);
    expect(transport.mutationPaths, isEmpty);
  });

  testWidgets('only a confirmed selected baby unlocks baby-only saves', (
    tester,
  ) async {
    const id = '3df630e7-513a-481f-b1f8-e2577200e219';
    final transport = FixtureApiJsonTransportByPath(const {
      '/v1/babies': {
        'items': [
          {
            'id': id,
            'name': '真实宝宝',
            'birth_date': '2026-09-01',
            'sex': 'female',
            'feeding_mode': 'unknown',
            'version': 1,
            'created_at': '2026-09-01T00:00:00Z',
            'updated_at': '2026-09-01T00:00:00Z',
          },
        ],
      },
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner-1',
        babyId: id,
        locale: 'zh-CN',
        accessToken: 'access',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: runtime,
                kind: ChatFirstRecordKind.diaper,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('record-create-baby')), findsNothing);
  });

  testWidgets('failed baby lookup does not claim absence or permit saving', (
    tester,
  ) async {
    const id = '3df630e7-513a-481f-b1f8-e2577200e219';
    final transport = FixtureApiJsonTransportByPath({
      '/v1/babies': {
        'http_status': 503,
        'body': {
          'error': {'code': 'unavailable'},
        },
      },
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner-1',
        babyId: id,
        locale: 'zh-CN',
        accessToken: 'access',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: runtime,
                kind: ChatFirstRecordKind.sleep,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法核对宝宝档案'), findsOneWidget);
    expect(find.byKey(const ValueKey('record-save')), findsNothing);
    expect(find.byKey(const ValueKey('record-create-baby')), findsNothing);

    transport.responsesByPath['/v1/babies'] = const {
      'items': [
        {
          'id': id,
          'name': '真实宝宝',
          'birth_date': '2026-09-01',
          'sex': 'female',
          'feeding_mode': 'unknown',
          'version': 1,
          'created_at': '2026-09-01T00:00:00Z',
          'updated_at': '2026-09-01T00:00:00Z',
        },
      ],
    };
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-save')), findsOneWidget);
    expect(transport.getPaths, ['/v1/babies', '/v1/babies']);
  });

  testWidgets('milk facts lead, use Chinese 24-hour time and ±5 correction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _runtime(_FlakyRecordTransport());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: runtime,
                kind: ChatFirstRecordKind.formula,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026年10月15日 10:00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('record-start'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('record-volume'))).dy,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('record-volume-plus')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('record-volume')))
          .controller!
          .text,
      '55',
    );
    await tester.tap(find.byKey(const ValueKey('record-volume-minus')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('record-volume')))
          .controller!
          .text,
      '50',
    );
    await tester.enterText(find.byKey(const ValueKey('record-volume')), '0');
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-error')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('record-volume-plus')));
    await tester.pump();
    expect(find.byKey(const ValueKey('record-error')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('record-volume')))
          .controller!
          .text,
      '5',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('narrow large-text record sheet keeps save action usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: _runtime(_FlakyRecordTransport()),
                kind: ChatFirstRecordKind.pumping,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('record-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('record-volume')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('real backend confirmation is needed before synced feedback', (
    tester,
  ) async {
    final transport = _FlakyRecordTransport();
    final runtime = _runtime(transport);
    expect(runtime.recordRevision.value, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: runtime,
                kind: ChatFirstRecordKind.formula,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-record-sheet')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('record-volume')), '60');
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-record-sheet')),
      findsOneWidget,
    );
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('已同步'), findsNothing);
    expect(runtime.recordRevision.value, 0);
    final firstKey = transport.lastHeaders?['Idempotency-Key'];
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(transport.lastHeaders?['Idempotency-Key'], firstKey);
    expect(find.byKey(const ValueKey('chat-first-record-sheet')), findsNothing);
    expect(find.textContaining('已同步'), findsOneWidget);
    expect(runtime.recordRevision.value, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'server-confirmed save stays successful when the selected baby changes in flight',
    (tester) async {
      final transport = _DelayedRecordTransport();
      var current = const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner-1',
        babyId: _babyId,
        locale: 'zh-CN',
        accessToken: 'access',
      );
      final runtime = MomCozyApiRuntime.fromSession(
        current,
        jsonTransport: transport,
        sessionProvider: () => current,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showChatFirstRecordSheet(
                  context,
                  runtime: runtime,
                  kind: ChatFirstRecordKind.formula,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('record-volume')), '60');
      await tester.tap(find.byKey(const ValueKey('record-save')));
      await tester.pump();
      expect(transport.saveStarted.isCompleted, isTrue);

      current = current.copyWith(
        babyId: '19034cac-b3ac-46d0-af27-5344b02531e2',
      );
      transport.completeSave();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chat-first-record-sheet')),
        findsNothing,
      );
      expect(runtime.recordRevision.value, 1);
      expect(find.textContaining('已由服务器确认保存'), findsOneWidget);
      expect(find.textContaining('账号或宝宝已切换'), findsOneWidget);
      expect(find.textContaining('保存失败'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'baby-only record cannot claim synchronization without a real baby',
    (tester) async {
      final runtime = _runtime(_FlakyRecordTransport(), babyId: '');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showChatFirstRecordSheet(
                  context,
                  runtime: runtime,
                  kind: ChatFirstRecordKind.sleep,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.textContaining('先创建宝宝档案'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-save')), findsNothing);
      expect(find.byKey(const ValueKey('record-create-baby')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('missing-baby action reaches the real baby setup route', (
    tester,
  ) async {
    final runtime = _runtime(_FlakyRecordTransport(), babyId: '');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: FilledButton(
              onPressed: () => showChatFirstRecordSheet(
                context,
                runtime: runtime,
                kind: ChatFirstRecordKind.diaper,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
        GoRoute(
          path: '/baby',
          builder: (_, _) => const Scaffold(body: Text('真实宝宝资料入口')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-create-baby')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/baby');
    expect(find.text('真实宝宝资料入口'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}

const _babyId = '5d56ff19-4f29-4414-9554-a125669a314b';

MomCozyApiRuntime _runtime(
  ApiJsonTransport transport, {
  String babyId = _babyId,
}) => MomCozyApiRuntime(
  jsonTransport: transport,
  session: MomCozySession(
    status: MomCozySessionStatus.authenticated,
    userId: 'owner-1',
    babyId: babyId,
    locale: 'zh-CN',
    accessToken: 'access',
  ),
  now: () => DateTime(2026, 10, 15, 10),
  timezoneProvider: () async => 'Asia/Shanghai',
);

class _DelayedRecordTransport extends FixtureApiJsonTransport {
  _DelayedRecordTransport() : super(const {});

  final saveStarted = Completer<void>();
  final _saveResponse = Completer<Map<String, Object?>>();
  Map<String, Object?>? _body;

  void completeSave() {
    final observation = Map<String, Object?>.from(
      _body?['observation'] as Map? ?? const {},
    );
    _saveResponse.complete({
      'id': 'record-delayed',
      'baby_id': _babyId,
      'version': 1,
      'observation': observation,
      'deleted_at': null,
      'created_at': '2026-10-23T02:00:00Z',
      'updated_at': '2026-10-23T02:00:00Z',
    });
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/babies') {
      return const {
        'items': [
          {
            'id': _babyId,
            'name': '真实宝宝',
            'birth_date': '2026-09-01',
            'sex': 'female',
            'feeding_mode': 'unknown',
            'version': 1,
            'created_at': '2026-09-01T00:00:00Z',
            'updated_at': '2026-09-01T00:00:00Z',
          },
        ],
      };
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    _body = Map<String, Object?>.from(body);
    saveStarted.complete();
    return _saveResponse.future;
  }
}

class _FlakyRecordTransport extends FixtureApiJsonTransport {
  _FlakyRecordTransport() : super(const {});
  int saves = 0;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/babies') {
      return const {
        'items': [
          {
            'id': _babyId,
            'name': '真实宝宝',
            'birth_date': '2026-09-01',
            'sex': 'female',
            'feeding_mode': 'unknown',
            'version': 1,
            'created_at': '2026-09-01T00:00:00Z',
            'updated_at': '2026-09-01T00:00:00Z',
          },
        ],
      };
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await super.postJson(path, body: body, headers: headers);
    if (saves++ == 0) {
      throw const ApiHttpException(
        statusCode: 503,
        statusText: 'Unavailable',
        body: null,
      );
    }
    final observation = Map<String, Object?>.from(
      body['observation'] as Map? ?? const {},
    );
    return {
      'id': 'record-1',
      'baby_id': _babyId,
      'version': 1,
      'observation': observation,
      'deleted_at': null,
      'created_at': '2026-10-15T02:00:00Z',
      'updated_at': '2026-10-15T02:00:00Z',
    };
  }
}
