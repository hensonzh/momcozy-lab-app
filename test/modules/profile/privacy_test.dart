import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_episode.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/intake.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/profile/application/privacy_controller.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/privacy_page.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

CareConsent consent(
  CareConsentScope scope, {
  bool active = true,
  int version = 2,
  String episode = 'episode',
}) => CareConsent(
  id: scope.name,
  episodeId: episode,
  scope: scope,
  active: active,
  version: version,
  policyVersion: privacyPolicyVersion,
  recordedAt: DateTime.utc(2026, 9, 12),
);

class Consents extends Fake implements IntakeRepository {
  Map<CareConsentScope, CareConsent> data = {
    for (final s in CareConsentScope.values) s: consent(s),
  };
  final writes =
      <
        ({
          String episode,
          CareConsentScope scope,
          bool active,
          int version,
          String policy,
        })
      >[];
  ProductFailure? readFailure, writeFailure;
  Completer<void>? pending;
  bool commitThenFail = false;
  CareConsentScope? failScope;
  @override
  Future<List<CareConsent>> consents(String id) async {
    if (readFailure != null) throw readFailure!;
    return data.values
        .map(
          (c) => consent(
            c.scope,
            active: c.active,
            version: c.version,
            episode: id,
          ),
        )
        .toList();
  }

  @override
  Future<CareConsent> setConsent(
    String id, {
    required CareConsentScope scope,
    required bool active,
    required int expectedVersion,
    required String policyVersion,
  }) async {
    writes.add((
      episode: id,
      scope: scope,
      active: active,
      version: expectedVersion,
      policy: policyVersion,
    ));
    if (pending != null) await pending!.future;
    if (writeFailure != null &&
        !commitThenFail &&
        (failScope == null || failScope == scope)) {
      throw writeFailure!;
    }
    final value = consent(
      scope,
      active: active,
      version: expectedVersion + 1,
      episode: id,
    );
    data[scope] = value;
    if (writeFailure != null && (failScope == null || failScope == scope)) {
      throw writeFailure!;
    }
    return value;
  }
}

class Care extends Fake implements CareRepository {
  bool empty = false;
  @override
  Future<ServiceCatalog> catalog() async => readServiceCatalog(
    Map<String, Object?>.from(
      jsonDecode(
            File(
              'test/fixtures/product_baseline/care_catalog.json',
            ).readAsStringSync(),
          )
          as Map,
    ),
  );
  @override
  Future<CareOverview> overview() async => CareOverview(
    orders: [],
    episodes: empty
        ? []
        : [
            for (final id in ['episode', 'other'])
              CareEpisode(
                id: id,
                orderId: 'order',
                packageId: id == 'episode'
                    ? 'feeding-confidence'
                    : 'breastfeeding-support',
                status: CareEpisodeStatus.active,
                stage: CareStage.activeCare,
                totalSessions: 2,
                remainingSessions: 1,
                version: 1,
              ),
          ],
  );
}

Future<void> mount(
  WidgetTester tester,
  Consents repo, {
  double width = 390,
  double scale = 1,
  Care? care,
  String? initialEpisodeId = 'episode',
  VoidCallback? onNotifications,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
      home: PrivacyPage(
        care: care ?? Care(),
        consents: repo,
        onBack: () {},
        onNotifications: onNotifications ?? () {},
        initialEpisodeId: initialEpisodeId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String label) async {
  final f = find.text(label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> toggle(WidgetTester tester, CareConsentScope scope) async {
  final f = find.byKey(ValueKey(scope));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/design_system/privacy-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
    ),
  );
}

void main() {
  test(
    'partial save retries same identity/version, then resumes remaining changes',
    () async {
      final repo = Consents();
      final c = PrivacyController(repository: repo, episodeId: 'episode');
      addTearDown(c.dispose);
      await c.load();
      c.toggle(CareConsentScope.ibclcCase, false);
      c.toggle(CareConsentScope.video, false);
      repo.writeFailure = const ProductFailure(ProductFailureKind.offline);
      repo.commitThenFail = true;
      await c.save();
      expect(c.saved, isFalse);
      expect(c.uncertain, isTrue);
      expect(c.canEdit, isFalse);
      final first = repo.writes.single;
      c.toggle(CareConsentScope.aiContext, false);
      expect(c.draft[CareConsentScope.aiContext], isTrue);
      repo.writeFailure = null;
      await c.save();
      expect(repo.writes[1], first);
      expect(repo.writes.last.scope, CareConsentScope.video);
      expect(c.saved, isTrue);
      expect(c.dirty, isFalse);
      expect(c.current[CareConsentScope.ibclcCase]!.version, 3);
    },
  );
  test(
    'acknowledged partial save never repeats an already completed scope',
    () async {
      final repo = Consents()
        ..failScope = CareConsentScope.video
        ..writeFailure = const ProductFailure(ProductFailureKind.offline);
      final c = PrivacyController(repository: repo, episodeId: 'episode');
      addTearDown(c.dispose);
      await c.load();
      c.toggle(CareConsentScope.ibclcCase, false);
      c.toggle(CareConsentScope.video, false);
      await c.save();
      expect(c.current[CareConsentScope.ibclcCase]!.active, isFalse);
      expect(c.current[CareConsentScope.video]!.active, isTrue);
      expect(c.saved, isFalse);
      repo.writeFailure = null;
      await c.save();
      expect(
        repo.writes.where((w) => w.scope == CareConsentScope.ibclcCase),
        hasLength(1),
      );
      expect(c.saved, isTrue);
    },
  );
  test(
    'conflict requires reload and picks current version before new write',
    () async {
      final repo = Consents();
      final c = PrivacyController(repository: repo, episodeId: 'other');
      addTearDown(c.dispose);
      await c.load();
      c.toggle(CareConsentScope.aiContext, false);
      repo.writeFailure = const ProductFailure(ProductFailureKind.conflict);
      await c.save();
      expect(c.needsReload, isTrue);
      await c.save();
      expect(repo.writes, hasLength(1));
      repo.data[CareConsentScope.aiContext] = consent(
        CareConsentScope.aiContext,
        version: 9,
      );
      repo.writeFailure = null;
      await c.load();
      expect(c.dirty, isFalse);
      c.toggle(CareConsentScope.aiContext, false);
      await c.save();
      expect(repo.writes.last.version, 9);
      expect(repo.writes.last.episode, 'other');
      expect(repo.writes.last.policy, privacyPolicyVersion);
    },
  );
  test(
    'reloading an uncertain operation resolves authoritative state without more writes',
    () async {
      final repo = Consents()..commitThenFail = true;
      final c = PrivacyController(repository: repo, episodeId: 'episode');
      addTearDown(c.dispose);
      await c.load();
      c.toggle(CareConsentScope.video, false);
      repo.writeFailure = const ProductFailure(ProductFailureKind.offline);
      await c.save();
      await c.load();
      expect(c.current[CareConsentScope.video]!.active, isFalse);
      expect(c.uncertain, isFalse);
      expect(c.dirty, isFalse);
      expect(repo.writes, hasLength(1));
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'privacy scopes, revoke confirmation and notifications $width/$scale',
        (tester) async {
          final repo = Consents();
          var notifications = false;
          await mount(
            tester,
            repo,
            width: width,
            scale: scale,
            onNotifications: () => notifications = true,
          );
          await shot(tester, 'top', width, scale);
          expect(find.byType(Switch), findsNWidgets(3));
          expect(repo.writes, isEmpty);
          await toggle(tester, CareConsentScope.video);
          expect(repo.writes, isEmpty);
          await click(tester, 'Save changes');
          await shot(tester, 'confirm', width, scale);
          await click(tester, 'Keep access');
          expect(repo.writes, isEmpty);
          await click(tester, 'Save changes');
          await click(tester, 'Turn off access');
          expect(repo.writes.single.scope, CareConsentScope.video);
          expect(repo.writes.single.active, isFalse);
          expect(repo.data[CareConsentScope.ibclcCase]!.active, isTrue);
          expect(find.text('Privacy settings saved'), findsOneWidget);
          await click(tester, 'Manage notifications & reminders');
          expect(notifications, isTrue);
          await shot(tester, 'saved', width, scale);
          expect(repo.data[CareConsentScope.notifications]!.active, isTrue);
        },
      );
    }
  }
  testWidgets(
    'no service and failed read never expose editable fake defaults',
    (tester) async {
      final repo = Consents();
      await mount(
        tester,
        repo,
        care: Care()..empty = true,
        initialEpisodeId: null,
      );
      await shot(tester, 'empty', 390, 1);
      expect(find.byType(Switch), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repo.readFailure = const ProductFailure(ProductFailureKind.offline);
      await mount(tester, repo);
      expect(find.byType(Switch), findsNothing);
      await shot(tester, 'offline', 390, 1);
    },
  );
  testWidgets(
    'discarding a service switch keeps displayed and saved scope aligned',
    (tester) async {
      final repo = Consents();
      await mount(tester, repo);
      await toggle(tester, CareConsentScope.aiContext);
      final picker = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expert support service').last);
      await tester.pumpAndSettle();
      await click(tester, 'Keep reviewing');
      expect(tester.state<FormFieldState<String>>(picker).value, 'episode');
      expect(repo.writes, isEmpty);
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expert support service').last);
      await tester.pumpAndSettle();
      await click(tester, 'Discard and leave');
      expect(tester.state<FormFieldState<String>>(picker).value, 'other');
      await toggle(tester, CareConsentScope.aiContext);
      await click(tester, 'Save changes');
      expect(repo.writes.single.episode, 'other');
    },
  );
  testWidgets(
    'unknown requested service does not silently edit another service',
    (tester) async {
      final repo = Consents();
      await mount(tester, repo, initialEpisodeId: 'unowned');
      expect(find.text('No consent found for this service'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(repo.writes, isEmpty);
    },
  );
  testWidgets(
    'pending save locks edits and read retry can resolve uncertain result',
    (tester) async {
      final repo = Consents();
      await mount(tester, repo);
      await toggle(tester, CareConsentScope.aiContext);
      repo.pending = Completer<void>();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey(CareConsentScope.aiContext)),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      repo.writeFailure = const ProductFailure(ProductFailureKind.offline);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      await shot(tester, 'uncertain', 390, 1);
      expect(find.text('Privacy settings saved'), findsNothing);
      repo.pending = null;
      repo.writeFailure = null;
      await click(tester, 'Reload consent');
      expect(repo.writes, hasLength(1));
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey(CareConsentScope.aiContext)),
            )
            .value,
        isTrue,
      );
    },
  );
}
