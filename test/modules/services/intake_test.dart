import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_age_label.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/care/intake.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/services/application/intake_controller.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/intake_page.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_api_repository.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_codec.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

final _now = DateTime.utc(2026, 9, 8, 15);
Map<String, Object?> _fixture() => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/product_baseline/intake_context.json',
        ).readAsStringSync(),
      )
      as Map,
);
IntakeContext _context() => readIntakeContext(_fixture());

IntakeContext _readyContext({bool saved = false}) {
  final base = _context(), original = _context().babies.single;
  final baby = BabyProfile(
    id: original.id,
    name: 'Luna',
    birthDate: original.birthDate,
    sex: BabySex.female,
    feedingMode: FeedingMode.expressedMilk,
  );
  return IntakeContext(
    appointment: base.appointment,
    babies: [baby],
    policyVersion: base.policyVersion,
    deliveryDate: base.deliveryDate,
    consents: [
      if (saved)
        CareConsent(
          id: 'consent',
          episodeId: base.appointment.episodeId,
          scope: CareConsentScope.ibclcCase,
          active: true,
          version: 1,
          policyVersion: base.policyVersion,
          recordedAt: _now,
        ),
    ],
    intake: saved
        ? CareIntake(
            id: 'intake',
            appointmentId: base.appointment.id,
            episodeId: base.appointment.episodeId,
            version: 1,
            submittedAt: _now,
            content: IntakeContent(
              symptoms: {IntakeSymptom.latchDifficulty},
              feedingGoal: 'Original goal',
              supportNeeded: '',
              profile: IntakeProfile(
                baby: baby,
                deliveryDate: base.deliveryDate!,
                region: 'CA',
              ),
            ),
          )
        : null,
  );
}

Future<void> _mountIntake(
  WidgetTester tester,
  _Repository repository, {
  double width = 390,
  double scale = 1,
  VoidCallback? onBack,
  ValueChanged<CareIntake>? onPreconsult,
  bool settle = true,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('intake-capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: IntakePage(
          repository: repository,
          appointmentId: repository.context.appointment.id,
          now: () => _now,
          onBack: onBack ?? () {},
          onManageBabies: () async {},
          onPreconsult: onPreconsult ?? (_) {},
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _clickIntake(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  if (find.text(text).evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(text),
      250,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(find.text(text)),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _intakeShot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  if (scale == 1 || width == 320) {
    await expectLater(
      find.byKey(const ValueKey('intake-capture')),
      matchesGoldenFile(
        '../../goldens/design_system/intake-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
      ),
    );
  }
}

class _Repository implements IntakeRepository {
  IntakeContext context = _context();
  Future<CareIntake>? nextSave;
  Future<IntakeContext>? nextLoad;
  final payloads = <IntakeContent>[];
  final consentVersions = <int>[];
  @override
  Future<IntakeContext> load(String appointmentId) async => nextLoad ?? context;
  @override
  Future<CareIntake> save(
    String appointmentId, {
    required IntakeContent content,
    required int expectedVersion,
    required int expectedConsentVersion,
    required String policyVersion,
  }) async {
    payloads.add(content);
    consentVersions.add(expectedConsentVersion);
    return nextSave ??
        CareIntake(
          id: 'intake',
          appointmentId: appointmentId,
          episodeId: context.appointment.episodeId,
          version: expectedVersion + 1,
          content: content,
          submittedAt: _now,
        );
  }

  @override
  Future<List<CareConsent>> consents(String episodeId) async =>
      context.consents;
  @override
  Future<CareConsent> setConsent(
    String episodeId, {
    required CareConsentScope scope,
    required bool active,
    required int expectedVersion,
    required String policyVersion,
  }) async => CareConsent(
    id: 'consent',
    episodeId: episodeId,
    scope: scope,
    active: active,
    version: expectedVersion + 1,
    policyVersion: policyVersion,
    recordedAt: _now,
  );
}

void main() {
  testWidgets('inventory intake server consent validation', (tester) async {
    final repository = _Repository()..context = _readyContext(saved: true);
    await _mountIntake(tester, repository);
    await tester.enterText(
      find.byKey(const ValueKey('goal-1')),
      'Updated goal',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    final pending = Completer<CareIntake>();
    repository.nextSave = pending.future;
    await _clickIntake(tester, 'Save changes');
    pending.completeError(
      const ProductFailure(
        ProductFailureKind.conflict,
        code: 'consent_conflict',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Consent has changed. Reload and confirm again.'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/intake-consent-validation-390.png',
      ),
    );
    expect(repository.payloads, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  test('intake age labels use calendar months and retain remaining days', () {
    expect(
      formatBabyAge(LocalDate(2026, 8, 18), LocalDate(2026, 9, 9)),
      '3 wk 1 day',
    );
    expect(
      formatBabyAge(LocalDate(2026, 1, 31), LocalDate(2026, 4, 30)),
      '3 mo',
    );
    expect(
      formatBabyAge(LocalDate(2024, 1, 31), LocalDate(2026, 2, 28)),
      '2 yr 1 mo',
    );
    expect(
      formatBabyAge(LocalDate(2026, 9, 8), LocalDate(2026, 9, 8)),
      'Newborn',
    );
    expect(
      formatBabyAge(LocalDate(2026, 9, 8), LocalDate(2026, 9, 9)),
      '1 day',
    );
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'intake design disclosures consent and save at $width / $scale',
        (tester) async {
          final repository = _Repository()..context = _readyContext();
          CareIntake? preconsult;
          await _mountIntake(
            tester,
            repository,
            width: width,
            scale: scale,
            onPreconsult: (v) => preconsult = v,
          );
          await _clickIntake(tester, 'Latching difficulties');
          await tester.enterText(
            find.byKey(const ValueKey('goal-1')),
            'A steadier feeding routine with less stress',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.widgetWithText(FilledButton, 'Save information'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Save information'),
                )
                .onPressed,
            isNull,
          );
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await _intakeShot(tester, 'form', width, scale);
          await _clickIntake(tester, 'Additional details');
          await tester.ensureVisible(find.byKey(const ValueKey('support-1')));
          await tester.enterText(
            find.byKey(const ValueKey('support-1')),
            'I would like help checking positioning and latch.',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await _intakeShot(tester, 'optional', width, scale);
          await _clickIntake(tester, 'Additional details');
          await _clickIntake(tester, 'Basic information');
          await tester.ensureVisible(find.text('Baby\'s age'));
          await tester.pumpAndSettle();
          expect(find.text('3 wk'), findsOneWidget);
          await _intakeShot(tester, 'profile', width, scale);
          await _clickIntake(tester, 'Basic information');
          await _clickIntake(tester, 'Read details');
          expect(find.text('Who can see it'), findsOneWidget);
          await _intakeShot(tester, 'consent', width, scale);
          await _clickIntake(tester, 'Got it');
          expect(repository.payloads, isEmpty);
          await _clickIntake(
            tester,
            'Allow the IBCLC for this service to view this form',
          );
          await _clickIntake(tester, 'Save information');
          expect(
            repository.payloads.single.supportNeeded,
            'I would like help checking positioning and latch.',
          );
          expect(find.text('Intake form complete'), findsOneWidget);
          expect(find.byTooltip('Close intake result'), findsNothing);
          await _intakeShot(tester, 'saved', width, scale);
          await _clickIntake(tester, 'Discuss with Momcozy AI');
          expect(preconsult?.version, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'intake uncertain save locks fields and retries identical snapshot',
    (tester) async {
      final repository = _Repository()..context = _readyContext();
      await _mountIntake(tester, repository);
      await _clickIntake(tester, 'Latching difficulties');
      await tester.enterText(
        find.byKey(const ValueKey('goal-1')),
        'Original goal',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _clickIntake(
        tester,
        'Allow the IBCLC for this service to view this form',
      );
      final wait = Completer<CareIntake>();
      repository.nextSave = wait.future;
      await _clickIntake(tester, 'Save information');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(IntakePage), findsOneWidget);
      wait.completeError(const ProductFailure(ProductFailureKind.offline));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('goal-1')))
            .enabled,
        isFalse,
      );
      await _intakeShot(tester, 'uncertain', 390, 1);
      await _clickIntake(tester, 'Back');
      expect(
        find.text(
          'Your save has not been confirmed. Refresh your records before trying again to avoid duplicates.',
        ),
        findsOneWidget,
      );
      await _intakeShot(tester, 'uncertain-leave', 390, 1);
      await _clickIntake(tester, 'Keep editing');
      repository.nextSave = null;
      await _clickIntake(tester, 'Try saving again');
      expect(repository.payloads[0], same(repository.payloads[1]));
      await _clickIntake(tester, 'Maybe later · View appointment');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final status in ['held', 'expired']) {
    testWidgets('intake blocks unconfirmed appointment $status', (
      tester,
    ) async {
      final data = _fixture();
      (data['appointment'] as Map)['status'] = status;
      final repository = _Repository()..context = readIntakeContext(data);
      await _mountIntake(tester, repository, width: 320, scale: 2);
      expect(find.text('Confirm an appointment time first'), findsOneWidget);
      expect(find.text('What would you most like help with?'), findsNothing);
      expect(repository.payloads, isEmpty);
      await _intakeShot(tester, status, 320, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('intake load failure can recover without stale form actions', (
    tester,
  ) async {
    final gate = Completer<IntakeContext>();
    final repository = _Repository()
      ..context = _readyContext()
      ..nextLoad = gate.future;
    await _mountIntake(tester, repository, settle: false);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Save information'), findsNothing);
    await _intakeShot(tester, 'loading', 390, 1);
    gate.completeError(const ProductFailure(ProductFailureKind.unavailable));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load right now. Please try again later.'),
      findsOneWidget,
    );
    await _intakeShot(tester, 'load-error', 390, 1);
    repository.nextLoad = null;
    await _clickIntake(tester, 'Try again');
    expect(find.text('What would you most like help with?'), findsOneWidget);
    expect(repository.payloads, isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'intake consent withdrawal and discard preserve edits at $scale',
      (tester) async {
        final repository = _Repository()..context = _readyContext(saved: true);
        var back = false;
        await _mountIntake(
          tester,
          repository,
          width: 320,
          scale: scale,
          onBack: () => back = true,
        );
        await _clickIntake(
          tester,
          'Allow the IBCLC for this service to view this form',
        );
        await _clickIntake(tester, 'Save changes');
        expect(repository.payloads, isEmpty);
        await _clickIntake(tester, 'Back');
        expect(find.text('Your unsaved changes will be lost.'), findsOneWidget);
        await _intakeShot(tester, 'discard', 320, scale);
        await _clickIntake(tester, 'Keep editing');
        expect(back, isFalse);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('intake-consent')),
              )
              .value,
          isFalse,
        );
        await _clickIntake(tester, 'Back');
        await _clickIntake(tester, 'Leave');
        expect(back, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'intake profile menus and birth date preserve draft at $scale',
      (tester) async {
        final repository = _Repository()..context = _readyContext();
        await _mountIntake(tester, repository, width: 320, scale: scale);
        await _clickIntake(tester, 'Basic information');
        await _clickIntake(tester, 'California (CA)');
        await _intakeShot(tester, 'region-menu', 320, scale);
        await tester.tap(find.text('New York (NY)').last);
        await tester.pumpAndSettle();
        await _clickIntake(tester, 'Girl');
        await _intakeShot(tester, 'sex-menu', 320, scale);
        await tester.tap(find.text('Boy').last);
        await tester.pumpAndSettle();
        await _clickIntake(tester, 'Bottle-fed breast milk');
        await _intakeShot(tester, 'feeding-menu', 320, scale);
        await tester.tap(find.text('Combination feeding').last);
        await tester.pumpAndSettle();
        final birth = find.byKey(const ValueKey('birth-2026-08-18'));
        await Scrollable.ensureVisible(tester.element(birth), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(birth);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(picker.lastDate, DateTime(2026, 9, 8));
        expect(
          picker.initialEntryMode,
          scale == 2
              ? DatePickerEntryMode.inputOnly
              : DatePickerEntryMode.calendar,
        );
        await _intakeShot(tester, 'birth-picker', 320, scale);
        final cancel = MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)),
        ).cancelButtonLabel;
        await tester.tap(find.text(cancel));
        await tester.pumpAndSettle();
        expect(repository.payloads, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'editing a saved intake returns without repeating first-use preconsult',
    (tester) async {
      final repository = _Repository()..context = _readyContext(saved: true);
      var back = false, preconsult = false;
      await _mountIntake(
        tester,
        repository,
        onBack: () => back = true,
        onPreconsult: (_) => preconsult = true,
      );
      await tester.enterText(
        find.byKey(const ValueKey('goal-1')),
        'Updated goal',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _clickIntake(tester, 'Save changes');
      expect(back, isTrue);
      expect(preconsult, isFalse);
      expect(find.text('Intake form complete'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'intake validates required consent and retains the submitted revision on retry',
    () async {
      final repository = _Repository();
      final controller = IntakeController(
        repository: repository,
        appointmentId: repository.context.appointment.id,
        now: () => _now,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.postpartumDays, '21');
      controller.change(() {
        controller.goal = 'Reduce feeding pain';
        controller.feedingMode = FeedingMode.breastfeeding;
      });
      controller.toggleSymptom(IntakeSymptom.feedingPain);
      await controller.save();
      expect(repository.payloads, isEmpty);
      expect(controller.validation, contains('IBCLC'));
      controller.change(() => controller.consent = true);
      final pending = Completer<CareIntake>();
      repository.nextSave = pending.future;
      final first = controller.save();
      await controller.save();
      expect(repository.payloads, hasLength(1));
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await first;
      expect(controller.uncertainSave, isTrue);
      controller.change(() => controller.goal = 'Changed during retry');
      expect(controller.goal, 'Reduce feeding pain');
      repository.nextSave = null;
      final saved = await controller.save();
      expect(saved!.version, 1);
      expect(repository.payloads[0], same(repository.payloads[1]));
      expect(repository.consentVersions, [0, 0]);
      expect(controller.dirty, isFalse);
    },
  );
  test('rebooking prefills content without reusing authorization', () async {
    final repository = _Repository();
    final value = repository.context;
    final profile = IntakeProfile(
      baby: BabyProfile(
        id: value.babies.single.id,
        name: 'Baby',
        birthDate: value.babies.single.birthDate,
        sex: BabySex.female,
        feedingMode: FeedingMode.breastfeeding,
      ),
      deliveryDate: value.deliveryDate!,
      region: 'CA',
    );
    repository.context = IntakeContext(
      appointment: value.appointment,
      babies: value.babies,
      consents: [
        CareConsent(
          id: 'consent',
          episodeId: value.appointment.episodeId,
          scope: CareConsentScope.ibclcCase,
          active: true,
          version: 1,
          policyVersion: value.policyVersion,
          recordedAt: _now,
        ),
      ],
      policyVersion: value.policyVersion,
      previousIntake: CareIntake(
        id: 'previous',
        appointmentId: 'cancelled-appointment',
        episodeId: value.appointment.episodeId,
        version: 1,
        submittedAt: _now,
        content: IntakeContent(
          symptoms: {IntakeSymptom.feedingPain},
          feedingGoal: 'Previous goal',
          supportNeeded: '',
          profile: profile,
        ),
      ),
    );
    final controller = IntakeController(
      repository: repository,
      appointmentId: value.appointment.id,
      now: () => _now,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.goal, 'Previous goal');
    expect(controller.consent, isFalse);
    expect(controller.saved, isNull);
  });
  test(
    'intake API carries real baby identity, calendar dates and consent version without risk or age aliases',
    () async {
      final context = _context();
      final content = IntakeContent(
        symptoms: {IntakeSymptom.feedingPain},
        feedingGoal: 'Goal',
        supportNeeded: '',
        profile: IntakeProfile(
          baby: BabyProfile(
            id: context.babies.single.id,
            name: 'Baby',
            birthDate: context.babies.single.birthDate,
            sex: BabySex.female,
            feedingMode: FeedingMode.breastfeeding,
          ),
          deliveryDate: context.deliveryDate!,
          region: 'CA',
        ),
      );
      final json = {
        ...writeIntakeContent(content),
        'id': 'intake',
        'appointment_id': context.appointment.id,
        'episode_id': context.appointment.episodeId,
        'version': 1,
        'submitted_at': _now.toIso8601String(),
      };
      final transport = FixtureApiJsonTransport(json);
      await IntakeApiRepository(transport: transport).save(
        context.appointment.id,
        content: content,
        expectedVersion: 0,
        expectedConsentVersion: 0,
        policyVersion: context.policyVersion,
      );
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastBody!['expected_consent_version'], 0);
      expect(transport.lastBody!['consent_to_share'], isTrue);
      expect(
        (transport.lastBody!['profile'] as Map)['baby_id'],
        context.babies.single.id,
      );
      expect(jsonEncode(transport.lastBody), isNot(contains('postpartum_day')));
      expect(jsonEncode(transport.lastBody), isNot(contains('risk_level')));
      expect(jsonEncode(transport.lastBody), isNot(contains('baby_age_label')));
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('intake form with missing feeding mode at $width / $scale', (
        tester,
      ) async {
        await loadMomCozyTestFonts();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
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
            home: IntakePage(
              repository: repository,
              appointmentId: repository.context.appointment.id,
              now: () => _now,
              onBack: () {},
              onManageBabies: () async {},
              onPreconsult: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(IntakePage),
            matchesGoldenFile(
              '../../goldens/product_baseline/intake-${width.toInt()}.png',
            ),
          );
        }
        if (scale == 2) {
          for (var step = 0; step < 8; step++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -400),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'intake saves only after fields and explicit sharing are complete',
    (tester) async {
      await loadMomCozyTestFonts();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: IntakePage(
            repository: repository,
            appointmentId: repository.context.appointment.id,
            now: () => _now,
            onBack: () => closed = true,
            onManageBabies: () async {},
            onPreconsult: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latching difficulties'));
      await tester.enterText(
        find.byKey(const ValueKey('goal-1')),
        'Find a comfortable feeding position',
      );
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<FeedingMode>),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<FeedingMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exclusive breastfeeding').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('intake-consent')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('intake-consent')));
      await tester.scrollUntilVisible(
        find.text('Save information'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save information'));
      await tester.pumpAndSettle();
      expect(find.text('Intake form complete'), findsOneWidget);
      expect(
        repository.payloads.single.profile.baby.id,
        repository.context.babies.single.id,
      );
      await tester.tap(find.text('Maybe later · View appointment'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
