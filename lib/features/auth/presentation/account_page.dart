import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
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
      TextButton(
        key: const ValueKey('account-sign-out'),
        onPressed: _logout,
        child: const Text('Sign out'),
      ),
    ];
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
