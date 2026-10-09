import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/web_demo/demo_memory_transport.dart';

void main() {
  final today = DateTime.utc(2026, 10, 9, 10);

  test(
    'fictional seed is isolated, and unknown API operations fail closed',
    () async {
      final demo = DemoMemoryTransport(now: () => today);
      expect((await demo.getJson('/v1/profile/me'))['preferred_name'], 'Mia');
      expect((await demo.getJson('/v1/babies'))['items'], isNotEmpty);
      expect(
        () => demo.getJson('/v1/auth/me'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => demo.postJson('/v1/agent/runs', body: {'message': 'hi'}),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => demo.patchJson('/v1/profile/me', body: {'email': 'x'}),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );

  test(
    'schedule writes are in memory, reset and new tab restore seed',
    () async {
      final demo = DemoMemoryTransport(now: () => today);
      final before = await demo.getJson('/v1/schedule');
      final beforeCount = (before['personal'] as List).length;
      final created = await demo.postJson(
        '/v1/schedule/personal',
        body: {
          'title': 'Demo walk',
          'date': '2026-10-09',
          'start_time': '16:30',
          'note': 'Only this tab',
        },
      );
      expect(created['title'], 'Demo walk');
      final after = await demo.getJson('/v1/schedule');
      expect((after['personal'] as List).length, beforeCount + 1);
      expect(
        (await DemoMemoryTransport(
          now: () => today,
        ).getJson('/v1/schedule'))['personal'],
        before['personal'],
      );
      demo.reset();
      expect(
        (await demo.getJson('/v1/schedule'))['personal'],
        before['personal'],
      );
    },
  );

  test('deleted records can be restored in this tab only', () async {
    final demo = DemoMemoryTransport(now: () => today);
    final deleted = await demo.deleteJson(
      '/v1/babies/demo-baby/records/demo-feeding',
      headers: {'If-Match': '1'},
    );
    expect(deleted['version'], 2);
    expect(
      () => demo.postJson(
        '/v1/babies/demo-baby/records/demo-feeding/restore',
        body: {'expected_version': 1},
      ),
      throwsA(isA<UnsupportedError>()),
    );
    final restored = await demo.postJson(
      '/v1/babies/demo-baby/records/demo-feeding/restore',
      body: {'expected_version': deleted['version']},
    );
    expect(restored['version'], 3);
    expect(restored['deleted_at'], isNull);
    expect(
      () => demo.postJson(
        '/v1/babies/demo-baby/records/demo-feeding/restore',
        body: {'expected_version': 2},
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test(
    'a saved baby record is visible in subsequent reads and disappears on reset',
    () async {
      final demo = DemoMemoryTransport(now: () => today);
      final saved = await demo.postJson(
        '/v1/babies/demo-baby/records',
        body: {
          'observation': {
            'kind': 'feeding',
            'occurred_at': '2026-10-09T09:00:00Z',
            'method': 'formula',
            'volume_ml': 75,
            'note': '',
          },
        },
      );
      expect(saved['baby_id'], 'demo-baby');
      final data = await demo.getJson(
        '/v1/babies/demo-baby/records',
        query: {
          'start_date': '2026-10-09',
          'end_date': '2026-10-10',
          'timezone': 'UTC',
          'offset': 0,
          'limit': 200,
        },
      );
      expect(
        (data['items'] as List).any(
          (item) => (item as Map)['id'] == saved['id'],
        ),
        isTrue,
      );
      demo.reset();
      final reset = await demo.getJson(
        '/v1/babies/demo-baby/records',
        query: {'start_date': '2026-10-09', 'end_date': '2026-10-10'},
      );
      expect(
        (reset['items'] as List).any(
          (item) => (item as Map)['id'] == saved['id'],
        ),
        isFalse,
      );
    },
  );
}
