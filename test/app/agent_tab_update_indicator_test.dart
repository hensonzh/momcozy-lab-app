import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

import '../support/fixture_api_transport.dart';

AgentStreamEvent _event(String id, String type, List<String> tabs) =>
    AgentStreamEvent({
      'event_id': id,
      'type': type,
      'payload': {'tabs': tabs, 'action_id': 'action-$id'},
    });

MomCozyApiRuntime _runtime(String userId) => MomCozyApiRuntime(
  jsonTransport: FixtureApiJsonTransport(const {}),
  userId: userId,
  babyId: 'baby',
  timezoneProvider: () async => 'UTC',
);

Finder _dot(String tab) => find.byKey(ValueKey('bottom-nav-update-$tab'));

void main() {
  testWidgets(
    'only successful agent writes mark affected tabs; visiting clears each',
    (tester) async {
      final runtime = _runtime('mia');
      var location = '/';
      late StateSetter navigate;
      await tester.pumpWidget(
        MomCozyRuntimeScope(
          apiRuntime: runtime,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                navigate = setState;
                return MomCozyRouteShell(
                  location: location,
                  onSelectTab: (index) => setState(() {
                    location = [
                      '/me',
                      '/baby',
                      '/',
                      '/schedule',
                      '/more',
                    ][index];
                  }),
                  child: const Text('Content'),
                );
              },
            ),
          ),
        ),
      );

      runtime.handleAgentApplicationEvent(
        _event('failed', 'action.failed', ['me', 'baby', 'schedule']),
      );
      runtime.handleAgentApplicationEvent(
        _event('applied', 'action.applied', ['me', 'baby', 'schedule']),
      );
      await tester.pump();
      expect(_dot('me'), findsNothing);
      expect(_dot('baby'), findsNothing);
      expect(_dot('schedule'), findsNothing);

      final records = _event('records', 'product.tabs.updated', ['me', 'baby']);
      runtime.handleAgentApplicationEvent(records);
      runtime.handleAgentApplicationEvent(
        _event('schedule', 'product.tabs.updated', ['schedule']),
      );
      await tester.pump();
      expect(_dot('me'), findsOneWidget);
      expect(_dot('baby'), findsOneWidget);
      expect(_dot('schedule'), findsOneWidget);
      expect(_dot('more'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-me')));
      await tester.pump();
      expect(_dot('me'), findsNothing);
      expect(_dot('baby'), findsOneWidget);
      expect(_dot('schedule'), findsOneWidget);

      runtime.handleAgentApplicationEvent(
        _event('already-viewed', 'product.tabs.updated', ['me']),
      );
      await tester.pump();
      expect(_dot('me'), findsNothing);

      navigate(() => location = '/baby'); // Non-tap navigation clears too.
      await tester.pump();
      expect(_dot('baby'), findsNothing);
      expect(_dot('schedule'), findsOneWidget);
      runtime.handleAgentApplicationEvent(records); // Replay after leaving Me.
      await tester.pump();
      expect(_dot('me'), findsNothing);
      runtime.handleAgentApplicationEvent(
        _event('new-write', 'product.tabs.updated', ['me']),
      );
      await tester.pump();
      expect(_dot('me'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
      await tester.pump();
      expect(_dot('schedule'), findsNothing);
      navigate(() => location = '/');
      await tester.pump();
      expect(_dot('me'), findsOneWidget);
      expect(_dot('baby'), findsNothing);
      expect(_dot('schedule'), findsNothing);
    },
  );

  testWidgets('ignores unsupported tabs and resets badges with a new runtime', (
    tester,
  ) async {
    var runtime = _runtime('mia');
    late StateSetter replaceRuntime;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          replaceRuntime = setState;
          return MomCozyRuntimeScope(
            apiRuntime: runtime,
            child: const MaterialApp(
              home: MomCozyRouteShell(location: '/', child: Text('Content')),
            ),
          );
        },
      ),
    );
    runtime.handleAgentApplicationEvent(
      _event('unknown', 'product.tabs.updated', [
        'more',
        'momcozy ai',
        'bogus',
      ]),
    );
    await tester.pump();
    expect(_dot('more'), findsNothing);
    expect(_dot('me'), findsNothing);
    runtime.handleAgentApplicationEvent(
      _event('write', 'product.tabs.updated', ['me']),
    );
    await tester.pump();
    expect(_dot('me'), findsOneWidget);
    replaceRuntime(() => runtime = _runtime('leo'));
    await tester.pump();
    expect(_dot('me'), findsNothing);
  });
}
