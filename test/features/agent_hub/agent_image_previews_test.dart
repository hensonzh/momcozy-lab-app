import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import '../../support/agent_image_scenarios.dart';

void main() {
  final imageBytes = File('assets/images/mom/milk-hero.png').readAsBytesSync();
  testWidgets('sent images size their tap target to decoded aspect ratio', (
    tester,
  ) async {
    Uint8List png(int width, int height) => Uint8List.fromList(
      image_codec.encodePng(
        image_codec.copyResize(
          image_codec.decodePng(imageBytes)!,
          width: width,
          height: height,
        ),
      ),
    );

    for (final (width, height, expectedHeight) in [
      (320, 160, 56.0),
      (160, 320, 224.0),
    ]) {
      final bytes = png(width, height);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentSentImages(
              images: [
                AgentStreamImageInput(
                  dataUrl: '',
                  localBytes: bytes,
                  name: 'photo.png',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          ResizeImage(MemoryImage(bytes), width: 336),
          tester.element(find.byType(MaterialApp)),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('agent-sent-image-0'));
      expect(tester.getSize(target).width, 112);
      expect(tester.getSize(target).height, closeTo(expectedHeight, 1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('remote thumbnail uses a compact square until decoded', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentSentImages(
            images: const [
              AgentStreamImageInput(dataUrl: '', fileId: 'remote'),
            ],
            loadImageThumbnail: (_) => pending.future,
          ),
        ),
      ),
    );
    await tester.pump();
    final target = find.byKey(const ValueKey('agent-sent-image-0'));
    expect(tester.getSize(target), const Size(112, 112));
    final bytes = Uint8List.fromList(
      image_codec.encodePng(
        image_codec.copyResize(
          image_codec.decodePng(imageBytes)!,
          width: 320,
          height: 160,
        ),
      ),
    );
    pending.complete(bytes);
    await tester.runAsync(
      () => precacheImage(
        ResizeImage(MemoryImage(bytes), width: 336),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(target).height, closeTo(56, 1));
  });

  testWidgets('empty thumbnail stops loading and preserves original access', (
    tester,
  ) async {
    var originals = 0;
    await tester.pumpWidget(
      agentImageTestHost(
        AgentSentImages(
          images: const [
            AgentStreamImageInput(
              dataUrl: '',
              fileId: 'fixture-id',
              name: 'Notes.png',
            ),
          ],
          loadImageThumbnail: (_) async => Uint8List(0),
          loadImageContent: (_) async {
            originals++;
            return imageBytes;
          },
        ),
        1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('agent-sent-image-0')), findsOneWidget);
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(imageBytes),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
    await tester.pumpAndSettle();
    expect(originals, 1);
    expect(find.byKey(const ValueKey('agent-image-stage')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final failure in ['sync', 'async', 'corrupt', 'local-with-remote']) {
    testWidgets(
      'image read failure $failure recovers using authenticated original',
      (tester) async {
        var reads = 0;
        final good = imageBytes;
        await tester.pumpWidget(
          agentImageTestHost(
            AgentSentImages(
              images: [
                AgentStreamImageInput(
                  dataUrl: '',
                  fileId: 'fixture-id',
                  name: 'Notes.png',
                  localBytes: failure == 'local-with-remote'
                      ? Uint8List.fromList([1, 2, 3])
                      : null,
                ),
              ],
              loadImageThumbnail: (_) async => good,
              loadImageContent: (id) {
                expect(id, 'fixture-id');
                reads++;
                if (reads > 1 || failure == 'local-with-remote') {
                  return Future.value(good);
                }
                if (failure == 'sync') throw StateError('fixture-denied');
                if (failure == 'async') {
                  return Future.error(StateError('fixture-offline'));
                }
                return Future.value(Uint8List.fromList([1, 2, 3]));
              },
            ),
            2,
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(good),
            tester.element(find.byType(MaterialApp)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent-sent-image-0')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('media-viewer-load-error')),
          findsOneWidget,
        );
        expect(find.byType(InteractiveViewer), findsNothing);
        await tester.tap(find.byKey(const ValueKey('media-viewer-retry')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('agent-image-stage')), findsOneWidget);
        expect(reads, failure == 'local-with-remote' ? 1 : 2);
        await tester.tap(find.byKey(const ValueKey('agent-sent-image-close')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('closing a pending original never reopens the image', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    await tester.pumpWidget(
      agentImageTestHost(
        AgentSentImages(
          images: const [
            AgentStreamImageInput(
              dataUrl: '',
              fileId: 'fixture-id',
              name: 'Notes.png',
            ),
          ],
          loadImageContent: (_) => pending.future,
        ),
        1,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('agent-sent-image-close')));
    await tester.pumpAndSettle();
    pending.completeError(StateError('fixture-late-failure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-sent-image-close')), findsNothing);
    expect(find.byKey(const ValueKey('agent-sent-image-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history image loads its authenticated thumbnail by file id', (
    tester,
  ) async {
    var thumbnailLoadCount = 0;
    var originalLoadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentSentImages(
            images: const [
              AgentStreamImageInput(
                dataUrl: '',
                fileId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
                mimeType: 'image/png',
                name: '历史图片.png',
              ),
            ],
            loadImageThumbnail: (fileId) async {
              thumbnailLoadCount += 1;
              expect(fileId, '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518');
              return imageBytes;
            },
            loadImageContent: (fileId) async {
              originalLoadCount += 1;
              expect(fileId, '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518');
              return imageBytes;
            },
          ),
        ),
      ),
    );

    await tester.pump();

    expect(thumbnailLoadCount, 1);
    expect(originalLoadCount, 0);
    expect(find.text('点击查看'), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
    await tester.pump();
    await tester.pump();

    expect(thumbnailLoadCount, 1);
    expect(originalLoadCount, 1);
    expect(
      find.byKey(const ValueKey('agent-sent-image-close')),
      findsOneWidget,
    );
  });
}
