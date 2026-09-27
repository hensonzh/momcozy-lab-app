import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'auth_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/design_system/momcozy_text_roles.dart';

class MomCozyAccountPage extends StatefulWidget {
  const MomCozyAccountPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
  });
  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  @override
  State<MomCozyAccountPage> createState() => _MomCozyAccountPageState();
}

class _MomCozyAccountPageState extends State<MomCozyAccountPage> {
  late Future<Map<String, Object?>> _profile;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _profile = widget.runtimeController.runtime.authRepository.account();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 72
            : 56,
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: SvgPicture.asset(
                  'assets/images/me_baby_overview/icons/back-button.svg',
                  width: 36,
                  height: 32,
                ),
              )
            : null,
      ),
      body: ClipRect(
        child: MomCozyPageBody(
          child: FutureBuilder<Map<String, Object?>>(
            future: _profile,
            builder: (context, snapshot) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MomHomeTokens.gap,
                children: [
                  Text(
                    'Your account, cared for.',
                    style: MomHomeTokens.text(
                      12,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    _surface([
                      Text(
                        'Loading account…',
                        style: MomHomeTokens.text(16, weight: FontWeight.w700),
                      ),
                      Text(
                        'Your account details will appear here.',
                        style: MomHomeTokens.text(
                          12,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                      const LinearProgressIndicator(
                        semanticsLabel: 'Loading account',
                      ),
                    ])
                  else if (snapshot.hasError)
                    _surface([
                      Text(
                        'Account unavailable',
                        style: MomHomeTokens.text(18, weight: FontWeight.w700),
                      ),
                      Text(
                        accountAuthErrorText(snapshot.error!),
                        style: _paragraph(context),
                      ),
                      FilledButton(
                        onPressed: () => setState(_reload),
                        child: const Text('Retry'),
                      ),
                    ])
                  else
                    ..._accountContent(context, snapshot.data!),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  TextStyle _paragraph(BuildContext context) => MomHomeTokens.text(
    13,
    color: MomHomeTokens.secondary,
    height: 1.55,
  ).merge(MomCozyTextRoles.paragraphOf(context));

  Widget _surface(List<Widget> children) => MomHomeSurface(
    gradient: const LinearGradient(
      colors: [MomHomeTokens.surface, MomHomeTokens.surface],
    ),
    border: MomHomeTokens.border,
    child: Padding(
      padding: const EdgeInsets.all(MomHomeTokens.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MomHomeTokens.gap,
        children: children,
      ),
    ),
  );

  Widget _status(String label, {required bool positive}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: positive ? MomHomeTokens.mint : MomHomeTokens.neutralSurface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: MomHomeTokens.text(
        11,
        weight: FontWeight.w700,
        color: positive ? MomHomeTokens.teal : MomHomeTokens.secondary,
      ),
    ),
  );

  List<Widget> _accountContent(
    BuildContext context,
    Map<String, Object?> profile,
  ) {
    final providers =
        (profile['auth_providers'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    return [
      MomHomeSurface(
        gradient: MomHomeTokens.milk,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MomHomeTokens.inset,
            vertical: 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MomHomeTokens.gap,
            children: [
              Text(
                'Account details',
                style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
              ),
              Text(
                profile['email'] as String? ?? 'Internal test account',
                style: MomHomeTokens.text(18, weight: FontWeight.w700),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _status(
                    profile['email_verified'] == true
                        ? 'Email verified'
                        : 'Email not verified',
                    positive: profile['email_verified'] == true,
                  ),
                  _status(switch (profile['account_status']) {
                    'active' => 'Active',
                    'deletion_pending' => 'Deletion requested',
                    'disabled' => 'Disabled',
                    _ => 'Status unavailable',
                  }, positive: profile['account_status'] == 'active'),
                ],
              ),
            ],
          ),
        ),
      ),
      Semantics(
        header: true,
        child: Text(
          'Sign-in methods',
          style: MomHomeTokens.text(18, weight: FontWeight.w700),
        ),
      ),
      _surface([
        for (final provider in providers)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Text(switch (provider) {
                'email' => 'Email and password',
                'google' => 'Previous sign-in method (retired)',
                _ => 'Other sign-in method',
              }, style: MomHomeTokens.text(14, weight: FontWeight.w700)),
              Text(
                provider == 'google' ? 'No longer available' : 'Connected',
                style: MomHomeTokens.text(
                  12,
                  color: provider == 'google'
                      ? MomHomeTokens.secondary
                      : MomHomeTokens.teal,
                ),
              ),
            ],
          ),
        if (providers.isEmpty)
          Text('No sign-in methods available.', style: _paragraph(context)),
        if (providers.contains('google') &&
            !providers.contains('email') &&
            profile['account_status'] == 'active' &&
            profile['email_verified'] == true &&
            profile['email'] is String)
          Text(
            'This account has no email password. Confirm you can access this inbox before signing out. Then use Forgot your password? on the sign-in page to set one.',
            style: _paragraph(context),
          ),
      ]),
      if (providers.contains('email') && profile['account_status'] == 'active')
        TextButton(
          key: const ValueKey('account-change-password'),
          onPressed: _changePassword,
          child: const Text('Change password'),
        ),
      TextButton(
        key: const ValueKey('account-sign-out'),
        onPressed: _logout,
        child: const Text('Sign out'),
      ),
    ];
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChangePasswordDialog(
        onSubmit:
            widget.runtimeController.runtime.authRepository.changePassword,
      ),
    );
    if (changed != true || !mounted) return;
    try {
      // Changing the password revokes every server session, including this one.
      await widget.runtimeController.logout(
        sessionStore: widget.sessionStore,
        revokeRemote: false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password changed. Sign in again with your new password.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.runtimeController.logout(sessionStore: widget.sessionStore);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Sign-out could not finish on the server or this device. Reconnect and try again.',
          ),
        ),
      );
    }
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.onSubmit});

  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  })
  onSubmit;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmPassword: _confirm.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (error is TimeoutException ||
          error is ApiRequestTimeoutException ||
          error is IOException) {
        // The server may have changed the password and revoked this session.
        // Sign out locally rather than retrying an indeterminate mutation.
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (error is ApiHttpException &&
          error.statusCode == 401 &&
          error.errorCode == 'authentication_required') {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        setState(() {
          _error =
              error is ApiHttpException &&
                  error.errorCode == 'invalid_current_password'
              ? 'Current password is incorrect.'
              : error is ApiHttpException &&
                    error.errorCode == 'validation_failed'
              ? 'Choose a different password and try again.'
              : accountAuthErrorText(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('account-current-password'),
                controller: _current,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              TextFormField(
                key: const ValueKey('account-new-password'),
                controller: _next,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) =>
                    value != null &&
                        value.length >= 8 &&
                        value.length <= 128 &&
                        RegExp('[A-Za-z]').hasMatch(value) &&
                        RegExp('[0-9]').hasMatch(value)
                    ? null
                    : 'Use 8–128 characters with a letter and a number.',
              ),
              TextFormField(
                key: const ValueKey('account-confirm-password'),
                controller: _confirm,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) =>
                    value == _next.text && value != null && value.isNotEmpty
                    ? null
                    : 'Passwords do not match.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'You will be signed out on all devices after changing your password.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('account-change-password-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change password'),
        ),
      ],
    ),
  );
}
