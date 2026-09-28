@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/lactation/lactation_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/domain/shared/record_deletion.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/lactation_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'lactation_test.dart' show LactationFixture, date, now, sample;

const _offline = ProductFailure(ProductFailureKind.offline);
const _conflict = ProductFailure(ProductFailureKind.conflict);
final _longNote =
    '${('Track how feeding feels, one day at a time. ' * 60).substring(0, 1995)}End of note.';

class _Repository extends LactationFixture {
  ProductFailure? readFailure, updateFailure, deleteFailure, restoreFailure;
  Completer<List<LactationRecord>>? pendingRead;
  @override
  Future<List<LactationRecord>> list(DayWindow window) async {
    if (pendingRead != null) return pendingRead!.future;
    if (readFailure != null) throw readFailure!;
    return super.list(window);
  }

  @override
  Future<LactationRecord> update(
    String id,
    LactationObservation observation, {
    required int expectedVersion,
  }) async {
    if (updateFailure != null) throw updateFailure!;
    return super.update(id, observation, expectedVersion: expectedVersion);
  }

  @override
  Future<RecordDeletion> delete(
    String id, {
    required int expectedVersion,
  }) async {
    if (deleteFailure != null) throw deleteFailure!;
    return super.delete(id, expectedVersion: expectedVersion);
  }

  @override
  Future<LactationRecord> restore(
    String id, {
    required int expectedVersion,
  }) async {
    if (restoreFailure != null) throw restoreFailure!;
    return super.restore(id, expectedVersion: expectedVersion);
  }
}

Future<void> _click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
      '../../goldens/ui_refactor/lactation/$name-${width.toInt()}-${scale.toInt()}x.png',
    ),
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repo,
  double width,
  double scale, {
  bool create = false,
  VoidCallback? onClose,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: LactationPage(
        repository: repo,
        ownerUserId: 'mom',
        date: date,
        now: () => now,
        create: create,
        onClose: onClose ?? () {},
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/mom/milk-hero.png'),
      tester.element(find.byType(LactationPage)),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'lactation route reads, charts, long notes, conflicts and undo $width/$scale',
        (tester) async {
          final repo = _Repository()
            ..pendingRead = Completer<List<LactationRecord>>();
          repo.records = [
            LactationRecord(
              id: 'entry',
              ownerUserId: 'mom',
              version: 4,
              observation: PumpObservation(
                occurredAt: sample.observation.occurredAt,
                side: BreastSide.right,
                volumeMl: 0,
                note: _longNote,
              ),
            ),
            LactationRecord(
              id: 'missing',
              ownerUserId: 'mom',
              version: 1,
              observation: PumpObservation(
                occurredAt: now,
                side: BreastSide.left,
              ),
            ),
            LactationRecord(
              id: 'nurse',
              ownerUserId: 'mom',
              version: 1,
              observation: NursingObservation(
                occurredAt: now,
                side: BreastSide.left,
                durationMinutes: 0,
              ),
            ),
            LactationRecord(
              id: 'previous',
              ownerUserId: 'mom',
              version: 1,
              observation: PumpObservation(
                occurredAt: now.subtract(const Duration(days: 8)),
                side: BreastSide.left,
                volumeMl: 65.5,
              ),
            ),
          ];
          await _mount(tester, repo, width, scale);
          await _shot(tester, 'loading', width, scale);
          repo.pendingRead!.completeError(_offline);
          repo.pendingRead = null;
          await tester.pumpAndSettle();
          await _shot(tester, 'read-error', width, scale);
          await _click(tester, find.text('Try again'));
          await _shot(tester, 'overview', width, scale);
          await _click(tester, find.text('30 days'));
          final semantics = tester.ensureSemantics();
          expect(
            find.bySemanticsLabel(
              RegExp(
                'Pumped milk over 30 days.*8/31: 65.5 ml.*9/7: Not recorded.*9/8: 0 ml',
              ),
            ),
            findsOneWidget,
          );
          await _shot(tester, '30-days', width, scale);
          await _click(tester, find.text('7 days'));
          expect(
            find.bySemanticsLabel(RegExp('Pumped milk over 7 days.*9/8: 0 ml')),
            findsOneWidget,
          );
          semantics.dispose();
          final note = find.text(_longNote);
          await Scrollable.ensureVisible(tester.element(note), alignment: 0);
          await tester.pumpAndSettle();
          expect(tester.getSize(note).width, greaterThan(width - 100));
          await _shot(tester, 'long-note-start', width, scale);
          final edit = find.byKey(const ValueKey('lactation-edit-entry'));
          await tester.ensureVisible(edit);
          await tester.pumpAndSettle();
          await _shot(tester, 'long-note-end', width, scale);
          await _click(tester, edit);
          repo.updateFailure = _conflict;
          await tester.enterText(
            find.byKey(const ValueKey('lactation-measurement-pump')),
            '65.5',
          );
          await _click(tester, find.text('Save changes'));
          expect(repo.records.first.version, 4);
          await _shot(tester, 'save-conflict', width, scale);
          await _click(tester, find.text('Back to records'));
          await _shot(tester, 'leave-confirm', width, scale);
          await _click(tester, find.text('Keep editing'));
          expect(find.text('65.5'), findsOneWidget);
          await _click(tester, find.text('Back to records'));
          await _click(tester, find.text('Leave'));
          final delete = find.byKey(const ValueKey('lactation-delete-entry'));
          repo.deleteFailure = _offline;
          await _click(tester, delete);
          expect(repo.records.any((r) => r.id == 'entry'), isTrue);
          expect(
            find.text("You're offline. Connect and try again.").hitTestable(),
            findsOneWidget,
          );
          await _shot(tester, 'delete-error', width, scale);
          repo.deleteFailure = null;
          await _click(tester, find.text('Try again'));
          await _click(tester, delete);
          expect(find.text('Record deleted').hitTestable(), findsOneWidget);
          repo.restoreFailure = _offline;
          await _click(tester, find.text('Undo'));
          expect(repo.records.any((r) => r.id == 'entry'), isFalse);
          await _shot(tester, 'restore-error', width, scale);
          repo.restoreFailure = null;
          await _click(tester, find.text('Undo'));
          expect(repo.restoreVersion, 9);
          expect(
            repo.records.firstWhere((r) => r.id == 'entry').observation.note,
            _longNote,
          );
          expect(find.text('Record restored.').hitTestable(), findsOneWidget);
          await _shot(tester, 'restored', width, scale);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        'lactation route time input validates and pending save locks edits $width/$scale',
        (tester) async {
          final repo = _Repository()..records = [];
          var closed = 0;
          await _mount(
            tester,
            repo,
            width,
            scale,
            create: true,
            onClose: () => closed++,
          );
          await tester.pumpAndSettle();
          await _click(tester, find.text('14:30'));
          final picker = find.byKey(const ValueKey('momcozy-time-picker'));
          final strings = MaterialLocalizations.of(tester.element(picker));
          if (scale == 1) {
            await _shot(tester, 'time-dial', width, scale);
            await _click(
              tester,
              find.byTooltip(strings.inputTimeModeButtonLabel),
            );
          }
          await _shot(tester, 'time-input', width, scale);
          final fields = find.descendant(
            of: picker,
            matching: find.byType(TextFormField),
          );
          await tester.enterText(fields.at(0), '99');
          await tester.enterText(fields.at(1), '60');
          await _click(tester, find.text(strings.okButtonLabel));
          expect(picker, findsOneWidget);
          for (final element
              in find
                  .descendant(of: picker, matching: find.byType(Scrollable))
                  .evaluate()) {
            final scroll =
                (element as StatefulElement).state as ScrollableState;
            if (axisDirectionToAxis(scroll.axisDirection) == Axis.horizontal) {
              expect(
                scroll.position.maxScrollExtent,
                0,
                reason: 'Time controls must fit without horizontal clipping',
              );
            }
          }
          final dialogRect = tester.getRect(
            find.descendant(of: picker, matching: find.byType(Dialog)).first,
          );
          for (final text in [
            strings.timePickerInputHelpText,
            strings.invalidTimeLabel,
          ]) {
            final labels = find.descendant(
              of: picker,
              matching: find.text(text),
            );
            for (final element in labels.evaluate()) {
              final rect = tester.getRect(
                find.byElementPredicate((candidate) => candidate == element),
              );
              expect(
                rect.left,
                greaterThanOrEqualTo(dialogRect.left),
                reason: '$text must not be clipped on the left',
              );
              expect(
                rect.right,
                lessThanOrEqualTo(dialogRect.right),
                reason: '$text must not be clipped on the right',
              );
            }
          }
          await _shot(tester, 'time-invalid', width, scale);
          await tester.enterText(fields.at(0), '12');
          await tester.enterText(fields.at(1), '00');
          await _click(tester, find.text(strings.okButtonLabel));
          expect(picker, findsNothing);
          expect(find.text('12:00'), findsOneWidget);
          final measure = find.byKey(
            const ValueKey('lactation-measurement-pump'),
          );
          await tester.ensureVisible(measure);
          await tester.enterText(measure, '0');
          await tester.pumpAndSettle();
          final pending = Completer<LactationRecord>();
          repo.nextCreate = pending.future;
          await _click(tester, find.text('Save this record'));
          expect(repo.keys, hasLength(1));
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Saving…'),
                )
                .onPressed,
            isNull,
          );
          await _shot(tester, 'saving', width, scale);
          await tester.tap(find.byTooltip('Close feeding and pumping records'));
          expect(closed, 0);
          pending.completeError(_offline);
          await tester.pumpAndSettle();
          await _click(
            tester,
            find.byTooltip('Close feeding and pumping records'),
          );
          await _shot(tester, 'uncertain-leave', width, scale);
          await _click(tester, find.text('Keep editing'));
          repo.nextCreate = null;
          await _click(tester, find.text('Try saving again'));
          expect(repo.keys, hasLength(2));
          expect(repo.keys.first, repo.keys.last);
          final saved = repo.records.single.observation as PumpObservation;
          expect(saved.volumeMl, 0);
          expect(saved.occurredAt, DateTime(2026, 9, 8, 12));
          expect(find.text('Record saved.').hitTestable(), findsOneWidget);
          await _shot(tester, 'saved-zero', width, scale);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
