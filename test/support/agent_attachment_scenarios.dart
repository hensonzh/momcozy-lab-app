import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_file_previews.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentAttachments(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final draft = TextEditingController(text: 'Keep my draft');
  var images = <AgentStreamImageInput>[];
  var files = <AgentStreamFileInput>[];
  var locked = false;
  var cameras = 0, sends = 0;
  late StateSetter update;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Cozymate')),
        body: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.bottomCenter,
              child: AgentComposerBar(
                controller: draft,
                canSend: !locked,
                isRunning: false,
                isInputLocked: locked,
                images: images,
                files: files,
                canAttachImage: !locked,
                canAttachFile: !locked,
                isAttachmentPending: locked,
                attachmentUploadProgress: .5,
                onChanged: (_) {},
                onSend: () => sends++,
                onCancel: () {},
                onTakePhoto: () => cameras++,
                onPickPhoto: () => update(
                  () => images = const [
                    AgentStreamImageInput(
                      name: 'Feeding notes and observations.png',
                      size: 2048,
                      dataUrl:
                          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
                    ),
                  ],
                ),
                onPickFile: () => update(
                  () => files = const [
                    AgentStreamFileInput(
                      fileId: 'fixture-pdf',
                      name: 'Care plan and feeding notes.pdf',
                      mimeType: 'application/pdf',
                      size: 4096,
                    ),
                  ],
                ),
                onRemoveImage: (_) => update(() => images = []),
                onRemoveFile: (_) => update(() => files = []),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/cozymate_attachment_camera.png'),
      tester.element(find.byType(AgentComposerBar)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.showKeyboard(find.byKey(const ValueKey('agent-composer-input')));
  await tester.pumpAndSettle();
  Future<void> menu() async {
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
  }

  await menu();
  expect(
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
    isFalse,
  );
  expect(find.text('拍摄一张照片'), findsOneWidget);
  expect(find.text('PDF · 最大 10 MB'), findsOneWidget);
  expect(find.textContaining('Word'), findsNothing);
  expect(
    tester
        .getBottomLeft(find.byKey(const ValueKey('agent-attachment-menu')))
        .dy,
    lessThan(
      tester
          .getTopLeft(find.byKey(const ValueKey('agent-composer-surface')))
          .dy,
    ),
  );
  await capture('menu');
  await tester.tap(find.byKey(const ValueKey('agent-composer-input')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('agent-attachment-menu')), findsNothing);
  expect(draft.text, 'Keep my draft');
  await menu();
  await tester.tap(
    find.byKey(const ValueKey('agent-attachment-camera-button')),
  );
  await tester.pumpAndSettle();
  expect(cameras, 1);
  await menu();
  await tester.tap(find.byKey(const ValueKey('agent-attachment-photo-button')));
  await tester.pumpAndSettle();
  expect(find.text('Feeding notes and observations.png'), findsOneWidget);
  final removeImage = find.byKey(const ValueKey('agent-remove-image-button'));
  expect(tester.getSize(removeImage).shortestSide, greaterThanOrEqualTo(24));
  await menu();
  await tester.tap(find.byKey(const ValueKey('agent-attachment-file-button')));
  await tester.pumpAndSettle();
  expect(
    tester
        .getTopLeft(find.byKey(const ValueKey('agent-image-attachment-0')))
        .dy,
    tester.getTopLeft(find.byKey(const ValueKey('agent-file-attachment-0'))).dy,
  );
  await capture('pending-image');
  final removeFile = find.byKey(const ValueKey('agent-remove-file-button'));
  await tester.ensureVisible(removeFile);
  await tester.pumpAndSettle();
  expect(tester.getSize(removeFile).shortestSide, greaterThanOrEqualTo(24));
  await capture('pending-file');
  update(() => locked = true);
  await tester.pump();
  expect(tester.widget<IconButton>(removeFile).onPressed, isNull);
  expect(
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('agent-attachment-button')),
        )
        .onPressed,
    isNull,
  );
  await capture('uploading');
  update(() => locked = false);
  await tester.pumpAndSettle();
  await tester.tap(removeFile);
  await tester.pumpAndSettle();
  expect(files, isEmpty);
  await tester.ensureVisible(removeImage);
  await tester.pumpAndSettle();
  await tester.tap(removeImage);
  await tester.pumpAndSettle();
  expect(images, isEmpty);
  expect(draft.text, 'Keep my draft');
  expect(sends, 0);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  draft.dispose();
}

Future<void> verifyAgentSentFiles(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  const name = 'Care plan and feeding notes with a long file name.pdf';
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Cozymate')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AgentSentFiles(
            files: [
              AgentStreamFileInput(
                fileId: 'fixture-one',
                name: name,
                mimeType: 'application/pdf',
                size: 512,
              ),
              AgentStreamFileInput(
                fileId: 'fixture-two',
                name: 'Notes.pdf',
                mimeType: 'application/pdf',
                size: 2048,
              ),
              AgentStreamFileInput(
                fileId: 'fixture-three',
                name: 'Care.pdf',
                mimeType: 'application/pdf',
                size: 2097152,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('PDF · 512 B'), findsOneWidget);
  expect(find.text('PDF · 2.0 KB'), findsOneWidget);
  expect(find.text('PDF · 2.0 MB'), findsOneWidget);
  expect(find.byTooltip(name), findsOneWidget);
  expect(tester.takeException(), isNull);
  await capture('sent-files');
  await tester.pumpWidget(const SizedBox());
}
