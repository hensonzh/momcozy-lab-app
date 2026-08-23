import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/migrations/legacy_prenatal_contract_filter.dart';

void main() {
  group('legacy prenatal contract filter', () {
    test('recognizes retired artifacts, forms, routes, and plan payloads', () {
      expect(isRetiredPrenatalArtifactType('hospital_bag_cart'), isTrue);
      expect(
        isRetiredPrenatalForm(const {'id': 'birthPlanCardIntake'}),
        isTrue,
      );
      expect(
        isRetiredPrenatalRoute(
          'https://app.example.com/hospital-bag-cart?source=history',
        ),
        isTrue,
      );
      expect(isRetiredPrenatalPlanType('birth_journey'), isTrue);
      expect(
        isRetiredPrenatalPlanPayload(const {'task_type': 'prenatal'}),
        isTrue,
      );
    });

    test('does not classify postpartum contracts as retired', () {
      expect(isRetiredPrenatalArtifactType('ibclc_booking_card'), isFalse);
      expect(isRetiredPrenatalForm(const {'id': 'support_intake'}), isFalse);
      expect(isRetiredPrenatalRoute('/lactation'), isFalse);
      expect(isRetiredPrenatalPlanType('lactation'), isFalse);
      expect(
        isRetiredPrenatalPlanPayload(const {'task_type': 'pumping'}),
        isFalse,
      );
    });

    test('removes only retired links from persisted markdown', () {
      const markdown = '''Keep this text.

[Open old cart](/hospital-bag-cart)

[Open lactation](/lactation)

https://app.example.com/hospital-bag-cart?source=history''';

      expect(
        stripRetiredPrenatalLinks(markdown),
        'Keep this text.\n\n[Open lactation](/lactation)',
      );
    });
  });
}
