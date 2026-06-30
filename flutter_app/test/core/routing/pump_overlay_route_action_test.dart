import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/routing/pump_overlay_route_action.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Pump overlay route action fixtures', () {
    test('map overlay snapshots to route-aware native actions', () {
      final fixture = readFixtureMap(
        'route_intents/pump_notification_and_overlay_intents.json',
      );
      final input = Map<String, Object?>.from(fixture['input']! as Map);
      final snapshots = List<Object?>.from(input['overlaySnapshots']! as List)
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(growable: false);
      final expected =
          List<Object?>.from(fixture['expectedOverlayActions']! as List)
              .whereType<Map>()
              .map((value) => Map<String, Object?>.from(value))
              .toList(growable: false);

      final actual = snapshots.map(_actionFromFixture).toList(growable: false);

      expect(actual.map((action) => action.toMap()), expected);
    });

    test('clamp progress and skip non-Android overlay work', () {
      expect(clampPumpOverlayProgress(64.4), 64);
      expect(clampPumpOverlayProgress(101), 100);
      expect(clampPumpOverlayProgress(-1), 0);
      expect(clampPumpOverlayProgress(double.nan), 0);

      expect(
        buildPumpOverlayRouteAction(
          platform: 'web',
          permissionGranted: true,
          state: 'running',
          processAll: 50,
          routePath: '/',
          appVisible: true,
        ).toMap(),
        {'type': 'skip', 'reason': 'platform-not-android'},
      );
    });
  });
}

PumpOverlayRouteAction _actionFromFixture(Map<String, Object?> snapshot) {
  return buildPumpOverlayRouteAction(
    platform: snapshot['platform']! as String,
    permissionGranted: snapshot['permissionGranted']! as bool,
    state: snapshot['state']! as String,
    processAll: snapshot['processAll'],
    routePath: snapshot['routePath']! as String,
    appVisible: snapshot['appVisible']! as bool,
  );
}
