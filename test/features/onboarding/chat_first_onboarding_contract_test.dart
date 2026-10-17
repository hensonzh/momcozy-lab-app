import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('new state separates entry permission from a legacy full profile', () {
    final required = OnboardingState.fromMap(const {
      'status': 'required',
      'can_enter_app': false,
      'role': null,
      'profile_scope': 'none',
      'primary_infant_id': null,
    });
    expect(required.canEnterApp, isFalse);
    expect(required.profileConfirmed, isFalse);
    final father = OnboardingState.fromMap(const {
      'status': 'completed',
      'can_enter_app': true,
      'role': 'father',
      'profile_scope': 'chat_first',
      'primary_infant_id': null,
    });
    expect(father.canEnterApp, isTrue);
    expect(father.role, FamilyRole.father);
    expect(father.profileConfirmed, isFalse);
    expect(father.primaryInfantId, isNull);
    final legacy = OnboardingState.fromMap(const {
      'status': 'completed',
      'can_enter_app': true,
      'role': 'mother',
      'profile_scope': 'legacy_full',
      'primary_infant_id': 'baby-1',
    });
    expect(legacy.canEnterApp, isTrue);
    expect(legacy.profileConfirmed, isTrue);
    expect(legacy.primaryInfantId, 'baby-1');
    expect(
      () => OnboardingState.fromMap(const {
        'status': 'required',
        'can_enter_app': true,
        'role': 'mother',
        'profile_scope': 'none',
      }),
      throwsFormatException,
    );
  });

  test('mother draft sends collected facts only, with no invented babies', () {
    final draft = ChatFirstOnboardingDraft()
      ..role = FamilyRole.mother
      ..concerns.addAll(['milk-supply', 'baby-sleep'])
      ..age = 32
      ..deliveryCount = 2
      ..deliveryDate = DateTime(2026, 9, 28)
      ..gestationWeeks = 36
      ..gestationDays = 2
      ..babyCount = 2;
    final body = draft.toMap();
    expect(body['role'], 'mother');
    expect(body['stage'], 'postpartum');
    expect(body['delivery_date'], '2026-09-28');
    expect(body['concerns'], ['milk-supply', 'baby-sleep']);
    expect(body['baby_count'], 2);
    for (final field in ['display_name', 'feeding_methods', 'infants']) {
      expect(body.containsKey(field), isFalse);
    }
    draft.gestationWeeks = 37;
    draft.gestationDays = 0;
    expect(draft.toMap()['gestation_days'], 0);
    draft.gestationDays = 1;
    expect(() => draft.toMap(), throwsFormatException);
  });

  test('non-mother sends role alone; unselected mother cannot be saved', () {
    final draft = ChatFirstOnboardingDraft();
    expect(() => draft.toMap(), throwsFormatException);
    draft.role = FamilyRole.maternalGrandparent;
    expect(draft.toMap(), {'role': 'maternal-grandparent'});
    draft.role = FamilyRole.mother;
    expect(() => draft.toMap(), throwsFormatException);
  });

  test(
    'repository uses new authenticated contract for read and completion',
    () async {
      final transport = FixtureApiJsonTransportByPath(
        const {
          chatFirstOnboardingEndpoint: {
            'status': 'required',
            'can_enter_app': false,
            'role': null,
            'profile_scope': 'none',
            'primary_infant_id': null,
          },
        },
        writeResponsesByPath: const {
          chatFirstOnboardingEndpoint: {
            'status': 'completed',
            'can_enter_app': true,
            'role': 'father',
            'profile_scope': 'chat_first',
            'primary_infant_id': null,
          },
        },
      );
      final repository = OnboardingApiRepository(transport: transport);
      expect((await repository.fetchChatFirstState()).canEnterApp, isFalse);
      expect(transport.getPaths, [chatFirstOnboardingEndpoint]);
      final state = await repository.completeChatFirst(
        ChatFirstOnboardingDraft()..role = FamilyRole.father,
      );
      expect(state.role, FamilyRole.father);
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastPath, chatFirstOnboardingEndpoint);
      expect(transport.lastBody, {'role': 'father'});
    },
  );

  test(
    'chat-first controller unlocks the matching account after real save',
    () async {
      final transport = FixtureApiJsonTransportByPath(
        const {
          chatFirstOnboardingEndpoint: {
            'status': 'required',
            'can_enter_app': false,
            'role': null,
            'profile_scope': 'none',
            'primary_infant_id': null,
          },
        },
        writeResponsesByPath: const {
          chatFirstOnboardingEndpoint: {
            'status': 'completed',
            'can_enter_app': true,
            'role': 'father',
            'profile_scope': 'chat_first',
            'primary_infant_id': null,
          },
        },
      );
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'father-user',
            babyId: '',
            locale: 'zh-CN',
            accessToken: 'access',
          ),
        ),
      );
      final controller = OnboardingController(
        runtimeController: runtime,
        chatFirstMode: true,
      );
      await controller.load();
      expect(transport.getPaths, contains(chatFirstOnboardingEndpoint));
      expect(controller.requiresOnboardingFor('father-user'), isTrue);
      expect(
        await controller.completeChatFirst(
          ChatFirstOnboardingDraft()..role = FamilyRole.father,
        ),
        isTrue,
      );
      expect(controller.requiresOnboardingFor('father-user'), isFalse);
      expect(controller.state?.role, FamilyRole.father);
      expect(transport.mutationPaths, [chatFirstOnboardingEndpoint]);
      controller.dispose();
      runtime.dispose();
    },
  );
}
