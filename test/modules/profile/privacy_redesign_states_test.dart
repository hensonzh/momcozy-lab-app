import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_order.dart';
import 'package:momcozy_flutter_app/domain/care/intake.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/privacy_page.dart';
import 'package:momcozy_flutter_app/services/care/care_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'privacy_test.dart' as fixture;

class _Care extends fixture.Care {
  Completer<void>? gate;
  ProductFailure? failure;
  bool longName = false;
  @override
  Future<CareOverview> overview() async {
    await gate?.future;
    if (failure != null) throw failure!;
    return super.overview();
  }

  @override
  Future<ServiceCatalog> catalog() async {
    if (!longName) return super.catalog();
    final data =
        jsonDecode(
              File(
                'test/fixtures/product_baseline/care_catalog.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    (data['packages'] as List).first['name'] = '喂养安心与亲喂持续支持陪伴计划';
    return readServiceCatalog(data);
  }
}

class _Consents extends fixture.Consents {
  Completer<void>? readGate;
  @override
  Future<List<CareConsent>> consents(String id) async {
    await readGate?.future;
    return super.consents(id);
  }
}

Future<void> _mount(
  WidgetTester tester,
  fixture.Consents repo,
  _Care care,
  double width,
  double scale,
) async {
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
        care: care,
        consents: repo,
        onBack: () {},
        onNotifications: () {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/ui_refactor/privacy-$name-${width.toInt()}-${scale.toInt()}x.png',
    ),
  );
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    final (width, scale) = size;
    testWidgets(
      'overview and consent loads never show editable defaults $size',
      (tester) async {
        final care = _Care()..gate = Completer<void>();
        final repo = _Consents()..readGate = Completer<void>();
        await _mount(tester, repo, care, width, scale);
        expect(find.byType(Switch), findsNothing);
        await _shot(tester, 'overview-loading', width, scale);
        care.failure = const ProductFailure(ProductFailureKind.offline);
        care.gate!.complete();
        await tester.pumpAndSettle();
        await _show(tester, find.text('Try again'));
        await _shot(tester, 'overview-error', width, scale);
        care.failure = null;
        await tester.tap(find.text('Try again'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Switch), findsNothing);
        await tester.ensureVisible(find.text('Loading…'));
        await tester.pump();
        await _shot(tester, 'consent-loading', width, scale);
        repo.readFailure = const ProductFailure(ProductFailureKind.offline);
        repo.readGate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(Switch), findsNothing);
        await _show(tester, find.text('Try again'));
        await _shot(tester, 'consent-error', width, scale);
        repo.readFailure = null;
        await fixture.click(tester, 'Try again');
        expect(find.byType(Switch), findsNWidgets(3));
        expect(repo.writes, isEmpty);
      },
    );
    testWidgets(
      'long service selection and large consent copy remain readable $size',
      (tester) async {
        final repo = _Consents();
        await _mount(tester, repo, _Care()..longName = true, width, scale);
        await tester.pumpAndSettle();
        final picker = find.byType(DropdownButtonFormField<String>);
        await _show(tester, picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await _shot(tester, 'long-picker', width, scale);
        await tester.tap(find.text('Expert support service').last);
        await tester.pumpAndSettle();
        expect(tester.state<FormFieldState<String>>(picker).value, 'other');
        await _show(
          tester,
          find.byKey(const ValueKey(CareConsentScope.ibclcCase)),
        );
        await _shot(tester, 'required-scopes', width, scale);
        await fixture.toggle(tester, CareConsentScope.aiContext);
        await fixture.click(tester, 'Save changes');
        expect(repo.writes.single.episode, 'other');
        await _show(tester, find.text('Privacy settings saved'));
        await _shot(tester, 'saved-bottom', width, scale);
      },
    );
    testWidgets(
      'explicit dialog close and cancel retain unsaved consent $size',
      (tester) async {
        final repo = _Consents();
        await _mount(tester, repo, _Care(), width, scale);
        await tester.pumpAndSettle();
        await fixture.toggle(tester, CareConsentScope.video);
        await fixture.click(tester, 'Save changes');
        await fixture.click(tester, 'Keep access');
        await fixture.click(tester, 'Back');
        await _shot(tester, 'leave-confirm', width, scale);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          tester
              .widget<Switch>(
                find.byKey(const ValueKey(CareConsentScope.video)),
              )
              .value,
          isFalse,
        );
        await fixture.click(tester, 'Save changes');
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(repo.writes, isEmpty);
      },
    );
    testWidgets(
      'partially committed required consent only retries unresolved scope $size',
      (tester) async {
        final repo = _Consents();
        await _mount(tester, repo, _Care(), width, scale);
        await tester.pumpAndSettle();
        await fixture.toggle(tester, CareConsentScope.ibclcCase);
        await fixture.toggle(tester, CareConsentScope.aiContext);
        repo.failScope = CareConsentScope.aiContext;
        repo.writeFailure = const ProductFailure(
          ProductFailureKind.unavailable,
        );
        await fixture.click(tester, 'Save changes');
        await fixture.click(tester, 'Turn off access');
        expect(repo.data[CareConsentScope.ibclcCase]!.active, isFalse);
        expect(repo.data[CareConsentScope.video]!.active, isTrue);
        expect(repo.writes, hasLength(2));
        await _show(tester, find.text('Try saving again'));
        await _shot(tester, 'partial-uncertain', width, scale);
        repo.writeFailure = null;
        await fixture.click(tester, 'Try saving again');
        expect(repo.writes, hasLength(3));
        expect(repo.writes.last.scope, CareConsentScope.aiContext);
        expect(repo.writes.last.version, repo.writes[1].version);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Privacy settings saved'), findsOneWidget);
      },
    );
    testWidgets(
      'pending uncertain and conflict keep recovery actions usable $size',
      (tester) async {
        final repo = _Consents();
        await _mount(tester, repo, _Care(), width, scale);
        await tester.pumpAndSettle();
        await fixture.toggle(tester, CareConsentScope.aiContext);
        repo.pending = Completer<void>();
        await _show(tester, find.text('Save changes'));
        await tester.tap(find.text('Save changes'));
        await tester.pump();
        await _shot(tester, 'saving', width, scale);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
              .onPressed,
          isNull,
        );
        repo.writeFailure = const ProductFailure(ProductFailureKind.offline);
        repo.pending!.complete();
        await tester.pumpAndSettle();
        await _show(tester, find.text('Try saving again'));
        await _shot(tester, 'uncertain-bottom', width, scale);
        await fixture.click(tester, 'Back');
        await _shot(tester, 'uncertain-leave', width, scale);
        await fixture.click(tester, 'Keep reviewing');
        repo.pending = null;
        repo.writeFailure = const ProductFailure(ProductFailureKind.conflict);
        await fixture.click(tester, 'Try saving again');
        await _show(tester, find.text('Reload consent'));
        await _shot(tester, 'conflict-bottom', width, scale);
        expect(find.text('Privacy settings saved'), findsNothing);
        expect(
          tester
              .widget<Switch>(
                find.byKey(const ValueKey(CareConsentScope.aiContext)),
              )
              .onChanged,
          isNull,
        );
        repo.writeFailure = null;
        await fixture.click(tester, 'Reload');
        expect(
          tester
              .widget<Switch>(
                find.byKey(const ValueKey(CareConsentScope.aiContext)),
              )
              .value,
          isTrue,
        );
        await fixture.toggle(tester, CareConsentScope.aiContext);
        await fixture.click(tester, 'Save changes');
        expect(find.text('Privacy settings saved'), findsOneWidget);
        expect(repo.writes.map((w) => w.version).toSet(), {2});
      },
    );
  }
}
