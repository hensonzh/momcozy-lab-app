import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

import '../../support/momcozy_test_fonts.dart';
import 'baby_profile_controller_test.dart';

class _Profiles extends Profiles {
  Completer<void>? saveGate;
  Completer<void>? readGate;
  ProductFailure? readFailure;
  int submissions = 0;

  @override
  Future<List<BabyProfile>> list() async {
    await readGate?.future;
    if (readFailure != null) throw readFailure!;
    return const [
      BabyProfile(
        id: 'baby',
        name: 'Luna server',
        version: 8,
        sex: BabySex.male,
        feedingMode: FeedingMode.formula,
      ),
    ];
  }

  @override
  Future<BabyProfile> save(
    BabyProfile profile, {
    required String timezone,
    required String idempotencyKey,
  }) async {
    submissions++;
    await saveGate?.future;
    return super.save(
      profile,
      timezone: timezone,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      Future<BabyProfileController> open(
        WidgetTester tester,
        _Profiles repo,
      ) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = BabyProfileController(
          repository: repo,
          initial: BabyProfile(
            id: 'baby',
            name: 'Luna',
            birthDate: LocalDate(2026, 8, 22),
            sex: BabySex.female,
            version: 7,
          ),
          timezone: 'UTC',
          now: () => DateTime.utc(2026, 9, 14),
        );
        addTearDown(c.dispose);
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
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<BabyProfile>(
                    context: context,
                    builder: (_) => BabyProfileEditor(controller: c),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        return c;
      }

      Future<void> capture(WidgetTester tester, String state) async {
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/design_system/baby-profile-current-$state-${width.toInt()}-${scale.toInt()}x.png',
          ),
        );
      }

      Future<void> tap(WidgetTester tester, Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      testWidgets(
        'profile draft, conflict reload and removed profile $width/$scale',
        (tester) async {
          final repo = _Profiles();
          final c = await open(tester, repo);
          await capture(tester, 'existing');
          await tester.enterText(find.byType(TextField), '');
          await tap(tester, find.text('保存宝宝资料'));
          expect(find.text('请填写宝宝称呼。').hitTestable(), findsOneWidget);
          expect(repo.submissions, 0);
          await capture(tester, 'validation');
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(
            find.byType(TextField),
            List.filled(121, '宝').join(),
          );
          expect(c.name.length, 120);
          await tester.pumpAndSettle();
          await capture(tester, 'maximum-name');
          await tester.enterText(find.byType(TextField), 'Luna local');
          repo.nextFailure = const ProductFailure(ProductFailureKind.conflict);
          await tap(tester, find.text('保存宝宝资料'));
          expect(c.name, 'Luna local');
          expect(find.text('重新载入').hitTestable(), findsOneWidget);
          await capture(tester, 'conflict');
          repo.readGate = Completer<void>();
          await tester.tap(find.text('重新载入'));
          await tester.pump();
          expect(c.busy, isTrue);
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            isFalse,
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            DefaultTextStyle.of(tester.element(find.text('正在保存…'))).style.color,
            MomHomeTokens.secondary,
          );
          await capture(tester, 'reload-pending');
          repo.readGate!.complete();
          await tester.pumpAndSettle();
          expect(c.name, 'Luna server');
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Luna server',
          );
          expect(c.sex, BabySex.male);
          expect(c.feedingMode, FeedingMode.formula);
          await tester.ensureVisible(find.byType(TextField));
          await tester.pumpAndSettle();
          await capture(tester, 'reloaded');
          await tester.enterText(find.byType(TextField), 'Luna retained');
          repo.nextFailure = const ProductFailure(ProductFailureKind.conflict);
          await tap(tester, find.text('保存宝宝资料'));
          expect(repo.writes.last.version, 8);
          repo.readFailure = const ProductFailure(ProductFailureKind.forbidden);
          await tap(tester, find.text('重新载入'));
          expect(c.name, 'Luna retained');
          await tester.ensureVisible(find.text('当前账号没有访问权限'));
          await tester.pumpAndSettle();
          await capture(tester, 'removed');
          await tap(tester, find.byTooltip('关闭宝宝资料'));
          await capture(tester, 'discard');
          await tap(tester, find.text('继续填写'));
          expect(c.name, 'Luna retained');
          await tap(tester, find.byTooltip('关闭宝宝资料'));
          await tap(tester, find.text('离开'));
          expect(find.byType(BabyProfileEditor), findsNothing);
        },
      );

      testWidgets(
        'profile choices and uncertain save preserve exact request $width/$scale',
        (tester) async {
          final repo = _Profiles();
          final c = await open(tester, repo);
          await tap(tester, find.text('2026-08-22'));
          final picker = find.byType(DatePickerDialog);
          final strings = MaterialLocalizations.of(tester.element(picker));
          await capture(tester, 'birth-picker');
          if (scale == 1) {
            await tap(tester, find.byTooltip(strings.inputDateModeButtonLabel));
          }
          final dateInput = find.descendant(
            of: picker,
            matching: find.byType(TextFormField),
          );
          final acceptDate = find.descendant(
            of: picker,
            matching: find.text(strings.okButtonLabel),
          );
          for (final invalid in [
            DateTime(1899, 12, 31),
            DateTime(2026, 9, 15),
          ]) {
            await tester.enterText(
              dateInput,
              strings.formatCompactDate(invalid),
            );
            await tap(tester, acceptDate);
            expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
            expect(c.birthDate, LocalDate(2026, 8, 22));
          }
          await capture(tester, 'date-out-of-range');
          await tester.enterText(
            dateInput,
            strings.formatCompactDate(DateTime(2026, 9, 1)),
          );
          await tap(tester, acceptDate);
          expect(c.birthDate, LocalDate(2026, 9, 1));
          await tap(tester, find.text('清除日期'));
          expect(c.birthDate, isNull);
          await capture(tester, 'cleared');
          await tap(tester, find.text('男宝宝'));
          expect(c.sex, BabySex.male);
          final menu = find.byType(DropdownButtonFormField<FeedingMode>);
          await tap(tester, menu);
          await capture(tester, 'feeding-menu');
          await tap(tester, find.text('混合喂养').last);
          expect(c.feedingMode, FeedingMode.mixed);
          await capture(tester, 'feeding-selected');
          repo.saveGate = Completer<void>();
          repo.nextFailure = const ProductFailure(
            ProductFailureKind.unavailable,
          );
          await tester.tap(find.text('保存宝宝资料'));
          await tester.pump();
          expect(c.busy, isTrue);
          expect(repo.submissions, 1);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            isFalse,
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            DefaultTextStyle.of(tester.element(find.text('正在保存…'))).style.color,
            MomHomeTokens.secondary,
          );
          await capture(tester, 'pending');
          repo.saveGate!.complete();
          await tester.pumpAndSettle();
          expect(c.uncertain, isTrue);
          expect(find.text('重试确认保存').hitTestable(), findsOneWidget);
          await capture(tester, 'uncertain');
          await tap(tester, find.byTooltip('关闭宝宝资料'));
          await capture(tester, 'uncertain-leave');
          await tap(tester, find.text('继续填写'));
          await tap(tester, find.text('重试确认保存'));
          expect(find.byType(BabyProfileEditor), findsNothing);
          expect(repo.submissions, 2);
          expect(repo.keys.first, repo.keys.last);
          expect(repo.writes.last.birthDate, isNull);
          expect(repo.writes.last.sex, BabySex.male);
          expect(repo.writes.last.feedingMode, FeedingMode.mixed);
          expect(repo.writes.last.version, 7);
        },
      );
    }
  }
}
