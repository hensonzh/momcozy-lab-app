import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/lactation/lactation_record.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_profile.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/mom/application/mother_home_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/application/mom_home_view_data.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_home_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/expert_support_section.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

final handoffNow = DateTime(2026, 9, 13, 15);
final handoffDate = LocalDate(2026, 9, 13);

class HandoffProfile extends Fake implements MotherProfileRepository {
  bool hasDelivery = true;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<MotherProfile> get() async {
    await gate?.future;
    if (fail) throw const ProductFailure(ProductFailureKind.unavailable);
    return MotherProfile(
      userId: 'mom',
      displayName: 'Mia',
      timezone: 'Asia/Shanghai',
      deliveryDate: hasDelivery ? LocalDate(2026, 8, 23) : null,
    );
  }
}

class HandoffDiary extends Fake implements MotherDiaryRepository {
  MotherDiary value = const MotherDiary();
  bool fail = false;
  Completer<void>? gate;
  int saves = 0;
  @override
  Future<List<MotherDiaryEntry>> list({
    required LocalDate start,
    required LocalDate end,
  }) async {
    await gate?.future;
    if (fail) throw const ProductFailure(ProductFailureKind.unavailable);
    return [
      MotherDiaryEntry(
        id: 'diary',
        ownerUserId: 'mom',
        date: handoffDate,
        diary: value,
        version: saves + 1,
        updatedAt: handoffNow,
      ),
    ];
  }

  @override
  Future<MotherDiaryEntry> save({
    required LocalDate date,
    required MotherDiary diary,
    required int expectedVersion,
  }) async {
    saves++;
    value = diary;
    return MotherDiaryEntry(
      id: 'diary',
      ownerUserId: 'mom',
      date: date,
      diary: diary,
      version: expectedVersion + 1,
      updatedAt: handoffNow,
    );
  }
}

class HandoffMilk extends Fake implements LactationRepository {
  List<LactationRecord> records = [];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<List<LactationRecord>> list(DayWindow window) async {
    await gate?.future;
    if (fail) throw const ProductFailure(ProductFailureKind.unavailable);
    return records;
  }

  @override
  Future<LactationRecord> create(
    LactationObservation observation, {
    required String idempotencyKey,
  }) async {
    final record = LactationRecord(
      id: 'created-${records.length}',
      ownerUserId: 'mom',
      version: 1,
      observation: observation,
    );
    records = [...records, record];
    return record;
  }
}

class HandoffInsight implements MomDailyInsightRepository {
  int reads = 0;
  bool fail = false;
  MomDailyInsight value = const MomDailyInsight(
    status: MomInsightStatus.ready,
    eyebrow: 'Cozymate · 基于你的近期记录',
    title: '昨夜休息偏少，\n今天先把恢复放在第一位',
    body: '结合睡眠、精力和泌乳趋势，建议降低强度、优先补充休息，并留意乳房不适。',
  );
  @override
  Future<MomDailyInsight> read(LocalDate date) async {
    reads++;
    if (fail) throw const ProductFailure(ProductFailureKind.unavailable);
    return value;
  }
}

class HandoffCare extends Fake implements CareRepository {
  bool purchased = false, fail = false;
  CareEpisodeStatus status = CareEpisodeStatus.active;
  int remaining = 3;
  DateTime? endsAt;
  CareEpisode get episode => CareEpisode(
    id: 'episode',
    orderId: 'order',
    packageId: 'package',
    status: status,
    stage: CareStage.activeCare,
    totalSessions: 3,
    remainingSessions: remaining,
    version: 1,
    assignedIbclcId: 'expert',
    endsAt: endsAt,
  );
  static const package = ServicePackage(
    id: 'package',
    name: '新手妈妈开奶陪跑计划',
    subtitle: '',
    description: '',
    durationDays: 14,
    sessions: 3,
    priceMinor: 0,
    currency: 'USD',
    highlights: [],
    expertServices: [],
    continuousServices: [],
  );
  static const provider = CareProvider(
    id: 'expert',
    displayName: 'Jamie Lee',
    timezone: 'Asia/Shanghai',
    regions: [],
    languages: [],
    bio: '',
    sandbox: true,
  );
  @override
  Future<ServiceCatalog> catalog() async => const ServiceCatalog(
    packages: [package],
    providers: [provider],
    availableRegions: [],
    paymentMode: PaymentMode.sandbox,
  );
  @override
  Future<CareOverview> overview() async {
    if (fail) throw const ProductFailure(ProductFailureKind.unavailable);
    return CareOverview(orders: [], episodes: [if (purchased) episode]);
  }
}

class HandoffScenario {
  HandoffScenario({bool recorded = false, bool purchased = false}) {
    care.purchased = purchased;
    if (recorded) {
      diary.value = const MotherDiary(
        rest: MotherRest(total: SleepTotalBand.fourToFiveHours),
        body: MotherBody(energy: BodyEnergy.energized, impact: BodyImpact.none),
        mood: MotherMood(tone: MoodTone.steady),
      );
      milk.records = [
        for (var i = 0; i < 2; i++)
          LactationRecord(
            id: 'pump$i',
            ownerUserId: 'mom',
            version: 1,
            observation: PumpObservation(
              occurredAt: handoffNow.subtract(Duration(hours: i + 1)),
              side: BreastSide.left,
              volumeMl: 55,
            ),
          ),
        for (var i = 0; i < 2; i++)
          LactationRecord(
            id: 'feed$i',
            ownerUserId: 'mom',
            version: 1,
            observation: NursingObservation(
              occurredAt: handoffNow.subtract(Duration(hours: i + 1)),
              side: BreastSide.left,
              durationMinutes: 10,
            ),
          ),
      ];
    }
  }
  bool mockPortrait = true;
  final profile = HandoffProfile();
  final diary = HandoffDiary();
  final milk = HandoffMilk();
  final insight = HandoffInsight();
  final care = HandoffCare();
  final sink = MemoryMomCozyTelemetrySink();
  final actions = <String>[];
  late final observability = MomCozyObservability(
    sink: sink,
    now: () => handoffNow,
  );
  late final controller = MotherHomeController(
    profileRepository: profile,
    diaryRepository: diary,
    lactationRepository: milk,
    ownerUserId: 'mom',
    now: () => handoffNow,
    insightRepository: insight,
  );
  Widget host({double scale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: momCozyTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      bottomNavigationBar: const MomCozyBottomNavigation(location: '/me'),
      body: SafeArea(
        child: MotherHomePage(
          controller: controller,
          observability: observability,
          onAsk: (_) => actions.add('ai'),
          onRecoveryDetails: () async {
            actions.add('recovery');
          },
          onLactationDetails: () async {
            actions.add('milk');
          },
          expertSupport: ExpertSupportSection(
            repository: care,
            now: () => handoffNow,
            observability: observability,
            portraitForProvider: mockPortrait
                ? (_) => const AssetImage(
                    'assets/images/mom_home/ibclc_jamie_lee.png',
                  )
                : null,
            onCatalog: () async {
              actions.add('catalog');
            },
            onProgress: (_) async {
              actions.add('progress');
            },
            onBook: (_) async {
              actions.add('book');
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> verifyMomHandoff(
  WidgetTester tester, {
  required HandoffScenario scenario,
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  await tester.pumpWidget(scenario.host(scale: scale));
  await tester.pumpAndSettle();
  for (final name in [
    'cozymate_avatar.png',
    'expert_group.png',
    'ibclc_jamie_lee.png',
  ]) {
    final context = tester.element(find.byType(MotherHomePage));
    await tester.runAsync(
      () => precacheImage(AssetImage('assets/images/mom_home/$name'), context),
    );
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('下午好，Mia'), findsOneWidget);
  await capture('top');
  await tester.tap(
    find.text(
      scenario.milk.records.isEmpty
          ? MomDailyInsight.waiting.title
          : scenario.insight.value.title,
    ),
  );
  expect(scenario.actions, contains('ai'));
  await tester.scrollUntilVisible(
    find.text('让专业的人，陪你把问题解决'),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('让专业的人，陪你把问题解决'));
  await tester.pumpAndSettle();
  expect(scenario.actions, contains('catalog'));
  if (scenario.care.purchased) {
    await tester.scrollUntilVisible(
      find.text('预约咨询'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('我的陪伴计划'), findsOneWidget);
    expect(find.text('Jamie Lee'), findsOneWidget);
    await tester.tap(find.text('预约咨询'));
    await tester.pumpAndSettle();
    expect(scenario.actions, contains('book'));
    await tester.tap(find.text('服务进度 ›'));
    await tester.pumpAndSettle();
    expect(scenario.actions, contains('progress'));
  }
  await capture('bottom');
  expect(tester.takeException(), isNull);
  expect(
    scenario.sink.events.any(
      (e) => e.attributes['action'] == 'mom_home_ai_insight_click',
    ),
    isTrue,
  );
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}
