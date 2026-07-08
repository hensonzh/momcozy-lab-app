import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

class MomCozyAuthPage extends StatefulWidget {
  const MomCozyAuthPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
    this.redirectTo,
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
  });

  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  final String? redirectTo;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;

  @override
  State<MomCozyAuthPage> createState() => _MomCozyAuthPageState();
}

class _MomCozyAuthPageState extends State<MomCozyAuthPage> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final FocusNode _inviteCodeFocusNode = FocusNode();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _inviteCodeFocusNode.dispose();
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _errorText!,
                      key: const ValueKey('auth-error-text'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('auth-invite-code-field'),
                    controller: _inviteCodeController,
                    focusNode: _inviteCodeFocusNode,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: '邀请码',
                      hintText: '请输入邀请码',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    onSubmitted: (_) => _submitInvite(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('auth-invite-login-button'),
                    onPressed: _submitting ? null : _submitInvite,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key_rounded),
                    label: const Text('邀请码登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitInvite() async {
    if (_submitting) return;
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      setState(() {
        _errorText = '请输入邀请码';
      });
      _inviteCodeFocusNode.requestFocus();
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final runtime = widget.runtimeController.runtime;
      final deviceId = await widget.authDeviceIdStore.readOrCreateDeviceId();
      final tokens = await runtime.authRepository.inviteLogin(
        inviteCode: inviteCode,
        deviceId: deviceId,
      );
      await _completeAuth(tokens, runtime);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _authErrorText(error, inviteLogin: true);
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
}

String _authErrorText(Object error, {bool inviteLogin = false}) {
  if (error is ApiHttpException) {
    if (inviteLogin && error.errorCode == 'permission_denied') {
      return '邀请码已在其他设备使用过';
    }
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
