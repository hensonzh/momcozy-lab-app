import 'dart:convert';
import 'dart:io';

String readMigrationFixture(String relativePath) {
  final candidate = File('test/fixtures/$relativePath');
  if (candidate.existsSync()) return candidate.readAsStringSync();
  throw FileSystemException('Fixture not found', relativePath);
}

Map<String, Object?> readFixtureMap(String relativePath) {
  final decoded = jsonDecode(readMigrationFixture(relativePath));
  if (decoded is! Map) {
    throw FormatException('Fixture must be a JSON object: $relativePath');
  }
  return Map<String, Object?>.from(decoded);
}

List<Object?> readFixtureList(String relativePath) {
  final decoded = jsonDecode(readMigrationFixture(relativePath));
  if (decoded is! List) {
    throw FormatException('Fixture must be a JSON array: $relativePath');
  }
  return decoded;
}
