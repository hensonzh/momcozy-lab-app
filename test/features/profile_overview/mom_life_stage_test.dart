import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

void main() {
  group('MomLifeStage', () {
    test('prefers the explicit profile value', () {
      expect(
        MomLifeStage.resolve(
          explicitValue: 'fertility',
          expectedDueDate: DateTime(2026, 9, 20),
        ),
        MomLifeStage.fertility,
      );
    });

    test('infers the stage from canonical dates', () {
      expect(
        MomLifeStage.resolve(expectedDueDate: DateTime(2026, 9, 20)),
        MomLifeStage.pregnancy,
      );
      expect(
        MomLifeStage.resolve(actualDeliveryDate: DateTime(2026, 5, 20)),
        MomLifeStage.postpartum,
      );
    });

    test('supports the legacy prenatal alias without broad guessing', () {
      expect(MomLifeStage.tryParse('prenatal'), MomLifeStage.pregnancy);
      expect(MomLifeStage.tryParse('newborn'), isNull);
    });
  });
}
