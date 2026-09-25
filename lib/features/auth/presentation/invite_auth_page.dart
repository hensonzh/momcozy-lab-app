import 'dart:async';
import 'auth_login_chrome.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';

import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_last_invite_code.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/text/english_error_text.dart';

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
    return Theme(
      data: authLoginTheme(Theme.of(context)),
      child: Scaffold(
        body: MomCozyPageBody(
          maxWidth: MomCozyLayout.maxAppWidth,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthLoginHeader(
                    title: 'Welcome',
                    subtitle: 'Continue with an invitation code',
                    compact: true,
                  ),
                  MomSettingsCard(
                    children: [
                      if (_errorText != null)
                        AuthNotice(
                          _errorText!,
                          error: true,
                          textKey: const ValueKey('auth-error-text'),
                        ),
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
                          labelText: 'Invitation code',
                          hintText: 'Enter your invitation code',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: const Icon(Icons.key_rounded),
                        ),
                        onSubmitted: (_) => _submitInvite(),
                      ),
                      FilledButton(
                        key: const ValueKey('auth-invite-login-button'),
                        onPressed: _submitting ? null : _submitInvite,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in with code'),
                      ),
                    ],
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
        _errorText = 'Enter your invitation code';
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
      _showError(
        'Could not read this device\'s sign-in ID. Restart the app and try again.',
      );
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
      _showError(
        'Your account was verified, but we could not save your sign-in on this device. Restart the app and try again.',
      );
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
      _showError('Sign-in was saved. Restart the app to continue.');
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
      return 'This invitation code has already been used on another device.';
    }
    return englishErrorText(
      error.errorMessage,
      fallback: 'Could not verify your account. Please try again later.',
    );
  }
  return 'Could not verify your account. Please try again later.';
}
