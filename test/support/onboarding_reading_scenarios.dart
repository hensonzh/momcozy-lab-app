import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'fixture_api_transport.dart';

Future<void> verifyOnboardingReading(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  for (final generating in [false, true]) {
    final transport = FixtureApiJsonTransportByPath(
      {
        '/v1/onboarding/me': {
          'status': generating ? 'avatar_generating' : 'avatar_required',
          'current_step': 'avatar',
          'profile_confirmed': true,
          'can_enter_app': true,
          'can_continue_with_default': true,
          if (generating)
            'avatar': {
              'id': 'generation',
              'stage': 'postpartum',
              'status': 'queued',
              'created_at': '2026-09-10T00:00:00Z',
              'error_code': '',
              'candidates': [],
            },
        },
      },
      writeResponsesByPath: {
        '/v1/onboarding/me/complete': {
          'status': 'completed',
          'profile_confirmed': true,
          'can_enter_app': true,
          'avatar_setup_completed': true,
        },
      },
    );
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'reading-fixture',
          babyId: '',
          locale: 'en-US',
          accessToken: 'fixture-token',
        ),
      ),
    );
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: OnboardingPage(
          controller: controller,
          pickPortrait: (_) async => null,
        ),
      ),
    );
    Future<void> frame() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    Future<void> showParagraph(String prefix, String state) async {
      final copy = find.textContaining(prefix);
      expect(copy, findsOneWidget);
      final style = tester.renderObject<RenderParagraph>(copy).text.style!;
      expect(style.height, 1.55, reason: prefix);
      await tester.ensureVisible(copy);
      await frame();
      await capture(state);
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await frame();
      await tester.tap(finder);
      await frame();
    }

    try {
      await frame();
      final reason = find.textContaining(
        generating
            ? 'Your photo has been received.'
            : 'A portrait helps us make your companion',
      );
      expect(
        tester.renderObject<RenderParagraph>(reason).text.style!.height,
        1.55,
      );
      if (generating) {
        await showParagraph('Your photo is uploaded.', 'generation-stage');
        await showParagraph('Image generation can take', 'generation-wait');
        expect(transport.mutationPaths, isEmpty);
      } else {
        await showParagraph('Your photo is used only', 'photo-privacy');
        await tap(find.widgetWithText(FilledButton, 'Upload a photo'));
        await tap(find.text('Choose from library'));
        expect(transport.mutationPaths, isEmpty);
        await tap(find.text('Use the MomCozy character for now'));
        await tap(find.widgetWithText(FilledButton, 'Continue'));
        expect(transport.lastBody?['use_default_avatar'], isTrue);
        await showParagraph('Applying your choice', 'activation');
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      runtime.dispose();
      await tester.pump();
    }
  }
}
