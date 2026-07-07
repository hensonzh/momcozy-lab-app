import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

enum MomCozyAuthMode { login, signup }

const _defaultInviteCode = String.fromEnvironment(
  'MOMCOZY_INVITE_CODE',
  defaultValue: 'MOMCOZY-BETA',
);

class MomCozyAuthPage extends StatefulWidget {
  const MomCozyAuthPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
    this.redirectTo,
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
    this.inviteCode = _defaultInviteCode,
  });

  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  final String? redirectTo;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;
  final String inviteCode;

  @override
  State<MomCozyAuthPage> createState() => _MomCozyAuthPageState();
}

class _MomCozyAuthPageState extends State<MomCozyAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  MomCozyAuthMode _mode = MomCozyAuthMode.login;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<MomCozyAuthMode>(
                      segments: const [
                        ButtonSegment(
                          value: MomCozyAuthMode.login,
                          icon: Icon(Icons.login_rounded),
                          label: Text('登录'),
                        ),
                        ButtonSegment(
                          value: MomCozyAuthMode.signup,
                          icon: Icon(Icons.person_add_alt_1_rounded),
                          label: Text('注册'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _submitting
                          ? null
                          : (next) => setState(() {
                              _mode = next.single;
                              _errorText = null;
                            }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('auth-email-field'),
                      controller: _emailController,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('auth-password-field'),
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.password],
                      obscureText: true,
                      textInputAction: _mode == MomCozyAuthMode.signup
                          ? TextInputAction.next
                          : TextInputAction.done,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.password_rounded),
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_mode == MomCozyAuthMode.signup) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('auth-display-name-field'),
                        controller: _displayNameController,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.badge_outlined),
                          labelText: '昵称',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        key: const ValueKey('auth-error-text'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('auth-submit-button'),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _mode == MomCozyAuthMode.login
                                  ? Icons.login_rounded
                                  : Icons.person_add_alt_1_rounded,
                            ),
                      label: Text(_mode == MomCozyAuthMode.login ? '登录' : '注册'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('auth-invite-login-button'),
                      onPressed: _submitting ? null : _submitInvite,
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('邀请码体验'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final runtime = widget.runtimeController.runtime;
      final auth = runtime.authRepository;
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final tokens = _mode == MomCozyAuthMode.login
          ? await auth.login(email: email, password: password)
          : await auth.signup(
              email: email,
              password: password,
              displayName: _displayNameController.text,
            );
      await _completeAuth(tokens, runtime);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _authErrorText(error);
      });
    }
  }

  Future<void> _submitInvite() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final runtime = widget.runtimeController.runtime;
      final deviceId = await widget.authDeviceIdStore.readOrCreateDeviceId();
      final tokens = await runtime.authRepository.inviteLogin(
        inviteCode: widget.inviteCode,
        deviceId: deviceId,
      );
      await _completeAuth(tokens, runtime);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _authErrorText(error);
      });
    }
  }

  Future<void> _completeAuth(
    MomCozyAuthTokenResponse tokens,
    MomCozyApiRuntime runtime,
  ) async {
    final session = tokens.toSession(
      babyId: runtime.babyId,
      locale: runtime.locale,
    );
    await widget.sessionStore.writeSession(session);
    widget.runtimeController.replaceSession(session);
    if (!mounted) return;
    context.go(_safeRedirect(widget.redirectTo) ?? '/');
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 3 || !trimmed.contains('@')) return '请输入邮箱';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (_mode == MomCozyAuthMode.signup && password.length < 8) {
      return '密码至少 8 位';
    }
    if (password.isEmpty) return '请输入密码';
    return null;
  }
}

String _authErrorText(Object error) {
  if (error is ApiHttpException) {
    return error.errorMessage?.isNotEmpty == true
        ? error.errorMessage!
        : '认证失败，请稍后重试。';
  }
  return '认证失败，请稍后重试。';
}

String? _safeRedirect(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path;
  if (path.isEmpty || !path.startsWith('/')) return null;
  if (path == '/login') return null;
  return uri.toString();
}
