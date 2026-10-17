import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';

/// Do not render an unauthenticated app when secure session restoration fails.
/// Retrying keeps the saved session intact; only a successful load mounts it.
class MomCozyBootstrap extends StatefulWidget {
  const MomCozyBootstrap({super.key, required this.load});

  final Future<Widget> Function() load;

  @override
  State<MomCozyBootstrap> createState() => _MomCozyBootstrapState();
}

class _MomCozyBootstrapState extends State<MomCozyBootstrap> {
  Widget? _app;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final app = await widget.load();
      if (mounted) setState(() => _app = app);
    } catch (error) {
      // Keep the stored session and its credentials untouched. Never fall back
      // to a demo or anonymous session when secure storage is unavailable.
      debugPrint(
        'Momcozy startup failed: '
        '${error is MomCozySessionPersistenceException ? error : error.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const CircularProgressIndicator(
                      key: ValueKey('startup-loading'),
                    )
                  : Column(
                      key: const ValueKey('startup-error'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 38),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to open Momcozy securely',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your saved sign-in has not been cleared. Check your device and try again, or contact support if this continues.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const ValueKey('startup-retry'),
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
