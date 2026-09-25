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
      expect(metricsFor(state.active.expand((e) => e.issues)).length, 7);
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
    await tester.tap(find.text('Energized'));
    await tester.pumpAndSettle();
    await save('energy');
    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();
    expect(c.latest(MeMetric.energy)?.value, 'Energized');
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
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
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
