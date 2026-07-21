import 'package:file_selector/file_selector.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';

typedef AgentPlatformDocumentOpener = Future<XFile?> Function();

class AgentHubPlatformDocumentPicker {
  AgentHubPlatformDocumentPicker({AgentPlatformDocumentOpener? openDocument})
    : _openDocument = openDocument ?? _openPdfDocument;

  static const int maxDocumentBytes = 10 * 1024 * 1024;

  final AgentPlatformDocumentOpener _openDocument;

  Future<AgentHubLocalDocument?> pick() async {
    final file = await _openDocument();
    if (file == null) return null;

    final declaredLength = await file.length();
    if (declaredLength > maxDocumentBytes) {
      throw const AgentDocumentInputException('file_too_large');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    if (bytes.length > maxDocumentBytes) {
      throw const AgentDocumentInputException('file_too_large');
    }
    if (!_isPdf(bytes)) {
      throw const AgentDocumentInputException('unsupported_file_type');
    }

    final name = file.name.trim();
    return AgentHubLocalDocument(
      bytes: bytes,
      mimeType: 'application/pdf',
      name: name.toLowerCase().endsWith('.pdf') && name.isNotEmpty
          ? name
          : 'document.pdf',
    );
  }
}

Future<XFile?> _openPdfDocument() {
  const pdfGroup = XTypeGroup(
    label: 'PDF',
    extensions: <String>['pdf'],
    mimeTypes: <String>['application/pdf'],
    uniformTypeIdentifiers: <String>['com.adobe.pdf'],
  );
  return openFile(acceptedTypeGroups: const <XTypeGroup>[pdfGroup]);
}

bool _isPdf(List<int> bytes) {
  const signature = <int>[0x25, 0x50, 0x44, 0x46, 0x2d];
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}
