import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_entry_intent.dart';

void main() {
  group('Status entry intent', () {
    test('parses growth query with a stable one-shot id', () {
      final first = statusEntryIntentFromRoute(
        Uri.parse('/status?statusIntent=growth&statusIntentId=7'),
        null,
      );
      final repeated = statusEntryIntentFromRoute(
        Uri.parse('/status?statusIntent=growth&statusIntentId=7'),
        null,
      );
      final next = statusEntryIntentFromRoute(
        Uri.parse('/status?statusIntent=growth&statusIntentId=8'),
        null,
      );

      expect(first?.kind, StatusEntryIntentKind.growth);
      expect(repeated?.token, first?.token);
      expect(next?.token, isNot(first?.token));
    });

    test('accepts typed diary and plan route extras', () {
      final diary = statusEntryIntentFromRoute(null, const {
        'type': 'OpenStatusPregnancyDiaryBadge',
        'eventId': 'diary-1',
      });
      final plan = statusEntryIntentFromRoute(null, const {
        'source': 'birthJourneyPlanChanged',
        'eventId': 'plan-1',
      });

      expect(diary?.kind, StatusEntryIntentKind.pregnancyDiary);
      expect(plan?.kind, StatusEntryIntentKind.birthJourney);
    });

    test('ignores unknown and malformed extras safely', () {
      expect(
        statusEntryIntentFromRoute(Uri.parse('/status'), const {1: 'growth'}),
        isNull,
      );
      expect(
        statusEntryIntentFromRoute(
          Uri.parse('/status?statusIntent=unknown'),
          const {'type': 'UnknownIntent'},
        ),
        isNull,
      );
    });
  });
}
