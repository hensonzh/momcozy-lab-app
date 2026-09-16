import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  const messages = {
    'image-error': '图片上传失败，请重试。',
    'file-error': '文件上传失败，请重试。',
    'too-large': '文件不能超过 10MB。',
    'unsupported': '暂仅支持 PDF 文件。',
    'cleanup-error': '附件清理失败，已保留草稿，请重试。',
  };
  for (final width in [390.0, 320.0]) {
    final scale = width == 320 ? 2.0 : 1.0;
    for (final entry in messages.entries) {
      testWidgets('attachment ${entry.key} preserves draft $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final media = _Media();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: AgentHubPage(
                mediaRepository: media,
                pickImage: (_) async =>
                    throw StateError('private picker detail'),
                pickDocument: () async {
                  if (entry.key == 'too-large') {
                    throw const AgentDocumentInputException('file_too_large');
                  }
                  if (entry.key == 'unsupported') {
                    throw const AgentDocumentInputException(
                      'unsupported_file_type',
                    );
                  }
                  if (entry.key == 'file-error') {
                    throw StateError('private picker detail');
                  }
                  return AgentHubLocalDocument(
                    bytes: Uint8List.fromList('%PDF-1.4\nfixture'.codeUnits),
                    mimeType: 'application/pdf',
                    name: 'Care notes.pdf',
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(MomCozyAssets.agentAvatar),
            tester.element(find.byType(AgentHubPage)),
          ),
        );
        final input = find.byKey(const ValueKey('agent-composer-input'));
        await tester.enterText(input, 'Keep my draft');
        await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey(
              entry.key == 'image-error'
                  ? 'agent-attachment-photo-button'
                  : 'agent-attachment-file-button',
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (entry.key == 'cleanup-error') {
          await tester.tap(
            find.byKey(const ValueKey('agent-new-session-button')),
          );
          await tester.pumpAndSettle();
          expect(media.deletions, 1);
          expect(find.text('Care notes.pdf'), findsOneWidget);
        } else {
          expect(media.uploads, 0);
        }
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('private picker detail'), findsNothing);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Keep my draft',
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/agent-attachment-notice-${entry.key}-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );
        await tester.drag(find.byType(SnackBar), const Offset(0, 180));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsNothing);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Keep my draft',
        );
        if (entry.key == 'cleanup-error') {
          media.failDelete = false;
          await tester.tap(
            find.byKey(const ValueKey('agent-new-session-button')),
          );
          await tester.pumpAndSettle();
          expect(media.deletions, 2);
          expect(find.text('Care notes.pdf'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _Media implements MediaRepository {
  int uploads = 0;
  int deletions = 0;
  bool failDelete = true;

  @override
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
  }) async {
    uploads++;
    return UploadedMediaFile(
      id: 'fixture-document',
      name: file.name,
      sizeBytes: file.sizeBytes,
      extension: 'pdf',
      mimeType: 'application/pdf',
    );
  }

  @override
  Future<void> deleteFile({
    required String fileId,
    String? idempotencyKey,
  }) async {
    deletions++;
    if (failDelete) throw StateError('private delete detail');
  }
}
