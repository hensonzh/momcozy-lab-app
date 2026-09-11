import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/google_sign_in_gateway.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'auth_page.dart';
import '../../../shared/widgets/product_feedback.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: MomCozyPageBody(
      child: FutureBuilder<Map<String, Object?>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ProductLoadingView();
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              child: ProductEmptyView(
                title: accountAuthErrorText(snapshot.error!),
                icon: Icons.error_outline_rounded,
                action: TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Retry'),
                ),
              ),
            );
          }
          final profile = snapshot.data!;
          final providers =
              (profile['auth_providers'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              const <String>[];
          return ListView(
            padding: MomCozyInsets.page,
            children: [
              MomCozySurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      profile['email'] as String? ?? 'Internal test account',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: MomCozySpacing.compact),
                    Text(
                      profile['email_verified'] == true
                          ? 'Email verified'
                          : 'Email not verified',
                    ),
                    Text('Account status: ${profile['account_status']}'),
                    Text('Sign-in methods: ${providers.join(', ')}'),
                  ],
                ),
              ),
              const SizedBox(height: MomCozySpacing.card),
              if (_message != null)
                Text(_message!, key: const ValueKey('account-message')),
              if (_busy) const LinearProgressIndicator(),
              if (providers.contains('email') && !providers.contains('google'))
                OutlinedButton(
                  key: const ValueKey('account-link-google'),
                  onPressed: _busy ? null : _linkGoogle,
                  child: const Text('Link Google account'),
                ),
              OutlinedButton(
                key: const ValueKey('account-sign-out'),
                onPressed: _busy ? null : _logout,
                child: const Text('Sign out'),
              ),
              const SizedBox(height: MomCozySpacing.section),
              MomCozySurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Delete account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Your access will end immediately. Account identifiers are removed and a request is created to erase associated data. Some records may require retention.',
                    ),
                    TextButton(
                      key: const ValueKey('account-delete'),
                      onPressed: _busy ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: MomCozyColors.danger,
                      ),
                      child: const Text('Request account deletion'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _linkGoogle() async {
    var password = '';
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Confirm your password'),
        content: TextField(
          key: const ValueKey('account-link-password'),
          onChanged: (value) => password = value,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password),
            child: const Text('Continue'),
          ),
        ],
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
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete your account?'),
        content: const Text(
          'You will be signed out on every device and lose access to this account. Data erasure is processed separately. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          MomCozyPrimaryButton(
            destructive: true,
            key: const ValueKey('account-confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
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
