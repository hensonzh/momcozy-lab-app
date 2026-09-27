import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'invite_auth_page.dart';
import 'auth_login_chrome.dart';

enum _RegistrationRecovery { authenticated, notCommitted, unknown }

enum _AuthStep {
  login,
  register,
  verifyRegistration,
  setPassword,
  forgot,
  reset,
}

class MomCozyAuthPage extends StatefulWidget {
  const MomCozyAuthPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
    this.lastInviteCodeStore = const FlutterSecureMomCozyLastInviteCodeStore(),
    this.internalInviteOnly = const bool.fromEnvironment(
      'MOMCOZY_INTERNAL_INVITE_LOGIN',
    ),
  });
  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;
  final MomCozyLastInviteCodeStore lastInviteCodeStore;
  final bool internalInviteOnly;
  @override
  State<MomCozyAuthPage> createState() => _MomCozyAuthPageState();
}

class _MomCozyAuthPageState extends State<MomCozyAuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _code = TextEditingController();
  final _scroll = ScrollController();
  _AuthStep _step = _AuthStep.login;
  bool _busy = false;
  bool _showPassword = false;
  bool _registrationResultUnknown = false;
  bool _resetResultUnknown = false;
  String? _message;
  String? _error;
  DateTime? _resendAt;
  Timer? _resendTimer;

  int get _resendSeconds {
    final remaining = _resendAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  void _startResendCooldown() {
    _resendAt = DateTime.now().add(const Duration(seconds: 60));
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || timer.tick >= 60 || _resendSeconds == 0) {
        _resendAt = null;
        timer.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _code.dispose();
    _scroll.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _navigate(_AuthStep step, {String? message, bool preserveCode = false}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
      _message = message;
      if (!preserveCode) _code.clear();
      if (step != _AuthStep.setPassword) {
        _password.clear();
        _confirmPassword.clear();
        _registrationResultUnknown = false;
      }
      if (step != _AuthStep.reset) _resetResultUnknown = false;
      _showPassword = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  String get _title => switch (_step) {
    _AuthStep.login => 'Momcozy',
    _AuthStep.register => 'Create your account',
    _AuthStep.verifyRegistration => 'Verify your email',
    _AuthStep.setPassword => 'Set your password',
    _AuthStep.forgot => 'Forgot password?',
    _AuthStep.reset => 'Reset your password',
  };
  String get _submitLabel => switch (_step) {
    _AuthStep.login => 'Sign in',
    _AuthStep.register => 'Send verification code',
    _AuthStep.verifyRegistration => 'Continue',
    _AuthStep.setPassword => 'Create account',
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
    final usesCode =
        _step == _AuthStep.verifyRegistration || _step == _AuthStep.reset;
    final usesPassword =
        _step == _AuthStep.login ||
        _step == _AuthStep.setPassword ||
        _step == _AuthStep.reset;
    final isLogin = _step == _AuthStep.login;
    final sessionExpired =
        isLogin &&
        widget.runtimeController.currentSession.status ==
            MomCozySessionStatus.expired;
    final hasLoginNotice = sessionExpired || _message != null || _error != null;
    final theme = authLoginTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: const Color(0xfff5edf4),
        body: Container(
          decoration: const BoxDecoration(gradient: authLoginBackground),
          child: MomCozyPageBody(
            maxWidth: MomCozyLayout.maxAppWidth,
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                  24,
                  (92.0 - MediaQuery.paddingOf(context).top).clamp(16.0, 92.0),
                  24,
                  32,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AutofillGroup(
                  onDisposeAction: AutofillContextAction.cancel,
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthLoginHeader(
                          title: _title,
                          compact: !isLogin,
                          subtitle: switch (_step) {
                            _AuthStep.login =>
                              'Care and support, every step of the way.',
                            _AuthStep.register =>
                              'Start by verifying your email.',
                            _AuthStep.verifyRegistration =>
                              'Enter the code we sent before setting your password.',
                            _AuthStep.setPassword =>
                              'Choose a password for your verified email.',
                            _AuthStep.forgot =>
                              'We\'ll send a code to help you reset your password.',
                            _AuthStep.reset =>
                              'Choose a new password for your account.',
                          },
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isLogin) ...[
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
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: AuthNotice(
                                    _error!,
                                    error: true,
                                    textKey: const ValueKey('auth-error-text'),
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
                                readOnly: _step == _AuthStep.setPassword,
                                onChanged: _step == _AuthStep.register
                                    ? (_) => setState(() {})
                                    : null,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                style: authReferenceText(16, height: 24 / 16),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: isLogin
                                    ? authReferenceInputDecoration(
                                        context,
                                        hintText: 'Email',
                                      )
                                    : authReferenceInputDecoration(
                                        context,
                                        hintText: 'you@example.com',
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
                                label: 'verification code',
                                child: TextFormField(
                                  key: const ValueKey('auth-code-field'),
                                  controller: _code,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  autofillHints: const [
                                    AutofillHints.oneTimeCode,
                                  ],
                                  decoration: authReferenceInputDecoration(
                                    context,
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
                            if (usesPassword) ...[
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
                                  textInputAction:
                                      _step == _AuthStep.setPassword ||
                                          _step == _AuthStep.reset
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  style: authReferenceText(16, height: 24 / 16),
                                  textAlignVertical: TextAlignVertical.center,
                                  onChanged: isLogin
                                      ? (_) => setState(() {})
                                      : null,
                                  onFieldSubmitted:
                                      _busy ||
                                          _step == _AuthStep.setPassword ||
                                          _step == _AuthStep.reset
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
                                      : authReferenceInputDecoration(
                                          context,
                                          hintText: 'Enter your password',
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
                                        ).copyWith(
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
                            if (_step == _AuthStep.setPassword ||
                                _step == _AuthStep.reset) ...[
                              const SizedBox(height: MomCozySpacing.section),
                              _AuthField(
                                label: 'Confirm password',
                                child: TextFormField(
                                  key: const ValueKey(
                                    'auth-confirm-password-field',
                                  ),
                                  controller: _confirmPassword,
                                  enabled: !_busy,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: _busy
                                      ? null
                                      : (_) => _submit(),
                                  decoration: authReferenceInputDecoration(
                                    context,
                                    hintText: 'Enter your password again',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Confirm your password.';
                                    }
                                    return value == _password.text
                                        ? null
                                        : 'Passwords do not match.';
                                  },
                                ),
                              ),
                            ],
                            if (isLogin) ...[
                              const SizedBox(height: 18),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    key: const ValueKey('auth-forgot-button'),
                                    onPressed: _busy
                                        ? null
                                        : () => _navigate(_AuthStep.forgot),
                                    style: TextButton.styleFrom(
                                      foregroundColor: authLoginLink,
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
                                    child: const Text('Forgot your password?'),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(
                              height: isLogin ? 34 : MomCozySpacing.page,
                            ),
                            FilledButton(
                              key: const ValueKey('auth-submit-button'),
                              onPressed:
                                  _busy ||
                                      (_step == _AuthStep.register &&
                                          _email.text.trim().isEmpty)
                                  ? null
                                  : _submit,
                              style: authLoginButtonStyle(),
                              child: _busy
                                  ? const SizedBox.square(
                                      dimension: MomCozyIconSizes.medium,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_submitLabel),
                            ),
                            if (isLogin) ...[
                              if (hasLoginNotice) ...[
                                const SizedBox(height: 16),
                                if (sessionExpired)
                                  const AuthNotice(
                                    'Your session expired. Please sign in again.',
                                  ),
                                if (_message != null)
                                  AuthNotice(
                                    _message!,
                                    textKey: const ValueKey(
                                      'auth-success-text',
                                    ),
                                  ),
                                if (_error != null)
                                  AuthNotice(
                                    _error!,
                                    error: true,
                                    textKey: const ValueKey('auth-error-text'),
                                  ),
                              ],
                              SizedBox(height: hasLoginNotice ? 28 : 72),
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
                                    key: const ValueKey('auth-register-button'),
                                    onPressed: _busy
                                        ? null
                                        : () => _navigate(_AuthStep.register),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(44, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                      foregroundColor: authLoginLink,
                                      textStyle: authReferenceText(
                                        14,
                                        color: authLoginLink,
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
                                  onPressed: _busy || _resendSeconds > 0
                                      ? null
                                      : _resend,
                                  style: TextButton.styleFrom(
                                    foregroundColor: authRose,
                                  ),
                                  child: Text(
                                    _resendSeconds > 0
                                        ? 'Request another code in ${_resendSeconds}s'
                                        : 'Request another code',
                                  ),
                                ),
                              if (_step == _AuthStep.setPassword)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _navigate(
                                          _AuthStep.verifyRegistration,
                                        ),
                                  child: const Text('Back to verification'),
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
                        if (isLogin) ...[
                          const SizedBox(height: 24),
                          const AuthLegalFooter(compact: true),
                          const SizedBox(height: 8),
                          const AuthLanguageButton(),
                        ] else if (_step == _AuthStep.register)
                          const AuthLegalFooter(
                            compact: true,
                            registration: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      if (_step == _AuthStep.verifyRegistration || _step == _AuthStep.reset) {
        _message = null;
      }
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = null;
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
    if ((_step == _AuthStep.verifyRegistration || _step == _AuthStep.reset) &&
        _message != null) {
      setState(() => _message = null);
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      final api = widget.runtimeController.runtime.authRepository;
      final email = _email.text.trim(), password = _password.text;
      switch (_step) {
        case _AuthStep.register:
          await api.register(email: email);
          _startResendCooldown();
          if (mounted) {
            _navigate(
              _AuthStep.verifyRegistration,
              message:
                  'Check your inbox and spam folder for an 8-digit code. Codes expire in 15 minutes.',
            );
          }
        case _AuthStep.verifyRegistration:
          await api.checkRegistrationCode(email: email, code: _code.text);
          if (mounted) _navigate(_AuthStep.setPassword, preserveCode: true);
        case _AuthStep.setPassword:
          final deviceId = await widget.authDeviceIdStore
              .readOrCreateDeviceId();
          if (_registrationResultUnknown) {
            final recovery = await _recoverRegistration(
              api,
              email,
              password,
              deviceId,
            );
            if (recovery == _RegistrationRecovery.authenticated) return;
            if (recovery == _RegistrationRecovery.unknown) {
              _showUnknownRegistrationMessage();
              return;
            }
          }
          MomCozyAuthTokenResponse? issued;
          try {
            issued = await api.verifyEmail(
              email: email,
              code: _code.text,
              password: password,
              confirmPassword: _confirmPassword.text,
              deviceId: deviceId,
            );
          } on ApiHttpException catch (error) {
            if (error.errorCode != 'invalid_or_expired_code') rethrow;
            if (_registrationResultUnknown) {
              // The timed-out request may still commit after our first login check.
              // Never discard the password draft on a possibly raced code error.
              final recovery = await _recoverRegistration(
                api,
                email,
                password,
                deviceId,
              );
              if (recovery == _RegistrationRecovery.authenticated) return;
              _showUnknownRegistrationMessage();
              return;
            }
            if (mounted) {
              _navigate(
                _AuthStep.verifyRegistration,
                message:
                    'Code expired or invalid. Request another code and try again.',
              );
            }
          } on TimeoutException {
            await _recoverUnknownRegistration(api, email, password, deviceId);
          } on ApiRequestTimeoutException {
            await _recoverUnknownRegistration(api, email, password, deviceId);
          } on IOException {
            await _recoverUnknownRegistration(api, email, password, deviceId);
          }
          if (issued != null) await _accept(issued);
        case _AuthStep.login:
          try {
            final tokens = await api.login(
              email: email,
              password: password,
              deviceId: await widget.authDeviceIdStore.readOrCreateDeviceId(),
            );
            await _accept(tokens);
          } on ApiHttpException catch (error) {
            if (error.errorCode != 'email_unverified') rethrow;
            String? notice;
            try {
              await api.resendVerification(email);
              _startResendCooldown();
              notice =
                  'Check your inbox and spam folder for an 8-digit code. Codes expire in 15 minutes.';
            } catch (_) {
              notice =
                  'Could not request a new code. If you already have a valid code, enter it below; otherwise request another.';
            }
            if (mounted) {
              _navigate(_AuthStep.verifyRegistration, message: notice);
            }
          }
        case _AuthStep.forgot:
          await api.forgotPassword(email);
          _password.clear();
          _startResendCooldown();
          if (mounted) {
            _navigate(
              _AuthStep.reset,
              message:
                  'If this email is eligible, check your inbox and spam folder for a reset code. Codes expire in 15 minutes.',
            );
          }
        case _AuthStep.reset:
          try {
            await api.resetPassword(
              email: email,
              code: _code.text,
              password: password,
              confirmPassword: _confirmPassword.text,
            );
          } on ApiHttpException catch (error) {
            if (!_resetResultUnknown ||
                error.errorCode != 'invalid_or_expired_code') {
              rethrow;
            }
            _showUnknownResetMessage();
            return;
          } on TimeoutException {
            _showUnknownResetMessage();
            return;
          } on ApiRequestTimeoutException {
            _showUnknownResetMessage();
            return;
          } on IOException {
            _showUnknownResetMessage();
            return;
          }
          _password.clear();
          _confirmPassword.clear();
          if (mounted) {
            _navigate(
              _AuthStep.login,
              message: 'Password reset. Sign in with your new password.',
            );
          }
      }
    });
  }

  Future<_RegistrationRecovery> _recoverRegistration(
    MomCozyAuthApiRepository api,
    String email,
    String password,
    String deviceId,
  ) async {
    late final MomCozyAuthTokenResponse tokens;
    try {
      tokens = await api.login(
        email: email,
        password: password,
        deviceId: deviceId,
      );
    } on ApiHttpException catch (error) {
      if (error.errorCode == 'authentication_required' ||
          error.errorCode == 'email_unverified') {
        return _RegistrationRecovery.notCommitted;
      }
      return _RegistrationRecovery.unknown;
    } on TimeoutException {
      return _RegistrationRecovery.unknown;
    } on ApiRequestTimeoutException {
      return _RegistrationRecovery.unknown;
    } on IOException {
      return _RegistrationRecovery.unknown;
    }
    await _accept(tokens);
    return _RegistrationRecovery.authenticated;
  }

  Future<void> _recoverUnknownRegistration(
    MomCozyAuthApiRepository api,
    String email,
    String password,
    String deviceId,
  ) async {
    _registrationResultUnknown = true;
    if (await _recoverRegistration(api, email, password, deviceId) ==
        _RegistrationRecovery.authenticated) {
      return;
    }
    _showUnknownRegistrationMessage();
  }

  void _showUnknownRegistrationMessage() {
    if (!mounted) return;
    setState(() {
      _error =
          'We could not confirm whether your account was created. Reconnect and try again, or sign in with the password you chose.';
    });
  }

  void _showUnknownResetMessage() {
    _resetResultUnknown = true;
    if (!mounted) return;
    setState(() {
      _error =
          'We could not confirm whether your password was reset. Try signing in with the new password. If it does not work, request another reset code.';
    });
  }

  Future<void> _resend() => _run(() async {
    if (_email.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your email first.';
      });
      return;
    }
    final api = widget.runtimeController.runtime.authRepository;
    if (_step == _AuthStep.verifyRegistration) {
      await api.resendVerification(_email.text);
    } else {
      await api.forgotPassword(_email.text);
    }
    _startResendCooldown();
    if (mounted) {
      setState(() {
        _message = _step == _AuthStep.verifyRegistration
            ? 'Check your inbox and spam folder for an 8-digit code. Codes expire in 15 minutes.'
            : 'If this email is eligible, check your inbox and spam folder. A request within 60 seconds may not send another code.';
      });
    }
  });

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
  if (error is ApiHttpException) {
    return switch (error.errorCode) {
      'auth_email_unavailable' =>
        'Email verification is temporarily unavailable. Please try again later.',
      'invalid_or_expired_code' =>
        'This code is invalid or expired. Request a new code and try again.',
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
