import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/google_sign_in_gateway.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'auth_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/momcozy_text_roles.dart';

class MomCozyAccountPage extends StatefulWidget {
  const MomCozyAccountPage({
    super.key,
    required this.runtimeController,
    required this.sessionStore,
    this.googleSignIn = const NativeGoogleSignInGateway(),
  });
  final MomCozyRuntimeController runtimeController;
  final MomCozySessionStore sessionStore;
  final GoogleSignInGateway googleSignIn;
  @override
  State<MomCozyAccountPage> createState() => _MomCozyAccountPageState();
}

class _MomCozyAccountPageState extends State<MomCozyAccountPage> {
  late Future<Map<String, Object?>> _profile;
  bool _busy = false;
  String? _message;
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

  Widget _surface(List<Widget> children, {bool quiet = false}) =>
      MomHomeSurface(
        gradient: LinearGradient(
          colors: [
            quiet ? MomHomeTokens.background : MomHomeTokens.surface,
            quiet ? MomHomeTokens.background : MomHomeTokens.surface,
          ],
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
                'google' => 'Google',
                _ => 'Other sign-in method',
              }, style: MomHomeTokens.text(14, weight: FontWeight.w700)),
              Text(
                'Connected',
                style: MomHomeTokens.text(12, color: MomHomeTokens.teal),
              ),
            ],
          ),
        if (providers.isEmpty)
          Text('No sign-in methods available.', style: _paragraph(context)),
        if (providers.contains('email') && !providers.contains('google'))
          OutlinedButton(
            key: const ValueKey('account-link-google'),
            onPressed: _busy ? null : _linkGoogle,
            child: const Text(
              'Link Google account',
              textAlign: TextAlign.center,
            ),
          ),
        if (_busy)
          const LinearProgressIndicator(semanticsLabel: 'Updating account'),
      ]),
      if (_message != null)
        Semantics(
          liveRegion: true,
          child: _surface([
            Text(
              _message!,
              key: const ValueKey('account-message'),
              style: _paragraph(context),
            ),
          ]),
        ),
      TextButton(
        key: const ValueKey('account-sign-out'),
        onPressed: _busy ? null : _logout,
        child: const Text('Sign out'),
      ),
      _surface([
        Text(
          'Delete account',
          style: MomHomeTokens.text(
            14,
            weight: FontWeight.w700,
            color: MomCozyColors.danger,
          ),
        ),
        Text(
          'Your access will end immediately. Account identifiers are removed and a request is created to erase associated data. Some records may require retention.',
          style: _paragraph(context),
        ),
        TextButton(
          key: const ValueKey('account-delete'),
          onPressed: _busy ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: MomCozyColors.danger),
          child: const Text(
            'Request account deletion',
            textAlign: TextAlign.center,
          ),
        ),
      ], quiet: true),
    ];
  }

  Future<void> _linkGoogle() async {
    var password = '';
    final entered = await showDialog<String>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => MomSettingsDialog(
        title: 'Confirm your password',
        content: TextField(
          key: const ValueKey('account-link-password'),
          onChanged: (value) => password = value,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: MomHomeTokens.text(16),
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.pop(context, password),
          child: const Text('Continue'),
        ),
        onCancel: () => Navigator.pop(context),
      ),
    );
    if (!mounted || entered == null || entered.isEmpty) return;
    await _run(() async {
      final idToken = await widget.googleSignIn.signIn();
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _message = 'Google sign-in was canceled.';
          });
        }
        return;
      }
      await widget.runtimeController.runtime.authRepository.linkGoogle(
        idToken: idToken,
        password: entered,
      );
      if (mounted) {
        setState(() {
          _message = 'Google account linked.';
          _reload();
        });
      }
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => MomSettingsDialog(
        title: 'Delete your account?',
        content: const Text(
          'You will be signed out on every device and lose access to this account. Data erasure is processed separately. This cannot be undone.',
        ),
        primaryAction: FilledButton(
          key: const ValueKey('account-confirm-delete'),
          style: FilledButton.styleFrom(backgroundColor: MomCozyColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete account', textAlign: TextAlign.center),
        ),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      await widget.runtimeController.runtime.authRepository.deleteAccount();
      await widget.runtimeController.logout(
        sessionStore: widget.sessionStore,
        revokeRemote: false,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Account access removed. Your data erasure request is pending.',
          ),
        ),
      );
    });
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = accountAuthErrorText(error);
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
}
