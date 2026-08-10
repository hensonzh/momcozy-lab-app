import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_context_publisher.dart';

void main() {
  test(
    'publishes semantic snapshots at most twice a second and keeps latest',
    () async {
      final published = <Map<String, Object?>>[];
      final publisher = MotionRealtimeContextPublisher(
        minimumInterval: const Duration(milliseconds: 30),
        publish: (snapshot) async => published.add(snapshot),
      );

      publisher.add({'sequence': 1});
      await Future<void>.delayed(Duration.zero);
      publisher.add({'sequence': 2});
      publisher.add({'sequence': 3});

      await Future<void>.delayed(const Duration(milliseconds: 45));

      expect(published, [
        {'sequence': 1},
        {'sequence': 3},
      ]);
      await publisher.close();
    },
  );

  test(
    'force publishes a material transition without waiting for heartbeat',
    () async {
      final published = <Map<String, Object?>>[];
      final publisher = MotionRealtimeContextPublisher(
        minimumInterval: const Duration(seconds: 1),
        publish: (snapshot) async => published.add(snapshot),
      );

      publisher.add({'sequence': 1});
      publisher.add({'sequence': 2}, force: true);
      await Future<void>.delayed(Duration.zero);

      expect(published, [
        {'sequence': 1},
        {'sequence': 2},
      ]);
      await publisher.close();
    },
  );
}
