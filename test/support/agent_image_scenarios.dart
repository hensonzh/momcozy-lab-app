import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentImage(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  const name = 'Feeding notes and observations with a long image name.png';
  final bytes = (await rootBundle.load(
    'assets/images/mom/milk-hero.png',
  )).buffer.asUint8List();
  final pending = Completer<Uint8List>();
  var thumbnails = 0, originals = 0;
  final thumbnailIds = <String>[], originalIds = <String>[];
  await tester.pumpWidget(
    _host(
      AgentSentImages(
        images: const [
          AgentStreamImageInput(
            dataUrl: '',
            fileId: 'fixture-image',
            name: name,
            size: 4096,
          ),
        ],
        loadImageThumbnail: (id) async {
          thumbnailIds.add(id);
          thumbnails++;
          return bytes;
        },
        loadImageContent: (id) {
          originalIds.add(id);
          originals++;
          return originals == 1 ? pending.future : Future.value(bytes);
        },
      ),
      scale,
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      MemoryImage(bytes),
      tester.element(find.byType(MaterialApp)),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      ResizeImage(MemoryImage(bytes), width: 336),
      tester.element(find.byType(MaterialApp)),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text(name), findsNothing);
  expect(find.text('4.0 KB'), findsNothing);
  final trigger = find.byKey(const ValueKey('agent-sent-image-0'));
  expect(tester.getSize(trigger).height, greaterThanOrEqualTo(44));
  expect(thumbnails, 1);
  expect(thumbnailIds, ['fixture-image']);
  expect(originals, 0);
  await capture('metadata');
  await tester.tap(trigger);
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text(name), findsOneWidget);
  expect(
    tester
        .renderObject<RenderParagraph>(
          find.descendant(of: find.text(name), matching: find.byType(RichText)),
        )
        .didExceedMaxLines,
    isFalse,
  );
  expect(find.byKey(const ValueKey('media-viewer-loading')), findsOneWidget);
  await capture('loading');
  pending.complete(Uint8List(0));
  await tester.pump();
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('media-viewer-load-error')), findsOneWidget);
  await capture('empty-response');
  await tester.tap(find.byKey(const ValueKey('media-viewer-retry')));
  await tester.pumpAndSettle();
  expect(originals, 2);
  expect(originalIds, ['fixture-image', 'fixture-image']);
  expect(thumbnails, 1);
  expect(find.byKey(const ValueKey('agent-original-image')), findsOneWidget);
  await capture('loaded');
  final stage = find.byKey(const ValueKey('agent-image-stage'));
  final center = tester.getCenter(stage);
  final first = await tester.startGesture(
    center - const Offset(20, 0),
    pointer: 1,
  );
  final second = await tester.startGesture(
    center + const Offset(20, 0),
    pointer: 2,
  );
  await first.moveTo(center - const Offset(80, 0));
  await second.moveTo(center + const Offset(80, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<InteractiveViewer>(stage)
        .transformationController!
        .value
        .getMaxScaleOnAxis(),
    greaterThan(1),
  );
  await capture('zoomed');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('agent-sent-image-close')), findsNothing);
  expect(find.text(name), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}

Widget agentImageTestHost(Widget child, double scale) => _host(child, scale);

Future<void> verifyUnavailableAgentImage(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  await tester.pumpWidget(
    _host(
      AgentSentImages(
        images: [
          AgentStreamImageInput(
            dataUrl: '',
            name: 'Unavailable image.png',
            localBytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      ),
      scale,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Size unknown'), findsNothing);
  await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('media-viewer-load-error')), findsOneWidget);
  expect(find.byKey(const ValueKey('media-viewer-retry')), findsNothing);
  expect(find.byType(InteractiveViewer), findsNothing);
  await capture('unavailable');
  await tester.tap(find.byKey(const ValueKey('agent-sent-image-close')));
  await tester.pumpAndSettle();
  expect(find.text('Unavailable image.png'), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}

Widget _host(Widget child, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    appBar: AppBar(title: const Text('Momcozy AI')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);
