@Tags(['golden'])
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/lactation/lactation_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/domain/shared/record_deletion.dart';
import 'package:momcozy_flutter_app/modules/mom/application/lactation_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/lactation_panel.dart';
import 'package:momcozy_flutter_app/services/lactation/lactation_api_repository.dart';
import 'package:momcozy_flutter_app/services/lactation/lactation_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

final date = LocalDate(2026, 9, 8);
final now = DateTime(2026, 9, 8, 14, 30);
final sample = LactationRecord(
  id: 'entry',
  ownerUserId: 'mom',
  version: 4,
  observation: PumpObservation(
    occurredAt: DateTime(2026, 9, 8, 11, 10),
    side: BreastSide.right,
    volumeMl: 55,
    feeling: BreastComfort.comfortable,
  ),
);

void main() {
  test(
    'wire contract keeps methods exclusive and carries the deletion version',
    () async {
      final transport = FixtureApiJsonTransport({'id': 'entry', 'version': 9});
      final repo = LactationApiRepository(transport: transport);
      final receipt = await repo.delete('entry', expectedVersion: 4);
      expect(receipt.version, 9);
      expect(transport.lastHeaders, {'If-Match': '4'});
      expect(transport.lastPath, '/v1/lactation/records/entry');
      expect(
        writeLactationObservation(
          NursingObservation(occurredAt: now, side: BreastSide.left),
        ).containsKey('volume_ml'),
        isFalse,
      );
      expect(
        () => readLactationRecord({
          'id': 'entry',
          'owner_user_id': 'mom',
          'version': 1,
          'observation': {
            'occurred_at': now.toUtc().toIso8601String(),
            'method': 'nurse',
            'side': 'left',
            'volume_ml': 70,
          },
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'uncertain save retries the same payload and key, blocks duplicate taps, and undo uses receipt',
    () async {
      final repository = LactationFixture();
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.begin();
      controller.edit(controller.draft!.copyWith(measurement: '85'));
      final pending = Completer<LactationRecord>();
      repository.nextCreate = pending.future;
      final saving = controller.save();
      expect(await controller.save(), isFalse);
      expect(repository.keys, ['request-key']);
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      expect(await saving, isFalse);
      expect(controller.uncertainSave, isTrue);
      controller.edit(controller.draft!.copyWith(measurement: '90'));
      expect(controller.draft!.measurement, '85');
      repository.nextCreate = null;
      expect(await controller.save(), isTrue);
      expect(repository.keys, ['request-key', 'request-key']);
      expect(controller.summary(date).measuredVolumeMl, 140);
      expect(controller.draft, isNull);
      final created = controller.records.firstWhere(
        (record) => record.id == 'created',
      );
      expect(await controller.delete(created), isTrue);
      expect(controller.summary(date).measuredVolumeMl, 55);
      await controller.undoDelete();
      expect(repository.restoreVersion, 9);
      expect(controller.summary(date).measuredVolumeMl, 140);
    },
  );

  test(
    'changing method clears the old measurement and rejects invalid typed input',
    () {
      final draft = LactationDraft(occurredAt: now, measurement: '55');
      final nursing = draft.copyWith(method: LactationMethod.nurse);
      expect(nursing.measurement, isEmpty);
      expect(nursing.observation, isA<NursingObservation>());
      expect(
        nursing.copyWith(measurement: '4.5').errors(now),
        contains('measurement'),
      );
      expect(
        draft.copyWith(measurement: 'not a number').errors(now),
        contains('measurement'),
      );
      expect(
        draft.copyWith(measurement: '0').observation,
        isA<PumpObservation>().having(
          (value) => value.volumeMl,
          'measured zero',
          0,
        ),
      );
      expect(nursing.copyWith(measurement: '0').errors(now), isEmpty);
    },
  );

  testWidgets(
    'single record editor saves a real observation, then delete and undo change the list',
    (tester) async {
      final repository = LactationFixture();
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: Scaffold(
            body: LactationPanel(
              controller: controller,
              onClose: () {},
              initialCreate: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('lactation-measurement-pump')),
        '80',
      );
      await tester.tap(find.text('Save this record'));
      await tester.pumpAndSettle();
      expect(repository.keys, hasLength(1));
      final menu = find.byKey(
        const ValueKey('lactation-record-actions-created'),
      );
      await tester.scrollUntilVisible(
        menu,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lactation-delete-created')));
      await tester.pumpAndSettle();
      expect(controller.records, hasLength(1));
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(controller.records, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'lactation modal switches to nursing and saves at $width / $scale',
        (tester) async {
          await loadMomCozyTestFonts();
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = LactationFixture();
          await tester.pumpWidget(
            MaterialApp(
              theme: momCozyTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showLactationPanel(
                      context,
                      repository: repository,
                      ownerUserId: 'mom',
                      date: date,
                      now: () => now,
                      create: true,
                    ),
                    child: const Text('Open records'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open records'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/lactation-dialog-pump-${width.toInt()}.png',
              ),
            );
          }
          if (scale == 2) {
            await Scrollable.ensureVisible(
              tester.element(find.text('Nursing')),
              alignment: .3,
            );
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Nursing'));
          await tester.pumpAndSettle();
          expect(find.text('Left side duration'), findsOneWidget);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/lactation-dialog-nurse-${width.toInt()}.png',
              ),
            );
          }
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.ensureVisible(
            find.byKey(const ValueKey('lactation-measurement-nurse')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('lactation-measurement-nurse')),
            '12',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save this record'));
          await tester.pumpAndSettle();
          final saved = repository.records.last.observation;
          expect(saved, isA<NursingObservation>());
          expect((saved as NursingObservation).durationMinutes, 12);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
    for (final entry in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'lactation ${entry ? 'entry' : 'list'} renders at $width / $scale',
          (tester) async {
            await loadMomCozyTestFonts();
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = _controller(LactationFixture());
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              MaterialApp(
                theme: momCozyTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: RepaintBoundary(
                    key: const ValueKey('capture'),
                    child: Material(
                      color: MomCozyColors.background,
                      child: LactationPanel(
                        controller: controller,
                        onClose: () {},
                        initialCreate: entry,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await expectLater(
                find.byKey(const ValueKey('capture')),
                matchesGoldenFile(
                  '../../goldens/product_baseline/lactation-${entry ? 'entry' : 'list'}-${width.toInt()}.png',
                ),
              );
            }
            if (scale == 2) {
              if (entry) {
                tester.view.viewInsets = const FakeViewPadding(bottom: 300);
                addTearDown(tester.view.resetViewInsets);
                await tester.enterText(
                  find.byKey(const ValueKey('lactation-measurement-pump')),
                  '80',
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              } else {
                await tester.drag(find.byType(ListView), const Offset(0, -500));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            }
          },
        );
      }
    }
  }
}

LactationController _controller(LactationFixture repository) =>
    LactationController(
      repository: repository,
      ownerUserId: 'mom',
      date: date,
      now: () => now,
      mutationKey: () => 'request-key',
    );

class LactationFixture implements LactationRepository {
  List<LactationRecord> records = [sample];
  final keys = <String>[];
  Future<LactationRecord>? nextCreate;
  ProductFailure? createFailure;
  LactationRecord? deleted;
  int? restoreVersion;
  @override
  Future<List<LactationRecord>> list(DayWindow window) async =>
      List.of(records);
  @override
  Future<LactationRecord> create(
    LactationObservation observation, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (createFailure != null) throw createFailure!;
    if (nextCreate != null) return nextCreate!;
    final result = LactationRecord(
      id: 'created',
      ownerUserId: 'mom',
      version: 1,
      observation: observation,
    );
    records.add(result);
    return result;
  }

  @override
  Future<LactationRecord> update(
    String id,
    LactationObservation observation, {
    required int expectedVersion,
  }) async {
    final result = LactationRecord(
      id: id,
      ownerUserId: 'mom',
      version: expectedVersion + 1,
      observation: observation,
    );
    records = [result, ...records.where((record) => record.id != id)];
    return result;
  }

  @override
  Future<RecordDeletion> delete(
    String id, {
    required int expectedVersion,
  }) async {
    deleted = records.firstWhere((record) => record.id == id);
    records.remove(deleted);
    return RecordDeletion(id: id, version: 9);
  }

  @override
  Future<LactationRecord> restore(
    String id, {
    required int expectedVersion,
  }) async {
    restoreVersion = expectedVersion;
    final record = deleted!;
    records.add(record);
    deleted = null;
    return record;
  }
}
