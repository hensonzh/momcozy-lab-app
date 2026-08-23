import 'dart:typed_data';

abstract interface class AgentCardExportService {
  Future<void> sharePng({required Uint8List bytes, required String filename});
}

String buildAgentCardExportFilename({
  required String cardType,
  required DateTime now,
}) {
  final normalizedType = cardType.trim().isEmpty
      ? 'card'
      : cardType.trim().toLowerCase();
  final date = now.toUtc().toIso8601String().substring(0, 10);
  return 'comate-$normalizedType-$date.png'.replaceAll(
    RegExp(r'[^a-z0-9._-]+', caseSensitive: false),
    '-',
  );
}
