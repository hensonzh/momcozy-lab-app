import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'baby_test_repositories.dart';

class RefreshProfiles extends BabyTestProfiles {
  int reads = 0;
  Completer<void>? gate;
  ProductFailure? failure;
  @override
  Future<List<BabyProfile>> list() async {
    reads++;
    await gate?.future;
    if (failure != null) throw failure!;
    return super.list();
  }
}

class RefreshRecords extends BabyTestRecords {
  int recentReads = 0, curveReads = 0, latestReads = 0;
  Completer<void>? gate;
  @override
  Future<List<BabyGrowthRecord>> latestGrowth(String babyId) async {
    latestReads++;
    await gate?.future;
    return super.latestGrowth(babyId);
  }

  @override
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  }) async {
    if (kind == BabyRecordKind.growth) {
      curveReads++;
    } else {
      recentReads++;
    }
    final page = await super.list(
      babyId: babyId,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      kind: kind,
      offset: offset,
      limit: limit,
    );
    await gate?.future;
    return page;
  }
}

BabyFeedingRecord feed(double ml) => BabyFeedingRecord(
  id: 'feed',
  babyId: 'baby',
  occurredAt: babyTestNow,
  method: BabyFeedingMethod.expressedMilk,
  volumeMl: ml,
);

void main() {
  late RefreshProfiles p;
  late RefreshRecords r;
  late BabyHomeController c;
  late DateTime now;
  setUp(() {
    p = RefreshProfiles();
    r = RefreshRecords()..values = [feed(40)];
    now = babyTestNow;
    c = BabyHomeController(
      profileRepository: p,
      recordRepository: r,
      timezoneProvider: () async => 'Asia/Shanghai',
      now: () => now,
    );
  });
  test(
    'warm profile and record refresh keep data visible and coalesce loads',
    () async {
      await c.load();
      final profiles = c.profiles.value;
      p.gate = Completer();
      final first = c.load();
      final second = c.load();
      expect(p.reads, 2);
      expect(c.baby!.name, 'Luna');
      expect(c.profiles.value, same(profiles));
      expect(c.summary!.measuredIntakeMl, 40);
      p.gate!.complete();
      await Future.wait([first, second]);
      final growth = c.latestGrowth.value;
      r.gate = Completer();
      r.values = [feed(80)];
      final refresh = c.refreshRecords(kind: BabyRecordKind.feeding);
      expect(c.recentRecords.loading, false);
      expect(c.summary!.measuredIntakeMl, 40);
      expect(c.latestGrowth.value, same(growth));
      r.gate!.complete();
      await refresh;
      expect(c.summary!.measuredIntakeMl, 80);
      expect(r.latestReads, 2);
      expect(r.curveReads, 2);
      c.dispose();
    },
  );
  test('growth refresh requests only growth resources', () async {
    await c.load();
    await c.refreshRecords(kind: BabyRecordKind.growth);
    expect(r.recentReads, 1);
    expect(r.latestReads, 2);
    expect(r.curveReads, 2);
    c.dispose();
  });
  test(
    'profile save applies server result without redundant reads or stale overwrite',
    () async {
      await c.load();
      p.gate = Completer();
      final stale = c.load();
      final saved = await p.save(
        BabyProfile(
          id: 'baby',
          name: 'Luna Mae',
          birthDate: babyTestProfile.birthDate,
          sex: BabySex.female,
          version: 1,
        ),
        timezone: 'Asia/Shanghai',
      );
      await c.applySavedProfile(saved);
      expect(c.baby!.name, 'Luna Mae');
      expect(r.recentReads, 1);
      expect(r.latestReads, 1);
      p.values = [babyTestProfile];
      p.gate!.complete();
      await stale;
      expect(c.baby!.name, 'Luna Mae');
      c.dispose();
    },
  );
  test('late same-baby response cannot overwrite newer refresh', () async {
    await c.load();
    final old = Completer<void>();
    r.gate = old;
    r.values = [feed(60)];
    final first = c.refreshRecords(kind: BabyRecordKind.feeding);
    await Future<void>.delayed(Duration.zero);
    r.gate = null;
    r.values = [feed(90)];
    await c.refreshRecords(kind: BabyRecordKind.feeding);
    old.complete();
    await first;
    expect(c.summary!.measuredIntakeMl, 90);
    c.dispose();
  });
  test(
    'offline background reads preserve data but forbidden reads remove it',
    () async {
      await c.load();
      r.loadFailure = const ProductFailure(ProductFailureKind.offline);
      await c.refreshRecords();
      expect(c.summary!.measuredIntakeMl, 40);
      expect(c.recentRecords.failure!.kind, ProductFailureKind.offline);
      p.failure = const ProductFailure(ProductFailureKind.offline);
      await c.load();
      expect(c.baby!.name, 'Luna');
      p.failure = const ProductFailure(ProductFailureKind.forbidden);
      await c.load();
      expect(c.baby, isNull);
      expect(c.recentRecords.value, isNull);
      c.dispose();
    },
  );
  test(
    'snapshot restores immediately but never restores another baby or yesterday totals',
    () async {
      await c.load();
      final snapshot = c.snapshot;
      c.dispose();
      BabyHomeController restore({String? id}) => BabyHomeController(
        profileRepository: p,
        recordRepository: r,
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => now,
        selectedBabyId: id,
        snapshot: snapshot,
      );
      final warm = restore();
      expect(warm.summary!.measuredIntakeMl, 40);
      warm.dispose();
      final other = restore(id: 'other');
      expect(other.summary, isNull);
      expect(other.latestGrowth.value, isNull);
      other.dispose();
      now = now.add(const Duration(days: 1));
      final tomorrow = restore();
      expect(tomorrow.summary, isNull);
      expect(tomorrow.latestGrowth.hasValue, true);
      tomorrow.dispose();
    },
  );
  test(
    'day rollover clears daily totals before waiting for response',
    () async {
      await c.load();
      now = now.add(const Duration(days: 1));
      r.gate = Completer();
      final refresh = c.refreshRecords();
      expect(c.summary, isNull);
      r.gate!.complete();
      await refresh;
      expect(c.summary!.measuredIntakeMl, isNull);
      c.dispose();
    },
  );
  testWidgets(
    'cancel record and unchanged profile perform no additional reads',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BabyHomePage(controller: c, onAsk: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = (p.reads, r.recentReads, r.latestReads, r.curveReads);
      await tester.tap(find.byType(BabyFeedingSummary));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect((p.reads, r.recentReads, r.latestReads, r.curveReads), before);
      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit this baby\'s profile'));
      await tester.pumpAndSettle();
      expect(find.byType(BabyProfileEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect((p.reads, r.recentReads, r.latestReads, r.curveReads), before);
    },
  );
  testWidgets('saved record refreshes recent records without clearing home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BabyHomePage(controller: c, onAsk: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BabyFeedingSummary));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bottle feeding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breast milk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('feeding-volume')), '40');
    await tester.pumpAndSettle();
    r.gate = Completer();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(BabyRecordEditor), findsNothing);
    expect(c.summary!.measuredIntakeMl, 40);
    expect(r.recentReads, 2);
    expect(r.latestReads, 1);
    expect(p.reads, 1);
    r.gate!.complete();
    await tester.pumpAndSettle();
    expect(c.summary!.feedingCount, 2);
  });
}
