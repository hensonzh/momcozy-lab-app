@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';

import '../../support/momcozy_test_fonts.dart';

final _now = DateTime(2026, 9, 20, 15);

class _MeHomeRepository implements MeRepository {
  _MeHomeRepository({MeState? initial}) : state = initial ?? _emptyState;

  static const _emptyState = MeState(
    profile: {'preferred_name': 'Mia', 'actual_delivery_date': '2026-08-30'},
  );

  MeState state;

  @override
  Future<MeState> load(DateTime _) async => state;

  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> value) async {
    state = state.copyWith(profile: {...state.profile, ...value});
    return state.profile;
  }

  @override
  Future<MeConcern> saveConcern(MeConcern value) async => value;

  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> value) async => value;

  @override
  Future<MeObservation> saveRecord(MeObservation value) async => value;
}

MeController _controller(_MeHomeRepository repository) => MeController(
  repository: repository,
  now: () => _now,
  state: repository.state,
);

Future<void> _pumpHome(
  WidgetTester tester,
  MeController controller, {
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xfffbf8f4),
          body: MeHomePage(
            controller: controller,
            onAsk: (_) {},
            onSharedRecord: (_, _) async {},
          ),
          bottomNavigationBar: const MomCozyBottomNavigation(location: '/me'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('greeting and mother name occupy separate lines', (tester) async {
    final repository = _MeHomeRepository(
      initial: const MeState(
        profile: {
          'preferred_name': 'Local App Test',
          'actual_delivery_date': '2026-09-20',
        },
      ),
    );
    await _pumpHome(
      tester,
      _controller(repository),
      size: const Size(393, 844),
      scale: 1,
    );
    final greeting = find.text('Good afternoon');
    final name = find.text('Local App Test');
    expect(greeting, findsOneWidget);
    expect(name, findsOneWidget);
    expect(
      tester.getRect(name).top,
      greaterThanOrEqualTo(tester.getRect(greeting).bottom),
    );
    expect(
      tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('postpartum stage appears below the day in profile shortcut', (
    tester,
  ) async {
    final controller = _controller(_MeHomeRepository());
    await _pumpHome(tester, controller, size: const Size(393, 844), scale: 1);
    final summary = find.text('Postpartum day 21\nEarly recovery');
    expect(summary, findsOneWidget);
    expect(tester.widget<Text>(summary).textAlign, TextAlign.right);
    expect(find.text('Postpartum day 21 · Early recovery'), findsNothing);
  });

  test('Pumping is a default record without overriding saved order', () {
    expect(const MeState().visibleMetrics, [
      MeMetric.feed,
      MeMetric.pump,
      MeMetric.energy,
      MeMetric.sleep,
    ]);
    expect(
      const MeState(
        order: [MeMetric.sleep, MeMetric.feed, MeMetric.energy],
      ).visibleMetrics,
      [MeMetric.sleep, MeMetric.feed, MeMetric.energy, MeMetric.pump],
    );
  });

  testWidgets('Me home shows Pumping in Today\'s records by default', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      _controller(_MeHomeRepository()),
      size: const Size(393, 844),
      scale: 1,
    );
    await tester.scrollUntilVisible(
      find.text('Pumping'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pumping'), findsOneWidget);
  });

  testWidgets('Manage records is right aligned with the section title', (
    tester,
  ) async {
    final controller = _controller(_MeHomeRepository());
    await _pumpHome(tester, controller, size: const Size(393, 844), scale: 1);
    final title = tester.getRect(find.text("Today's records"));
    final action = tester.getRect(find.text('Manage records ›'));
    expect(action.right, closeTo(393 - 16, 1));
    expect(action.center.dy, closeTo(title.center.dy, 1));
  });

  for (final width in [320.0, 393.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('empty metric value stays on one line at $width/$scale', (
        tester,
      ) async {
        final cardWidth = (width - 44) / 2;
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final kind in [
          MeMetric.feed,
          MeMetric.energy,
          MeMetric.sleep,
          MeMetric.mood,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SizedBox(
                  width: cardWidth,
                  child: MeHomeMetric(
                    kind: kind,
                    width: cardWidth,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
          final text = find.text('No entry yet');
          expect(text, findsOneWidget);
          expect(tester.widget<Text>(text).maxLines, 1);
          expect(
            tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
            isFalse,
          );
          final card = tester.getRect(find.byType(MeHomeMetric));
          expect(
            tester.getRect(text).right,
            lessThanOrEqualTo(card.right - 10),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('Me home empty state matches Figma at ${width.toInt()}px', (
      tester,
    ) async {
      final repository = _MeHomeRepository();
      final controller = _controller(repository);
      await _pumpHome(tester, controller, size: Size(width, 844), scale: 1);
      expect(find.text('Choose what you\'d like to work on'), findsOneWidget);
      if (width < 400) {
        await tester.scrollUntilVisible(
          find.text('Energy'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('No entry yet'), findsAtLeastNWidgets(1));
        await tester.drag(find.byType(ListView), const Offset(0, 4000));
        await tester.pumpAndSettle();
      } else {
        expect(find.text('No entry yet'), findsNWidgets(4));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/me_home/me-home-empty-${width.toInt()}.png',
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('Me home fits long names and 2x English text at $width', (
      tester,
    ) async {
      final repository = _MeHomeRepository(
        initial: _MeHomeRepository._emptyState.copyWith(
          profile: {
            'preferred_name':
                'Alexandra-Margaret Catherine Elizabeth Chen Richardson',
            'actual_delivery_date': '2026-08-30',
          },
        ),
      );
      await _pumpHome(
        tester,
        _controller(repository),
        size: Size(width, 844),
        scale: 2,
      );
      final greeting = find.text('Good afternoon');
      final name = find.text(
        'Alexandra-Margaret Catherine Elizabeth Chen Richardson',
      );
      final profile = find.text('My profile ›');
      expect(greeting, findsOneWidget);
      expect(name, findsOneWidget);
      expect(profile, findsOneWidget);
      expect(
        tester.getRect(name).top,
        greaterThanOrEqualTo(tester.getRect(greeting).bottom),
      );
      final paragraph = tester.renderObject<RenderParagraph>(name);
      expect(paragraph.didExceedMaxLines, isFalse);
      final titleBounds = tester.getRect(name);
      final profileBounds = tester.getRect(profile);
      expect(titleBounds.left, greaterThanOrEqualTo(0));
      expect(titleBounds.right, lessThanOrEqualTo(width));
      expect(profileBounds.right, lessThanOrEqualTo(width));
      expect(titleBounds.overlaps(profileBounds), isFalse);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Energy'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Me home active concern state matches Figma', (tester) async {
    final repository = _MeHomeRepository(
      initial: _MeHomeRepository._emptyState.copyWith(
        concerns: [
          const MeConcern(id: 'comfort', issues: [MeIssue.comfort]),
        ],
      ),
    );
    final controller = _controller(repository);
    await _pumpHome(tester, controller, size: const Size(393, 844), scale: 1);
    expect(find.text('Discomfort while nursing or pumping'), findsOneWidget);
    expect(find.text('My focus ›'), findsOneWidget);
    expect(find.text('No entry yet'), findsNWidgets(5));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/me_home/me-home-active-393.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
