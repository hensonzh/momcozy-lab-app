import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_concerns.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_profile_page.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_manage_records.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_design.dart';
import '../../support/momcozy_test_fonts.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_record_sheet.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_shared_record_sheet.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import '../baby/baby_test_repositories.dart';

class TestMeRepository implements MeRepository {
  MeState state = const MeState(
    profile: {'preferred_name': 'Mia', 'actual_delivery_date': '2026-08-30'},
  );
  int reads = 0, saves = 0;
  bool fail = false;
  Completer<MeState>? pending;
  @override
  Future<MeState> load(DateTime _) async {
    reads++;
    return pending?.future ?? state;
  }

  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> v) async {
    saves++;
    if (fail) throw StateError('offline');
    state = state.copyWith(profile: {...state.profile, ...v});
    return state.profile;
  }

  @override
  Future<MeConcern> saveConcern(MeConcern v) async {
    saves++;
    if (fail) throw StateError('offline');
    return v;
  }

  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> v) async {
    saves++;
    if (fail) throw StateError('offline');
    return v;
  }

  @override
  Future<MeObservation> saveRecord(MeObservation v) async {
    saves++;
    if (fail) throw StateError('offline');
    return v;
  }
}

final now = DateTime(2026, 9, 20, 15);
MeController controller(TestMeRepository repo) =>
    MeController(repository: repo, now: () => now, state: repo.state);
Future<void> setup(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(393, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, home: child),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name, Widget child) async {
  final key = GlobalKey();
  await setup(tester, RepaintBoundary(key: key, child: child));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final w = element.widget as Image;
      await precacheImage(w.image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/design-evidence/me/actual/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  expect(tester.takeException(), isNull);
  final back = find.byTooltip('Back');
  if (back.evaluate().isNotEmpty) {
    expect(tester.getTopLeft(back.first).dx, lessThan(24));
  }
}

void main() {
  test(
    'legacy choice values display in English without changing stored data',
    () {
      final record = MeObservation.fromJson({
        'id': 'legacy-energy',
        'kind': 'energy',
        'occurred_at': '2026-09-20T10:00:00Z',
        'value': '有力气',
        'fields': <String, Object?>{},
      });
      expect(record.displayValue, 'Energized');
      expect(record.toJson()['value'], '有力气');
      expect(
        MeObservation(
          id: 'english',
          kind: MeMetric.latch,
          occurredAt: now,
          value: 'Stayed latched',
        ).displayValue,
        'Stayed latched',
      );
    },
  );

  test(
    'historical structured observations keep raw data but display in English',
    () {
      final legacy = <(MeMetric, String, Map<String, Object?>, String)>[
        (MeMetric.pain, '疼痛 3 分', {'pain': 3}, '3 / 10'),
        (MeMetric.pump, '泵奶 80 毫升', {'volume_ml': 80}, '80 ml'),
        (MeMetric.storage, '保存 45 毫升', {'volume_ml': 45.5}, '45.5 ml'),
        (MeMetric.pump, 'leche', {'volume_ml': 60}, '60 ml'),
        (MeMetric.mood, '不认识的状态', {}, 'Review saved record'),
        (MeMetric.latch, 'CozyMate', {}, 'Review saved record'),
        (MeMetric.pain, '疼痛', {}, 'Review saved record'),
        (MeMetric.pain, '有力气', {'pain': 4}, '4 / 10'),
        (MeMetric.mood, '愿意吃', {}, 'Review saved record'),
        (MeMetric.feed, 'leche materna', {}, 'Review saved record'),
        (MeMetric.diaper, '4 cambios', {}, 'Review saved record'),
        (MeMetric.weight, 'Cozymate 4 kg', {}, 'Review saved record'),
        (MeMetric.feed, '— min', {}, '— min'),
        (MeMetric.feed, '90 ml', {}, '90 ml'),
        (MeMetric.diaper, '8 diaper changes', {}, '8 diaper changes'),
        (MeMetric.weight, '4.2 kg', {}, '4.2 kg'),
      ];
      for (final (kind, raw, fields, expected) in legacy) {
        final record = MeObservation(
          id: 'historic-${kind.name}',
          kind: kind,
          occurredAt: now,
          value: raw,
          fields: fields,
        );
        expect(record.displayValue, expected, reason: raw);
        expect(record.toJson()['value'], raw);
        expect(record.toJson()['fields'], fields);
      }
      expect(
        MeObservation(
          id: 'current-pain',
          kind: MeMetric.pain,
          occurredAt: now,
          value: '3 / 10',
          fields: const {'pain': 3},
        ).displayValue,
        '3 / 10',
      );
    },
  );

  for (final scale in [1.5, 2.0]) {
    testWidgets(
      'unreviewed historic energy stays within the Me card at 320px/$scale',
      (tester) async {
        final repo = TestMeRepository()
          ..state = MeState(
            profile: const {'preferred_name': 'Mia'},
            records: [
              MeObservation(
                id: 'historic-energy',
                kind: MeMetric.energy,
                occurredAt: now,
                value: '不认识的状态',
              ),
            ],
          );
        final c = controller(repo);
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: MeHomePage(
                controller: c,
                onAsk: (_) {},
                onSharedRecord: (_, _) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final text = find.text('Review saved record');
        await tester.scrollUntilVisible(
          text,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('不认识的状态'), findsNothing);
        final card = find.ancestor(of: text, matching: find.byType(Ink)).first;
        final labelRect = tester.getRect(text);
        final dateRect = tester.getRect(find.text('Today 15:00'));
        expect(labelRect.bottom, lessThan(dateRect.top));
        expect(dateRect.bottom, lessThanOrEqualTo(tester.getRect(card).bottom));
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 1,
          ),
        );
        expect(tester.takeException(), isNull);
        if (scale == 2) {
          final imageContext = tester.element(find.byType(MeHomePage));
          await tester.runAsync(() async {
            await Future.wait([
              for (final image in tester.widgetList<Image>(find.byType(Image)))
                precacheImage(image.image, imageContext),
            ]);
          });
          await tester.pumpAndSettle();
          await expectLater(
            find.ancestor(of: text, matching: find.byType(MeHomeMetric)),
            matchesGoldenFile(
              '../../goldens/design_system/me-historic-observation-grid-320-2x.png',
            ),
          );
        }
      },
    );
  }

  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });
  test(
    'multi concerns deduplicate records and ended concerns retain records',
    () {
      final state = MeState(
        concerns: [
          const MeConcern(
            id: 'a',
            issues: [MeIssue.comfort, MeIssue.feeding, MeIssue.intake],
          ),
        ],
      );
      expect(state.visibleMetrics.toSet().length, state.visibleMetrics.length);
      expect(metricsFor(state.active.expand((e) => e.issues)).length, 6);
    },
  );
  test('late read does not overwrite a successful save', () async {
    final repo = TestMeRepository()..pending = Completer<MeState>();
    final c = controller(repo);
    final read = c.load();
    await c.saveProfile({'preferred_name': 'New'});
    repo.pending!.complete(const MeState(profile: {'preferred_name': 'Old'}));
    await read;
    expect(c.state!.profile['preferred_name'], 'New');
    c.dispose();
  });
  test('failed refresh preserves content and exposes retry', () async {
    final repo = TestMeRepository()..pending = Completer<MeState>();
    final c = controller(repo);
    final read = c.load();
    expect(c.state!.profile['preferred_name'], 'Mia');
    repo.pending!.completeError(StateError('offline'));
    await read;
    expect(c.state!.profile['preferred_name'], 'Mia');
    expect(c.error, isNotNull);
    c.dispose();
  });
  test(
    'cross-day reads discard the previous day even when it finishes last',
    () async {
      var clock = now;
      final repo = TestMeRepository()..pending = Completer<MeState>();
      final first = repo.pending!;
      final c = MeController(
        repository: repo,
        now: () => clock,
        state: repo.state,
      );
      final yesterday = c.load();
      clock = now.add(const Duration(days: 1));
      repo.pending = Completer<MeState>();
      final today = c.load();
      repo.pending!.complete(
        const MeState(profile: {'preferred_name': 'Today'}),
      );
      await today;
      first.complete(const MeState(profile: {'preferred_name': 'Yesterday'}));
      await yesterday;
      expect(repo.reads, 2);
      expect(c.state!.profile['preferred_name'], 'Today');
      expect(c.loading, isFalse);
      c.dispose();
    },
  );
  test(
    'partial refresh failure retains existing shared records without duplicates',
    () async {
      final record = MeObservation(
        id: 'feed',
        kind: MeMetric.feed,
        occurredAt: now,
        value: '90 ml',
      );
      final repo = TestMeRepository()..state = MeState(records: [record]);
      final c = controller(repo);
      repo.state = const MeState(failedMetrics: {MeMetric.feed});
      await c.load();
      expect(c.latest(MeMetric.feed)?.value, '90 ml');
      expect(c.state!.failedMetrics, {MeMetric.feed});
      repo.state = MeState(records: [record]);
      await c.load();
      expect(c.state!.records, hasLength(1));
      expect(c.state!.failedMetrics, isEmpty);
      c.dispose();
    },
  );
  test('daily diaper summary replaces corresponding event counts', () {
    final repo = TestMeRepository()
      ..state = MeState(
        records: [
          MeObservation(
            id: 'event',
            kind: MeMetric.diaper,
            occurredAt: now,
            value: '1 次',
            fields: const {'wet': 1, 'stool': 0, 'count': 1},
          ),
          MeObservation(
            id: 'daily',
            kind: MeMetric.diaper,
            occurredAt: now,
            value: '8 次',
            fields: const {'daily_summary': true, 'wet': 6, 'stool': 2},
          ),
        ],
      );
    final c = controller(repo);
    expect(c.latest(MeMetric.diaper)?.value, '8 times');
    c.dispose();
  });
  testWidgets('drag handle starts immediately across its full touch area', (
    tester,
  ) async {
    final repo = TestMeRepository();
    final c = controller(repo);
    await setup(tester, MeManageRecords(controller: c));

    final handle = find.byType(ReorderableDragStartListener).at(2);
    final bounds = tester.getRect(handle);
    expect(bounds.size, const Size(46, 58));
    final gesture = await tester.startGesture(
      bounds.topLeft + const Offset(4, 5),
    );
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Energy')).dy,
      greaterThan(tester.getTopLeft(find.text('Sleep')).dy),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(repo.saves, 0);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(
      c.state!.visibleMetrics.indexOf(MeMetric.energy),
      greaterThan(c.state!.visibleMetrics.indexOf(MeMetric.sleep)),
    );
    c.dispose();
  });

  testWidgets('long-pressing a drag handle reorders and enables Save', (
    tester,
  ) async {
    final repo = TestMeRepository();
    final c = controller(repo);
    await setup(tester, MeManageRecords(controller: c));

    final handle = find.byIcon(Icons.drag_handle).at(2);
    final start = tester.getCenter(handle);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Energy')).dy,
      greaterThan(tester.getTopLeft(find.text('Sleep')).dy),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(repo.saves, 0);
    c.dispose();
  });

  testWidgets(
    'sorting enables only when changed; revert disables without saving',
    (tester) async {
      final repo = TestMeRepository();
      final c = controller(repo);
      await setup(tester, MeManageRecords(controller: c));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Move to top').first);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Move to top').first);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repo.saves, 0);
      c.dispose();
    },
  );
  testWidgets('onboarding values appear in Me profile summary', (tester) async {
    final repo = TestMeRepository()
      ..state = const MeState(
        profile: {
          'preferred_name': 'Mia',
          'age': 32,
          'actual_delivery_date': '2026-09-20',
          'delivery_count': 2,
          'baby_count': 6,
          'current_delivery_method': 'assisted_vaginal',
          'gestation_weeks': 39,
          'gestation_days': 2,
          'feeding_methods': ['direct', 'formula'],
        },
      );
    final c = controller(repo);
    await setup(tester, MeProfilePage(controller: c));
    expect(find.textContaining('Six babies'), findsOneWidget);
    expect(find.textContaining('Assisted birth'), findsOneWidget);
    expect(
      find.text('Current feeding methods  Direct breastfeeding, Formula'),
      findsOneWidget,
    );
    expect(find.textContaining('39 wk 2 days'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit ›').at(2));
    await tester.tap(find.text('Edit ›').at(2));
    await tester.pumpAndSettle();
    expect(find.byType(MeProfileEditor), findsOneWidget);
    final choices = find.byType(MeChoice);
    expect(tester.widget<MeChoice>(choices.first).selected, isTrue);
    await tester.ensureVisible(find.text('Not sure yet').first);
    await tester.tap(find.text('Not sure yet').first);
    await tester.pumpAndSettle();
    expect(tester.widget<MeChoice>(choices.first).selected, isFalse);
    expect(repo.saves, 0);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.state.profile['feeding_methods'], ['unknown']);
    expect(find.text('Current feeding methods  Not sure yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('legacy profile choices do not expose unreviewed catalog text', (
    tester,
  ) async {
    final repo = TestMeRepository()
      ..state = const MeState(
        profile: {
          'preferred_name': 'Mia',
          'age': 30,
          'delivery_count': 3,
          'baby_count': '双胞胎',
          'current_delivery_method': '剖宫产',
          'feeding_methods': ['direct', '瓶喂', 'CozyMate'],
          'feeding_preference': 'lactancia',
        },
      );
    final c = controller(repo);
    await setup(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: MeProfilePage(controller: c),
      ),
      size: const Size(320, 568),
    );
    expect(find.textContaining('Third or later'), findsOneWidget);
    expect(find.textContaining('Direct breastfeeding'), findsOneWidget);
    final review = find.textContaining('Review saved choice');
    expect(review, findsWidgets);
    for (final label in review.evaluate()) {
      final paragraph = label.findRenderObject()! as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 1,
        ),
      );
    }
    for (final raw in ['双胞胎', '剖宫产', '瓶喂', 'CozyMate', 'lactancia']) {
      expect(find.textContaining(raw), findsNothing);
    }
    expect(c.state!.profile, repo.state.profile);
    final feedingEdit = find.text('Edit ›').at(2);
    await tester.ensureVisible(feedingEdit);
    await tester.tap(feedingEdit);
    await tester.pumpAndSettle();
    expect(find.byType(MeProfileEditor), findsOneWidget);
    await tester.ensureVisible(find.text('Formula'));
    await tester.tap(find.text('Formula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.state.profile['feeding_methods'], ['direct', 'formula']);
    expect(repo.state.profile['baby_count'], '双胞胎');
    expect(find.byType(MeProfilePage), findsOneWidget);
    await c.saveProfile({
      'feeding_methods': <String>['unknown'],
    });
    await tester.pumpAndSettle();
    expect(find.text('Current feeding methods  Not sure yet'), findsOneWidget);
    expect(repo.state.profile['feeding_methods'], ['unknown']);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('profile failure preserves draft and uses approved error', (
    tester,
  ) async {
    final repo = TestMeRepository()..fail = true;
    final c = controller(repo);
    await setup(tester, MeProfileEditor(controller: c, group: 0));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextFormField).first, '新名字');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(find.text('新名字'), findsOneWidget);
    expect(repo.reads, 0);
    c.dispose();
  });
  testWidgets(
    'concern multi selection renders verbatim labels with record union',
    (tester) async {
      final c = controller(TestMeRepository());
      await setup(tester, MeConcernFlow(controller: c));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(MeIssue.comfort.label));
      await tester.tap(find.text(MeIssue.feeding.label));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text(MeIssue.comfort.label), findsOneWidget);
      expect(find.text(MeIssue.feeding.label), findsOneWidget);
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Suggested records for you'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      c.dispose();
    },
  );
  testWidgets('reminder toggle uses On and Off at 320px and 2x text', (
    tester,
  ) async {
    final c = controller(TestMeRepository());
    await setup(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: MeConcernFlow(controller: c),
      ),
      size: const Size(320, 568),
    );
    await tester.ensureVisible(find.text(MeIssue.comfort.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MeIssue.comfort.label));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Remind me to log'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Close'), findsNothing);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('profile card Edit affordance stays on one line at 320px/2x', (
    tester,
  ) async {
    final repo = TestMeRepository()
      ..state = const MeState(
        profile: {
          'preferred_name': 'Alexandra Catherine Morrison',
          'age': 33,
          'actual_delivery_date': '2026-08-30',
        },
      );
    final c = controller(repo);
    await setup(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: MeProfilePage(controller: c),
      ),
      size: const Size(320, 568),
    );
    final edit = find.text('Edit ›').first;
    final text = tester.widget<Text>(edit);
    final natural = TextPainter(
      text: TextSpan(text: 'Edit ›', style: text.style),
      textScaler: const TextScaler.linear(2),
      textDirection: TextDirection.ltr,
    )..layout();
    final render = tester.renderObject<RenderParagraph>(edit);
    expect(render.size.width, greaterThanOrEqualTo(natural.width - 1));
    final name = find.textContaining('Alexandra Catherine Morrison');
    expect(name, findsOneWidget);
    final summary = tester.renderObject<RenderParagraph>(name);
    expect(summary.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/me-profile-long-edit-320-2x.png',
      ),
    );
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(MeProfileEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    natural.dispose();
    c.dispose();
  });
  testWidgets('captures home with navigation', (tester) async {
    final c = controller(TestMeRepository());
    await capture(
      tester,
      'home',
      Scaffold(
        backgroundColor: const Color(0xfffbf8f4),
        body: MeHomePage(
          controller: c,
          onAsk: (_) {},
          onSharedRecord: (_, _) async {},
        ),
        bottomNavigationBar: const MomCozyBottomNavigation(location: '/me'),
      ),
    );
  });
  testWidgets('captures forms and sorting', (tester) async {
    for (final group in [0, 1, 2, 3]) {
      final c = controller(TestMeRepository());
      await capture(
        tester,
        'profile-$group',
        MeProfileEditor(controller: c, group: group),
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
    final c = controller(TestMeRepository());
    await capture(tester, 'manager', MeManageRecords(controller: c));
    c.dispose();
  });
  testWidgets('captures active concerns, empty state and profile overview', (
    tester,
  ) async {
    final repo = TestMeRepository();
    var c = controller(repo);
    await capture(
      tester,
      'concerns-empty',
      MeConcernsPage(controller: c, onRecord: (_) async {}),
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    repo.state = repo.state.copyWith(
      concerns: [
        const MeConcern(id: 'a', issues: [MeIssue.comfort]),
      ],
    );
    c = controller(repo);
    await capture(
      tester,
      'active-home',
      Scaffold(
        backgroundColor: const Color(0xfffbf8f4),
        body: MeHomePage(
          controller: c,
          onAsk: (_) {},
          onSharedRecord: (_, _) async {},
        ),
        bottomNavigationBar: const MomCozyBottomNavigation(location: '/me'),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    c = controller(repo);
    await capture(
      tester,
      'concern-detail',
      MeConcernDetail(controller: c, concernId: 'a', onRecord: (_) async {}),
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    c = controller(repo);
    c.state = c.state!.copyWith(
      profile: {...c.state!.profile, 'actual_delivery_date': '2026-08-31'},
    );
    await capture(tester, 'profile', MeProfilePage(controller: c));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('captures selected confirmation', (tester) async {
    final c = controller(TestMeRepository());
    final key = GlobalKey();
    await setup(
      tester,
      RepaintBoundary(
        key: key,
        child: MeConcernFlow(
          controller: c,
          initial: const MeConcern(id: 'capture', issues: [MeIssue.comfort]),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/design-evidence/me/actual/confirmation.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('captures record sheets and settings above the root navigation', (
    tester,
  ) async {
    final c = controller(TestMeRepository());
    final key = GlobalKey();
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext host;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) {
              host = context;
              return Scaffold(
                backgroundColor: const Color(0xfffbf8f4),
                body: MeHomePage(
                  controller: c,
                  onAsk: (_) {},
                  onSharedRecord: (_, _) async {},
                ),
                bottomNavigationBar: const MomCozyBottomNavigation(
                  location: '/me',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> save(String name) async {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/design-evidence/me/actual/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    unawaited(showMeRecordSheet(host, c, MeMetric.energy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doing well'));
    await tester.pumpAndSettle();
    await save('energy');
    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();
    expect(c.latest(MeMetric.energy)?.value, 'Doing well');
    expect(find.byType(MeRecordSheet), findsNothing);
    unawaited(showMeNotificationSettings(host));
    await tester.pumpAndSettle();
    await save('settings');
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'shared weight keeps measurement source and persists to Baby repository',
    (tester) async {
      final repo = BabyTestRecords();
      final editor = BabyRecordEditorController(
        repository: repo,
        baby: babyTestProfile,
        timezone: 'Asia/Shanghai',
        now: () => babyTestNow,
        kind: BabyRecordKind.growth,
      );
      editor.setGrowthValue(GrowthMetric.weight, '4.2');
      editor.setMeasurementSource('clinic');
      await capture(
        tester,
        'weight',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MeSharedRecordSheet(controller: editor),
          ),
        ),
      );
      final saved = (await editor.save())!.single as BabyGrowthRecord;
      expect(saved.measurementSource, 'clinic');
      expect(saved.savedAt, babyTestNow);
      expect(repo.values, hasLength(1));
      editor.dispose();
    },
  );
  testWidgets(
    'concern confirmation remains scrollable at 320 with double text scale',
    (tester) async {
      final c = controller(TestMeRepository());
      await setup(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: MeConcernFlow(
            controller: c,
            initial: const MeConcern(
              id: 'large',
              issues: [MeIssue.comfort, MeIssue.feeding],
            ),
          ),
        ),
        size: const Size(320, 568),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      final lastMetric = find.text(MeMetric.latch.label);
      await tester.ensureVisible(lastMetric);
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: lastMetric,
        matching: find.byType(MeMetricRow),
      );
      expect(
        tester.getRect(lastMetric).bottom,
        lessThanOrEqualTo(tester.getRect(row).bottom - 7),
      );
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
  testWidgets('manage records rows fit English labels at 320 and 2x text', (
    tester,
  ) async {
    final repo = TestMeRepository();
    final c = controller(repo);
    await setup(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: MeManageRecords(controller: c),
      ),
      size: const Size(320, 568),
    );
    expect(find.text('Show on home'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to top').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    for (var i = 0; i < 4; i++) {
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    repo.fail = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final error = find.text('Could not save. Please try again.');
    expect(error, findsOneWidget);
    expect(tester.getRect(error).bottom, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('manage records fits at 320 and 1.5x text', (tester) async {
    final c = controller(TestMeRepository());
    await setup(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.5),
        ),
        child: MeManageRecords(controller: c),
      ),
      size: const Size(320, 568),
    );
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('small viewport forms scroll with keyboard', (tester) async {
    final c = controller(TestMeRepository());
    await setup(
      tester,
      MeProfileEditor(controller: c, group: 3),
      size: const Size(320, 568),
    );
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.tap(find.byType(TextFormField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    c.dispose();
  });
}
