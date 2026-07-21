import 'dart:typed_data';

class AgentHubLocalDocument {
  const AgentHubLocalDocument({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;

  int get size => bytes.length;
}

typedef AgentHubDocumentPicker = Future<AgentHubLocalDocument?> Function();

class AgentDocumentInputException implements Exception {
  const AgentDocumentInputException(this.code);

  final String code;

  @override
  String toString() => 'AgentDocumentInputException($code)';
}
