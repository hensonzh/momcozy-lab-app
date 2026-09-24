import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/google_sign_in_gateway.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'invite_auth_page.dart';
import 'auth_login_chrome.dart';

enum _AuthStep { login, register, verify, forgot, reset }

class MomCozyAuthPage extends StatefulWidget {
  const MomCozyAuthPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
    this.lastInviteCodeStore = const FlutterSecureMomCozyLastInviteCodeStore(),
    this.googleSignIn = const NativeGoogleSignInGateway(),
    this.internalInviteOnly = const bool.fromEnvironment(
      'MOMCOZY_INTERNAL_INVITE_LOGIN',
    ),
  });
  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;
  final MomCozyLastInviteCodeStore lastInviteCodeStore;
  final GoogleSignInGateway googleSignIn;
  final bool internalInviteOnly;
  @override
  State<MomCozyAuthPage> createState() => _MomCozyAuthPageState();
}

class _MomCozyAuthPageState extends State<MomCozyAuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _scroll = ScrollController();
  _AuthStep _step = _AuthStep.login;
  bool _busy = false;
  bool _showPassword = false;
  bool _rememberMe = false;
  bool _googleFeedback = false;
  String? _message;
  String? _error;
  DateTime? _resendAt;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _navigate(_AuthStep step, {String? message}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
      _message = message;
      _code.clear();
      _showPassword = false;
      _googleFeedback = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  String get _title => switch (_step) {
    _AuthStep.login => 'Welcome back',
    _AuthStep.register => 'Create your account',
    _AuthStep.verify => 'Verify your email',
    _AuthStep.forgot => 'Forgot password?',
    _AuthStep.reset => 'Reset your password',
  };
  String get _submitLabel => switch (_step) {
    _AuthStep.login => 'Sign in',
    _AuthStep.register => 'Create account',
    _AuthStep.verify => 'Verify and continue',
    _AuthStep.forgot => 'Send reset code',
    _AuthStep.reset => 'Reset password',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.internalInviteOnly) {
      return MomCozyInviteAuthPage(
        runtimeController: widget.runtimeController,
        sessionStore: widget.sessionStore,
        authDeviceIdStore: widget.authDeviceIdStore,
        lastInviteCodeStore: widget.lastInviteCodeStore,
      );
    }
    final usesCode = _step == _AuthStep.verify || _step == _AuthStep.reset;
    final isLogin = _step == _AuthStep.login;
    final theme = authLoginTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: isLogin ? Colors.white : null,
        body: MomCozyPageBody(
          maxWidth: MomCozyLayout.maxAppWidth,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: isLogin
                  ? const EdgeInsets.fromLTRB(24, 20, 24, 32)
                  : const EdgeInsets.fromLTRB(16, 16, 16, 28),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isLogin) ...[
                        const AuthLoginBrandPanel(),
                        const SizedBox(height: 20),
                      ],
                      AuthLoginHeader(
                        title: _title,
                        compact: !isLogin,
                        subtitle: switch (_step) {
                          _AuthStep.login =>
                            'Care and support, every step of the way.',
                          _AuthStep.register =>
                            'A little support, made for you.',
                          _AuthStep.verify =>
                            'Enter the code we sent to your email.',
                          _AuthStep.forgot =>
                            'We’ll send a code to help you reset your password.',
                          _AuthStep.reset =>
                            'Choose a new password for your account.',
                        },
                      ),
                      MomSettingsCard(
                        color: isLogin
                            ? Colors.transparent
                            : MomHomeTokens.surface,
                        border: !isLogin,
                        padding: isLogin
                            ? EdgeInsets.zero
                            : const EdgeInsets.all(MomHomeTokens.inset),
                        spacing: isLogin ? 0 : MomHomeTokens.gap,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_step == _AuthStep.login &&
                                  widget
                                          .runtimeController
                                          .currentSession
                                          .status ==
                                      MomCozySessionStatus.expired)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 14),
                                  child: AuthNotice(
                                    'Your session expired. Please sign in again.',
                                  ),
                                ),
                              if (_message != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: AuthNotice(
                                    _message!,
                                    textKey: const ValueKey(
                                      'auth-success-text',
                                    ),
                                  ),
                                ),
                              if (_error != null && !_googleFeedback)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: AuthNotice(
                                    _error!,
                                    error: true,
                                    textKey: const ValueKey('auth-error-text'),
                                  ),
                                ),
                              if (_step == _AuthStep.login) ...[
                                OutlinedButton.icon(
                                  key: const ValueKey('auth-google-button'),
                                  onPressed: _busy ? null : _google,
                                  // Official asset: https://developers.google.com/identity/branding-guidelines
                                  icon: Image.asset(
                                    'assets/images/google_sign_in.png',
                                    width: 24,
                                    height: 24,
                                    excludeFromSemantics: true,
                                  ),
                                  label: const Text('Continue with Google'),
                                  style: OutlinedButton.styleFrom(
                                    alignment: Alignment.center,
                                    foregroundColor: authReferenceInk,
                                    backgroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(56),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                    textStyle: authReferenceText(
                                      16,
                                      weight: FontWeight.w600,
                                      height: 24 / 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(
                                      color: authReferenceBorder,
                                    ),
                                  ),
                                ),
                                if (_error != null && _googleFeedback)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: MomCozySpacing.compact,
                                    ),
                                    child: AuthNotice(
                                      _error!,
                                      error: true,
                                      textKey: const ValueKey(
                                        'auth-error-text',
                                      ),
                                    ),
                                  ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 44),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: authReferenceBorder,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            fontFamily: 'NotoSansSCHome',
                                            fontFamilyFallback:
                                                MomCozyTypography
                                                    .fontFamilyFallback,
                                            fontSize: 14,
                                            height: 20 / 14,
                                            color: authReferenceMuted,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: authReferenceBorder,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              _AuthField(
                                label: isLogin ? 'Email' : 'Email address',
                                showLabel: !isLogin,
                                child: TextFormField(
                                  key: const ValueKey('auth-email-field'),
                                  controller: _email,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  style: isLogin
                                      ? authReferenceText(16, height: 24 / 16)
                                      : null,
                                  textAlignVertical: isLogin
                                      ? TextAlignVertical.center
                                      : TextAlignVertical.top,
                                  decoration: isLogin
                                      ? authReferenceInputDecoration(
                                          context,
                                          hintText: 'Email',
                                        )
                                      : const InputDecoration(
                                          hintText: 'you@example.com',
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: MomCozySpacing.page,
                                            vertical: MomCozySpacing.content,
                                          ),
                                        ),
                                  validator: (v) =>
                                      v != null &&
                                          RegExp(
                                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                          ).hasMatch(v.trim())
                                      ? null
                                      : 'Enter a valid email address.',
                                ),
                              ),
                              if (usesCode) ...[
                                const SizedBox(height: MomCozySpacing.section),
                                _AuthField(
                                  label: '8-digit email code',
                                  child: TextFormField(
                                    key: const ValueKey('auth-code-field'),
                                    controller: _code,
                                    enabled: !_busy,
                                    keyboardType: TextInputType.number,
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode,
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Enter your code',
                                    ),
                                    validator: (v) =>
                                        RegExp(
                                          r'^\d{8}$',
                                        ).hasMatch(v?.trim() ?? '')
                                        ? null
                                        : 'Enter the 8-digit code from your email.',
                                  ),
                                ),
                              ],
                              if (_step != _AuthStep.forgot) ...[
                                SizedBox(
                                  height: _step == _AuthStep.login
                                      ? 24
                                      : MomCozySpacing.section,
                                ),
                                _AuthField(
                                  showLabel: !isLogin,
                                  label: _step == _AuthStep.login
                                      ? 'Password'
                                      : 'Set password',
                                  action: null,
                                  child: TextFormField(
                                    key: const ValueKey('auth-password-field'),
                                    controller: _password,
                                    enabled: !_busy,
                                    obscureText: !_showPassword,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.done,
                                    style: isLogin
                                        ? authReferenceText(16, height: 24 / 16)
                                        : null,
                                    textAlignVertical: isLogin
                                        ? TextAlignVertical.center
                                        : TextAlignVertical.top,
                                    onChanged: isLogin
                                        ? (_) => setState(() {})
                                        : null,
                                    onFieldSubmitted: _busy
                                        ? null
                                        : (_) => _submit(),
                                    autofillHints: [
                                      _step == _AuthStep.login
                                          ? AutofillHints.password
                                          : AutofillHints.newPassword,
                                    ],
                                    decoration: isLogin
                                        ? authReferenceInputDecoration(
                                            context,
                                            hintText: 'Password',
                                            suffixIcon: IconButton(
                                              key: const ValueKey(
                                                'auth-password-visibility',
                                              ),
                                              tooltip: _showPassword
                                                  ? 'Hide password'
                                                  : 'Show password',
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(() {
                                                      _showPassword =
                                                          !_showPassword;
                                                    }),
                                              icon: Icon(
                                                _showPassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                                size: 22,
                                              ),
                                            ),
                                          )
                                        : InputDecoration(
                                            hintText: 'Enter your password',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal:
                                                      MomCozySpacing.page,
                                                  vertical:
                                                      MomCozySpacing.content,
                                                ),
                                            suffixIcon: IconButton(
                                              key: const ValueKey(
                                                'auth-password-visibility',
                                              ),
                                              tooltip: _showPassword
                                                  ? 'Hide password'
                                                  : 'Show password',
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(() {
                                                      _showPassword =
                                                          !_showPassword;
                                                    }),
                                              icon: Icon(
                                                _showPassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: MomCozyIconSizes.medium,
                                              ),
                                            ),
                                            helperMaxLines: 8,
                                            errorMaxLines: 8,
                                            helperText:
                                                '8–128 characters, including a letter and a number',
                                          ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Enter your password.';
                                      }
                                      if (_step != _AuthStep.login &&
                                          (v.length < 8 ||
                                              v.length > 128 ||
                                              !RegExp('[A-Za-z]').hasMatch(v) ||
                                              !RegExp('[0-9]').hasMatch(v))) {
                                        return 'Use 8–128 characters with a letter and a number.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                              if (isLogin) ...[
                                const SizedBox(height: 18),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 4,
                                  children: [
                                    SizedBox(
                                      width: 150,
                                      child: CheckboxListTile(
                                        key: const ValueKey('auth-remember-me'),
                                        value: _rememberMe,
                                        onChanged: _busy
                                            ? null
                                            : (value) => setState(() {
                                                _rememberMe = value ?? false;
                                              }),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        checkboxShape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        side: const BorderSide(
                                          color: authReferenceBorder,
                                        ),
                                        activeColor: authReferenceInk,
                                        title: Text(
                                          'Remember me',
                                          maxLines: 1,
                                          style: authReferenceText(
                                            14,
                                            height: 20 / 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      key: const ValueKey('auth-forgot-button'),
                                      onPressed: _busy
                                          ? null
                                          : () => _navigate(_AuthStep.forgot),
                                      style: TextButton.styleFrom(
                                        foregroundColor: authReferenceInk,
                                        minimumSize: const Size(44, 44),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        textStyle: authReferenceText(
                                          14,
                                          height: 20 / 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      child: const Text(
                                        'Forgot your password?',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              SizedBox(
                                height: isLogin ? 72 : MomCozySpacing.page,
                              ),
                              FilledButton(
                                key: const ValueKey('auth-submit-button'),
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: Size.fromHeight(
                                    isLogin ? 56 : 48,
                                  ),
                                  tapTargetSize: isLogin
                                      ? MaterialTapTargetSize.shrinkWrap
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: MomCozySpacing.card,
                                  ),
                                  backgroundColor: isLogin
                                      ? authReferenceInk
                                      : authRose,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      isLogin ? 12 : 16,
                                    ),
                                  ),
                                  foregroundColor: MomCozyColors.raised,
                                  textStyle: isLogin
                                      ? authReferenceText(
                                          16,
                                          color: Colors.white,
                                          weight: FontWeight.w600,
                                          height: 24 / 16,
                                        )
                                      : MomHomeTokens.text(
                                          13,
                                          weight: FontWeight.w700,
                                          height: 18 / 13,
                                        ),
                                ),
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: MomCozyIconSizes.medium,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_submitLabel),
                              ),
                              if (_step == _AuthStep.login) ...[
                                const SizedBox(height: 36),
                                Wrap(
                                  spacing: 12,
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account?",
                                      style: authReferenceText(
                                        14,
                                        height: 20 / 14,
                                      ),
                                    ),
                                    TextButton(
                                      key: const ValueKey(
                                        'auth-register-button',
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => _navigate(_AuthStep.register),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(44, 44),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.zero,
                                        foregroundColor: authReferenceInk,
                                        textStyle: authReferenceText(
                                          14,
                                          weight: FontWeight.w600,
                                          height: 20 / 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      child: const Text('Sign up now'),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                if (usesCode)
                                  TextButton(
                                    onPressed: _busy ? null : _resend,
                                    style: TextButton.styleFrom(
                                      foregroundColor: authRose,
                                    ),
                                    child: const Text('Resend code'),
                                  ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _navigate(_AuthStep.login),
                                  style: TextButton.styleFrom(
                                    foregroundColor: authRose,
                                  ),
                                  child: const Text('Back to sign in'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (isLogin) ...[
                        const SizedBox(height: 224),
                        const AuthLegalFooter(compact: true),
                        const SizedBox(height: 8),
                        const AuthLanguageButton(),
                      ] else if (_step == _AuthStep.register)
                        const AuthLegalFooter(compact: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool googleFeedback = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _googleFeedback = googleFeedback;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = accountAuthErrorText(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      final api = widget.runtimeController.runtime.authRepository;
      final email = _email.text.trim(), password = _password.text;
      switch (_step) {
        case _AuthStep.register:
          await api.register(email: email, password: password);
          _resendAt = DateTime.now().add(const Duration(seconds: 60));
          if (mounted) {
            _navigate(
              _AuthStep.verify,
              message:
                  'If verification is needed, a code is on its way. Check your inbox and spam folder. Codes expire in 15 minutes.',
            );
          }
        case _AuthStep.login:
          try {
            final tokens = await api.login(
              email: email,
              password: password,
              deviceId: await widget.authDeviceIdStore.readOrCreateDeviceId(),
            );
            await _accept(tokens);
            TextInput.finishAutofillContext(shouldSave: _rememberMe);
          } on ApiHttpException catch (error) {
            if (error.errorCode != 'email_unverified') rethrow;
            await api.resendVerification(email);
            if (mounted) {
              _navigate(
                _AuthStep.verify,
                message:
                    'Verify your email to continue. Check your inbox for a code.',
              );
            }
          }
        case _AuthStep.verify:
          await _accept(
            await api.verifyEmail(
              email: email,
              code: _code.text,
              password: password,
              deviceId: await widget.authDeviceIdStore.readOrCreateDeviceId(),
            ),
          );
        case _AuthStep.forgot:
          await api.forgotPassword(email);
          _password.clear();
          _resendAt = DateTime.now().add(const Duration(seconds: 60));
          if (mounted) {
            _navigate(
              _AuthStep.reset,
              message:
                  'If this email has an eligible account, a reset code is on its way. Codes expire in 15 minutes.',
            );
          }
        case _AuthStep.reset:
          await api.resetPassword(
            email: email,
            code: _code.text,
            password: password,
          );
          _password.clear();
          if (mounted) {
            _navigate(
              _AuthStep.login,
              message: 'Password reset. Sign in with your new password.',
            );
          }
      }
    });
  }

  Future<void> _resend() => _run(() async {
    if (_resendAt?.isAfter(DateTime.now()) ?? false) {
      setState(() {
        _message = 'Please wait 60 seconds before requesting another code.';
      });
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your email first.';
      });
      return;
    }
    final api = widget.runtimeController.runtime.authRepository;
    if (_step == _AuthStep.verify) {
      await api.resendVerification(_email.text);
    } else {
      await api.forgotPassword(_email.text);
    }
    _resendAt = DateTime.now().add(const Duration(seconds: 60));
    if (mounted) {
      setState(() {
        _message = 'If your account is eligible, a new code is on its way.';
      });
    }
  });

  Future<void> _google() => _run(() async {
    final token = await widget.googleSignIn.signIn();
    if (token == null) {
      if (mounted) {
        setState(() {
          _message = 'Google sign-in was canceled.';
        });
      }
      return;
    }
    await _accept(
      await widget.runtimeController.runtime.authRepository.googleLogin(
        idToken: token,
        deviceId: await widget.authDeviceIdStore.readOrCreateDeviceId(),
      ),
    );
  }, googleFeedback: true);

  Future<void> _accept(MomCozyAuthTokenResponse tokens) async {
    if (!mounted) return;
    final api = widget.runtimeController.runtime.authRepository;
    try {
      await widget.runtimeController.saveAuthenticatedSession(
        tokens.toSession(babyId: 'demo-baby', locale: 'en-US'),
        sessionStore: widget.sessionStore,
      );
      _password.clear();
    } catch (_) {
      try {
        await api.logoutSession(tokens.refreshToken);
      } catch (_) {
        /* Keep the original storage error. */
      }
      rethrow;
    }
    // Route guards listen to the controller and restore the intended route.
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.child,
    this.action,
    this.showLabel = true,
  });

  final String label;
  final Widget child;
  final Widget? action;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showLabel) ...[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: MomCozySpacing.compact,
          children: [
            ExcludeSemantics(
              child: Text(
                label,
                style: MomHomeTokens.text(12, weight: FontWeight.w700),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: MomCozySpacing.compact),
      ],
      Semantics(label: label, child: child),
    ],
  );
}

String accountAuthErrorText(Object error) {
  if (error is GoogleSignInUnavailable) {
    return 'Google sign-in is unavailable. Try again or use email.';
  }
  if (error is ApiHttpException) {
    return switch (error.errorCode) {
      'account_link_required' =>
        'This email already has an account. Sign in with your password, then link Google in Account settings.',
      'account_link_conflict' =>
        'Choose the Google account with the same email address. Each Google account can only be linked once.',
      'oauth_unavailable' =>
        'Google sign-in is temporarily unavailable. Please use email or try later.',
      'auth_email_unavailable' =>
        'Email verification is temporarily unavailable. Please try again later.',
      'invalid_or_expired_code' =>
        'This code is invalid or expired. Request a new code and try again.',
      'oauth_token_invalid' =>
        'Google sign-in could not be verified. Please try again.',
      'permission_denied' || 'account_inactive' =>
        'This account is unavailable. Contact support for help.',
      'authentication_required' => 'Email or password is incorrect.',
      'validation_failed' =>
        'Check your email, code, and password and try again.',
      _ =>
        error.statusCode == 429
            ? 'Too many attempts. Please wait and try again.'
            : 'Unable to continue. Please try again shortly.',
    };
  }
  return 'Unable to connect or save your session. Check your connection and try again.';
}
