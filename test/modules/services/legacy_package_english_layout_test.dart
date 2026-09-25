import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_catalog_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_package_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_renew_page.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/service_purchase_dialog.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

const _legacyPackage = ServicePackage(
  id: 'feeding-confidence',
  name: '喂养信心计划',
  subtitle: 'Cozymate 喂养支持',
  description: '了解宝宝的喂养需求。',
  durationDays: 7,
  sessions: 2,
  priceMinor: 21900,
  currency: 'USD',
  highlights: ['查看宝宝是否吃饱'],
  expertServices: ['首次视频咨询 60 分钟', '后续咨询 20 分钟'],
  continuousServices: ['记录喂养', '跟踪进展'],
);

class _LegacyRepository extends Fake implements CareRepository {
  _LegacyRepository({this.activeEpisode});

  final CareEpisode? activeEpisode;

  @override
  Future<ServiceCatalog> catalog() async => const ServiceCatalog(
    packages: [_legacyPackage],
    providers: [],
    availableRegions: ['CA'],
    paymentMode: PaymentMode.sandbox,
  );

  @override
  Future<CareOverview> overview() async =>
      CareOverview(orders: const [], episodes: [?activeEpisode]);
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('legacy plan is readable on a 320px screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _LegacyRepository();

    Future<void> mount(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: child,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await mount(
      ServiceCatalogPage(
        repository: repository,
        onSelect: (_) {},
        onBack: () {},
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Feeding Confidence'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Feeding Confidence'), findsOneWidget);
    expect(
      find.text('Expert feeding support for your family.'),
      findsOneWidget,
    );
    expect(find.text('喂养信心计划'), findsNothing);
    expect(find.textContaining('Cozymate'), findsNothing);

    await mount(
      ServicePackagePage(
        repository: repository,
        packageId: _legacyPackage.id,
        onBack: () {},
        onBook: (_) {},
        onProgress: (_) {},
      ),
    );
    expect(find.text('Feeding Confidence package'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Plan details need English review'),
      170,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan details need English review'), findsOneWidget);
    final purchaseButton = find.widgetWithText(FilledButton, 'Purchase');
    expect(purchaseButton, findsOneWidget);
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/service-legacy-purchase-blocked-320-2x.png',
      ),
    );

    expect(find.textContaining('Cozymate'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('IBCLC support'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Contact support to confirm the format and length.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Ongoing AI & app support'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Contact support to confirm the included ongoing support.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('renewal cannot start checkout with untranslated entitlements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _LegacyRepository();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ServiceRenewPage(
          repository: repo,
          onBack: () {},
          onBook: (_) {},
          onProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'English details pending');
    await tester.scrollUntilVisible(
      button,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      find.text('Plan details need English review before purchase.'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/service-legacy-renewal-blocked-320-2x.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing service remains accessible despite legacy catalog copy',
    (tester) async {
      const episode = CareEpisode(
        id: 'active',
        orderId: 'paid',
        packageId: 'feeding-confidence',
        status: CareEpisodeStatus.active,
        stage: CareStage.preparation,
        totalSessions: 2,
        remainingSessions: 1,
        version: 1,
      );
      CareEpisode? booked;
      await tester.pumpWidget(
        MaterialApp(
          home: ServicePackagePage(
            repository: _LegacyRepository(activeEpisode: episode),
            packageId: episode.packageId,
            onBack: () {},
            onBook: (value) => booked = value,
            onProgress: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final book = find.widgetWithText(FilledButton, 'Book an appointment');
      expect(tester.widget<FilledButton>(book).onPressed, isNotNull);
      await tester.tap(book);
      expect(booked, same(episode));
    },
  );

  testWidgets('direct purchase entry also refuses untranslated benefits', (
    tester,
  ) async {
    final repo = _LegacyRepository();
    Future<CareEpisode?>? attempted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => attempted = showServicePurchase(
              context,
              repository: repo,
              package: _legacyPackage,
              catalog: const ServiceCatalog(
                packages: [_legacyPackage],
                providers: [],
                availableRegions: ['CA'],
                paymentMode: PaymentMode.sandbox,
              ),
            ),
            child: const Text('Open checkout'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open checkout'));
    expect(await attempted, isNull);
    expect(find.byType(ServicePurchaseDialog), findsNothing);
  });
}
