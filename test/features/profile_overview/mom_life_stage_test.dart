import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

void main() {
  group('MomLifeStage', () {
    test('prefers the explicit profile value', () {
      expect(
        MomLifeStage.resolve(
          explicitValue: 'fertility',
          deliveryDate: DateTime(2026, 9, 20),
          now: () => DateTime(2026, 7, 1),
        ),
        MomLifeStage.fertility,
      );
    });

    test('infers pregnancy only while a delivery date is in the future', () {
      expect(
        MomLifeStage.resolve(
          deliveryDate: DateTime(2026, 9, 20),
          now: () => DateTime(2026, 7, 1),
        ),
        MomLifeStage.pregnancy,
      );
      expect(
        MomLifeStage.resolve(
          deliveryDate: DateTime(2026, 5, 20),
          now: () => DateTime(2026, 7, 1),
        ),
        MomLifeStage.postpartum,
      );
    });

    test('supports the legacy prenatal alias without broad guessing', () {
      expect(MomLifeStage.tryParse('prenatal'), MomLifeStage.pregnancy);
      expect(MomLifeStage.tryParse('newborn'), isNull);
    });
  });
}
