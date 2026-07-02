import 'dart:convert';
import 'dart:io';

import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_dry_run.dart';

Future<void> main(List<String> args) async {
  final targets = args.isEmpty ? _fixtureFiles() : args.map(File.new).toList();
  if (targets.isEmpty) {
    stderr.writeln('No storage migration input files found.');
    exitCode = 64;
    return;
  }

  var hasUnhandled = false;
  for (final file in targets) {
    if (!file.existsSync()) {
      stderr.writeln('Input not found: ${file.path}');
      exitCode = 66;
      return;
    }

    final input = _readJsonObject(file);
    final report = buildStorageMigrationDryRunReport(input, source: file.path);
    final json = const JsonEncoder.withIndent('  ').convert(report.toJson());
    stdout.writeln(json);
    hasUnhandled =
        hasUnhandled ||
        report.unhandledLegacyKeys.values.any((keys) => keys.isNotEmpty);
  }

  if (hasUnhandled) {
    exitCode = 1;
  }
}

Map<String, Object?> _readJsonObject(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw FormatException(
      'Storage migration input must be an object: ${file.path}',
    );
  }
  return Map<String, Object?>.from(decoded);
}

List<File> _fixtureFiles() {
  final candidates = [
    Directory('../test/fixtures/storage_migration'),
    Directory('test/fixtures/storage_migration'),
  ];
  for (final directory in candidates) {
    if (!directory.existsSync()) continue;
    return directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
  }
  return const [];
}
