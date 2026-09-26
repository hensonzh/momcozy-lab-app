import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/presentation/notification_scope.dart';
import '../features/notifications/presentation/notification_settings_page.dart';
import '../modules/profile/presentation/privacy_page.dart';
import '../modules/mom/presentation/lactation_page.dart';
import '../services/lactation/lactation_api_repository.dart';
import '../domain/shared/local_date.dart';
import 'me_home_route.dart';
import 'momcozy_api_runtime.dart';

Widget buildMotherHome(BuildContext context) {
  final runtime = MomCozyRuntimeScope.of(context);
  return MeHomeRoute(key: ValueKey(runtime), runtime: runtime);
}

final momModuleRoutes = <GoRoute>[
  GoRoute(
    path: '/me/lactation',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return LactationPage(
        key: ValueKey('lactation-${runtime.currentSession.userId}'),
        repository: LactationApiRepository(transport: runtime.jsonTransport),
        ownerUserId: runtime.currentSession.userId,
        date: LocalDate.fromDateTime(runtime.now().toLocal()),
        now: runtime.now,
        create: state.uri.queryParameters['create'] == '1',
        onClose: () => context.canPop() ? context.pop() : context.go('/me'),
      );
    },
  ),
  GoRoute(
    path: '/privacy',
    builder: (context, state) => PrivacyPage(
      onBack: () => context.canPop() ? context.pop() : context.go('/more'),
    ),
  ),
  GoRoute(
    path: '/notifications/settings',
    builder: (context, state) => NotificationSettingsPage(
      coordinator: NotificationScope.maybeOf(context),
    ),
  ),
];
