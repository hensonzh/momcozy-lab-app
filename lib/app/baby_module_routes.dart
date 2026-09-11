import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/baby/baby_record.dart';
import '../modules/baby/application/baby_home_controller.dart';
import '../modules/baby/presentation/baby_home_page.dart';
import '../modules/baby/presentation/baby_records_page.dart';
import '../services/baby/baby_profiles_api_repository.dart';
import '../services/baby/baby_records_api_repository.dart';
import 'momcozy_api_runtime.dart';

Widget buildBabyHome(
  BuildContext context, {
  Future<void> Function(String babyId)? onBabySelected,
}) {
  final runtime = MomCozyRuntimeScope.of(context);
  return BabyHomePage(
    key: ValueKey(runtime),
    controller: BabyHomeController(
      profileRepository: BabyProfilesApiRepository(
        transport: runtime.jsonTransport,
      ),
      recordRepository: BabyRecordsApiRepository(
        transport: runtime.jsonTransport,
      ),
      timezoneProvider: runtime.timezoneProvider,
      now: runtime.now,
      selectedBabyId: runtime.currentSession.babyId,
    ),
    onAsk: (text) => context.go('/', extra: {'agentPrefill': text}),
    onHistory: (babyId) async {
      await context.push('/babies/$babyId/records');
    },
    onBabySelected: onBabySelected,
    rememberedBabyId: runtime.currentSession.babyId,
  );
}

final babyModuleRoutes = <GoRoute>[
  GoRoute(
    path: '/babies/:babyId/records',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context),
          babyId = state.pathParameters['babyId']!;
      return BabyRecordsPage(
        key: ValueKey('baby-records-${runtime.currentSession.userId}-$babyId'),
        babyId: babyId,
        profiles: BabyProfilesApiRepository(transport: runtime.jsonTransport),
        repository: BabyRecordsApiRepository(transport: runtime.jsonTransport),
        timezoneProvider: runtime.timezoneProvider,
        now: runtime.now,
        initialKind:
            BabyRecordKind.values
                .where(
                  (value) => value.name == state.uri.queryParameters['kind'],
                )
                .firstOrNull ??
            BabyRecordKind.feeding,
        onBack: () => context.canPop() ? context.pop() : context.go('/baby'),
      );
    },
  ),
];
