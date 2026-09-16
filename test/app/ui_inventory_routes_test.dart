import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'inventory exports the actual registered user routes, including auth gates',
    () async {
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(
          const MomCozySession(
            status: MomCozySessionStatus.anonymous,
            userId: 'inventory',
            babyId: 'inventory-baby',
            locale: 'zh-CN',
          ),
        ),
      );
      final onboarding = OnboardingController(runtimeController: runtime);
      final router = createMomCozyRouter(
        runtimeController: runtime,
        onboardingController: onboarding,
      );
      final rows = <Map<String, Object?>>[];
      void visit(List<RouteBase> routes, String parent) {
        for (final route in routes) {
          if (route is GoRoute) {
            final path = route.path.startsWith('/')
                ? route.path
                : '$parent/${route.path}';
            rows.add({
              'path': path,
              'name': route.name,
              'has_redirect': route.redirect != null,
              'has_builder': route.builder != null || route.pageBuilder != null,
            });
            visit(route.routes, path);
          } else if (route is ShellRouteBase) {
            visit(route.routes, parent);
          }
        }
      }

      visit(router.configuration.routes, '');
      expect(
        rows.map((e) => e['path']),
        containsAll([
          '/me',
          '/baby',
          '/',
          '/schedule',
          '/more',
          '/login',
          '/onboarding',
        ]),
      );
      final output = Platform.environment['MOMCOZY_UI_ROUTES_OUTPUT'];
      final withOnboarding = List<Map<String, Object?>>.of(rows);
      final defaultRouter = createMomCozyRouter(runtimeController: runtime);
      rows.clear();
      visit(defaultRouter.configuration.routes, '');
      if (output != null) {
        final file = File(output);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          '${const JsonEncoder.withIndent('  ').convert({'default_local_build': rows, 'onboarding_enabled_build': withOnboarding, 'notes': 'The local build uses default false capability flags. Onboarding/avatar routes require an OnboardingController. History is an in-page capability, not an independent GoRoute.'})}\n',
        );
      }
      defaultRouter.dispose();
      router.dispose();
      onboarding.dispose();
      runtime.dispose();
    },
  );
}
