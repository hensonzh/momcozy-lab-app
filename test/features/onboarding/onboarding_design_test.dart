import 'dart:async';
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
        OnboardingController controller, {
        bool load = true,
        OnboardingPortraitPicker? picker,
        OnboardingAvatarImageLoader? thumbnailLoader,
      }) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (load) await controller.load();
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
              now: () => DateTime(2026, 9, 24),
              pickPortrait: picker ?? (_) async => null,
              avatarThumbnailLoader: thumbnailLoader ?? (_) async => portrait,
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
        {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/onboarding-$name-${width.toInt()}${scale == 1 ? '' : '-2x'}.png',
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
        await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
        expect(
          find.text('Enter the name you\'d like us to use.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('onboarding-display-name')),
          List.filled(20, 'Long name').join(' '),
        );
        for (final age in ['11', '71']) {
          await tester.enterText(
            find.byKey(const ValueKey('onboarding-age')),
            age,
          );
          await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
          expect(find.text('Enter an age between 12 and 70.'), findsOneWidget);
        }

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
        await tap(
          tester,
          find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
        );
        expect(find.text('Choose your delivery date.'), findsOneWidget);
        await tap(tester, find.text('Choose date'));
        await tap(tester, find.text('Cancel'));
        expect(find.text('Choose date'), findsOneWidget);
        await tap(tester, find.text('Choose date'));
        await tap(tester, find.text('OK'));
        await tap(tester, find.byTooltip('Back'));
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('onboarding-display-name')),
              )
              .controller!
              .text,
          'Mia',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('onboarding-age')))
              .controller!
              .text,
          '32',
        );
        await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
        expect(find.text('Choose date'), findsNothing);
        await tap(
          tester,
          find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
        );
        await capture(tester, 'birth');
        await tap(tester, find.text('Prefer not to say yet'));
        await tap(tester, find.text('Cesarean birth').last);
        transport.writeResponsesByPath['/v1/onboarding/me/profile'] = {
          'http_status': 503,
          'body': {
            'error': {
              'code': 'unavailable',
              'message': 'Profile could not be saved. Try again.',
            },
          },
        };
        await tap(
          tester,
          find.byKey(const ValueKey('onboarding-postpartum-save')),
        );
        expect(
          find.text('Profile could not be saved. Try again.'),
          findsOneWidget,
        );
        await capture(tester, 'birth-error');
        expect(find.text('How was your delivery?'), findsOneWidget);
        transport.writeResponsesByPath['/v1/onboarding/me/profile'] = _state(
          'required',
        );
        await tap(
          tester,
          find.byKey(const ValueKey('onboarding-postpartum-save')),
        );
        expect(transport.mutationPaths, [
          '/v1/onboarding/me/profile',
          '/v1/onboarding/me/profile',
        ]);
        expect(transport.lastBody?['delivery_type'], 'cesarean');
        expect(find.text('Create your digital companion'), findsOneWidget);
      });
      if (width == 320 && scale == 2) {
        testWidgets(
          'profile short viewport keeps save pending and recovers draft',
          (tester) async {
            final transport = _PendingProfileTransport();
            final runtime = _runtime(transport);
            final controller = OnboardingController(runtimeController: runtime);
            addTearDown(runtime.dispose);
            addTearDown(controller.dispose);
            await mount(tester, controller);
            tester.view.physicalSize = const Size(320, 568);
            tester.view.viewInsets = const FakeViewPadding(bottom: 200);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();
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
            await tap(tester, find.text('Choose date'));
            await capture(tester, 'short-date-input');
            await tap(tester, find.text('OK'));
            await tap(
              tester,
              find.byKey(
                const ValueKey('onboarding-postpartum-delivery-continue'),
              ),
            );
            await tap(tester, find.text('Prefer not to say yet'));
            await tap(tester, find.text('Cesarean birth').last);
            await tap(tester, find.text('1'));
            await tap(tester, find.text('6').last);
            final save = find.byKey(
              const ValueKey('onboarding-postpartum-save'),
            );
            await tester.ensureVisible(save);
            await tester.pumpAndSettle();
            await tester.tap(save);
            await tester.pump();
            expect(transport.calls, 1);
            expect(controller.busy, isTrue);
            expect(
              tester
                  .widget<FilledButton>(
                    find.descendant(
                      of: save,
                      matching: find.byType(FilledButton),
                    ),
                  )
                  .onPressed,
              isNull,
            );
            expect(find.byTooltip('Back'), findsNothing);
            await tester.ensureVisible(save);
            await tester.pump(const Duration(milliseconds: 300));
            await capture(tester, 'short-busy');
            transport.ready.complete();
            await tester.pumpAndSettle();
            expect(controller.busy, isFalse);
            expect(
              find.text('Profile could not be saved. Try again.'),
              findsOneWidget,
            );
            await tester.ensureVisible(save);
            await tester.pumpAndSettle();
            await capture(tester, 'short-error');
            expect(transport.lastBody?['delivery_type'], 'cesarean');
            expect(transport.lastBody?['infant_count'], 6);
            final failedBody = Map<String, Object?>.from(transport.lastBody!);
            transport.writeResponsesByPath['/v1/onboarding/me/profile'] =
                _state('required');
            await tap(tester, save);
            expect(transport.calls, 2);
            expect(transport.lastBody, failedBody);
            expect(find.text('Create your digital companion'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
      if (width == 320 && scale == 2) {
        testWidgets(
          'avatar short screen retries thumbnail and locks confirmation',
          (tester) async {
            final transport = _PendingAvatarTransport();
            final runtime = _runtime(transport);
            final controller = OnboardingController(runtimeController: runtime);
            addTearDown(runtime.dispose);
            addTearDown(controller.dispose);
            var imageAttempts = 0;
            await mount(
              tester,
              controller,
              thumbnailLoader: (id) async {
                if (id == 'file-1' && imageAttempts++ == 0) {
                  throw StateError('thumbnail');
                }
                return portrait;
              },
            );
            tester.view.physicalSize = const Size(320, 568);
            await tester.pumpAndSettle();
            final candidate = find.byKey(
              const ValueKey('onboarding-avatar-candidate-1'),
            );
            final retry = find.byKey(
              const ValueKey('onboarding-avatar-image-retry-file-1'),
            );
            await tester.ensureVisible(candidate);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<InkWell>(
                    find
                        .descendant(
                          of: candidate,
                          matching: find.byType(InkWell),
                        )
                        .first,
                  )
                  .onTap,
              isNull,
            );
            expect(controller.hasAvatarSelection, isFalse);
            await capture(tester, 'avatar-short-image-error');
            await tap(tester, retry);
            expect(imageAttempts, 2);
            await tap(tester, candidate);
            expect(controller.selectedAvatarCandidateId, 'candidate-1');
            final confirm = find.widgetWithText(
              FilledButton,
              'Continue with this avatar',
            );
            await tester.ensureVisible(confirm);
            await tester.pumpAndSettle();
            await tester.tap(confirm);
            await tester.pump();
            expect(transport.calls, 1);
            expect(controller.busy, isTrue);
            expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
            expect(
              tester
                  .widget<OutlinedButton>(
                    find.widgetWithText(OutlinedButton, 'Try another photo'),
                  )
                  .onPressed,
              isNull,
            );
            expect(
              tester
                  .widget<InkWell>(
                    find
                        .descendant(
                          of: candidate,
                          matching: find.byType(InkWell),
                        )
                        .first,
                  )
                  .onTap,
              isNull,
            );
            await tester.ensureVisible(confirm);
            await tester.pump(const Duration(milliseconds: 300));
            await capture(tester, 'avatar-short-confirm-busy');
            transport.ready.complete();
            await tester.pumpAndSettle();
            expect(
              find.text('Could not save your choice. Please try again.'),
              findsOneWidget,
            );
            expect(controller.selectedAvatarCandidateId, 'candidate-1');
            await tester.ensureVisible(confirm);
            await tester.pumpAndSettle();
            await capture(tester, 'avatar-short-confirm-error');
            expect(transport.lastBody?['avatar_candidate_id'], 'candidate-1');
            expect(transport.lastBody?['use_default_avatar'], isFalse);
            transport.writeResponsesByPath['/v1/onboarding/me/complete'] = {
              'status': 'completed',
              'profile_confirmed': true,
              'can_enter_app': true,
              'avatar_setup_completed': true,
            };
            await tap(tester, confirm);
            expect(transport.calls, 2);
            expect(
              find.text('Your digital companion is ready'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets('onboarding load failure retries at $width / $scale', (
        tester,
      ) async {
        final responses = <String, Map<String, Object?>>{
          '/v1/onboarding/me': {
            'http_status': 503,
            'body': {
              'error': {'code': 'unavailable', 'message': 'Try again shortly.'},
            },
          },
        };
        final transport = _DeferredOnboardingTransport(responses);
        final runtime = _runtime(transport);
        final controller = OnboardingController(runtimeController: runtime);
        addTearDown(runtime.dispose);
        addTearDown(controller.dispose);
        await mount(tester, controller, load: false);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await capture(tester, 'loading');
        transport.ready.complete();
        await tester.pumpAndSettle();
        expect(find.text('We couldn\'t load your setup'), findsOneWidget);
        await capture(tester, 'load-error');
        responses['/v1/onboarding/me'] = {
          'status': 'required',
          'profile_confirmed': false,
        };
        await tap(tester, find.text('Try again'));
        expect(find.text('A few basics first'), findsOneWidget);
        expect(transport.mutationPaths, isEmpty);
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
      if (width == 320 && scale == 2) {
        testWidgets('untranslated photo picker error stays out of the UI', (
          tester,
        ) async {
          final transport = FixtureApiJsonTransportByPath({
            '/v1/onboarding/me': _state('required'),
          });
          final runtime = _runtime(transport);
          final controller = OnboardingController(runtimeController: runtime);
          addTearDown(runtime.dispose);
          addTearDown(controller.dispose);
          await mount(
            tester,
            controller,
            picker: (_) async =>
                throw const FormatException('Cozymate 无法读取这张照片。'),
          );
          await tap(
            tester,
            find.widgetWithText(FilledButton, 'Upload a photo'),
          );
          await tap(tester, find.text('Take a photo'));
          expect(
            find.text('We couldn\'t open that photo. Please try another one.'),
            findsOneWidget,
          );
          expect(find.textContaining('Cozymate'), findsNothing);
          expect(find.textContaining('无法读取'), findsNothing);
        });
      }
      testWidgets(
        'avatar photo failure and default confirmation at $width / $scale',
        (tester) async {
          final writes = <String, Map<String, Object?>>{
            '/v1/onboarding/me/complete': {
              'http_status': 503,
              'body': {
                'error': {
                  'code': 'unavailable',
                  'message': 'Could not apply your choice. Try again.',
                },
              },
            },
          };
          final transport = FixtureApiJsonTransportByPath({
            '/v1/onboarding/me': _state('required'),
          }, writeResponsesByPath: writes);
          final runtime = _runtime(transport);
          final controller = OnboardingController(runtimeController: runtime);
          addTearDown(runtime.dispose);
          addTearDown(controller.dispose);
          await mount(
            tester,
            controller,
            picker: (_) async =>
                throw PlatformException(code: 'photo_access_denied'),
          );
          await tap(
            tester,
            find.widgetWithText(FilledButton, 'Upload a photo'),
          );
          await tap(tester, find.text('Take a photo'));
          expect(
            find.text('We couldn\'t open that photo. Please try another one.'),
            findsOneWidget,
          );
          await capture(tester, 'photo-error');
          await tap(tester, find.text('Use the MomCozy character for now'));
          await capture(tester, 'default-confirm');
          await tap(tester, find.text('Go back'));
          expect(transport.mutationPaths, isEmpty);
          await tap(tester, find.text('Use the MomCozy character for now'));
          await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
          expect(
            find.text('Could not apply your choice. Try again.'),
            findsOneWidget,
          );
          writes['/v1/onboarding/me/complete'] = {
            'status': 'completed',
            'profile_confirmed': true,
            'can_enter_app': true,
            'avatar_setup_completed': true,
          };
          await tap(tester, find.text('Use the MomCozy character for now'));
          await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
          expect(
            find.byKey(const ValueKey('avatar-activation-success')),
            findsOneWidget,
          );
          expect(transport.lastBody?['use_default_avatar'], isTrue);
        },
      );
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
            await capture(tester, 'review-selected');
            await tap(
              tester,
              find.byKey(const ValueKey('onboarding-avatar-default')),
            );
            expect(controller.defaultAvatarSelected, isTrue);
            await tester.ensureVisible(find.text('Continue with this avatar'));
            await tester.pumpAndSettle();
            await capture(tester, 'review-footer');
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

class _DeferredOnboardingTransport extends FixtureApiJsonTransportByPath {
  _DeferredOnboardingTransport(super.responsesByPath);
  final ready = Completer<void>();
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    await ready.future;
    return super.getJson(path, query: query);
  }
}

class _PendingProfileTransport extends FixtureApiJsonTransportByPath {
  _PendingProfileTransport()
    : super(
        {
          '/v1/onboarding/me': {
            'status': 'required',
            'profile_confirmed': false,
          },
        },
        writeResponsesByPath: {
          '/v1/onboarding/me/profile': {
            'http_status': 503,
            'body': {
              'error': {
                'code': 'unavailable',
                'message': 'Profile could not be saved. Try again.',
              },
            },
          },
        },
      );
  final ready = Completer<void>();
  int calls = 0;
  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls++;
    await ready.future;
    return super.putJson(path, body: body, headers: headers);
  }
}

class _PendingAvatarTransport extends FixtureApiJsonTransportByPath {
  _PendingAvatarTransport()
    : super(
        {'/v1/onboarding/me': _state('review')},
        writeResponsesByPath: {
          '/v1/onboarding/me/complete': {
            'http_status': 503,
            'body': {
              'error': {
                'code': 'unavailable',
                'message': 'Could not save your choice. Please try again.',
              },
            },
          },
        },
      );
  final ready = Completer<void>();
  int calls = 0;
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    calls++;
    await ready.future;
    return super.postJson(path, body: body, headers: headers);
  }
}
