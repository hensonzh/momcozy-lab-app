import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/primary_tab_activity.dart';

import '../../../app/momcozy_api_runtime.dart';
import '../../../features/auth/presentation/auth_page.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/design_system/momcozy_motion.dart';
import '../../../shared/design_system/momcozy_text_roles.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';

/// The fifth tab is an account surface. Health records belong in
/// Me or Baby; More must not become another clinical profile store.
class MorePage extends StatefulWidget {
  const MorePage({super.key, required this.onLogout, this.onDeleteAccount});

  final Future<void> Function()? onLogout;
  final Future<void> Function()? onDeleteAccount;

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  MomCozyApiRuntime? _runtime;
  Future<({String name, String email})>? _identity;
  ({String name, String email})? _cachedIdentity;
  final _tabRefresh = PrimaryTabRefresh(4);
  bool _deleting = false;
  String? _deleteMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    final refresh = _tabRefresh.shouldRefresh(context, runtime.now());
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _cachedIdentity = null;
      _identity = _loadIdentityAndCache(runtime);
    } else if (refresh) {
      _identity = _loadIdentityAndCache(runtime);
    }
  }

  Future<({String name, String email})> _loadIdentityAndCache(
    MomCozyApiRuntime runtime,
  ) async {
    final value = await _loadIdentity(runtime);
    if (mounted && identical(runtime, _runtime)) {
      setState(() => _cachedIdentity = value);
    }
    return value;
  }

  Future<({String name, String email})> _loadIdentity(
    MomCozyApiRuntime runtime,
  ) async {
    // Each field can still render if the other existing endpoint is unavailable.
    final values = await Future.wait([
      runtime.agentHubProfileRepository
          .fetchGreetingProfile()
          .then((profile) => profile.displayName)
          .catchError((_) => ''),
      runtime.authRepository
          .account()
          .then((account) => account['email'] as String? ?? '')
          .catchError((_) => ''),
    ]);
    return (name: values[0], email: values[1]);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({String name, String email})>(
        future: _identity,
        initialData: _cachedIdentity,
        builder: (context, snapshot) => _content(
          context,
          name: snapshot.data?.name ?? '',
          email: snapshot.data?.email ?? '',
          loading:
              snapshot.data == null &&
              snapshot.connectionState != ConnectionState.done,
        ),
      );

  Widget _content(
    BuildContext context, {
    required String name,
    required String email,
    required bool loading,
  }) {
    return ColoredBox(
      key: const ValueKey('route-page-/more'),
      color: MomHomeTokens.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MomHomeTokens.inset,
          vertical: 24,
        ),
        children: [
          Semantics(
            header: true,
            child: Text(
              'More',
              style: MomHomeTokens.text(26, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 22),
          Semantics(
            label: 'Account information',
            child: _AccountCard(name: name, email: email, loading: loading),
          ),
          const SizedBox(height: 16),
          TextButton(
            key: const ValueKey('more-logout'),
            onPressed: loading || _deleting || widget.onLogout == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await widget.onLogout!();
                    } catch (_) {
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          elevation: 0,
                          backgroundColor: MomHomeTokens.ink,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: const BorderSide(color: MomHomeTokens.border),
                          ),
                          content: Text(
                            'Sign-out could not finish. Reconnect and try again.',
                            style: MomHomeTokens.text(
                              13,
                              color: MomHomeTokens.surface,
                              height: 18 / 13,
                            ),
                          ),
                        ),
                      );
                    }
                    if (context.mounted) context.go('/login');
                  },
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              backgroundColor: MomHomeTokens.surface,
              foregroundColor: MomHomeTokens.ink,
              disabledForegroundColor: MomHomeTokens.secondary.withValues(
                alpha: .4,
              ),
              side: const BorderSide(color: MomHomeTokens.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size.fromHeight(52),
              textStyle: MomHomeTokens.text(14, weight: FontWeight.w600),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, size: 19),
                SizedBox(width: 12),
                Text('Sign out'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MomHomeSurface(
            gradient: const LinearGradient(
              colors: [MomHomeTokens.surface, MomHomeTokens.surface],
            ),
            border: MomHomeTokens.border,
            child: Padding(
              padding: const EdgeInsets.all(MomHomeTokens.inset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
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
                    style: MomHomeTokens.text(
                      12,
                      color: MomHomeTokens.secondary,
                      height: 1.5,
                    ).merge(MomCozyTextRoles.paragraphOf(context)),
                  ),
                  TextButton(
                    key: const ValueKey('account-delete'),
                    onPressed: _deleting || widget.onDeleteAccount == null
                        ? null
                        : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: MomCozyColors.danger,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      textStyle: MomHomeTokens.text(
                        13,
                        weight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Request account deletion'),
                  ),
                  if (_deleting)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Deleting account',
                    ),
                  if (_deleteMessage != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _deleteMessage!,
                        key: const ValueKey('account-message'),
                        style: MomHomeTokens.text(
                          13,
                          color: MomHomeTokens.secondary,
                          height: 1.55,
                        ).merge(MomCozyTextRoles.paragraphOf(context)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    if (_deleting || widget.onDeleteAccount == null) return;
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
    setState(() {
      _deleting = true;
      _deleteMessage = null;
    });
    try {
      await widget.onDeleteAccount!();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Account access removed. Your data erasure request is pending.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _deleteMessage = accountAuthErrorText(error));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.email,
    required this.loading,
  });
  final String name;
  final String email;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isNotEmpty ? name.trim() : 'My account';
    final initial = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final avatar = ExcludeSemantics(
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MomHomeTokens.surface,
        ),
        alignment: Alignment.center,
        child: Text(
          initial.isNotEmpty
              ? initial
              : loading
              ? '…'
              : 'M',
          textScaler: TextScaler.noScaling,
          style: MomHomeTokens.text(
            17,
            weight: FontWeight.w700,
            color: MomHomeTokens.rose,
            height: 20 / 17,
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
            constraints.maxWidth < 280;
        final nameText = Text(
          displayName,
          style: MomHomeTokens.text(18, weight: FontWeight.w700, height: 1.3),
        );
        return MomHomeSurface(
          gradient: MomHomeTokens.milk,
          backgroundDecoration: MomCardDecoration.account,
          child: Padding(
            padding: const EdgeInsets.all(MomHomeTokens.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (largeText) ...[
                  avatar,
                  const SizedBox(height: 12),
                  nameText,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: nameText),
                    ],
                  ),
                const SizedBox(height: 10),
                Text(
                  loading
                      ? 'Loading account…'
                      : email.isEmpty
                      ? 'Manage your account information'
                      : email,
                  style: MomHomeTokens.text(
                    12,
                    color: MomHomeTokens.secondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
