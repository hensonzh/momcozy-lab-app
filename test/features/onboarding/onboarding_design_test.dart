import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_banner.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

const _avatarAsset = 'assets/images/me_baby_overview/postpartum_avatar.png';
void main() {
  late Uint8List portrait;
  setUpAll(() async {
    await loadMomCozyTestFonts();
    portrait = (await rootBundle.load(_avatarAsset)).buffer.asUint8List();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      Future<void> mount(
        WidgetTester tester,
        OnboardingController controller,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await controller.load();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: OnboardingPage(
              controller: controller,
              pickPortrait: (_) async => null,
              avatarThumbnailLoader: (_) async => portrait,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(OnboardingPage));
          await precacheImage(const AssetImage(_avatarAsset), context);
          await precacheImage(MemoryImage(portrait), context);
        });
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> capture(WidgetTester tester, String name) async {
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/onboarding-$name-${width.toInt()}.png',
            ),
          );
        }
      }

      Future<void> tap(WidgetTester tester, Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      testWidgets('onboarding profile forms at $width / $scale', (
        tester,
      ) async {
        final transport = FixtureApiJsonTransportByPath(
          {
            '/v1/onboarding/me': {
              'status': 'required',
              'profile_confirmed': false,
            },
          },
          writeResponsesByPath: {
            '/v1/onboarding/me/profile': _state('required'),
          },
        );
        final runtime = _runtime(transport);
        final controller = OnboardingController(runtimeController: runtime);
        addTearDown(runtime.dispose);
        addTearDown(controller.dispose);
        await mount(tester, controller);
        await capture(tester, 'basics');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byKey(const ValueKey('onboarding-display-name')),
          'Mia',
        );
        await tester.enterText(
          find.byKey(const ValueKey('onboarding-age')),
          '32',
        );
        await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await capture(tester, 'delivery');
        await tap(tester, find.text('Choose date'));
        await tap(tester, find.text('OK'));
        await tap(
          tester,
          find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
        );
        await capture(tester, 'birth');
        await tap(tester, find.text('Prefer not to say yet'));
        await tap(tester, find.text('Cesarean birth').last);
        await tap(
          tester,
          find.byKey(const ValueKey('onboarding-postpartum-save')),
        );
        expect(transport.mutationPaths, ['/v1/onboarding/me/profile']);
        expect(transport.lastBody?['delivery_type'], 'cesarean');
        expect(find.text('Create your digital companion'), findsOneWidget);
      });
      testWidgets('avatar task banners at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final banners = <Widget>[];
        var opened = 0;
        for (final status in ['generating', 'review', 'failed', 'completed']) {
          final transport = FixtureApiJsonTransportByPath({
            '/v1/onboarding/me': status == 'completed'
                ? {
                    'status': 'completed',
                    'profile_confirmed': true,
                    'can_enter_app': true,
                    'avatar_setup_completed': true,
                  }
                : _state(status),
          });
          final runtime = _runtime(transport);
          final onboarding = OnboardingController(runtimeController: runtime);
          await onboarding.load();
          final task = AvatarTaskController(onboardingController: onboarding)
            ..setForeground(false);
          if (status == 'completed') task.showCompleted();
          addTearDown(runtime.dispose);
          addTearDown(onboarding.dispose);
          addTearDown(task.dispose);
          banners.add(
            AvatarTaskBanner(
              key: ValueKey(status),
              controller: task,
              onOpen: () => opened++,
            ),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(child: ListView(children: banners)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await capture(tester, 'banners');
        await tester.tap(find.byKey(const ValueKey('review')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(opened, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 4));
      });
      for (final status in ['required', 'generating', 'review', 'failed']) {
        testWidgets('onboarding avatar $status at $width / $scale', (
          tester,
        ) async {
          final transport = FixtureApiJsonTransportByPath({
            '/v1/onboarding/me': _state(status),
          });
          final runtime = _runtime(transport);
          final controller = OnboardingController(runtimeController: runtime);
          addTearDown(runtime.dispose);
          addTearDown(controller.dispose);
          await mount(tester, controller);
          await capture(tester, status);
          if (status == 'required' || status == 'failed') {
            await tap(
              tester,
              find.widgetWithText(FilledButton, 'Upload a photo'),
            );
            await capture(tester, '$status-source');
            await tap(tester, find.text('Choose from library'));
            expect(transport.mutationPaths, isEmpty);
          } else if (status == 'review') {
            await tap(
              tester,
              find.byKey(const ValueKey('onboarding-avatar-candidate-1')),
            );
            expect(controller.selectedAvatarCandidateId, 'candidate-1');
            await tap(
              tester,
              find.byKey(const ValueKey('onboarding-avatar-default')),
            );
            expect(controller.defaultAvatarSelected, isTrue);
            expect(transport.mutationPaths, isEmpty);
          }
          for (var i = 0; i < 6; i++) {
            await tester.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, -350),
            );
            await tester.pump(const Duration(milliseconds: 200));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}

MomCozyRuntimeController _runtime(FixtureApiJsonTransportByPath transport) =>
    MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport({}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'mia',
          babyId: '',
          locale: 'en-US',
          accessToken: 'test-access',
        ),
      ),
    );
Map<String, Object?> _state(String status) => {
  'status': 'avatar_$status',
  'current_step': 'avatar',
  'profile_confirmed': true,
  'can_enter_app': true,
  'can_continue_with_default': true,
  if (status != 'required')
    'avatar': {
      'id': 'generation',
      'stage': 'postpartum',
      'status': switch (status) {
        'review' => 'succeeded',
        'failed' => 'failed',
        _ => 'queued',
      },
      'created_at': '2026-09-10T00:00:00Z',
      'error_code': '',
      'candidates': [
        if (status == 'review')
          for (var i = 1; i <= 4; i++)
            {'id': 'candidate-$i', 'file_id': 'file-$i', 'position': i},
      ],
    },
};
