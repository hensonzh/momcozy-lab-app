import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;

  test('prenatal product modules and assets are removed', () {
    const removedPaths = <String>[
      'lib/features/hospital_bag',
      'lib/features/profile_overview/domain/mom_life_stage.dart',
      'lib/features/agent_hub/domain/birth_prep_profile_defaults.dart',
      'assets/images/me_baby_overview/pregnancy_avatar.png',
      'assets/images/me_baby_overview/2.0x/pregnancy_avatar.png',
      'assets/images/me_baby_overview/3.0x/pregnancy_avatar.png',
      'assets/images/me_baby_overview/prenatal_education.png',
      'assets/images/me_baby_overview/2.0x/prenatal_education.png',
      'assets/images/me_baby_overview/3.0x/prenatal_education.png',
    ];

    for (final relativePath in removedPaths) {
      expect(
        FileSystemEntity.typeSync('${root.path}/$relativePath'),
        FileSystemEntityType.notFound,
        reason: '$relativePath belongs to the removed prenatal product',
      );
    }

    final hospitalBagAssets = Directory('${root.path}/assets/images')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) => file.uri.pathSegments.last.startsWith('hospital_bag_'),
        );
    expect(hospitalBagAssets, isEmpty);
  });

  test('active Flutter source has no prenatal product contracts', () {
    const allowedLegacyFiles = <String>{'lib/core/privacy/log_redactor.dart'};
    const removedContracts = <String>[
      'OnboardingCareStage',
      'MomLifeStage',
      'PregnancyProgress',
      'current_care_stage',
      'estimated_due_date',
      'expected_due_date',
      'Pregnancy',
      'pregnancy',
      'Fertility',
      'fertility',
      'BirthPrepProfileDefaults',
      'HospitalBag',
      '/hospital-bag-cart',
      'pregnancy_plan.changed',
      'pregnancy.due_date_or_week',
      'PlanCategory.pregnancy',
      'birth_journey_plan_card',
      'birth_plan_card',
      'hospital_bag_card',
      'hospital_bag_cart',
    ];

    final violations = <String>[];
    for (final file
        in Directory('${root.path}/lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final relativePath = file.path.substring(root.path.length + 1);
      if (allowedLegacyFiles.contains(relativePath)) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final contract in removedContracts) {
        if (source.contains(contract)) {
          violations.add('$relativePath: $contract');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('Agent Runtime contract has no retired hospital bag context', () {
    final contract = File(
      '${root.path}/docs/backend-contract/agent-runtime.openapi.generated.json',
    ).readAsStringSync();

    expect(contract, isNot(contains('hospital_bag_cart')));
    expect(contract, isNot(contains('HospitalBagCart')));
    expect(contract, isNot(contains('HospitalBagCurrency')));
  });

  test('postpartum delivery and infant history remain first-class data', () {
    final onboarding = File(
      '${root.path}/lib/features/onboarding/domain/onboarding.dart',
    ).readAsStringSync();
    final profile = File(
      '${root.path}/lib/domain/mother/mother_profile.dart',
    ).readAsStringSync();

    for (final field in <String>['deliveryDate', 'deliveryType', 'infants']) {
      expect(onboarding, contains(field), reason: 'missing postpartum $field');
    }
    expect(profile, contains('deliveryDate'));
    expect(profile, contains('postpartumDay'));
  });
}
