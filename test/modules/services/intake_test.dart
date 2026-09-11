import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
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

class _Repository implements IntakeRepository {
  IntakeContext context = _context();
  Future<CareIntake>? nextSave;
  final payloads = <IntakeContent>[];
  final consentVersions = <int>[];
  @override
  Future<IntakeContext> load(String appointmentId) async => context;
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
      expect(controller.validation, contains('允许'));
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
        name: '宝宝',
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
            name: '宝宝',
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
      await tester.tap(find.text('含乳困难'));
      await tester.enterText(find.byKey(const ValueKey('goal-1')), '找到舒服的喂养姿势');
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<FeedingMode>),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<FeedingMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('纯母乳').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('intake-consent')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('intake-consent')));
      await tester.scrollUntilVisible(
        find.text('保存信息'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存信息'));
      await tester.pumpAndSettle();
      expect(find.text('信息采集已完成'), findsOneWidget);
      expect(
        repository.payloads.single.profile.baby.id,
        repository.context.babies.single.id,
      );
      await tester.tap(find.text('稍后再说，查看预约'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
