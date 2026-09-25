import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/staging_environment/staging_smoke.dart';

void main() {
  test(
    'live Product Backend and Agent Runtime staging smoke',
    () async {
      final config = StagingSmokeConfig.fromEnvironment(Platform.environment);
      final runner = StagingSmokeRunner(
        config: config,
        probes: buildDefaultStagingSmokeProbes(config),
      );

      final report = await runner.run();
      for (final result in report.results) {
        final marker = switch (result.status) {
          StagingSmokeStatus.passed => 'PASS',
          StagingSmokeStatus.failed => 'FAIL',
          StagingSmokeStatus.skipped => 'SKIP',
        };
        final elapsedMs = result.elapsed.inMilliseconds;
        final message = result.message == null ? '' : ' - ${result.message}';
        stdout.writeln('[$marker] ${result.name} (${elapsedMs}ms)$message');
      }
      stdout.writeln(
        'Summary: ${report.passedCount} passed, '
        '${report.skippedCount} skipped, ${report.failedCount} failed',
      );

      expect(
        report.hasFailures,
        isFalse,
        reason:
            'One or more live test probes failed; see the redacted '
            'probe report above.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
