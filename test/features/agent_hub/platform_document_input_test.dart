import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';

void main() {
  test('returns a bounded PDF document from the platform picker', () async {
    final picker = AgentHubPlatformDocumentPicker(
      openDocument: () async => XFile.fromData(
        Uint8List.fromList('%PDF-1.4\nfixture'.codeUnits),
        mimeType: 'application/pdf',
        path: '/tmp/checkup-report.pdf',
      ),
    );

    final document = await picker.pick();

    expect(document, isNotNull);
    expect(document!.name, 'checkup-report.pdf');
    expect(document.mimeType, 'application/pdf');
    expect(document.size, greaterThan(5));
  });

  test('rejects a renamed non-PDF file', () async {
    final picker = AgentHubPlatformDocumentPicker(
      openDocument: () async => XFile.fromData(
        Uint8List.fromList('not a PDF'.codeUnits),
        mimeType: 'application/pdf',
        path: '/tmp/fake.pdf',
      ),
    );

    expect(
      picker.pick,
      throwsA(
        isA<AgentDocumentInputException>().having(
          (error) => error.code,
          'code',
          'unsupported_file_type',
        ),
      ),
    );
  });

  test('rejects a PDF larger than 10MB', () async {
    final picker = AgentHubPlatformDocumentPicker(
      openDocument: () async => XFile.fromData(
        Uint8List(AgentHubPlatformDocumentPicker.maxDocumentBytes + 1),
        mimeType: 'application/pdf',
        name: 'too-large.pdf',
      ),
    );

    expect(
      picker.pick,
      throwsA(
        isA<AgentDocumentInputException>().having(
          (error) => error.code,
          'code',
          'file_too_large',
        ),
      ),
    );
  });

  test('returns null when document selection is cancelled', () async {
    final picker = AgentHubPlatformDocumentPicker(
      openDocument: () async => null,
    );

    expect(await picker.pick(), isNull);
  });
}
