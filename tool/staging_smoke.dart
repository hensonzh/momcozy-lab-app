import 'dart:io';

import 'package:app/core/staging/staging_smoke.dart';

Future<void> main() async {
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

  if (report.hasFailures) {
    exitCode = 1;
  }
}
