import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

class MomCozyInviteAuthPage extends StatefulWidget {
  const MomCozyInviteAuthPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
    this.authDeviceIdStore = const FlutterSecureMomCozyAuthDeviceIdStore(),
    this.lastInviteCodeStore = const FlutterSecureMomCozyLastInviteCodeStore(),
  });

  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  final MomCozyAuthDeviceIdStore authDeviceIdStore;
  final MomCozyLastInviteCodeStore lastInviteCodeStore;

  @override
  State<MomCozyInviteAuthPage> createState() => _MomCozyInviteAuthPageState();
}

class _MomCozyInviteAuthPageState extends State<MomCozyInviteAuthPage> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final FocusNode _inviteCodeFocusNode = FocusNode();
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastInviteCode());
  }

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
      body: MomCozyPageBody(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: MomCozyIconSizes.feature,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '欢迎使用',
                    textAlign: TextAlign.center,
                    style: MomCozyTypography.pageTitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '使用邀请码继续',
                    textAlign: TextAlign.center,
                    style: MomCozyTypography.secondaryText,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: MomCozySpacing.card),
                    Text(
                      _errorText!,
                      key: const ValueKey('auth-error-text'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: MomCozySpacing.card),
                  TextField(
                    key: const ValueKey('auth-invite-code-field'),
                    controller: _inviteCodeController,
                    focusNode: _inviteCodeFocusNode,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: '邀请码',
                      hintText: '请输入邀请码',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: const Icon(Icons.key_rounded),
                    ),
                    onSubmitted: (_) => _submitInvite(),
                  ),
                  const SizedBox(height: MomCozySpacing.card),
                  MomCozyPrimaryButton(
                    key: const ValueKey('auth-invite-login-button'),
                    onPressed: _submitting ? null : _submitInvite,
                    loading: _submitting,
                    child: const Text('邀请码登录'),
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

    final runtime = widget.runtimeController.runtime;
    final String deviceId;
    try {
      deviceId = await widget.authDeviceIdStore.readOrCreateDeviceId();
    } catch (error, stackTrace) {
      _recordLocalAuthFailure(
        runtime,
        operation: 'read_auth_device_id',
        error: error,
        stackTrace: stackTrace,
      );
      _showError('无法读取本机登录标识。请重启 App 后重试。');
      return;
    }

    final MomCozyAuthTokenResponse tokens;
    try {
      tokens = await runtime.authRepository.inviteLogin(
        inviteCode: inviteCode,
        deviceId: deviceId,
      );
    } catch (error) {
      _showError(_authErrorText(error, inviteLogin: true));
      return;
    }

    final session = tokens.toSession(
      babyId: runtime.babyId,
      locale: runtime.locale,
    );
    try {
      await widget.runtimeController.saveAuthenticatedSession(
        session,
        sessionStore: widget.sessionStore,
      );
    } catch (error, stackTrace) {
      _recordLocalAuthFailure(
        runtime,
        operation: 'persist_session',
        error: error,
        stackTrace: stackTrace,
      );
      _showError('账号认证已通过，但无法保存本机登录状态。请重启 App 后重试。');
      return;
    }

    await _rememberInviteCode(inviteCode, runtime);
    try {
      widget.runtimeController.replaceSession(session);
    } catch (error, stackTrace) {
      _recordLocalAuthFailure(
        runtime,
        operation: 'activate_session',
        error: error,
        stackTrace: stackTrace,
      );
      _showError('登录状态已保存，请重启 App 继续。');
    }
  }

  Future<void> _loadLastInviteCode() async {
    try {
      final inviteCode = await widget.lastInviteCodeStore.readLastInviteCode();
      if (!mounted) return;
      final restored = trimmedSessionValue(inviteCode);
      if (restored == null || _inviteCodeController.text.isNotEmpty) return;
      _inviteCodeController.value = TextEditingValue(
        text: restored,
        selection: TextSelection.collapsed(offset: restored.length),
      );
    } catch (error, stackTrace) {
      widget.runtimeController.runtime.observability.recordNonFatal(
        error,
        stackTrace: stackTrace,
        context: const {
          'feature': 'auth',
          'operation': 'read_last_invite_code',
        },
      );
    }
  }

  Future<void> _rememberInviteCode(
    String inviteCode,
    MomCozyApiRuntime runtime,
  ) async {
    try {
      await widget.lastInviteCodeStore.writeLastInviteCode(inviteCode);
    } catch (error, stackTrace) {
      runtime.observability.recordNonFatal(
        error,
        stackTrace: stackTrace,
        context: const {
          'feature': 'auth',
          'operation': 'write_last_invite_code',
        },
      );
    }
  }

  void _recordLocalAuthFailure(
    MomCozyApiRuntime runtime, {
    required String operation,
    required Object error,
    required StackTrace stackTrace,
  }) {
    runtime.observability.recordNonFatal(
      _SanitizedLocalAuthFailure(
        operation: operation,
        causeType: error.runtimeType.toString(),
      ),
      stackTrace: stackTrace,
      context: {'feature': 'auth', 'operation': operation},
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorText = message;
    });
  }
}

class _SanitizedLocalAuthFailure implements Exception {
  const _SanitizedLocalAuthFailure({
    required this.operation,
    required this.causeType,
  });

  final String operation;
  final String causeType;

  @override
  String toString() {
    return 'Local auth failure(operation: $operation, causeType: $causeType)';
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
