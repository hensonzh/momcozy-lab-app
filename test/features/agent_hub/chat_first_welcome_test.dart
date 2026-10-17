import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_welcome.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';

void main() {
  test(
    'welcome derives a stable idempotency key from accepted facts and calendar day',
    () {
      ChatFirstOnboardingDraft draft() =>
          ChatFirstOnboardingDraft(now: () => DateTime(2026, 10, 15))
            ..role = FamilyRole.mother
            ..age = 30
            ..deliveryCount = 1
            ..deliveryDate = DateTime(2026, 10, 12)
            ..gestationWeeks = 38
            ..gestationDays = 0
            ..babyCount = 1;
      final first = ChatFirstWelcomeRequest.forCompletedDraft(
        draft(),
        userId: 'owner-1',
        asOfDate: DateTime(2026, 10, 15),
      );
      final same = ChatFirstWelcomeRequest.forCompletedDraft(
        draft(),
        userId: 'owner-1',
        asOfDate: DateTime(2026, 10, 15),
      );
      final anotherDay = ChatFirstWelcomeRequest.forCompletedDraft(
        draft(),
        userId: 'owner-1',
        asOfDate: DateTime(2026, 10, 16),
      );
      final anotherAccount = ChatFirstWelcomeRequest.forCompletedDraft(
        draft(),
        userId: 'owner-2',
        asOfDate: DateTime(2026, 10, 15),
      );
      expect(first.idempotencyKey, same.idempotencyKey);
      expect(first.idempotencyKey, isNot(anotherDay.idempotencyKey));
      expect(first.idempotencyKey, isNot(anotherAccount.idempotencyKey));
      expect(first.message, contains('当前账号的权威资料'));
      expect(first.message, isNot(contains('Mia')));
      expect(first.message, isNot(contains('直接喂养')));
      expect(first.metadata, {'source': 'chat_first_welcome'});
      expect(isChatFirstWelcomePrompt(first.message), isTrue);
      expect(chatFirstWelcomeKeyForPrompt(first.message), first.idempotencyKey);
      expect(chatFirstWelcomeKeyForPrompt('普通用户文字'), isNull);
      expect(chatFirstWelcomeKeyForPrompt('[Momcozy Chat 欢迎引导][old]'), isNull);
      expect(isChatFirstWelcomePrompt('你好，我想知道宝宝为什么哭'), isFalse);
      final changed = draft()..concerns.add('crying');
      expect(
        ChatFirstWelcomeRequest.forCompletedDraft(
          changed,
          userId: 'owner-1',
          asOfDate: DateTime(2026, 10, 15),
        ).idempotencyKey,
        isNot(first.idempotencyKey),
      );
    },
  );

  test(
    'authoritative profile snapshot yields the same key as accepted draft',
    () {
      final draft = ChatFirstOnboardingDraft(now: () => DateTime(2026, 10, 15))
        ..role = FamilyRole.mother
        ..age = 30
        ..deliveryCount = 1
        ..deliveryDate = DateTime(2026, 10, 12)
        ..gestationWeeks = 38
        ..gestationDays = 0
        ..babyCount = 1
        ..concerns.addAll(['baby-sleep', 'crying']);
      final accepted = ChatFirstWelcomeRequest.forCompletedDraft(
        draft,
        userId: 'owner-1',
        asOfDate: DateTime(2026, 10, 15),
      );
      final fromBackend = ChatFirstWelcomeRequest.forAuthoritativeProfile(
        userId: 'owner-1',
        asOfDate: DateTime(2026, 10, 15),
        profile: const {
          'preferred_name': null,
          'age': 30,
          'delivery_count': 1,
          'actual_delivery_date': '2026-10-12',
          'gestation_weeks': 38,
          'gestation_days': 0,
          'baby_count': 1,
        },
        concerns: const [
          {'note': '宝宝为什么哭', 'ended': false},
          {'note': '宝宝睡得好吗', 'ended': false},
        ],
      );
      expect(fromBackend.idempotencyKey, accepted.idempotencyKey);
      expect(fromBackend.message, accepted.message);
    },
  );
}
