import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fixture privacy audit', () {
    test('test fixtures and future goldens use synthetic data only', () {
      final findings = <String>[];
      for (final root in _privacyAuditRoots()) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File) continue;
          final path = entity.path;
          _auditPath(path, findings);
          if (!_isTextFixture(path)) continue;
          _auditTextFile(entity, findings);
        }
      }

      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });
}

Iterable<Directory> _privacyAuditRoots() sync* {
  const candidates = ['test/fixtures', 'test/goldens', 'test/screenshots'];
  for (final path in candidates) {
    final directory = Directory(path);
    if (directory.existsSync()) yield directory;
  }
}

void _auditPath(String path, List<String> findings) {
  if (_emailPattern.hasMatch(path)) {
    findings.add('$path: file path contains an email-like value');
  }
  if (_phonePattern.hasMatch(path)) {
    findings.add('$path: file path contains a phone-like value');
  }
}

void _auditTextFile(File file, List<String> findings) {
  final text = file.readAsStringSync();
  for (final match in _emailPattern.allMatches(text)) {
    final email = match.group(0)!;
    if (!_isAllowedSyntheticEmail(email)) {
      findings.add('${file.path}: contains non-synthetic email $email');
    }
  }
  for (final match in _urlPattern.allMatches(text)) {
    final url = Uri.tryParse(match.group(0)!);
    if (url != null && !_isAllowedSyntheticHost(url.host)) {
      findings.add('${file.path}: contains non-synthetic URL ${url.host}');
    }
  }
  for (final match in _phonePattern.allMatches(text)) {
    findings.add('${file.path}: contains phone-like value ${match.group(0)}');
  }
  for (final match in _secretPattern.allMatches(text)) {
    final value = match.group(2) ?? '';
    if (!_isAllowedSyntheticSecret(value)) {
      findings.add('${file.path}: contains non-fixture secret placeholder');
    }
  }
}

bool _isTextFixture(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.json') ||
      lower.endsWith('.jsonl') ||
      lower.endsWith('.eventstream') ||
      lower.endsWith('.hex') ||
      lower.endsWith('.md') ||
      lower.endsWith('.txt') ||
      lower.endsWith('.yaml') ||
      lower.endsWith('.yml');
}

bool _isAllowedSyntheticEmail(String email) {
  final domain = email.split('@').last.toLowerCase();
  return domain == 'example.com' || domain == 'example.test';
}

bool _isAllowedSyntheticHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == 'example.com' ||
      normalized.endsWith('.example.com') ||
      normalized == 'example.test' ||
      normalized.endsWith('.example.test');
}

bool _isAllowedSyntheticSecret(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('test') ||
      normalized.contains('fixture') ||
      normalized.contains('demo') ||
      normalized.contains('example') ||
      normalized.contains('secret');
}

final _emailPattern = RegExp(
  r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
  caseSensitive: false,
);
final _urlPattern = RegExp(r'https?://[^\s"<>]+');
final _phonePattern = RegExp(r'\+\d[\d ()-]{8,}\d');
final _secretPattern = RegExp(
  r'\b(access[_-]?token|refresh[_-]?token|api[_-]?key|token)\b["\s:=]+'
  r'["]?([A-Za-z0-9._-]{12,})',
  caseSensitive: false,
);
