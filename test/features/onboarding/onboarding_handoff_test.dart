import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets(
    'accepted avatar task explains the wait before entering the app',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transport = FixtureApiJsonTransportByPath(
        const {
          onboardingMeEndpoint: {
            'status': 'avatar_required',
            'current_step': 'avatar',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'can_enter_app': false,
            'avatar_setup_completed': false,
            'can_continue_with_default': true,
          },
        },
        writeResponsesByPath: const {
          '$onboardingMeEndpoint/avatar-generations': {
            'status': 'avatar_generating',
            'current_step': 'generating',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'can_enter_app': true,
            'avatar_setup_completed': false,
            'avatar': {
              'id': 'generation-id',
              'stage': 'postpartum',
              'status': 'queued',
              'error_code': '',
              'created_at': '2026-08-09T00:00:00Z',
              'candidates': <Object?>[],
            },
          },
        },
      );
      final runtimeController = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: FixtureApiMultipartTransport(const {
            'id': 'portrait-file-id',
          }),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'handoff-user',
            babyId: '',
            locale: 'en-US',
            accessToken: 'access',
          ),
        ),
      );
      final onboardingController = OnboardingController(
        runtimeController: runtimeController,
      );
      await onboardingController.load();
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => OnboardingPage(
              controller: onboardingController,
              entryPath: '/home',
              pickPortrait: (_) async => OnboardingPortrait(
                bytes: Uint8List.fromList([1, 2, 3]),
                name: 'portrait.jpg',
                mimeType: 'image/jpeg',
              ),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('App home'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: momCozyTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      final upload = find.widgetWithText(FilledButton, 'Upload a photo');
      await tester.ensureVisible(upload);
      await tester.tap(upload);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Your digital companion is being created'),
        findsOneWidget,
      );
      expect(find.textContaining('keep working in the cloud'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Enter the app'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Wait here'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Enter the app'));
      await tester.pumpAndSettle();

      expect(find.text('App home'), findsOneWidget);
      expect(transport.lastPath, '$onboardingMeEndpoint/avatar-generations');

      router.dispose();
      onboardingController.dispose();
      runtimeController.dispose();
    },
  );
}
