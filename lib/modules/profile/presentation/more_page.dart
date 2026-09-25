import '../../../features/notifications/presentation/notification_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/momcozy_api_runtime.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/widgets/mom_settings_row.dart';

/// The fifth tab is an account and service surface.  Health records belong in
/// Me, Baby, or the service episode; More must not become another clinical
/// profile store.
class MorePage extends StatefulWidget {
  const MorePage({super.key, required this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  MomCozyApiRuntime? _runtime;
  Future<({String name, String email})>? _identity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = MomCozyRuntimeScope.of(context);
    if (!identical(runtime, _runtime)) {
      _runtime = runtime;
      _identity = _loadIdentity(runtime);
    }
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
        builder: (context, snapshot) => _content(
          context,
          name: snapshot.data?.name ?? '',
          email: snapshot.data?.email ?? '',
          loading: snapshot.connectionState != ConnectionState.done,
        ),
      );

  Widget _content(
    BuildContext context, {
    required String name,
    required String email,
    required bool loading,
  }) {
    final unread =
        NotificationScope.maybeOf(context)?.inbox?.state.unreadCount ?? 0;
    return ColoredBox(
      key: const ValueKey('route-page-/more'),
      color: MomHomeTokens.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MomHomeTokens.inset,
          vertical: 24,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'More',
                    style: MomHomeTokens.text(
                      22,
                      weight: FontWeight.w700,
                      height: 26 / 22,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/privacy'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  foregroundColor: MomHomeTokens.secondary,
                  textStyle: MomHomeTokens.text(12, height: 14 / 12),
                ),
                child: const Text('Privacy'),
              ),
            ],
          ),
          const SizedBox(height: MomHomeTokens.gap),
          Text(
            'Care for yourself and stay in control of your support',
            style: MomHomeTokens.text(
              12,
              color: MomHomeTokens.secondary,
              height: 14 / 12,
            ),
          ),
          const SizedBox(height: MomHomeTokens.gap),
          Semantics(
            label: 'Account information',
            child: _AccountCard(name: name, email: email, loading: loading),
          ),
          const SizedBox(height: MomHomeTokens.gap),
          const _SectionTitle('Everyday settings'),
          const SizedBox(height: MomHomeTokens.gap),
          Material(
            color: MomHomeTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
              side: const BorderSide(color: MomHomeTokens.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: MomCardBackground(
              decoration: MomCardDecoration.utility,
              child: Column(
                children: [
                  MomSettingsRow(
                    title: 'Account settings',
                    subtitle: 'Sign-in methods and account management',
                    onTap: () => context.push('/account'),
                  ),
                  const Divider(height: 1, color: MomHomeTokens.border),
                  MomSettingsRow(
                    title: 'Notifications',
                    subtitle: 'View messages and service reminders',
                    unreadCount: unread,
                    onTap: () => context.push('/notifications?from=/more'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MomHomeTokens.gap),
          const _SectionTitle('Expert care'),
          const SizedBox(height: MomHomeTokens.gap),
          MomExpertPlanEntry(
            settingsLayout: true,
            title: 'Expert support',
            trailingGap: MomHomeTokens.gap,
            onTap: () => context.push('/services'),
          ),
          const SizedBox(height: MomHomeTokens.gap),
          TextButton(
            key: const ValueKey('more-logout'),
            onPressed: loading || widget.onLogout == null
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
              foregroundColor: MomHomeTokens.secondary,
              disabledForegroundColor: MomHomeTokens.secondary.withValues(
                alpha: .4,
              ),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: MomHomeTokens.text(13, height: 16 / 13),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: MomHomeTokens.text(18, weight: FontWeight.w700, height: 30 / 18),
    ),
  );
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
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: MomHomeTokens.text(
            19,
            weight: FontWeight.w700,
            height: 25 / 19,
          ),
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Text(
            loading
                ? 'Loading account…'
                : email.isEmpty
                ? 'Manage your account information'
                : email,
            style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical =
            constraints.maxWidth < 328 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return MomHomeSurface(
          gradient: MomHomeTokens.milk,
          backgroundDecoration: MomCardDecoration.account,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MomHomeTokens.inset,
              vertical: 22,
            ),
            child: vertical
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(height: MomHomeTokens.gap),
                      identity,
                    ],
                  )
                : Row(
                    children: [
                      avatar,
                      const SizedBox(width: MomHomeTokens.gap),
                      Expanded(child: identity),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
