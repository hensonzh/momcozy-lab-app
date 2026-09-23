import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/baby_module_routes.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import '../support/fixture_api_transport.dart';

class HomeTransport extends FixtureApiJsonTransport {
  HomeTransport(this.name) : super({});
  final String name;
  Completer<void>? gate;
  int profiles = 0;
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/babies') profiles++;
    await gate?.future;
    if (path == '/v1/profile/me') return {'preferred_name': 'Mia'};
    if (path == '/v1/profile/lactation') {
      return {
        'actual_delivery_date': '2026-08-18',
        'current_delivery_method': 'unknown',
      };
    }
    if (path == '/v1/babies') {
      return {
        'items': [
          {
            'id': 'baby',
            'name': name,
            'version': 1,
            'birth_date': '2026-08-18',
            'sex': 'female',
            'feeding_mode': 'unknown',
            'created_at': '2026-08-18T00:00:00Z',
            'updated_at': '2026-08-18T00:00:00Z',
          },
        ],
      };
    }
    return {
      'items': [],
      'total': 0,
      'offset': query['offset'] ?? 0,
      'limit': query['limit'] ?? 200,
      'server_time': '2026-09-08T10:00:00Z',
    };
  }
}

void main() {
  testWidgets(
    'parent rebuild is stable, tab return keeps data, runtime change isolates account',
    (tester) async {
      final first = HomeTransport('Luna'), second = HomeTransport('Leo');
      MomCozyApiRuntime runtimeFor(HomeTransport transport, String user) =>
          MomCozyApiRuntime(
            jsonTransport: transport,
            userId: user,
            babyId: 'baby',
            timezoneProvider: () async => 'Asia/Shanghai',
            now: () => DateTime.utc(2026, 9, 8, 10),
          );
      var runtime = runtimeFor(first, 'first');
      var visible = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MomCozyRuntimeScope(
                  apiRuntime: runtime,
                  child: Builder(
                    builder: (context) => visible
                        ? buildBabyHome(context)
                        : const Text('Other tab'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsOneWidget);
      expect(first.profiles, 1);
      update(() {});
      await tester.pumpAndSettle();
      expect(first.profiles, 1);
      update(() => visible = false);
      await tester.pumpAndSettle();
      first.gate = Completer();
      update(() => visible = true);
      await tester.pump();
      expect(find.text('Luna'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(first.profiles, 2);
      first.gate!.complete();
      await tester.pumpAndSettle();
      second.gate = Completer();
      update(() => runtime = runtimeFor(second, 'second'));
      await tester.pump();
      expect(find.text('Luna'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      second.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Leo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
