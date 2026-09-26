import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/media/presentation/media_viewer_header.dart';
import 'package:momcozy_flutter_app/features/media/presentation/media_viewer_page.dart';

void main() {
  testWidgets('legacy route title stays out of visual and semantic labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final extra = <String, String>{
      'kind': 'image',
      'url': '/v1/assets/photo-1',
      'title': 'Cozymate 哺乳照片',
    };
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MediaViewerPage(
            path: '/media-viewer',
            title: 'Media',
            summary: '',
            icon: Icons.image,
            accent: Colors.black,
            routeExtra: extra,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Image'), findsOneWidget);
      expect(find.textContaining('哺乳'), findsNothing);
      expect(find.textContaining('Cozymate'), findsNothing);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().label.contains('Image'),
        ),
        findsWidgets,
      );
      expect(
        find.semantics.byPredicate(
          (node) => RegExp(
            r'哺乳|cozy[\s-]*mate',
            caseSensitive: false,
          ).hasMatch(node.getSemanticsData().label),
        ),
        findsNothing,
      );
      expect(extra['title'], 'Cozymate 哺乳照片');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('English media title updates old branding only in the UI', (
    tester,
  ) async {
    final extra = <String, String>{
      'kind': 'video',
      'url': '/v1/assets/video-1',
      'title': 'Cozy Mate feeding guide',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: MediaViewerPage(
          path: '/media-viewer',
          title: 'Media',
          summary: '',
          icon: Icons.video_library,
          accent: Colors.black,
          routeExtra: extra,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Momcozy AI feeding guide'), findsOneWidget);
    expect(find.textContaining('Cozy Mate'), findsNothing);
    expect(extra['title'], 'Cozy Mate feeding guide');
  });

  testWidgets('bilingual deep link uses its reviewed English title', (
    tester,
  ) async {
    final route = Uri(
      path: '/media-viewer',
      queryParameters: const {
        'kind': 'pdf',
        'url': '/v1/assets/document-1',
        'title': '喂养姿势与照护指南 · Feeding positions and care',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaViewerPage(
          path: '/media-viewer',
          title: 'Media',
          summary: '',
          icon: Icons.picture_as_pdf,
          accent: Colors.black,
          routeUri: route,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Feeding positions and care'), findsOneWidget);
    expect(find.textContaining('喂养'), findsNothing);
    expect(
      route.queryParameters['title'],
      '喂养姿势与照护指南 · Feeding positions and care',
    );
  });

  testWidgets('other-script media titles use English half or kind fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (raw, expected) in [
      (
        'Οδηγός θηλασμού · Feeding positions and care',
        'Feeding positions and care',
      ),
      ('מדריך להנקה', 'Image'),
      ('คู่มือการให้นม', 'Image'),
    ]) {
      final extra = <String, String>{
        'kind': 'image',
        'url': '/v1/assets/photo-1',
        'title': raw,
      };
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MediaViewerPage(
            path: '/media-viewer',
            title: 'Media',
            summary: '',
            icon: Icons.image,
            accent: Colors.black,
            routeExtra: extra,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining(raw), findsNothing);
      expect(extra['title'], raw);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('long English resource titles remain readable at 320px and 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = 'Feeding observations and notes from the past month ' * 5;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              MediaViewerHeader(title: title, onBack: () {}),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = find.text(title);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      tester.getSize(find.byType(MediaViewerHeader)).height,
      lessThan(210),
    );
    final scrollable = find.descendant(
      of: find.byType(MediaViewerHeader),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollable, findsOneWidget);
    expect(tester.getSize(scrollable).height, greaterThan(100));
    final before = tester
        .state<ScrollableState>(
          find.descendant(of: scrollable, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    await tester.drag(scrollable, const Offset(0, -80));
    await tester.pumpAndSettle();
    final after = tester
        .state<ScrollableState>(
          find.descendant(of: scrollable, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    expect(after, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}
