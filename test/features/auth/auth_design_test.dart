import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      Future<void> mount(WidgetTester tester, Widget page) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
            home: page,
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp));
          await Future.wait([
            precacheImage(
              const AssetImage('assets/images/auth_mother_baby.png'),
              context,
            ),
            precacheImage(
              const AssetImage('assets/images/momcozy_logo.png'),
              context,
            ),
            precacheImage(
              const AssetImage('assets/images/google_sign_in.png'),
              context,
            ),
          ]);
        });
        await tester.pumpAndSettle();
      }

      Future<void> tap(WidgetTester tester, Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(WidgetTester tester, String name) async {
        expect(tester.takeException(), isNull);
        if (scale == 1 || name.startsWith('auth-')) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/$name-${width.toInt()}${scale == 1 ? '' : '-2x'}.png',
            ),
          );
        }
      }

      testWidgets('email entry and registration at $width / $scale', (
        tester,
      ) async {
        final transport = FixtureApiJsonTransport({
          'status': 'verification_required',
        });
        final runtime = MomCozyRuntimeController(
          MomCozyApiRuntime(jsonTransport: transport),
        );
        addTearDown(runtime.dispose);
        await mount(
          tester,
          MomCozyAuthPage(
            runtimeController: runtime,
            sessionStore: MemoryMomCozySessionStore(),
            authDeviceIdStore: _DeviceId(),
            internalInviteOnly: false,
          ),
        );
        await capture(tester, 'auth-login');
        await tap(tester, find.byKey(const ValueKey('auth-language-button')));
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, 'English'))
              .selected,
          isTrue,
        );
        await capture(tester, 'auth-language');
        await tap(tester, find.widgetWithText(ListTile, 'English'));
        await tester.ensureVisible(find.text('Privacy Policy.'));
        await tester.pumpAndSettle();
        await capture(tester, 'auth-legal');
        await tap(tester, find.byKey(const ValueKey('auth-register-button')));
        await tester.ensureVisible(find.text('Create your account'));
        await tester.pumpAndSettle();
        await capture(tester, 'auth-register');
        await tester.enterText(
          find.byKey(const ValueKey('auth-email-field')),
          'mia@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-password-field')),
          'weak',
        );
        await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
        expect(transport.postedBodies, isEmpty);
        await capture(tester, 'auth-register-validation');
        await tester.enterText(
          find.byKey(const ValueKey('auth-password-field')),
          'secret123',
        );
        await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
        expect(transport.lastPath, '/v1/auth/register');
        expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
        expect(runtime.currentSession.isAuthenticated, isFalse);
        await tester.ensureVisible(find.text('Verify your email'));
        await tester.pumpAndSettle();
        await capture(tester, 'auth-verify');
      });
      testWidgets('reset form with keyboard at $width / $scale', (
        tester,
      ) async {
        final transport = FixtureApiJsonTransport({
          'status': 'reset_if_available',
        });
        final runtime = MomCozyRuntimeController(
          MomCozyApiRuntime(jsonTransport: transport),
        );
        addTearDown(runtime.dispose);
        await mount(
          tester,
          MomCozyAuthPage(
            runtimeController: runtime,
            sessionStore: MemoryMomCozySessionStore(),
            internalInviteOnly: false,
          ),
        );
        await tap(tester, find.byKey(const ValueKey('auth-forgot-button')));
        await tester.ensureVisible(find.text('Forgot password?'));
        await tester.pumpAndSettle();
        await capture(tester, 'auth-forgot');
        await tester.enterText(
          find.byKey(const ValueKey('auth-email-field')),
          'mia@example.com',
        );
        await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
        await tester.ensureVisible(find.text('Reset your password'));
        await tester.pumpAndSettle();
        await capture(tester, 'auth-reset');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byKey(const ValueKey('auth-code-field')),
          '12345678',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-password-field')),
          'new-secret123',
        );
        await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
        expect(transport.lastPath, '/v1/auth/reset-password');
        expect(transport.lastBody?['new_password'], 'new-secret123');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await capture(tester, 'auth-reset-complete');
      });
      testWidgets(
        'invite entry with short keyboard viewport at $width / $scale',
        (tester) async {
          final transport = FixtureApiJsonTransport({});
          final runtime = MomCozyRuntimeController(
            MomCozyApiRuntime(jsonTransport: transport),
          );
          addTearDown(runtime.dispose);
          await mount(
            tester,
            MomCozyAuthPage(
              runtimeController: runtime,
              sessionStore: MemoryMomCozySessionStore(),
              lastInviteCodeStore: _InviteStore(),
              internalInviteOnly: true,
            ),
          );
          await capture(tester, 'auth-invite');
          tester.view.physicalSize = Size(width, 568);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tap(
            tester,
            find.byKey(const ValueKey('auth-invite-login-button')),
          );
          expect(find.byKey(const ValueKey('auth-error-text')), findsOneWidget);
          expect(transport.postedBodies, isEmpty);
          await capture(tester, 'auth-invite-validation');
        },
      );
      testWidgets('account and confirmations at $width / $scale', (
        tester,
      ) async {
        final transport = FixtureApiJsonTransport({
          'email': 'mia.long-account@example.com',
          'email_verified': true,
          'account_status': 'active',
          'auth_providers': ['email'],
        });
        final runtime = MomCozyRuntimeController(
          MomCozyApiRuntime(jsonTransport: transport),
        );
        addTearDown(runtime.dispose);
        await mount(
          tester,
          MomCozyAccountPage(
            runtimeController: runtime,
            sessionStore: MemoryMomCozySessionStore(),
          ),
        );
        await capture(tester, 'account');
        await tap(tester, find.byKey(const ValueKey('account-link-google')));
        await capture(tester, 'account-link-password');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byKey(const ValueKey('account-link-password')),
          'password123',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'account-link-password-keyboard');
        await tap(tester, find.text('Cancel'));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('account-delete')),
          300,
        );
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.textContaining('Your access will end immediately.'),
              )
              .text
              .style!
              .height,
          1.55,
        );
        await tap(tester, find.byKey(const ValueKey('account-delete')));
        await capture(tester, 'account-delete');
        await tap(tester, find.text('Cancel'));
        expect(transport.mutationPaths, isEmpty);
      });
    }
  }
}

class _DeviceId implements MomCozyAuthDeviceIdStore {
  @override
  Future<String> readOrCreateDeviceId() async => 'test-device';
}

class _InviteStore implements MomCozyLastInviteCodeStore {
  @override
  Future<String?> readLastInviteCode() async => null;
  @override
  Future<void> writeLastInviteCode(String inviteCode) async {}
}
